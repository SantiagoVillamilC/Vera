import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/format/saludo.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/barra_vera.dart';
import 'package:vera/core/widgets/cargando_vera.dart';

import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/marca_vera.dart';
import 'package:vera/core/widgets/adornos_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/home/presentation/movimientos_tab.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Saludo cuando no hay nombre guardado.
const saludoGenerico = 'Hola';

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.offsetLocal,
    this.session,
    this.authRepository,
  });

  /// Por defecto la sesión real.
  final SessionStore? session;

  /// Por defecto el repositorio de autenticación real (cierre de sesión).
  final AuthRepository? authRepository;

  /// Por defecto el repositorio real.
  final NucleoRepository? repository;

  /// Solo para pruebas: zona horaria fija en lugar de la del equipo.
  final Duration? offsetLocal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _saldoVisible = true;

  late final NucleoRepository _nucleo = widget.repository ?? NucleoRepository();
  BigInt? _saldoCentavos;
  bool _errorSaldo = false;
  String? _nombre;
  bool _hayRecargaPendiente = false;
  KycEstado? _kyc;
  late Future<MovimientosPage> _movimientos;

  @override
  void initState() {
    super.initState();
    _movimientos = _nucleo.getMovimientos(limit: 3);
    _cargarSaldo();
    _cargarKyc();
    _cargarNombre();
    _cargarPendiente();
  }

  Future<void> _cargarPendiente() async {
    try {
      final id = await (widget.session ?? defaultSessionStore)
          .readDepositoPendiente();
      if (mounted) {
        setState(() => _hayRecargaPendiente = id != null && id.isNotEmpty);
      }
    } catch (_) {
      // Sin lectura posible no se ofrece el aviso.
    }
  }

  /// Al volver de una pantalla que pudo guardar o limpiar el depósito
  /// pendiente se relee, para que el aviso no quede desactualizado.
  Future<void> _abrir(String ruta) async {
    await context.push(ruta);
    if (mounted) await _cargarPendiente();
  }

  Future<void> _cargarNombre() async {
    try {
      final perfil = await (widget.session ?? defaultSessionStore)
          .readProfile();
      if (mounted) setState(() => _nombre = nombreDePerfil(perfil));
    } catch (_) {
      // Sin perfil legible se queda el saludo genérico.
    }
  }

  Future<void> _cargarSaldo() async {
    try {
      final s = await _nucleo.getSaldo();
      if (mounted) {
        setState(() {
          _saldoCentavos = s.montoCentavos;
          _errorSaldo = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errorSaldo = true);
    }
  }

  Future<void> _cargarKyc() async {
    try {
      final kyc = await _nucleo.getKycEstado();
      if (mounted) setState(() => _kyc = kyc);
    } catch (_) {
      // Sin estado de KYC el bloque de bajo monto no se muestra.
    }
  }

  void _recargarPreview() {
    final preview = _nucleo.getMovimientos(limit: 3);
    setState(() {
      _movimientos = preview;
    });
  }

  Future<void> _refrescar() async {
    final preview = _nucleo.getMovimientos(limit: 3);
    setState(() {
      _movimientos = preview;
    });
    // Un fallo del preview lo muestra el FutureBuilder, no debe romper el gesto.
    await Future.wait([
      _cargarSaldo(),
      _cargarKyc(),
      preview.then((_) {}, onError: (_) {}),
    ]);
  }

  /// Una transferencia confirmada en el chat cambia el saldo: se refresca al volver.
  Future<void> _abrirAsistente() async {
    await context.push('/asistente');
    if (mounted) await _refrescar();
  }

  /// Elegir una conversación del historial la reabre en el chat de Vera.
  Future<void> _abrirHistorialVera() async {
    final id = await context.push<String>('/asistente/historial');
    if (id != null && mounted) {
      await context.push('/asistente', extra: id);
      if (mounted) await _refrescar();
    }
  }

  void _onNavTap(int i) {
    if (i == 2) {
      _abrirAsistente();
      return;
    }
    setState(() => _tab = i);
  }

  Widget get _body => switch (_tab) {
    1 => MovimientosTab(repository: _nucleo, offsetLocal: widget.offsetLocal),
    3 => TarjetasTab(session: widget.session),
    4 => PerfilTab(
      session: widget.session ?? defaultSessionStore,
      authRepository: widget.authRepository,
    ),
    _ => _InicioTab(
      nombre: _nombre,
      saldoVisible: _saldoVisible,
      saldoCentavos: _saldoCentavos,
      errorSaldo: _errorSaldo,
      recargaPendiente: _hayRecargaPendiente,
      kyc: _kyc,
      onAbrir: _abrir,
      onToggleSaldo: () => setState(() => _saldoVisible = !_saldoVisible),
      movimientos: _movimientos,
      offsetLocal: widget.offsetLocal,
      onRefrescar: _refrescar,
      onVerTodos: () => setState(() => _tab = 1),
      onReintentarMovimientos: _recargarPreview,
      onHistorialVera: _abrirHistorialVera,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: FondoVera(child: _body),
      bottomNavigationBar: BarraVera(
        indice: _tab,
        alElegir: _onNavTap,
        alAbrirVera: _abrirAsistente,
      ),
    );
  }
}

// ── Inicio ─────────────────────────────────────────────────────

class _InicioTab extends StatelessWidget {
  const _InicioTab({
    required this.nombre,
    required this.saldoVisible,
    required this.onToggleSaldo,
    required this.saldoCentavos,
    required this.errorSaldo,
    required this.recargaPendiente,
    required this.kyc,
    required this.onAbrir,
    required this.movimientos,
    required this.offsetLocal,
    required this.onRefrescar,
    required this.onVerTodos,
    required this.onReintentarMovimientos,
    required this.onHistorialVera,
  });

  final String? nombre;
  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final BigInt? saldoCentavos;
  final bool errorSaldo;
  final bool recargaPendiente;
  final KycEstado? kyc;
  final void Function(String ruta) onAbrir;
  final Future<MovimientosPage> movimientos;
  final Duration? offsetLocal;
  final Future<void> Function() onRefrescar;
  final VoidCallback onVerTodos;
  final VoidCallback onReintentarMovimientos;
  final VoidCallback onHistorialVera;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefrescar,
        color: AppColors.gradientStart,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Saludo(nombre: nombre),
              const SizedBox(height: 20),
              _TarjetaSaldo(
                saldoVisible: saldoVisible,
                onToggleSaldo: onToggleSaldo,
                saldoCentavos: saldoCentavos,
                errorSaldo: errorSaldo,
                onAbrir: onAbrir,
                onHistorial: onVerTodos,
              ),
              if (recargaPendiente) ...[
                const SizedBox(height: 14),
                _AvisoRecargaPendiente(onTap: () => onAbrir('/recargar')),
              ],
              if (kyc case final kyc? when kyc.esBajoMonto) ...[
                const SizedBox(height: 14),
                _BloqueBajoMonto(kyc: kyc),
              ],
              const SizedBox(height: 14),
              _AccesosCard(onAbrir: onAbrir, onHistorialVera: onHistorialVera),
              const SizedBox(height: 14),
              _MovimientosSection(
                futuro: movimientos,
                offsetLocal: offsetLocal,
                onVerTodos: onVerTodos,
                onReintentar: onReintentarMovimientos,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Saludo ─────────────────────────────────────────────────────

class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre});

  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarVera(iniciales: inicialesDe(nombre), tamano: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludoDeLaHora(DateTime.now()),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              Text(
                nombre ?? saludoGenerico,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta de saldo ───────────────────────────────────────────

class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({
    required this.saldoVisible,
    required this.onToggleSaldo,
    required this.saldoCentavos,
    required this.errorSaldo,
    required this.onAbrir,
    required this.onHistorial,
  });

  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final BigInt? saldoCentavos;
  final bool errorSaldo;
  final void Function(String ruta) onAbrir;
  final VoidCallback onHistorial;

  Widget _saldo() {
    if (errorSaldo) {
      return const Text(
        'Error al cargar',
        style: TextStyle(color: Colors.white54, fontSize: 22),
      );
    }
    if (saldoCentavos == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: EsqueletoVera(ancho: 210, alto: 44, radio: 14),
      );
    }
    const estilo = TextStyle(
      color: Colors.white,
      fontSize: 44,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      height: 1.05,
    );
    if (!saldoVisible) return const Text('\$ ••••••', style: estilo);
    // Los centavos van aparte y en gris, como en el diseño: ",00" cuando es un monto entero.
    final texto = formatPesos(saldoCentavos!);
    final coma = texto.indexOf(',');
    final enteros = coma == -1 ? texto : texto.substring(0, coma);
    final centavos = coma == -1 ? ',00' : texto.substring(coma);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: estilo,
          children: [
            TextSpan(text: enteros),
            TextSpan(
              text: centavos,
              style: estilo.copyWith(color: Colors.white.withAlpha(110)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      gradiente: AppGradients.tarjetaSaldo,
      adorno: AdornoTarjeta.olas,
      radio: 32,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Saldo disponible',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                key: const Key('alternar_saldo'),
                onTap: onToggleSaldo,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  saldoVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _saldo(),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _BotonAccion(
                  etiqueta: 'Enviar',
                  icono: Icons.north_east_rounded,
                  claro: true,
                  alTocar: () => onAbrir('/enviar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _BotonAccion(
                  etiqueta: 'Recargar',
                  icono: Icons.add_rounded,
                  alTocar: () => onAbrir('/recargar'),
                ),
              ),
              const SizedBox(width: 8),
              _BotonRedondo(
                etiqueta: 'Enviar por llave',
                icono: Icons.vpn_key_outlined,
                alTocar: () => onAbrir('/enviar-llave'),
              ),
              const SizedBox(width: 8),
              _BotonRedondo(
                etiqueta: 'Historial',
                icono: Icons.history_rounded,
                alTocar: onHistorial,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
    this.claro = false,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final tinta = claro ? AppColors.tintaBotonClaro : Colors.white;
    return GestureDetector(
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: claro ? AppColors.botonClaro : AppColors.botonOscuro,
          borderRadius: BorderRadius.circular(26),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: tinta, size: 18),
              const SizedBox(width: 5),
              Text(
                etiqueta,
                maxLines: 1,
                style: TextStyle(
                  color: tinta,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        onTap: alTocar,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: etiqueta,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.botonOscuro,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

// ── Accesos ────────────────────────────────────────────────────

/// Atajos a lo que la app ya hace: categorías, estadísticas y el historial de Vera.
/// Entran una tras otra con un pequeño rebote y luego se mantienen en movimiento: flotan, los
/// puntos orbitan y los discos respiran.
class _AccesosCard extends StatefulWidget {
  const _AccesosCard({required this.onAbrir, required this.onHistorialVera});

  final void Function(String ruta) onAbrir;
  final VoidCallback onHistorialVera;

  @override
  State<_AccesosCard> createState() => _AccesosCardState();
}

class _AccesosCardState extends State<_AccesosCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// Una vuelta completa del movimiento permanente, que se repite un buen rato y luego para.
  /// Con la opción de accesibilidad de reducir movimiento no arranca.
  late final AnimationController _reposo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  static const _vueltas = 60;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducir = MediaQuery.of(context).disableAnimations;
    if (reducir) {
      _reposo.stop();
    } else if (!_reposo.isAnimating && _reposo.value == 0) {
      _reposo.repeat(count: _vueltas);
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _reposo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TeselaAcceso(
            llave: const Key('acceso_categorias'),
            etiqueta: 'Categorías',
            descripcion: 'Movimientos con categoría',
            icono: Icons.sell_outlined,
            disco: const Color(0xFF243E5E),
            punto: (Alignment.topRight, const Color(0xFFCDEFE0)),
            entrada: _entrada,
            reposo: _reposo,
            orden: 0,
            alTocar: () => widget.onAbrir('/inteligencia'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TeselaAcceso(
            llave: const Key('acceso_estadisticas'),
            etiqueta: 'Estadísticas',
            descripcion: 'Estadísticas',
            icono: Icons.bar_chart_rounded,
            disco: const Color(0xFF2B2455),
            punto: (Alignment.bottomRight, const Color(0xFFC3C0F0)),
            entrada: _entrada,
            reposo: _reposo,
            orden: 1,
            alTocar: () => widget.onAbrir('/estadisticas'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TeselaAcceso(
            llave: const Key('acceso_historial_vera'),
            etiqueta: 'Mis charlas',
            descripcion: 'Historial de Vera',
            icono: Icons.forum_outlined,
            disco: const Color(0xFF4A3322),
            punto: (Alignment.topLeft, const Color(0xFFCDEFE0)),
            entrada: _entrada,
            reposo: _reposo,
            orden: 2,
            alTocar: widget.onHistorialVera,
          ),
        ),
      ],
    );
  }
}

/// Tesela oscura y muy redondeada: ícono blanco sobre un disco de color, con un punto pastel
/// a un lado, y el nombre debajo.
///
/// Al aparecer sube y se agranda con rebote, y el punto salta con un resorte. Al tocarla se
/// hunde un poco, el disco brilla y el ícono se menea.
class _TeselaAcceso extends StatefulWidget {
  const _TeselaAcceso({
    required this.llave,
    required this.etiqueta,
    required this.descripcion,
    required this.icono,
    required this.disco,
    required this.punto,
    required this.entrada,
    required this.reposo,
    required this.orden,
    required this.alTocar,
  });

  final Key llave;
  final String etiqueta;

  /// Lo que anuncia el lector de pantalla.
  final String descripcion;
  final IconData icono;
  final Color disco;
  final (Alignment, Color) punto;

  /// Animación de entrada compartida por las tres teselas; [orden] decide cuándo arranca cada una.
  final Animation<double> entrada;

  /// Movimiento permanente: de 0 a 1 en cada vuelta, fuera de fase entre teselas.
  final Animation<double> reposo;
  final int orden;
  final VoidCallback alTocar;

  @override
  State<_TeselaAcceso> createState() => _TeselaAccesoState();
}

class _TeselaAccesoState extends State<_TeselaAcceso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _meneo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _presionada = false;

  late final Animation<double> _aparece = CurvedAnimation(
    parent: widget.entrada,
    curve: Interval(
      widget.orden * 0.14,
      0.55 + widget.orden * 0.14,
      curve: Curves.easeOutBack,
    ),
  );
  late final Animation<double> _opacidad = CurvedAnimation(
    parent: widget.entrada,
    curve: Interval(
      widget.orden * 0.14,
      0.4 + widget.orden * 0.14,
      curve: Curves.easeOut,
    ),
  );
  late final Animation<double> _salto = CurvedAnimation(
    parent: widget.entrada,
    curve: Interval(0.4 + widget.orden * 0.14, 1, curve: Curves.elasticOut),
  );

  @override
  void dispose() {
    _meneo.dispose();
    super.dispose();
  }

  void _tocar() {
    _meneo.forward(from: 0);
    widget.alTocar();
  }

  @override
  Widget build(BuildContext context) {
    final (lugar, colorPunto) = widget.punto;
    return AnimatedBuilder(
      animation: widget.reposo,
      builder: (context, hijoEstatico) {
        // Fase propia de cada tesela para que no se muevan al unísono.
        final fase = 2 * math.pi * (widget.reposo.value + widget.orden / 3);
        return Transform.translate(
          offset: Offset(0, 3.5 * math.sin(fase)),
          child: hijoEstatico,
        );
      },
      child: _tesela(lugar, colorPunto),
    );
  }

  Widget _tesela(Alignment lugar, Color colorPunto) {
    return Semantics(
      button: true,
      label: widget.descripcion,
      excludeSemantics: true,
      onTap: _tocar,
      child: FadeTransition(
        opacity: _opacidad,
        child: AnimatedBuilder(
          animation: _aparece,
          builder: (context, hijo) => Transform.translate(
            offset: Offset(0, 26 * (1 - _aparece.value)),
            child: Transform.scale(
              scale: 0.86 + 0.14 * _aparece.value,
              child: hijo,
            ),
          ),
          child: GestureDetector(
            key: widget.llave,
            onTap: _tocar,
            onTapDown: (_) => setState(() => _presionada = true),
            onTapUp: (_) => setState(() => _presionada = false),
            onTapCancel: () => setState(() => _presionada = false),
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _presionada ? 0.93 : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18212E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _presionada
                        ? widget.disco.withAlpha(255)
                        : const Color(0xFF28364A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.disco.withAlpha(_presionada ? 170 : 0),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 66,
                      height: 62,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            child: _Respira(
                              animacion: widget.reposo,
                              orden: widget.orden,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: widget.disco,
                                  shape: BoxShape.circle,
                                ),
                                child: AnimatedBuilder(
                                  animation: _meneo,
                                  builder: (context, hijo) => Transform.rotate(
                                    // Un vaivén que se apaga: seno por una curva que cae a cero.
                                    angle:
                                        0.5 *
                                        (1 - _meneo.value) *
                                        math.sin(_meneo.value * math.pi * 4),
                                    child: hijo,
                                  ),
                                  child: Icon(
                                    widget.icono,
                                    color: const Color(0xFFEAF2FF),
                                    size: 27,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: lugar,
                            child: _Orbita(
                              animacion: widget.reposo,
                              orden: widget.orden,
                              child: ScaleTransition(
                                scale: _salto,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: colorPunto,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.etiqueta,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFEAF2FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El disco del ícono se infla y se encoge suavemente, como si respirara.
class _Respira extends StatelessWidget {
  const _Respira({
    required this.animacion,
    required this.orden,
    required this.child,
  });

  final Animation<double> animacion;
  final int orden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, hijo) {
        final fase = 2 * math.pi * (animacion.value + orden / 3 + 0.25);
        return Transform.scale(scale: 1 + 0.055 * math.sin(fase), child: hijo);
      },
      child: child,
    );
  }
}

/// El punto pastel recorre un círculo pequeño alrededor de su sitio.
class _Orbita extends StatelessWidget {
  const _Orbita({
    required this.animacion,
    required this.orden,
    required this.child,
  });

  final Animation<double> animacion;
  final int orden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animacion,
      builder: (context, hijo) {
        final fase = 2 * math.pi * (animacion.value + orden / 3);
        return Transform.translate(
          offset: Offset(4 * math.cos(fase), 4 * math.sin(fase)),
          child: hijo,
        );
      },
      child: child,
    );
  }
}

// ── Avisos ─────────────────────────────────────────────────────

class _AvisoRecargaPendiente extends StatelessWidget {
  const _AvisoRecargaPendiente({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TarjetaVidrio(
        radio: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF16304B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.gradientStart,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Tienes una recarga pendiente',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Ver estado',
              style: TextStyle(
                color: AppColors.gradientStart,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Depósito de bajo monto ─────────────────────────────────────

class _BloqueBajoMonto extends StatelessWidget {
  const _BloqueBajoMonto({required this.kyc});

  final KycEstado kyc;

  @override
  Widget build(BuildContext context) {
    final tope = kyc.topeMensual;
    final disponible = kyc.disponibleMes;
    final usado = tope != null && disponible != null && tope > BigInt.zero
        ? 1 - (disponible.toDouble() / tope.toDouble()).clamp(0.0, 1.0)
        : null;
    return SizedBox(
      width: double.infinity,
      child: TarjetaVidrio(
        key: const Key('bloque_bajo_monto'),
        radio: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Depósito de bajo monto',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (kyc.tieneLimites) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CifraLimite(
                    etiqueta: 'Disponible del mes',
                    valor: formatPesos(disponible!),
                  ),
                  _CifraLimite(
                    etiqueta: 'Tope mensual',
                    valor: formatPesos(tope!),
                    alinearDerecha: true,
                  ),
                ],
              ),
              if (usado != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: usado,
                    minHeight: 6,
                    color: AppColors.gradientStart,
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
              ],
            ] else
              const Text(
                'Tu cupo mensual aún no está disponible.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _CifraLimite extends StatelessWidget {
  const _CifraLimite({
    required this.etiqueta,
    required this.valor,
    this.alinearDerecha = false,
  });

  final String etiqueta;
  final String valor;
  final bool alinearDerecha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alinearDerecha
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Movimientos recientes en home (preview, últimos 3) ─────────
// El Future vive en el estado de HomeScreen para que un rebuild no relance
// la petición.

class _MovimientosSection extends StatelessWidget {
  const _MovimientosSection({
    required this.futuro,
    required this.offsetLocal,
    required this.onVerTodos,
    required this.onReintentar,
  });

  final Future<MovimientosPage> futuro;
  final Duration? offsetLocal;
  final VoidCallback onVerTodos;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      radio: 30,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Movimientos recientes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: onVerTodos,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gradientStart,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Ver todos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<MovimientosPage>(
            future: futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: EsqueletoMovimientos(filas: 3),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: EstadoVista.error(
                    mensaje: mensajeDeError(snap.error!),
                    onReintentar: onReintentar,
                  ),
                );
              }
              final filas = construirFilas(
                snap.data?.items ?? const [],
                offset: offsetLocal,
              );
              if (filas.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Sin movimientos aún',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              final ahora = ahoraLocal(offset: offsetLocal);
              return Column(
                children: [
                  for (final f in filas)
                    MovimientoFilaTile(
                      fila: f.fila,
                      subtitulo: formatFechaCorta(f.local, ahora),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
