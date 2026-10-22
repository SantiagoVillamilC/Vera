import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dibujo decorativo de una tarjeta de VeraDark. No lleva datos: solo le da vida a la superficie.
enum AdornoTarjeta {
  /// Líneas de ola abajo, como la tarjeta de saldo.
  olas,

  /// Dos curvas largas que cruzan la cara, como la tarjeta Vera.
  curvas,
}

/// Pinta un [AdornoTarjeta] con un brillo suave arriba a la derecha. Se usa detrás del contenido.
class PinturaAdorno extends CustomPainter {
  const PinturaAdorno(this.tipo);

  final AdornoTarjeta tipo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Brillo difuso arriba a la derecha.
    canvas.drawCircle(
      Offset(w * 0.86, h * 0.04),
      w * 0.5,
      Paint()
        ..shader =
            RadialGradient(
              colors: [Colors.white.withAlpha(52), Colors.white.withAlpha(0)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.86, h * 0.04),
                radius: w * 0.5,
              ),
            ),
    );
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (tipo) {
      case AdornoTarjeta.olas:
        for (var i = 0; i < 3; i++) {
          final base = h * (0.60 + i * 0.07);
          final ruta = Path()..moveTo(0, base);
          for (var x = 0.0; x <= w; x += 4) {
            final t = x / w;
            ruta.lineTo(
              x,
              base +
                  math.sin(t * math.pi * 2 + i * 0.9) * (6 - i * 1.2) -
                  t * (10 + i * 4),
            );
          }
          canvas.drawPath(
            ruta,
            trazo
              ..strokeWidth = 1.2
              ..color = Colors.white.withAlpha(64 - i * 16),
          );
        }
      case AdornoTarjeta.curvas:
        for (var i = 0; i < 2; i++) {
          final desvio = i * w * 0.05;
          final ruta = Path()
            ..moveTo(w * 0.60 + desvio, 0)
            ..cubicTo(
              w * 0.68 + desvio,
              h * 0.34,
              w * 0.74 + desvio,
              h * 0.62,
              w,
              h * (0.74 + i * 0.05),
            );
          canvas.drawPath(
            ruta,
            trazo
              ..strokeWidth = 1.3
              ..color = Colors.white.withAlpha(70 - i * 26),
          );
        }
    }
  }

  @override
  bool shouldRepaint(PinturaAdorno old) => old.tipo != tipo;
}

/// Superficie con un [AdornoTarjeta] detrás del [child]. Recorta el dibujo con [radio].
class ConAdorno extends StatelessWidget {
  const ConAdorno({
    super.key,
    required this.tipo,
    required this.radio,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.expandir = false,
  });

  final AdornoTarjeta tipo;
  final double radio;
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// Cuando la tarjeta tiene alto fijo, el contenido recibe ese alto exacto.
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: expandir ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radio),
              child: CustomPaint(painter: PinturaAdorno(tipo)),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}

/// Halo suave de la esquina superior derecha del fondo, como el de las pantallas del diseño.
class PinturaHalo extends CustomPainter {
  const PinturaHalo();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width * 0.92, size.height * 0.02);
    final radio = size.width * 0.95;
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7FC4D8).withAlpha(46),
            const Color(0xFF7FC4D8).withAlpha(0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: radio)),
    );
  }

  @override
  bool shouldRepaint(PinturaHalo old) => false;
}
