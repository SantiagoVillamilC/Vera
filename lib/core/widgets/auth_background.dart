import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/paleta_vera.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    // Los destellos de luz se atenúan en claro para no ensuciar el fondo.
    final k = paleta.esClara ? 0.5 : 1.0;
    final segundo = paleta.esClara
        ? AppColors.gradientMid
        : AppColors.gradientEnd;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: paleta.background)),
          Positioned(
            top: -180,
            right: -120,
            child: _GlowBlob(
              color: paleta.gradientStart.withAlpha((55 * k).round()),
              size: 420,
            ),
          ),
          Positioned(
            top: 200,
            left: -100,
            child: _GlowBlob(
              color: segundo.withAlpha((35 * k).round()),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -140,
            right: -60,
            child: _GlowBlob(
              color: paleta.accent.withAlpha((20 * k).round()),
              size: 320,
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // En claro el degradado se apaga en el mismo tono: hacia negro transparente
    // dejaría un halo gris sobre el fondo blanco.
    final fin = context.paleta.esClara
        ? color.withAlpha(0)
        : Colors.transparent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, fin]),
      ),
    );
  }
}
