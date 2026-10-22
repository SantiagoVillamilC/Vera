import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/tintes.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Porcentaje con coma decimal, como se escribe en Colombia: `41,2%`.
String porcentajeDe(double parte) =>
    '${(parte * 100).toStringAsFixed(1).replaceAll('.', ',')}%';

/// Casillas de las burbujas: centro y diámetro como fracción del ancho. La más grande va a la
/// izquierda y las demás se reparten sin tocarse. Una categoría más allá de la sexta no se dibuja.
const _casillas = <({double x, double y, double d})>[
  (x: .28, y: .48, d: .50),
  (x: .74, y: .30, d: .36),
  (x: .78, y: .74, d: .30),
  (x: .36, y: .88, d: .26),
  (x: .50, y: .12, d: .22),
  (x: .12, y: .12, d: .18),
];

/// Cuánto de lo gastado se fue en cada categoría. Cada burbuja es una categoría real del mes:
/// su aro dice qué parte del total es y su tamaño sigue el orden, de mayor a menor.
class BurbujasCategorias extends StatelessWidget {
  const BurbujasCategorias({super.key, required this.resumen});

  final ResumenDelMes resumen;

  @override
  Widget build(BuildContext context) {
    final gastos = [
      for (final c in resumen.categorias)
        if (c.totalCentavos != BigInt.zero) c,
    ];
    final total = gastos.fold<double>(
      0,
      (a, c) => a + c.totalCentavos.abs().toDouble(),
    );
    final mostradas = gastos.take(_casillas.length).toList();
    final reducir = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth;
        return SizedBox(
          key: const Key('burbujas_categorias'),
          height: ancho * 1.02,
          child: Stack(
            children: [
              for (var i = 0; i < mostradas.length; i++)
                _posicionada(
                  casilla: _casillas[i],
                  ancho: ancho,
                  hijo: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reducir
                        ? Duration.zero
                        : Duration(milliseconds: 650 + i * 90),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Transform.scale(
                      scale: 0.6 + 0.4 * v,
                      child: Opacity(
                        opacity: v,
                        child: _Burbuja(
                          gasto: mostradas[i],
                          parte:
                              mostradas[i].totalCentavos.abs().toDouble() /
                              total,
                          diametro: _casillas[i].d * ancho,
                          progreso: v,
                          grande: i < 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _posicionada({
    required ({double x, double y, double d}) casilla,
    required double ancho,
    required Widget hijo,
  }) {
    final d = casilla.d * ancho;
    return Positioned(
      left: casilla.x * ancho - d / 2,
      top: casilla.y * ancho - d / 2,
      width: d,
      height: d,
      child: hijo,
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.gasto,
    required this.parte,
    required this.diametro,
    required this.progreso,
    required this.grande,
  });

  final GastoDeCategoria gasto;
  final double parte;
  final double diametro;
  final double progreso;

  /// Las tres mayores llevan el nombre; las demás solo icono y porcentaje.
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final tinte = tinteDeCategoria(gasto.nombre);
    final grueso = diametro > 120;
    return Semantics(
      label: '${gasto.nombre}, ${porcentajeDe(parte)} del gasto del mes',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _AroPainter(
          parte: parte * progreso,
          relleno: Color.alphaBlend(
            tinte.fondo.withAlpha(150),
            Colors.white.withAlpha(18),
          ),
          aro: AppColors.textPrimary,
        ),
        child: Padding(
          padding: EdgeInsets.all(diametro * 0.14),
          // Con la letra del sistema muy grande el contenido se achica, nunca se desborda.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconoDeCategoria(gasto.nombre),
                  size: grueso ? 26 : 20,
                  color: AppColors.textPrimary,
                ),
                if (grande) ...[
                  const SizedBox(height: 4),
                  Text(
                    gasto.nombre,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: grueso ? 15 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                Text(
                  porcentajeDe(parte),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: grueso ? 24 : 15,
                    fontWeight: FontWeight.w800,
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

class _AroPainter extends CustomPainter {
  const _AroPainter({
    required this.parte,
    required this.relleno,
    required this.aro,
  });

  final double parte;
  final Color relleno;
  final Color aro;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    canvas.drawCircle(centro, radio, Paint()..color = relleno);
    canvas.drawCircle(
      centro,
      radio - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.borderGlass,
    );
    // El aro arranca arriba y avanza en sentido horario.
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio - 2),
      -math.pi / 2,
      2 * math.pi * parte.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = aro,
    );
  }

  @override
  bool shouldRepaint(_AroPainter old) =>
      old.parte != parte || old.relleno != relleno;
}
