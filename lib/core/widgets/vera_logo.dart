import 'package:flutter/material.dart';
import 'package:vera/core/theme/paleta_vera.dart';

class VeraLogo extends StatelessWidget {
  const VeraLogo({super.key, this.size = 28, this.color});

  final double size;

  /// Color del texto. Si es nulo usa el texto principal del modo activo.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Vera.',
      style: TextStyle(
        color: color ?? context.paleta.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    );
  }
}
