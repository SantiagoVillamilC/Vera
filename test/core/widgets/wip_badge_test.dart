import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/wip_badge.dart';

void main() {
  testWidgets('WipBadge muestra exactamente (WIP)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WipBadge())),
    );

    expect(find.text('(WIP)'), findsOneWidget);
  });

  testWidgets('WipAviso muestra la línea Datos de muestra (WIP)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WipAviso())),
    );

    expect(find.text('Datos de muestra (WIP)'), findsOneWidget);
  });
}
