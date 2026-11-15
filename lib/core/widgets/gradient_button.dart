import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/paleta_vera.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    // En claro, el blanco no se lee sobre el gris del botón deshabilitado.
    final tinta = onPressed == null && paleta.esClara
        ? paleta.textMuted
        : Colors.white;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: onPressed == null ? null : AppGradients.brand,
        color: onPressed == null ? context.paleta.surfaceVariant : null,
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: AppColors.gradientMid.withAlpha(90),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tinta,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: tinta, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: onPressed == null
                              ? context.paleta.textMuted
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
