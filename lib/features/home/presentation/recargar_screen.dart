import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/platform/url_opener.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart'
    show formatHora;
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

const mensajeRecargaConfirmada =
    'Recarga confirmada. El dinero ya está en tu saldo.';
const mensajeRecargaRechazada =
    'La recarga fue rechazada y no se acreditó dinero en tu saldo.';
const mensajeRecargaExpirada =
    'La recarga expiró sin recibir el pago. Puedes iniciar una nueva.';
const mensajeRecargaPendiente = 'Esperando la confirmación de tu pago.';
const mensajeRecargaVerificando =
    'Estamos verificando el estado de tu recarga.';
const mensajeEnlaceInseguro =
    'El enlace de pago no es seguro y no se abrió. Intenta de nuevo o comunícate con soporte.';
const mensajeEnlaceNoAbrio =
    'No pudimos abrir el enlace de pago. Cópialo y ábrelo en tu navegador.';

const _codigosNoEncontrado = {'NotFound', 'DepositNotFound'};

bool _esNoEncontrado(ApiException e) =>
    e.statusCode == 404 || _codigosNoEncontrado.contains(e.code);

enum _Fase { retomando, errorAlRetomar, formulario, seguimiento }

enum _Respaldo { ninguno, inseguro, noAbrio }

class RecargarScreen extends StatefulWidget {
  const RecargarScreen({
    super.key,
    this.repository,
    this.urlOpener,
    this.session,
    this.intervaloSondeo = const Duration(seconds: 5),
    this.topeSondeo = const Duration(minutes: 5),
  });

  /// Por defecto las dependencias reales. Se inyectan para pruebas.
  final NucleoRepository? repository;
  final UrlOpener? urlOpener;
  final SessionStore? session;

  /// Cada cuánto se consulta el estado y cuánto dura el sondeo automático.
  final Duration intervaloSondeo;
  final Duration topeSondeo;

  @override
  State<RecargarScreen> createState() => _RecargarScreenState();
}

