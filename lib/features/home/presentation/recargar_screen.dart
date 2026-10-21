import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/platform/url_opener.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/gradient_button.dart';
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  // ── Vista ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Recargar saldo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
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
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 14)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tarjeta(
            child: Column(
              children: [
                _iconoDeEstado(estado),
                const SizedBox(height: 12),
                Text(
                  _titulo(estado),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mensaje(estado),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
                ),
                if (d != null) ...[
                  const SizedBox(height: 16),
                  Text(formatPesos(d.montoCentavos),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                  if (d.referencia.isNotEmpty)
                    Text('Referencia ${d.referencia}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (_respaldo != _Respaldo.ninguno) ...[
            const SizedBox(height: 16),
            _respaldoEnlace(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 14)),
          ],
          const SizedBox(height: 24),
          ..._acciones(),
        ],
      ),
    );
  }

  List<Widget> _acciones() {
    if (_esTerminal) {
      return [
        GradientButton(
          key: const Key('nueva-recarga'),
          label: 'Nueva recarga',
          onPressed: _volverAlFormulario,
        ),
      ];
    }
    return [
      if (_sondeoAgotado)
        GradientButton(
          key: const Key('consultar-de-nuevo'),
          label: 'Consultar de nuevo',
          icon: Icons.refresh_rounded,
          onPressed: _consultarDeNuevo,
        )
      else
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.gradientStart),
          ),
        ),
      if (_urlPago != null && _respaldo != _Respaldo.inseguro) ...[
        const SizedBox(height: 12),
        TextButton(
          key: const Key('abrir-pago'),
          onPressed: () => _abrirPago(_urlPago!),
          child: const Text('Abrir el pago de nuevo',
              style: TextStyle(color: AppColors.gradientStart)),
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
        borderRadius: BorderRadius.circular(16),
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
            SelectableText(_urlPago!,
                style: const TextStyle(
                    color: AppColors.accent, fontSize: 13)),
            TextButton.icon(
              key: const Key('copiar-enlace'),
              onPressed: _copiarEnlace,
              icon: const Icon(Icons.copy_rounded,
                  size: 18, color: AppColors.gradientStart),
              label: const Text('Copiar enlace',
                  style: TextStyle(color: AppColors.gradientStart)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconoDeEstado(EstadoDeposito estado) {
    final (icono, color) = switch (estado) {
      EstadoDeposito.confirmada => (
          Icons.check_circle_rounded,
          AppColors.accentGreen
        ),
      EstadoDeposito.rechazada => (Icons.cancel_rounded, AppColors.error),
      EstadoDeposito.expirada => (Icons.timer_off_rounded, AppColors.warning),
      _ => (Icons.hourglass_top_rounded, AppColors.gradientStart),
    };
    return Icon(icono, color: color, size: 48);
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
