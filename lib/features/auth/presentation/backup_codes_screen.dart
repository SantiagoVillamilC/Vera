import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/gradient_button.dart';

// Se muestra tras verificar el celular en el registro, con los códigos de
// respaldo reales que devuelve el backend.
class BackupCodesScreen extends StatefulWidget {
  const BackupCodesScreen({super.key, this.codes = const []});
  final List<String> codes;

  @override
  State<BackupCodesScreen> createState() => _BackupCodesScreenState();
}

class _BackupCodesScreenState extends State<BackupCodesScreen> {
  bool _confirmed = false;

  void _copyAll() {
    final text = widget.codes.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Códigos copiados al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.codes.isEmpty) return const _SinCodigos();
    return AuthBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGreen.withAlpha(80)),
              ),
              child: const Icon(Icons.shield_outlined, color: AppColors.accentGreen, size: 28),
            ),
            const SizedBox(height: 24),
            const Text(
              'Códigos de respaldo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Guarda estos códigos en un lugar seguro. Cada uno solo puede usarse una vez para recuperar tu cuenta si pierdes acceso a tu PIN.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 28),
            _CodesGrid(codes: widget.codes),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _copyAll,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar todos'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const SizedBox(height: 28),
            _ConfirmCheckbox(
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Ir a mi cuenta',
              onPressed: _confirmed ? () => context.go('/home') : null,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Sin códigos reales no se inventa ninguno: se explica y se lleva a /login.
class _SinCodigos extends StatelessWidget {
  const _SinCodigos();

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
            const SizedBox(height: 20),
            const Text(
              'No pudimos mostrar tus códigos de respaldo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Los códigos no llegaron completos. Inicia sesión para continuar y revisa tu cuenta.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Ir a iniciar sesión',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodesGrid extends StatelessWidget {
  const _CodesGrid({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.2,
        ),
        itemCount: codes.length,
        itemBuilder: (context, i) => Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            codes[i],
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmCheckbox extends StatelessWidget {
  const _ConfirmCheckbox({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.accentGreen,
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Guardé mis códigos de respaldo en un lugar seguro',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
