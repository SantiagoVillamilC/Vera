import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Ilustración de Vera: las tarjetas con el punto, en versión estática para iconos pequeños.
class MarcaVera extends StatelessWidget {
  const MarcaVera({super.key, this.tamano = 40, this.chispa = true});

  final double tamano;

  /// El destello de cuatro puntas que acompaña a Vera cuando es el asistente.
  final bool chispa;

  @override
  Widget build(BuildContext context) {
    final w = tamano * 0.62;
    final h = tamano * 0.44;
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: -0.5,
            child: _Tarjeta(
              ancho: w,
              alto: h,
              colores: const [Color(0xFF3F6FD0), Color(0xFF2A4FA8)],
            ),
          ),
          Transform.rotate(
            angle: -0.25,
            child: _Tarjeta(
              ancho: w,
              alto: h,
              colores: const [Color(0xFF6D8FE6), Color(0xFF4B6FCB)],
            ),
          ),
          Transform.rotate(
            angle: 0.08,
            child: _Tarjeta(
              ancho: w,
              alto: h,
              colores: const [Color(0xFFEAF2FF), Color(0xFFBFD2F5)],
              punto: true,
            ),
          ),
          if (chispa)
            Positioned(
              top: -tamano * 0.04,
              right: -tamano * 0.04,
              child: CustomPaint(
                size: Size.square(tamano * 0.3),
                painter: const _ChispaPainter(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.ancho,
    required this.alto,
    required this.colores,
    this.punto = false,
  });

  final double ancho;
  final double alto;
  final List<Color> colores;
  final bool punto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colores,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(alto * 0.28),
      ),
      child: punto
          ? Align(
              alignment: const Alignment(-0.1, -0.15),
              child: Container(
                width: alto * 0.26,
                height: alto * 0.26,
                decoration: const BoxDecoration(
                  color: Color(0xFF2B3FB0),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// Destello de cuatro puntas suelto, para decorar fondos y resultados.
class ChispaVera extends StatelessWidget {
  const ChispaVera({super.key, this.tamano = 16, this.color = Colors.white});

  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(tamano),
    painter: _ChispaPainter(color: color),
  );
}

class _ChispaPainter extends CustomPainter {
  const _ChispaPainter({this.color = Colors.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angulo = -math.pi / 2 + i * math.pi / 4;
      final radio = i.isEven ? r : r * 0.28;
      final p = c + Offset(math.cos(angulo), math.sin(angulo)) * radio;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Botón central de la barra: el orbe con el micrófono que abre a Vera por voz o texto.
class OrbeVera extends StatelessWidget {
  const OrbeVera({super.key, required this.alTocar, this.tamano = 74});

  final VoidCallback alTocar;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hablar con Vera',
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        key: const Key('boton_vera'),
        onTap: alTocar,
        child: Container(
          width: tamano,
          height: tamano,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.barra,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3F8FE0).withAlpha(110),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.orbe,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            // El micrófono: tocar abre a Vera, donde se habla con el flujo de voz del asistente.
            child: Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: tamano * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar con las iniciales de la persona: círculo azul con aro verde menta, como en VeraDark.
class AvatarVera extends StatelessWidget {
  const AvatarVera({super.key, required this.iniciales, this.tamano = 52});

  final String iniciales;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accentGreen.withAlpha(150),
          width: 2,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2F6AA8), Color(0xFF1A3F6E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          iniciales,
          style: TextStyle(
            color: Colors.white,
            fontSize: tamano * 0.34,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// La esfera de Vera con sus aros, como en la pantalla de voz. Está siempre en movimiento: respira,
/// emite ondas hacia afuera, el destello titila y las curvas de su superficie fluyen. Con [activo]
/// (grabando) todo se hace más intenso. Con la opción de accesibilidad de reducir movimiento queda
/// quieta.
class OrbeGrande extends StatefulWidget {
  const OrbeGrande({super.key, this.tamano = 210, this.activo = false});

  final double tamano;
  final bool activo;

  @override
  State<OrbeGrande> createState() => _OrbeGrandeState();
}

class _OrbeGrandeState extends State<OrbeGrande>
    with SingleTickerProviderStateMixin {
  /// Una vuelta completa del movimiento; se repite un buen rato y luego se detiene.
  late final AnimationController _vuelta = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  static const _vueltas = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _vuelta.stop();
    } else if (!_vuelta.isAnimating && _vuelta.value == 0) {
      _vuelta.repeat(count: _vueltas);
    }
  }

  @override
  void dispose() {
    _vuelta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    final activo = widget.activo;
    return SizedBox(
      width: t * 1.5,
      height: t * 1.15,
      child: AnimatedBuilder(
        animation: _vuelta,
        builder: (context, _) {
          final fase = _vuelta.value;
          final seno = math.sin(2 * math.pi * fase);
          // La esfera respira; grabando respira más hondo.
          final respiro = 1 + (activo ? 0.045 : 0.02) * seno;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Ondas que nacen en la esfera, crecen y se desvanecen. Dos, desfasadas.
              for (final desfase in [0.0, 0.5])
                _OndaExpansiva(
                  diametro: t,
                  progreso: (fase + desfase) % 1.0,
                  intensidad: activo ? 1.0 : 0.55,
                ),
              Transform.scale(
                scale: respiro,
                child: Container(
                  width: t,
                  height: t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFB4F2E2),
                        Color(0xFF6CB6F2),
                        Color(0xFF5A6FDA),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      center: Alignment(-0.45, -0.5),
                      radius: 1.05,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF6CB6F2,
                        ).withAlpha(((activo ? 120 : 70) + 25 * seno).round()),
                        blurRadius: 50,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CustomPaint(
                      painter: _OndasDeEsferaPainter(fase: fase),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: t * 0.3,
                top: t * 0.16,
                // El destello gira despacio y titila.
                child: Transform.rotate(
                  angle: 2 * math.pi * fase * 0.5,
                  child: Transform.scale(
                    scale:
                        0.85 +
                        0.25 * (0.5 + 0.5 * math.sin(4 * math.pi * fase)),
                    child: ChispaVera(tamano: t * 0.14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Anillo que se aleja de la esfera mientras se vuelve transparente.
class _OndaExpansiva extends StatelessWidget {
  const _OndaExpansiva({
    required this.diametro,
    required this.progreso,
    required this.intensidad,
  });

  final double diametro;

  /// De 0 (recién nacida) a 1 (desvanecida).
  final double progreso;
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    final tamano = diametro * (1.02 + 0.42 * progreso);
    final alfa = (110 * intensidad * (1 - progreso)).round().clamp(0, 255);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(alfa), width: 1.6),
      ),
    );
  }
}

/// Dos curvas suaves que dan relieve a la esfera. Con [fase] se desplazan, como una corriente.
class _OndasDeEsferaPainter extends CustomPainter {
  const _OndasDeEsferaPainter({this.fase = 0});

  final double fase;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = Colors.white.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    var n = 0;
    for (final (altura, amplitud) in [(0.46, 0.05), (0.7, 0.04)]) {
      // Cada curva oscila hacia un lado distinto y a otra velocidad.
      final giro = 2 * math.pi * fase * (n == 0 ? 1 : -1);
      final subida = math.sin(giro) * size.height * 0.035;
      final path = Path()..moveTo(0, size.height * altura + subida);
      path.cubicTo(
        size.width * (0.3 + 0.08 * math.sin(giro)),
        size.height * (altura - amplitud) - subida,
        size.width * (0.6 - 0.08 * math.sin(giro)),
        size.height * (altura + amplitud) + subida,
        size.width,
        size.height * (altura - amplitud / 2) - subida,
      );
      canvas.drawPath(path, trazo);
      n++;
    }
  }

  @override
  bool shouldRepaint(covariant _OndasDeEsferaPainter old) => old.fase != fase;
}
