import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

class EnviarScreen extends StatefulWidget {
  const EnviarScreen({super.key});

  @override
  State<EnviarScreen> createState() => _EnviarScreenState();
}

class _EnviarScreenState extends State<EnviarScreen> {
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _repo = NucleoRepository();
  final bool _loading = false;
  bool _enviando = false;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _hasAmount {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return raw.isNotEmpty && int.tryParse(raw) != null && int.parse(raw) > 0;
  }

  bool get _canSend =>
      _hasAmount && _recipientCtrl.text.trim().isNotEmpty;

  int _parseCentavos(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    final pesos = int.tryParse(clean) ?? 0;
    return pesos * 100;
  }

  String _generateKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final hash = now.hashCode ^ Object.hash(now, 'vera');
    return 'vera-${now.toRadixString(16)}-${hash.toRadixString(16)}';
  }

  Future<void> _confirmar() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      final result = await _repo.transferir(
        destino: _recipientCtrl.text.trim(),
        monto: '${_parseCentavos(_amountCtrl.text)}',
        idempotencyKey: _generateKey(),
      );
      if (!mounted) return;
      setState(() => _enviando = false);
      Navigator.of(context).pop(); // cierra el bottom sheet
      _mostrarExito(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    }
  }

  void _mostrarExito(Transferencia t) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Envío creado — estado: ${t.estado.name}'),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  void _onRevisar() {
    if (!_canSend || _loading) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _ConfirmSheet(
          amount: _amountCtrl.text,
          recipient: _recipientCtrl.text,
          enviando: _enviando,
          onConfirm: () {
            setSheetState(() {});
            _confirmar();
          },
        ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textSecondary, size: 22),
            onPressed: () {},
          ),
        ],
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
                            hintText: 'Celular o nombre',
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
                    onChanged: (_) => setState(() {}),
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

            const SizedBox(height: 8),

            // ── Recipient chip (mock — always shown) ────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jorge Ramírez',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '310 234 5678',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.accentGreen, size: 22),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Confirm button ──────────────────────────────────
            GestureDetector(
              onTap: (_loading || !_canSend) ? null : _onRevisar,
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
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
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

            const SizedBox(height: 20),

            // ── Fee label ───────────────────────────────────────
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on_rounded,
                      color: AppColors.accentGreen, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Sin comisión · Llega inmediato',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
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

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.amount,
    required this.recipient,
    required this.onConfirm,
    required this.enviando,
  });

  final String amount;
  final String recipient;
  final VoidCallback onConfirm;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
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
                  '\$$amount',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'a $recipient',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
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
                  onTap: enviando ? null : onConfirm,
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
            ],
          ),
        ],
      ),
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
