import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/utils/currency.dart';
import 'package:vera/core/utils/idempotency.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';
import 'package:vera/core/network/api_client.dart';

const _tiposLlave = [
  ('celular', 'Celular', Icons.smartphone_rounded),
  ('email', 'Correo electrónico', Icons.email_rounded),
  ('cbu', 'CBU', Icons.account_balance_rounded),
  ('cvu', 'CVU', Icons.account_balance_wallet_rounded),
  ('nit', 'NIT', Icons.badge_rounded),
];

class EnviarPorLlaveScreen extends StatefulWidget {
  const EnviarPorLlaveScreen({super.key});

  @override
  State<EnviarPorLlaveScreen> createState() => _EnviarPorLlaveScreenState();
}

class _EnviarPorLlaveScreenState extends State<EnviarPorLlaveScreen> {
  final _repo = NucleoRepository();
  final _llaveCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _tipoLlave = 'celular';
  bool _enviando = false;
  final _idempotency = IdempotencySlot();

  @override
  void dispose() {
    _llaveCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _montoCentavos => parseCentavos(_amountCtrl.text);

  bool get _puedeEnviar =>
      _montoCentavos > 0 && _llaveCtrl.text.trim().isNotEmpty;

  TextInputType get _keyboardType => switch (_tipoLlave) {
        'celular' => TextInputType.phone,
        'email' => TextInputType.emailAddress,
        _ => TextInputType.text,
      };

  String get _llaveHint => switch (_tipoLlave) {
        'celular' => '3001234567',
        'email' => 'ejemplo@correo.com',
        'cbu' => '0000000000000000000000',
        'cvu' => '0000000000000000000000',
        'nit' => '900123456-1',
        _ => '',
      };

  Future<void> _mostrarConfirmacion() async {
    if (!_puedeEnviar || _enviando) return;
    final confirmo = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConfirmSheet(
        tipoLlave: _tipoLlave,
        llave: _llaveCtrl.text.trim(),
        montoCentavos: _montoCentavos,
      ),
    );
    if (confirmo != true || !mounted) return;
    _enviar();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final resultado = await _repo.transferirInterbancaria(
        tipoLlave: _tipoLlave,
        llave: _llaveCtrl.text.trim(),
        monto: '$_montoCentavos',
        idempotencyKey: _idempotency.key,
      );
      if (!mounted) return;
      setState(() => _enviando = false);
      _idempotency.clear();
      _mostrarExito(resultado);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade800),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error inesperado. Intenta de nuevo.')),
      );
    }
  }

  void _mostrarExito(EnvioPorLlave envio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExitoSheet(envio: envio),
    ).then((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(top),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipoSelector(),
                  const SizedBox(height: 20),
                  _buildLlaveInput(),
                  const SizedBox(height: 20),
                  _buildMontoInput(),
                  const SizedBox(height: 32),
                  _buildEnviarButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double top) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
          const Expanded(
            child: Text(
              'Enviar por llave',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de llave',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tiposLlave.map((t) {
              final (valor, label, icon) = t;
              final active = _tipoLlave == valor;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() { _tipoLlave = valor; _llaveCtrl.clear(); });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: active ? AppGradients.brand : null,
                      color: active ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? Colors.transparent : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLlaveInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tiposLlave.firstWhere((t) => t.$1 == _tipoLlave).$2,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _llaveCtrl,
          keyboardType: _keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: _llaveHint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.gradientStart, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildMontoInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monto',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
            hintText: '0',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 28),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.gradientStart, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildEnviarButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _puedeEnviar ? AppGradients.brand : null,
          color: _puedeEnviar ? null : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: _puedeEnviar && !_enviando ? _mostrarConfirmacion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _enviando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Revisar envío',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ── Confirm sheet ─────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.tipoLlave,
    required this.llave,
    required this.montoCentavos,
  });
  final String tipoLlave;
  final String llave;
  final int montoCentavos;

  String get _tipoLabel => _tiposLlave
      .firstWhere((t) => t.$1 == tipoLlave, orElse: () => (tipoLlave, tipoLlave, Icons.key_rounded))
      .$2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmar envío',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _Row(label: 'Tipo de llave', valor: _tipoLabel),
          _Row(label: 'Llave', valor: llave),
          _Row(label: 'Monto', valor: formatPesos(montoCentavos)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Los envíos interbancarios pueden tardar hasta 24 horas en acreditarse.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          Text(valor, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Éxito sheet ───────────────────────────────────────────────────────────────

class _ExitoSheet extends StatelessWidget {
  const _ExitoSheet({required this.envio});
  final EnvioPorLlave envio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 18),
          const Text(
            'Envío iniciado',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            formatPesos(envio.montoCentavos),
            style: const TextStyle(
              color: AppColors.accentGreen, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          _Row(label: 'Llave', valor: envio.llave),
          _Row(label: 'Tipo', valor: envio.tipoLlave),
          const SizedBox(height: 24),
          const Text(
            'El envío puede tardar hasta 24 horas en acreditarse en la cuenta destino.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Listo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
