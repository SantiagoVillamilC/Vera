import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: AppColors.background),
          ),
          Positioned(
            top: -180,
            right: -120,
            child: _GlowBlob(
              color: AppColors.gradientStart.withAlpha(55),
              size: 420,
            ),
          ),
          Positioned(
            top: 200,
            left: -100,
            child: _GlowBlob(
              color: AppColors.gradientEnd.withAlpha(35),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -140,
            right: -60,
            child: _GlowBlob(
              color: AppColors.accent.withAlpha(20),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
