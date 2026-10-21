import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

class VeraLogo extends StatelessWidget {
  const VeraLogo({
    super.key,
    this.size = 28,
    this.color = AppColors.textPrimary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Vera.',
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }
}
