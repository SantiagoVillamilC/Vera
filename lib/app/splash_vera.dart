import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/cargando_vera.dart';
import 'package:vera/core/widgets/fondo_vera.dart';

/// Pantalla de arranque: el logo de Vera sobre el fondo de la app, con su anillo girando.
/// Se parece a la pantalla nativa de lanzamiento para que el paso de una a otra no se note.
class SplashVera extends StatelessWidget {
  const SplashVera({super.key});

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.of(context).disableAnimations;
    // Material da al texto la fuente del tema: el splash vive antes de que exista un Scaffold.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: FondoVera(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reducir
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, hijo) => Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.86 + 0.14 * v, child: hijo),
              ),
              child: const Column(
                key: Key('splash_vera'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  CargandoVera(tamano: 132),
                  SizedBox(height: 18),
                  Text(
                    'vera',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra [SplashVera] mientras [preparar] termina y durante al menos [esperaMinima], para que el
/// logo no parpadee. Después entra a la app con un fundido.
class Arranque extends StatefulWidget {
  const Arranque({
    super.key,
    required this.preparar,
    required this.app,
    this.esperaMinima = const Duration(milliseconds: 1300),
  });

  final Future<void> Function() preparar;

  /// La app real. Se construye solo cuando todo está listo: depende de la sesión ya cargada.
  final Widget Function() app;
  final Duration esperaMinima;

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.preparar(),
      Future<void>.delayed(widget.esperaMinima),
    ]).then<void>((_) {}, onError: (_) {}).whenComplete(() {
      // Si algo falla al preparar, igual se entra: la app cae al inicio de sesión.
      if (mounted) setState(() => _listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _listo
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.app())
          : const KeyedSubtree(key: ValueKey('splash'), child: _SplashRaiz()),
    );
  }
}

/// Splash con su propio [MediaQuery] y [Theme]: aún no hay `MaterialApp` encima.
class _SplashRaiz extends StatelessWidget {
  const _SplashRaiz();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.fromView(
      view: View.of(context),
      child: Theme(data: AppTheme.dark, child: const SplashVera()),
    );
  }
}
