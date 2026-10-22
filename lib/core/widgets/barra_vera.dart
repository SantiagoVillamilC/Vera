import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/marca_vera.dart';

/// Barra de navegación flotante de VeraDark: cuatro destinos y el orbe de Vera al centro.
/// El destino activo se muestra como píldora clara con su nombre.
class BarraVera extends StatelessWidget {
  const BarraVera({
    super.key,
    required this.indice,
    required this.alElegir,
    required this.alAbrirVera,
  });

  /// 0 inicio, 1 movimientos, 3 tarjetas y 4 perfil. El 2 es el orbe de Vera.
  final int indice;
  final ValueChanged<int> alElegir;
  final VoidCallback alAbrirVera;

  static const _destinos = [
    (0, Icons.home_outlined, 'Inicio', Key('nav_inicio')),
    (1, Icons.swap_vert_rounded, 'Movimientos', Key('nav_movimientos')),
    (3, Icons.credit_card_outlined, 'Tarjetas', Key('nav_tarjetas')),
    (4, Icons.person_outline_rounded, 'Perfil', Key('nav_perfil')),
  ];

  @override
  Widget build(BuildContext context) {
    final inferior = MediaQuery.of(context).padding.bottom;
    // La barra es de tamaño fijo: no crece con la letra del sistema.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + inferior),
        child: SizedBox(
          height: 86,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.barra.withAlpha(235),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final conEtiqueta = c.maxWidth > 330;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _item(_destinos[0], conEtiqueta),
                      _item(_destinos[1], conEtiqueta),
                      // El orbe vive en la fila: queda siempre entre dos destinos, aunque la
                      // píldora activa se ensanche y mueva a los demás.
                      SizedBox(
                        width: 74,
                        child: OverflowBox(
                          maxHeight: 100,
                          maxWidth: 74,
                          child: Transform.translate(
                            offset: const Offset(0, -14),
                            child: OrbeVera(alTocar: alAbrirVera),
                          ),
                        ),
                      ),
                      _item(_destinos[2], conEtiqueta),
                      _item(_destinos[3], conEtiqueta),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item((int, IconData, String, Key) d, bool conEtiqueta) {
    final (i, icono, etiqueta, llave) = d;
    final activo = indice == i;
    const duracion = Duration(milliseconds: 340);
    return Semantics(
      button: true,
      selected: activo,
      label: etiqueta,
      excludeSemantics: true,
      onTap: () => alElegir(i),
      child: _Realce(
        key: llave,
        alTocar: () => alElegir(i),
        // Al elegirlo, el destino se ensancha como una píldora clara, su ícono crece con un
        // pequeño rebote, aparece el nombre y el resto de la barra se acomoda con él.
        child: AnimatedContainer(
          duration: duracion,
          curve: Curves.easeOutCubic,
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: activo ? 14 : 8),
          decoration: BoxDecoration(
            color: activo ? AppColors.botonClaro : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.botonClaro.withAlpha(activo ? 60 : 0),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: activo ? 1.14 : 1,
                duration: duracion,
                curve: Curves.easeOutBack,
                child: Icon(
                  icono,
                  size: 24,
                  color: activo
                      ? AppColors.tintaBotonClaro
                      : AppColors.textSecondary,
                ),
              ),
              // El nombre se despliega hacia la derecha mientras se desvanece hacia adentro. El
              // ancho que gana uno es el que pierde el otro, así la barra nunca se desborda.
              TweenAnimationBuilder<double>(
                tween: Tween(end: activo && conEtiqueta ? 1.0 : 0.0),
                duration: duracion,
                curve: Curves.easeOutCubic,
                // Con el nombre totalmente oculto ni siquiera se construye.
                builder: (context, v, hijo) => v <= 0.001
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: hijo,
                          ),
                        ),
                      ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.tintaBotonClaro,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agranda su hijo mientras el cursor pasa por encima o el dedo lo mantiene pulsado.
/// Solo escala el dibujo: el diseño de la barra no cambia, así que nada se desborda.
class _Realce extends StatefulWidget {
  const _Realce({super.key, required this.alTocar, required this.child});

  final VoidCallback alTocar;
  final Widget child;

  @override
  State<_Realce> createState() => _RealceState();
}

class _RealceState extends State<_Realce> {
  bool _encima = false;
  bool _pulsado = false;

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.of(context).disableAnimations;
    final crecido = _encima || _pulsado;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.alTocar,
        onTapDown: (_) => setState(() => _pulsado = true),
        onTapUp: (_) => setState(() => _pulsado = false),
        onTapCancel: () => setState(() => _pulsado = false),
        child: AnimatedScale(
          scale: crecido ? 1.22 : 1,
          duration: reducir ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}
