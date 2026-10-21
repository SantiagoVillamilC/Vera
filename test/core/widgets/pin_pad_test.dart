import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/pin_pad.dart';

Future<void> _pump(WidgetTester tester, {VoidCallback? onBiometric}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NumPad(
              onDigit: (_) {},
              onDelete: () {},
              onBiometric: onBiometric,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('sin callback la tecla biométrica no se dibuja', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.fingerprint_rounded), findsNothing);
  });

  testWidgets('sin callback el 0 sigue centrado bajo el 8', (tester) async {
    await _pump(tester);

    expect(
      tester.getCenter(find.text('0')).dx,
      closeTo(tester.getCenter(find.text('8')).dx, 0.5),
    );
  });

  testWidgets('con callback la tecla se dibuja y responde', (tester) async {
    var toques = 0;
    await _pump(tester, onBiometric: () => toques++);

    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fingerprint_rounded));
    expect(toques, 1);
  });
}
