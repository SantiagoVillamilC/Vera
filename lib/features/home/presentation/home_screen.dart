import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/format/tarjeta_muestra.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/wip_badge.dart';
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

  late final NucleoRepository _nucleo =
      widget.repository ?? NucleoRepository();
  BigInt? _saldoCentavos;
  bool _errorSaldo = false;
  String? _nombre;
  bool _hayRecargaPendiente = false;
  late Future<MovimientosPage> _movimientos;

  @override
  void initState() {
    super.initState();
    _movimientos = _nucleo.getMovimientos(limit: 3);
    _cargarSaldo();
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
      final perfil =
          await (widget.session ?? defaultSessionStore).readProfile();
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
    await Future.wait([_cargarSaldo(), preview.then((_) {}, onError: (_) {})]);
  }

  void _onNavTap(int i) {
    if (i == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vera copilot (WIP)')),
      );
      return;
    }
    setState(() => _tab = i);
  }

  Widget get _body => switch (_tab) {
        1 => MovimientosTab(
            repository: _nucleo,
            offsetLocal: widget.offsetLocal,
          ),
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
            onAbrir: _abrir,
            onToggleSaldo: () => setState(() => _saldoVisible = !_saldoVisible),
            movimientos: _movimientos,
            offsetLocal: widget.offsetLocal,
            onRefrescar: _refrescar,
            onVerTodos: () => setState(() => _tab = 1),
            onReintentarMovimientos: _recargarPreview,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _body,
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: _onNavTap,
        bottomPadding: bottom,
      ),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.bottomPadding,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double bottomPadding;

  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.bar_chart_rounded, 'Movim.'),
    (Icons.mic_rounded, ''),
    (Icons.credit_card_rounded, 'Tarjetas'),
    (Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64 + bottomPadding + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 64 + bottomPadding,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Row(
                  children: List.generate(5, (i) {
                    if (i == 2) return const Expanded(child: SizedBox());
                    final active = currentIndex == i;
                    final (icon, label) = _items[i];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 22,
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted),
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: active
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                )),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding + 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gradientMid.withAlpha(120),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
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
    required this.onAbrir,
    required this.movimientos,
    required this.offsetLocal,
    required this.onRefrescar,
    required this.onVerTodos,
    required this.onReintentarMovimientos,
  });

  final String? nombre;
  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final BigInt? saldoCentavos;
  final bool errorSaldo;
  final bool recargaPendiente;
  final void Function(String ruta) onAbrir;
  final Future<MovimientosPage> movimientos;
  final Duration? offsetLocal;
  final Future<void> Function() onRefrescar;
  final VoidCallback onVerTodos;
  final VoidCallback onReintentarMovimientos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          nombre: nombre,
          saldoVisible: saldoVisible,
          onToggleSaldo: onToggleSaldo,
          saldoCentavos: saldoCentavos,
          errorSaldo: errorSaldo,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefrescar,
            color: AppColors.gradientStart,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recargaPendiente)
                    _AvisoRecargaPendiente(
                      onTap: () => onAbrir('/recargar'),
                    ),
                  _ActionsCard(onAbrir: onAbrir),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MovimientosSection(
                      futuro: movimientos,
                      offsetLocal: offsetLocal,
                      onVerTodos: onVerTodos,
                      onReintentar: onReintentarMovimientos,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header (purple top) ────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.nombre,
    required this.saldoVisible,
    required this.onToggleSaldo,
    required this.saldoCentavos,
    required this.errorSaldo,
  });

  final String? nombre;
  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final BigInt? saldoCentavos;
  final bool errorSaldo;

  Widget _buildSaldoWidget() {
    if (errorSaldo) {
      return const Text(
        'Error al cargar',
        style: TextStyle(color: Colors.white54, fontSize: 20),
      );
    }
    if (saldoCentavos == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white54,
        ),
      );
    }
    return Text(
      saldoVisible ? formatPesos(saldoCentavos!) : '\$ ••••••',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En tu cuenta',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre ?? saludoGenerico,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mis CVUs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    WipBadge(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildSaldoWidget()),
              GestureDetector(
                onTap: onToggleSaldo,
                child: Icon(
                  saldoVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Actions card ───────────────────────────────────────────────

class _AvisoRecargaPendiente extends StatelessWidget {
  const _AvisoRecargaPendiente({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gradientStart),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: AppColors.gradientStart, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tienes una recarga pendiente',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.onAbrir});

  final void Function(String ruta) onAbrir;

  static const _actions = [
    (Icons.send_rounded, 'Enviar\ndinero', '/enviar'),
    (Icons.key_rounded, 'Enviar por llave', '/enviar-llave'),
    (Icons.add_circle_outline_rounded, 'Recargar', '/recargar'),
    (Icons.receipt_long_rounded, 'Pagar\nservicios', ''),
    (Icons.credit_card_rounded, 'Pedir\ntarjeta', ''),
    (Icons.lock_outline_rounded, 'Mis\nclaves', ''),
    (Icons.account_balance_wallet_rounded, 'Remune-\nración', ''),
  ];

  /// 52 del icono, 6 de separación y dos líneas de etiqueta (11 con altura
  /// 1.3) que crecen con la escala de texto del sistema.
  static double _alturaCelda(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context).scale(11) / 11;
    return math.max(96, 58 + 2 * 11 * 1.3 * escala + 4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            // Altura fija: con childAspectRatio la celda se encoge en pantallas
            // angostas y la etiqueta de dos líneas desborda.
            child: GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                mainAxisExtent: _alturaCelda(context),
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _actions.map((a) {
                final (icon, label, route) = a;
                return _ActionCell(
                  icon: icon,
                  label: label,
                  onTap: route.isNotEmpty ? () => onAbrir(route) : null,
                );
              }).toList(),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _CardRow(),
        ],
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  /// Sin acción la celda queda marcada (WIP) y no responde al toque.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enDesarrollo = onTap == null;
    final cuerpo = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: enDesarrollo ? 0.6 : 1,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, color: AppColors.gradientStart, size: 24),
                ),
              ),
              if (enDesarrollo)
                const Positioned(top: -6, right: -10, child: WipBadge()),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (!enDesarrollo) return cuerpo;
    return Semantics(
      label: '${label.replaceAll('-\n', '').replaceAll('\n', ' ')}, en desarrollo',
      excludeSemantics: true,
      child: cuerpo,
    );
  }
}

class _CardRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('VERA',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    )),
                Text('VISA',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Datos de muestra compartidos con la pestaña Tarjetas.
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tarjetaMuestraRotulo,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                SizedBox(height: 3),
                Text(tarjetaMuestraNumero,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
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

  BoxDecoration get _tarjeta => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Últimos Movimientos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
              child: const Text('Ver todos',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<MovimientosPage>(
          future: futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: EstadoVista.cargando(),
              );
            }
            if (snap.hasError) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: _tarjeta,
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
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: _tarjeta,
                child: const Center(
                  child: Text('Sin movimientos aún',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14)),
                ),
              );
            }
            final ahora = ahoraLocal(offset: offsetLocal);
            return Container(
              decoration: _tarjeta,
              child: Column(
                children: [
                  for (var i = 0; i < filas.length; i++) ...[
                    MovimientoFilaTile(
                      fila: filas[i].fila,
                      subtitulo: formatFechaCorta(filas[i].local, ahora),
                    ),
                    if (i < filas.length - 1)
                      const Divider(
                          color: AppColors.border, height: 1, indent: 72),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
