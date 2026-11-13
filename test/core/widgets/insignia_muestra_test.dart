import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/insignia_muestra.dart';

import '../../features/home/presentation/cargar_roboto.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget hijo, {
  double escala = 1,
  Size size = const Size(320, 640),
}) async {
  await cargarRoboto();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: Scaffold(body: Center(child: hijo)),
    ),
  );
}

void main() {
  testWidgets('la insignia dice Datos de muestra', (tester) async {
    await _pump(tester, const InsigniaMuestra());

    expect(find.text(rotuloDatosDeMuestra), findsOneWidget);
  });

  testWidgets('la versión compacta dice Muestra', (tester) async {
    await _pump(tester, const InsigniaMuestra(compacta: true));

    expect(find.text('Muestra'), findsOneWidget);
    expect(find.text(rotuloDatosDeMuestra), findsNothing);
  });

  testWidgets('un lector de pantalla la anuncia en las dos versiones', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    for (final compacta in [false, true]) {
      await _pump(tester, InsigniaMuestra(compacta: compacta));

      expect(
        find.bySemanticsLabel(rotuloDatosDeMuestra),
        findsOneWidget,
        reason: 'compacta: $compacta',
      );
    }
    semantica.dispose();
  });

  testWidgets('el aviso nombra el detalle y lo anuncia completo', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await _pump(tester, const AvisoMuestra(detalle: 'la curva es de ejemplo'));

    expect(
      find.text('$rotuloDatosDeMuestra: la curva es de ejemplo'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('$rotuloDatosDeMuestra. la curva es de ejemplo'),
      findsOneWidget,
    );
    semantica.dispose();
  });

  testWidgets('con letra 2.0 crece pero con tope y no desborda', (
    tester,
  ) async {
    await _pump(tester, const InsigniaMuestra());
    final normal = tester.getSize(find.byType(InsigniaMuestra)).height;

    await _pump(tester, const InsigniaMuestra(), escala: 2);
    final grande = tester.getSize(find.byType(InsigniaMuestra)).height;

    expect(tester.takeException(), isNull);
    // Es contenido: crece con la letra, pero no 2.0 veces.
    expect(grande, greaterThan(normal));
    expect(grande, lessThan(normal * 2));
  });

  testWidgets('el aviso a 2.0 en 320 de ancho no desborda', (tester) async {
    await _pump(
      tester,
      const AvisoMuestra(
        detalle: 'los totales de ingresos y gastos y la curva de este período '
            'son de ejemplo. Tu balance, el gasto por categoría y los '
            'movimientos son reales.',
      ),
      escala: 2,
    );

    expect(tester.takeException(), isNull);
  });
}
