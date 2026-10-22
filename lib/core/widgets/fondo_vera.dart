import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/adornos_vera.dart';

/// Fondo de las pantallas principales de VeraDark: azul acerado arriba que cae a casi negro.
class FondoVera extends StatelessWidget {
  const FondoVera({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.fondo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: PinturaHalo())),
          ),
          child,
        ],
      ),
    );
  }
}
