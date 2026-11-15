import 'package:flutter/material.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/core/widgets/adornos_vera.dart';

/// Superficie de vidrio de VeraDark: relleno translúcido y filo claro.
class TarjetaVidrio extends StatelessWidget {
  const TarjetaVidrio({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radio = 26,
    this.gradiente,
    this.opaca = false,
    this.adorno,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;

  /// Reemplaza el relleno translúcido, por ejemplo en la tarjeta de saldo.
  final Gradient? gradiente;

  /// Relleno sólido para listas largas, donde el vidrio quedaría ilegible.
  final bool opaca;

  /// Dibujo decorativo detrás del contenido, por ejemplo las olas de la tarjeta de saldo.
  final AdornoTarjeta? adorno;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    // Una tarjeta de gradiente es de marca: se ve igual en claro y en oscuro.
    final deMarca = gradiente != null;
    final contenido = adorno == null
        ? child
        : ConAdorno(tipo: adorno!, radio: radio, padding: padding, child: child);
    return Container(
      padding: adorno == null ? padding : null,
      decoration: BoxDecoration(
        gradient: gradiente,
        color: deMarca ? null : (opaca ? paleta.surface : paleta.vidrio),
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(
          color: deMarca
              ? PaletaVera.oscura.borderGlass
              : (opaca ? paleta.border : paleta.borderGlass),
        ),
      ),
      child: deMarca ? ZonaOscura(child: contenido) : contenido,
    );
  }
}
