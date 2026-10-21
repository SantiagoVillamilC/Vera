import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';
import 'package:vera/features/nucleo/data/transferencia_mensajes.dart';

class EnviarScreen extends StatefulWidget {
  const EnviarScreen({super.key, this.repository, this.intent});

  /// Por defecto el repositorio real. Se inyecta para pruebas.
  final NucleoRepository? repository;
  final IdempotencyIntent? intent;

  @override
  State<EnviarScreen> createState() => _EnviarScreenState();
}

class _EnviarScreenState extends State<EnviarScreen> {
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late final NucleoRepository _repo = widget.repository ?? NucleoRepository();
  late final IdempotencyIntent _intent = widget.intent ?? IdempotencyIntent();
  final _enviando = ValueNotifier<bool>(false);
  bool _cargandoMaximo = false;

  /// Centavos exactos devueltos por el endpoint de máximo. Se descarta en
  /// cuanto el usuario edita el monto a mano.
  BigInt? _montoExacto;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _enviando.dispose();
    super.dispose();
  }

  BigInt? get _montoCentavos {
    final exacto = _montoExacto;
    if (exacto != null) return exacto;
    final clean = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final pesos = BigInt.tryParse(clean);
    if (pesos == null) return null;
    return pesos * BigInt.from(100);
  }

  bool get _hasAmount {
    final m = _montoCentavos;
    return m != null && m > BigInt.zero;
  }

  String? get _destino => normalizarDestino(_recipientCtrl.text);

  bool get _canSend => _hasAmount && _destino != null;

  Future<void> _enviarMaximo() async {
    if (_cargandoMaximo) return;
    setState(() => _cargandoMaximo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final max = await _repo.getMontoMaximo();
      if (!mounted) return;
      setState(() {
        _montoExacto = max.montoCentavos;
        _amountCtrl.text = formatPesos(max.montoCentavos);
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoMaximo = false);
    }
  }

  /// Devuelve el mensaje de error o null si el servidor respondió 2xx.
  Future<String?> _enviar(String destino, BigInt monto) async {
    if (_enviando.value) return null;
    _enviando.value = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key = _intent.keyFor(destino: destino, monto: monto);
      final result = await _repo.transferir(
        destino: destino,
        monto: monto.toString(),
        idempotencyKey: key,
      );
      _intent.registrarExito();
      final resultado = resultadoDeEstado(result.estado);
      messenger.showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          backgroundColor:
              resultado.exito ? AppColors.accentGreen : AppColors.warning,
        ),
      );
      return null;
    } catch (e) {
      _intent.registrarError(e);
      return mensajeDeErrorEnvio(e);
    } finally {
      _enviando.value = false;
    }
  }

  void _onRevisar() {
    final destino = _destino;
    final monto = _montoCentavos;
    if (!_canSend || destino == null || monto == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ConfirmSheet(
        repo: _repo,
        destino: destino,
        monto: monto,
        enviando: _enviando,
        onConfirm: () => _enviar(destino, monto),
      ),
    );
  }

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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Enviar dinero',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Recipient card ──────────────────────────────────
            _SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Para',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _recipientCtrl,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                maxLongitudDestino),
                          ],
                          style: const TextStyle(
                            color: AppColors.gradientStart,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Celular',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.contacts_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Amount card ─────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monto',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'COP',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() => _montoExacto = null),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '\$0',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _cargandoMaximo ? null : _enviarMaximo,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Enviar el máximo',
                        style: TextStyle(color: AppColors.gradientStart),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Nota (opcional)',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.edit_note_rounded,
                            color: AppColors.textMuted, size: 18),
                      ),
                      prefixIconConstraints: BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // ── Review button ───────────────────────────────────
            GestureDetector(
              onTap: _canSend ? _onRevisar : null,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _canSend
                      ? AppGradients.brand
                      : const LinearGradient(
                          colors: [AppColors.surfaceVariant, AppColors.surfaceVariant]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Revisar envío',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Confirm bottom sheet ───────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({
    required this.repo,
    required this.destino,
    required this.monto,
    required this.enviando,
    required this.onConfirm,
  });

  final NucleoRepository repo;
  final String destino;
  final BigInt monto;
  final ValueListenable<bool> enviando;
  final Future<String?> Function() onConfirm;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

enum _Consulta { cargando, ok, noEncontrado, falla }

class _ConfirmSheetState extends State<_ConfirmSheet> {
  _Consulta _consulta = _Consulta.cargando;
  String? _nombre;
  String? _mensajeConsulta;
  String? _errorEnvio;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    setState(() {
      _consulta = _Consulta.cargando;
      _mensajeConsulta = null;
    });
    try {
      final d = await widget.repo.getDestinatario(widget.destino);
      if (!mounted) return;
      setState(() {
        _nombre = d.nombre;
        _consulta = _Consulta.ok;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajeConsulta = mensajeDeError(e);
        _consulta = e is ApiException && e.statusCode == 404
            ? _Consulta.noEncontrado
            : _Consulta.falla;
      });
    }
  }

  Future<void> _confirmar() async {
    setState(() => _errorEnvio = null);
    final error = await widget.onConfirm();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _errorEnvio = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.enviando,
        builder: (context, enviando, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Confirmando envío',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    formatPesos(widget.monto),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _destinatario(),
                ],
              ),
            ),
            if (_errorEnvio != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorEnvio!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            _botones(enviando),
          ],
        ),
      ),
    );
  }

  Widget _destinatario() {
    switch (_consulta) {
      case _Consulta.cargando:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gradientStart,
          ),
        );
      case _Consulta.ok:
        return Text(
          _nombre!,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        );
      case _Consulta.noEncontrado:
        return Text(
          _mensajeConsulta!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        );
      case _Consulta.falla:
        return Column(
          children: [
            Text(
              _mensajeConsulta ?? mensajeSinRed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
            TextButton(
              onPressed: _consultar,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.gradientStart),
              ),
            ),
          ],
        );
    }
  }

  Widget _botones(bool enviando) {
    final puedeConfirmar = _consulta == _Consulta.ok && !enviando;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: enviando ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            key: const Key('confirmar'),
            onTap: puedeConfirmar ? _confirmar : null,
            child: Opacity(
              opacity: _consulta == _Consulta.ok ? 1 : 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared card wrapper ────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
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
