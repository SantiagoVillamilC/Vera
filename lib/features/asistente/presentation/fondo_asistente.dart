import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Fondo del chat de Vera: degradado de negro a violeta, con luces violetas de la marca que se
/// mueven despacio.
/// Con [intenso] (mientras se graba) las luces brillan más y pulsan más rápido.
/// Respeta "reducir movimiento": en ese caso queda estático.
class FondoAsistente extends StatefulWidget {
  const FondoAsistente({super.key, this.intenso = false});

  final bool intenso;

  @override
  State<FondoAsistente> createState() => _FondoAsistenteState();
}

class _FondoAsistenteState extends State<FondoAsistente>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: widget.intenso ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          builder: (context, k, _) => CustomPaint(
            painter: _FondoPainter(t: _ctrl.value, intensidad: k),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _FondoPainter extends CustomPainter {
  _FondoPainter({required this.t, required this.intensidad});

  final double t;
  final double intensidad;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1040), Color(0xFF050509), Color(0xFF07050F)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    final a = t * 2 * math.pi;
    final fuerza = 1 + 0.9 * intensidad;
    final pulso = 1 + 0.08 * intensidad * math.sin(a * 4);

    void luz(
      Color color,
      double cx,
      double cy,
      double radio,
      double alpha,
      double fase,
    ) {
      final centro = Offset(
        size.width * (cx + 0.08 * math.sin(a + fase)),
        size.height * (cy + 0.06 * math.cos(a + fase * 1.3)),
      );
      final r = size.shortestSide * radio * pulso;
      final alfa = (alpha * fuerza).clamp(0, 255).round();
      canvas.drawCircle(
        centro,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withAlpha(alfa), color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: centro, radius: r)),
      );
    }

    luz(AppColors.gradientStart, 0.85, 0.06, 0.9, 200, 0);
    luz(AppColors.gradientMid, 0.0, 0.3, 0.7, 110, 2.1);
    luz(AppColors.gradientEnd, 1.0, 0.92, 0.7, 120, 4.2);
  }

  @override
  bool shouldRepaint(_FondoPainter old) =>
      old.t != t || old.intensidad != intensidad;
}
