import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/marca_vera.dart';

void main() {
  testWidgets('el avatar muestra las iniciales', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AvatarVera(iniciales: 'VR')),
      ),
    );

    expect(find.text('VR'), findsOneWidget);
  });

  testWidgets('la marca se dibuja con y sin destello', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [MarcaVera(), MarcaVera(chispa: false)]),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(MarcaVera), findsNWidgets(2));
  });

  group('OrbeGrande', () {
    Future<void> montar(WidgetTester t, {bool reducir = false}) => t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
          child: child!,
        ),
        home: const Scaffold(body: Center(child: OrbeGrande())),
      ),
    );

    testWidgets('está siempre en movimiento', (tester) async {
      await montar(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('las ondas que emite cambian de tamaño con el tiempo', (
      tester,
    ) async {
      await montar(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final antes = tester.getSize(find.byType(SizedBox).first);
      List<double> anillos() => [
        for (final w in tester.widgetList<Container>(find.byType(Container)))
          if ((w.decoration as BoxDecoration?)?.border != null)
            w.constraints!.maxWidth,
      ];
      final a = anillos();
      await tester.pump(const Duration(milliseconds: 900));
      final b = anillos();

      expect(antes, isNotNull);
      expect(a, isNotEmpty);
      expect(b, isNot(a));
    });

    testWidgets('con reducir movimiento queda quieta', (tester) async {
      await montar(tester, reducir: true);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('el movimiento termina solo y no cuelga las pruebas', (
      tester,
    ) async {
      await montar(tester);

      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(minutes: 10),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
