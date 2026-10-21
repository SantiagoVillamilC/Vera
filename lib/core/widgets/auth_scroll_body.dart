import 'package:flutter/material.dart';

/// Cuerpo de las pantallas de autenticación que usan `Spacer` para repartir
/// el espacio libre. Si el contenido cabe, ocupa todo el alto disponible y se
/// ve igual que una `Column` normal. Si no cabe (pantallas de 640 dp o menos,
/// o con el teclado abierto), se desplaza en vez de desbordar.
///
/// El alto mínimo sale del `LayoutBuilder`, es decir, del área que de verdad
/// queda libre (descontados el teclado y las zonas seguras).
class AuthScrollBody extends StatelessWidget {
  const AuthScrollBody({super.key, required this.child});

  /// Normalmente una `Column` con `Spacer`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

/// Reemplaza a `Spacer` dentro de [AuthScrollBody]: reparte el espacio libre
/// igual que un `Spacer` con el mismo [flex], pero nunca baja de [minimo].
/// Así, cuando el contenido no cabe y la pantalla se desplaza, los bloques
/// no quedan pegados entre sí.
class EspacioFlexible extends StatelessWidget {
  const EspacioFlexible({super.key, this.flex = 1, required this.minimo});

  final int flex;
  final double minimo;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: SizedBox(height: minimo),
  );
}
