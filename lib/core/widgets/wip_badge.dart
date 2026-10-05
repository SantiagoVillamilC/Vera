import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Insignia pequeña que marca una función o un dato en construcción.
class WipBadge extends StatelessWidget {
  const WipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        '(WIP)',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Línea de aviso para pantallas cuyos datos aún son de muestra.
class WipAviso extends StatelessWidget {
  const WipAviso({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 14),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Datos de muestra (WIP)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