class _RecargarScreenState extends State<RecargarScreen>
    with WidgetsBindingObserver {
  late final NucleoRepository _repo = widget.repository ?? NucleoRepository();
  late final UrlOpener _opener = widget.urlOpener ?? defaultUrlOpener;
  late final SessionStore _session = widget.session ?? defaultSessionStore;
  final _montoCtrl = TextEditingController();

  _Fase _fase = _Fase.retomando;
  _Respaldo _respaldo = _Respaldo.ninguno;
  String? _urlPago;
  String? _depositoId;
  Deposito? _deposito;
  String? _error;
  Object? _errorAlRetomar;
  bool _creando = false;
  bool _consultando = false;
  bool _sondeoAgotado = false;
  Timer? _sondeo;
  Timer? _tope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detenerSondeo();
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _fase == _Fase.seguimiento &&
        !_esTerminal) {
      _consultar();
    }
  }

  BigInt? get _montoCentavos {
    final limpio = _montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final pesos = BigInt.tryParse(limpio);
    if (pesos == null) return null;
    return pesos * BigInt.from(100);
  }

  bool get _puedeRecargar {
    final m = _montoCentavos;
    return m != null && m > BigInt.zero;
  }

  bool get _esTerminal => _deposito?.estado.esTerminal ?? false;

  // ── Retomar ────────────────────────────────────────────────────

  Future<void> _iniciar() async {
    String? id;
    try {
      id = await _session.readDepositoPendiente();
    } on Object {
      id = null;
    }
    if (!mounted) return;
    if (id == null || id.isEmpty) {
      setState(() => _fase = _Fase.formulario);
      return;
    }
    _depositoId = id;
    await _consultar();
  }

  Future<void> _volverAlFormulario() async {
    _detenerSondeo();
    _depositoId = null;
    _deposito = null;
    try {
      await _session.clearDepositoPendiente();
    } on Object {
      // El borrado se reintenta en la próxima entrada si falla.
    }
    if (!mounted) return;
    setState(() {
      _fase = _Fase.formulario;
      _respaldo = _Respaldo.ninguno;
      _urlPago = null;
      _error = null;
      _sondeoAgotado = false;
      _montoCtrl.clear();
    });
  }

  // ── Consulta y sondeo ──────────────────────────────────────────

  Future<void> _consultar() async {
    final id = _depositoId;
    if (id == null || _consultando) return;
    _consultando = true;
    try {
      final d = await _repo.getDeposito(id);
      if (!mounted) return;
      await _aplicar(d);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_esNoEncontrado(e)) {
        await _volverAlFormulario();
      } else {
        _falloConsulta(e);
      }
    } on Object catch (e) {
      if (!mounted) return;
      _falloConsulta(e);
    } finally {
      _consultando = false;
    }
  }

  void _falloConsulta(Object e) {
    setState(() {
      if (_deposito == null) {
        _fase = _Fase.errorAlRetomar;
        _errorAlRetomar = e;
      } else {
        _error = mensajeDeError(e);
      }
    });
  }

  Future<void> _aplicar(Deposito d) async {
    final terminal = d.estado.esTerminal;
    if (terminal) {
      _detenerSondeo();
      try {
        await _session.clearDepositoPendiente();
      } on Object {
        // El estado ya es definitivo, mostrarlo es lo importante.
      }
      if (!mounted) return;
    }
    setState(() {
      _deposito = d;
      _fase = _Fase.seguimiento;
      _error = null;
    });
    if (!terminal && _sondeo == null && !_sondeoAgotado) _iniciarSondeo();
  }

  void _iniciarSondeo() {
    _detenerSondeo();
    _sondeo = Timer.periodic(widget.intervaloSondeo, (_) => _consultar());
    _tope = Timer(widget.topeSondeo, _agotarSondeo);
  }

  void _detenerSondeo() {
    _sondeo?.cancel();
    _tope?.cancel();
    _sondeo = null;
    _tope = null;
  }

  void _agotarSondeo() {
    _detenerSondeo();
    if (mounted) setState(() => _sondeoAgotado = true);
  }

  void _consultarDeNuevo() {
    setState(() => _sondeoAgotado = false);
    _iniciarSondeo();
    _consultar();
  }

  // ── Crear recarga ──────────────────────────────────────────────

  Future<void> _crear() async {
    final monto = _montoCentavos;
    if (_creando || monto == null || monto <= BigInt.zero) return;
    setState(() {
      _creando = true;
      _error = null;
    });
    final DepositoConPago deposito;
    try {
      deposito = await _repo.recargar(monto);
      if (!deposito.estado.esTerminal) {
        await _session.saveDepositoPendiente(deposito.id);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _creando = false;
        _error = mensajeDeError(e);
      });
      return;
    }
    if (!mounted) return;
    _depositoId = deposito.id;
    _urlPago = deposito.urlPago;
    _sondeoAgotado = false;
    setState(() {
      _creando = false;
      _deposito = deposito;
      _fase = _Fase.seguimiento;
      _respaldo = _Respaldo.ninguno;
    });
    if (deposito.estado.esTerminal) {
      await _aplicar(deposito);
      return;
    }
    _iniciarSondeo();
    await _abrirPago(deposito.urlPago);
  }

  Future<void> _abrirPago(String url) async {
    final uri = urlPagoSegura(url);
    if (uri == null) {
      setState(() => _respaldo = _Respaldo.inseguro);
      return;
    }
    var abrio = false;
    try {
      abrio = await _opener.abrir(uri);
    } on Object {
      abrio = false;
    }
    if (!mounted) return;
    setState(() => _respaldo = abrio ? _Respaldo.ninguno : _Respaldo.noAbrio);
  }

  Future<void> _copiarEnlace() async {
    final url = _urlPago;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  // ── Vista ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final enSeguimiento = _fase == _Fase.seguimiento;
    // El degradado va detrás de todo para que la barra superior no se vea como una franja.
    return FondoVera(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Center(
              child: Semantics(
                button: true,
                label: 'Volver',
                excludeSemantics: true,
                onTap: () => Navigator.of(context).maybePop(),
                child: GestureDetector(
                  key: const Key('volver'),
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.botonOscuro,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            enSeguimiento ? 'Tu recarga' : 'Recargar saldo',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: switch (_fase) {
          _Fase.retomando => const EstadoVista.cargando(),
          _Fase.errorAlRetomar => EstadoVista.deError(
            _errorAlRetomar ?? '',
            mensaje: _errorAlRetomar == null
                ? mensajeErrorGenerico
                : mensajeDeError(_errorAlRetomar!),
            onReintentar: () {
              setState(() => _fase = _Fase.retomando);
              _consultar();
            },
          ),
          _Fase.formulario => _formulario(),
          _Fase.seguimiento => _seguimiento(),
        },
      ),
    );
  }

  Widget _formulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monto a recargar (COP)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('monto'),
                  controller: _montoCtrl,
                  enabled: !_creando,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '\$0',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ],
          const SizedBox(height: 32),
          GradientButton(
            key: const Key('recargar'),
            label: 'Recargar saldo',
            icon: Icons.add_circle_outline_rounded,
            loading: _creando,
            onPressed: _puedeRecargar && !_creando ? _crear : null,
          ),
        ],
      ),
    );
  }

  Widget _seguimiento() {
    final d = _deposito;
    final estado = d?.estado ?? EstadoDeposito.pendiente;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _AroDeEstado(estado: estado)),
                const SizedBox(height: 18),
                Center(
                  child: _ChipDeEstado(texto: _titulo(estado), estado: estado),
                ),
                if (d != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      formatPesos(d.montoCentavos),
                      key: const Key('monto-recarga'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _mensaje(estado),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                if (_respaldo != _Respaldo.ninguno) ...[
                  const SizedBox(height: 18),
                  _respaldoEnlace(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _LineaDeTiempo(
                  estado: estado,
                  creada: d?.creadaEn,
                  referencia: d?.referencia ?? '',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(children: _acciones()),
        ),
      ],
    );
  }

  List<Widget> _acciones() {
    if (_esTerminal) {
      return [
        _BotonPrincipal(
          llave: const Key('nueva-recarga'),
          etiqueta: 'Nueva recarga',
          alTocar: _volverAlFormulario,
        ),
      ];
    }
    final hayEnlace = _urlPago != null && _respaldo != _Respaldo.inseguro;
    return [
      Row(
        children: [
          if (hayEnlace) ...[
            Expanded(
              child: _BotonSecundario(
                llave: const Key('copiar-enlace'),
                etiqueta: 'Copiar enlace',
                icono: Icons.copy_rounded,
                alTocar: _copiarEnlace,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _BotonSecundario(
              llave: const Key('consultar-de-nuevo'),
              etiqueta: 'Consultar de nuevo',
              icono: Icons.refresh_rounded,
              alTocar: _sondeoAgotado ? _consultarDeNuevo : _consultar,
            ),
          ),
        ],
      ),
      if (hayEnlace) ...[
        const SizedBox(height: 10),
        _BotonPrincipal(
          llave: const Key('abrir-pago'),
          etiqueta: 'Abrir el pago de nuevo',
          alTocar: () => _abrirPago(_urlPago!),
        ),
      ],
    ];
  }

  Widget _respaldoEnlace() {
    final inseguro = _respaldo == _Respaldo.inseguro;
    return Container(
      key: const Key('respaldo-enlace'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inseguro ? mensajeEnlaceInseguro : mensajeEnlaceNoAbrio,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          if (!inseguro && _urlPago != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _urlPago!,
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  String _titulo(EstadoDeposito estado) => switch (estado) {
    EstadoDeposito.confirmada => 'Recarga confirmada',
    EstadoDeposito.rechazada => 'Recarga rechazada',
    EstadoDeposito.expirada => 'Recarga expirada',
    _ => 'Recarga pendiente',
  };

  String _mensaje(EstadoDeposito estado) => switch (estado) {
    EstadoDeposito.confirmada => mensajeRecargaConfirmada,
    EstadoDeposito.rechazada => mensajeRecargaRechazada,
    EstadoDeposito.expirada => mensajeRecargaExpirada,
    EstadoDeposito.pendiente => mensajeRecargaPendiente,
    EstadoDeposito.desconocido => mensajeRecargaVerificando,
  };
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Colores y marca de cada estado de la recarga.
(IconData, Color) _marcaDeEstado(EstadoDeposito estado) => switch (estado) {
  EstadoDeposito.confirmada => (Icons.check_rounded, AppColors.accentGreen),
  EstadoDeposito.rechazada => (Icons.close_rounded, AppColors.error),
  EstadoDeposito.expirada => (Icons.timer_off_rounded, AppColors.warning),
  _ => (Icons.hourglass_top_rounded, AppColors.gradientStart),
};

/// Círculo claro con la marca del estado y un aro de avance alrededor.
class _AroDeEstado extends StatelessWidget {
  const _AroDeEstado({required this.estado});

  final EstadoDeposito estado;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = _marcaDeEstado(estado);
    final terminal = estado.esTerminal;
    return SizedBox(
      key: const Key('aro-estado'),
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
          ),
          CustomPaint(
            size: const Size.square(170),
            painter: _ArcoPainter(color: color, barrido: terminal ? 1.0 : 0.82),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDDEAF7),
            ),
            child: Icon(
              icono,
              size: 56,
              color: terminal ? color : const Color(0xFFB9CBE0),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcoPainter extends CustomPainter {
  const _ArcoPainter({required this.color, required this.barrido});

  final Color color;

  /// Fracción de la vuelta que se dibuja, de 0 a 1.
  final double barrido;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * barrido,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcoPainter old) =>
      old.color != color || old.barrido != barrido;
}

class _ChipDeEstado extends StatelessWidget {
  const _ChipDeEstado({required this.texto, required this.estado});

  final String texto;
  final EstadoDeposito estado;

  @override
  Widget build(BuildContext context) {
    final (_, color) = _marcaDeEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16304B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              color: Color(0xFFCFE3F8),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PasoEstado { hecho, enCurso, pendiente, fallo, aviso }

/// Los tres pasos de una recarga: creada, pago en el banco y dinero en el saldo.
class _LineaDeTiempo extends StatelessWidget {
  const _LineaDeTiempo({
    required this.estado,
    required this.creada,
    required this.referencia,
  });

  final EstadoDeposito estado;
  final DateTime? creada;
  final String referencia;

  String _hora(DateTime d) {
    final l = aLocal(d.toUtc());
    return 'Hoy, ${formatHora(l)}';
  }

  @override
  Widget build(BuildContext context) {
    final pasoBanco = switch (estado) {
      EstadoDeposito.confirmada => _PasoEstado.hecho,
      EstadoDeposito.rechazada => _PasoEstado.fallo,
      EstadoDeposito.expirada => _PasoEstado.aviso,
      _ => _PasoEstado.enCurso,
    };
    final subBanco = switch (estado) {
      EstadoDeposito.confirmada => 'Pago recibido',
      EstadoDeposito.rechazada => 'Pago rechazado',
      EstadoDeposito.expirada => 'Pago expirado',
      _ => 'En curso',
    };
    final pasoSaldo = estado == EstadoDeposito.confirmada
        ? _PasoEstado.hecho
        : _PasoEstado.pendiente;
    final subSaldo = estado == EstadoDeposito.confirmada
        ? 'Acreditado en tu saldo'
        : (referencia.isNotEmpty ? 'Referencia $referencia' : 'Pendiente');
    return TarjetaVidrio(
      key: const Key('linea-de-tiempo'),
      opaca: true,
      radio: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          _Paso(
            titulo: 'Recarga creada',
            detalle: creada == null ? 'Listo' : _hora(creada!),
            estado: _PasoEstado.hecho,
            conLinea: true,
          ),
          _Paso(
            titulo: 'Pago en tu banco',
            detalle: subBanco,
            estado: pasoBanco,
            conLinea: true,
          ),
          _Paso(
            titulo: 'Dinero en tu saldo',
            detalle: subSaldo,
            estado: pasoSaldo,
            conLinea: false,
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.titulo,
    required this.detalle,
    required this.estado,
    required this.conLinea,
  });

  final String titulo;
  final String detalle;
  final _PasoEstado estado;
  final bool conLinea;

  @override
  Widget build(BuildContext context) {
    final pendiente = estado == _PasoEstado.pendiente;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                _Marcador(estado: estado),
                if (conLinea)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: const Color(0xFF3B6EA8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: conLinea ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      color: pendiente
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.estado});

  final _PasoEstado estado;

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case _PasoEstado.hecho:
        return _circulo(const Color(0xFF3E8F5C), Icons.check_rounded);
      case _PasoEstado.fallo:
        return _circulo(AppColors.error, Icons.close_rounded);
      case _PasoEstado.aviso:
        return _circulo(AppColors.warning, Icons.timer_off_rounded);
      case _PasoEstado.pendiente:
        return Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF26354A),
          ),
        );
      case _PasoEstado.enCurso:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gradientStart, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gradientStart,
            ),
          ),
        );
    }
  }

  Widget _circulo(Color color, IconData icono) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    child: Icon(icono, color: Colors.white, size: 20),
  );
}

class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({
    required this.llave,
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
  });

  final Key llave;
  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: llave,
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.botonOscuro,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: AppColors.gradientStart, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.llave,
    required this.etiqueta,
    required this.alTocar,
  });

  final Key llave;
  final String etiqueta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: llave,
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.botonClaro,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Text(
          etiqueta,
          style: const TextStyle(
            color: AppColors.tintaBotonClaro,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
