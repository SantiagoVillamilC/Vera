import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/core/widgets/marca_vera.dart';

/// Indicador de carga de Vera: el logo flota dentro de un halo que respira y un anillo que gira.
/// Con "reducir movimiento" queda quieto, pero sigue indicando que algo carga.
class CargandoVera extends StatefulWidget {
  const CargandoVera({super.key, this.tamano = 64, this.mensaje});

  final double tamano;

  /// Texto bajo el logo, por ejemplo "Cargando tus movimientos".
  final String? mensaje;

  @override
  State<CargandoVera> createState() => _CargandoVeraState();
}

class _CargandoVeraState extends State<CargandoVera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    return Semantics(
      label: widget.mensaje ?? 'Cargando',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const Key('cargando_vera'),
              width: t,
              height: t,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final fase = _c.value * 2 * math.pi;
                  final respiro = 0.5 + 0.5 * math.sin(fase);
                  return CustomPaint(
                    painter: _AnilloPainter(
                      giro: fase,
                      respiro: respiro,
                      paleta: context.paleta,
                    ),
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, -math.sin(fase) * t * 0.04),
                        child: MarcaVera(tamano: t * 0.56, chispa: false),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.mensaje != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.mensaje!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.paleta.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  const _AnilloPainter({
    required this.giro,
    required this.respiro,
    required this.paleta,
  });

  final double giro;
  final double respiro;
  final PaletaVera paleta;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    // Halo que respira detrás del logo.
    canvas.drawCircle(
      centro,
      radio * (0.78 + 0.16 * respiro),
      Paint()
        ..shader = RadialGradient(
          colors: [
            paleta.gradientStart.withAlpha((70 + 50 * respiro).round()),
            paleta.gradientStart.withAlpha(0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: radio)),
    );
    final rect = Rect.fromCircle(center: centro, radius: radio - 2);
    // Pista tenue y arco que gira con la cola desvaneciéndose.
    canvas.drawCircle(
      centro,
      radio - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = paleta.velo.withAlpha(22),
    );
    canvas.drawArc(
      rect,
      giro,
      math.pi * 1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: giro,
          endAngle: giro + math.pi * 1.1,
          colors: [paleta.gradientStart.withAlpha(0), paleta.gradientStart],
          transform: GradientRotation(giro),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) =>
      old.giro != giro || old.respiro != respiro || old.paleta != paleta;
}

/// Bloque gris con un brillo que lo recorre: lo que se ve mientras llega una lista.
class EsqueletoVera extends StatefulWidget {
  const EsqueletoVera({
    super.key,
    this.ancho,
    this.alto = 16,
    this.radio = 8,
    this.circulo = false,
  });

  final double? ancho;
  final double alto;
  final double radio;
  final bool circulo;

  @override
  State<EsqueletoVera> createState() => _EsqueletoVeraState();
}

class _EsqueletoVeraState extends State<EsqueletoVera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = -1.5 + 3 * _c.value;
        return Container(
          width: widget.circulo ? widget.alto : widget.ancho,
          height: widget.alto,
          decoration: BoxDecoration(
            shape: widget.circulo ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circulo
                ? null
                : BorderRadius.circular(widget.radio),
            gradient: LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [
                context.paleta.velo.withAlpha(16),
                context.paleta.velo.withAlpha(40),
                context.paleta.velo.withAlpha(16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Filas de movimiento sin datos todavía: círculo, dos renglones y el monto.
class EsqueletoMovimientos extends StatelessWidget {
  const EsqueletoMovimientos({super.key, this.filas = 4});

  final int filas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando movimientos',
      liveRegion: true,
      child: Column(
        key: const Key('esqueleto_movimientos'),
        children: [
          for (var i = 0; i < filas; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const EsqueletoVera(alto: 50, circulo: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EsqueletoVera(ancho: 90.0 + (i % 3) * 30, alto: 14),
                        const SizedBox(height: 8),
                        const EsqueletoVera(ancho: 60, alto: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const EsqueletoVera(ancho: 64, alto: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
