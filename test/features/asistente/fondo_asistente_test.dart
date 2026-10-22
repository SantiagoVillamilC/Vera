import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/asistente/presentation/fondo_asistente.dart';

void main() {
  testWidgets('el fondo se pinta normal e intenso sin errores', (t) async {
    Future<void> montar(bool intenso) => t.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: FondoAsistente(intenso: intenso),
        ),
      ),
    );
    await montar(false);
    await t.pump(const Duration(seconds: 3));
    await montar(true);
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(FondoAsistente), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('con reducir movimiento no anima', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 400, height: 800, child: FondoAsistente()),
        ),
      ),
    );
    await t.pumpAndSettle(); // no se cuelga: no hay animación infinita
  });
}
