import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/utils/currency.dart';
import 'package:vera/core/utils/idempotency.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';
import 'package:vera/core/network/api_client.dart';

class RecargarScreen extends StatefulWidget {
  const RecargarScreen({super.key});

  @override
  State<RecargarScreen> createState() => _RecargarScreenState();
}

class _RecargarScreenState extends State<RecargarScreen> {
  final _repo = NucleoRepository();
  final _amountCtrl = TextEditingController();
  final _focusNode = FocusNode();

  KycEstado? _kyc;
  bool _loadingKyc = true;
  bool _enviando = false;
  final _idempotency = IdempotencySlot();

  @override
  void initState() {
    super.initState();
    _cargarKyc();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarKyc() async {
    try {
      final kyc = await _repo.getKycEstado();
      if (mounted) setState(() { _kyc = kyc; _loadingKyc = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingKyc = false);
    }
  }

  int get _montoCentavos => parseCentavos(_amountCtrl.text);

  bool get _puedeEnviar {
    if (_montoCentavos <= 0) return false;
    if (_kyc?.disponibleMesCentavos != null &&
        _montoCentavos > _kyc!.disponibleMesCentavos!) return false;
    return true;
  }

  Future<void> _confirmar() async {
    if (!_puedeEnviar || _enviando) return;
    setState(() => _enviando = true);
    try {
      final deposito = await _repo.crearDeposito(
        monto: '$_montoCentavos',
        idempotencyKey: _idempotency.key,
      );
      if (!mounted) return;
      setState(() => _enviando = false);
      _idempotency.clear();
      _mostrarResultado(deposito);
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

  void _mostrarResultado(Deposito deposito) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ResultadoSheet(deposito: deposito),
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
                  if (!_loadingKyc && _kyc != null) _buildLimitesCard(),
                  const SizedBox(height: 24),
                  _buildAmountInput(),
                  const SizedBox(height: 32),
                  _buildConfirmButton(),
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
          const Text(
            'Recargar saldo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitesCard() {
    final kyc = _kyc!;
    final tope = kyc.topeMensualCentavos;
    final disponible = kyc.disponibleMesCentavos;
    final usado = (tope != null && disponible != null) ? tope - disponible : null;
    final progreso = (tope != null && usado != null && tope > 0)
        ? (usado / tope).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  kyc.productoLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LimiteItem(
                  label: 'Tope mensual',
                  valor: tope != null ? formatPesos(tope) : '—',
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _LimiteItem(
                  label: 'Disponible este mes',
                  valor: disponible != null ? formatPesos(disponible) : '—',
                  color: AppColors.accentGreen,
                ),
              ),
            ],
          ),
          if (progreso != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progreso > 0.85 ? Colors.orange : AppColors.gradientStart,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Usaste ${(progreso * 100).toStringAsFixed(0)}% de tu cupo mensual',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuánto vas a recargar?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ingresa el monto en pesos',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          focusNode: _focusNode,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 36,
              fontWeight: FontWeight.w400,
            ),
            hintText: '0',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 36),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.gradientStart, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_kyc?.disponibleMesCentavos != null && _montoCentavos > _kyc!.disponibleMesCentavos!)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Supera tu disponible de ${formatPesos(_kyc!.disponibleMesCentavos!)}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmButton() {
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
          onPressed: _puedeEnviar && !_enviando ? _confirmar : null,
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
                  'Continuar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LimiteItem extends StatelessWidget {
  const _LimiteItem({required this.label, required this.valor, required this.color});
  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ResultadoSheet extends StatelessWidget {
  const _ResultadoSheet({required this.deposito});
  final Deposito deposito;

  String get _estadoLabel => switch (deposito.estado) {
        EstadoDeposito.pendiente => 'Pendiente de confirmación',
        EstadoDeposito.confirmada => 'Confirmada',
        EstadoDeposito.rechazada => 'Rechazada',
        EstadoDeposito.expirada => 'Expirada',
        _ => 'En proceso',
      };

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
            'Recarga iniciada',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatPesos(deposito.montoCentavos),
            style: const TextStyle(
              color: AppColors.accentGreen,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          _InfoRow(label: 'Referencia', valor: deposito.referencia),
          _InfoRow(label: 'Estado', valor: _estadoLabel),
          const SizedBox(height: 24),
          const Text(
            'El dinero se acreditará una vez el depósito sea confirmado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(14),
              ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.valor});
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
