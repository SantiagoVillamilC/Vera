import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/cargando_vera.dart';
import 'package:vera/core/widgets/estado_vista.dart';

Widget _en(Widget child, {bool reducir = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducir),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('EstadoVista.cargando usa la carga de Vera', (tester) async {
    await tester.pumpWidget(_en(const EstadoVista.cargando()));
    expect(find.byKey(const Key('cargando_vera')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('el anillo se mueve y con reducir movimiento queda quieto', (
    tester,
  ) async {
    String foto() => tester
        .renderObject<RenderBox>(find.byKey(const Key('cargando_vera')))
        .toString();
    await tester.pumpWidget(_en(const CargandoVera()));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_en(const CargandoVera(), reducir: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(foto(), isNotEmpty);
  });

  testWidgets('muestra el mensaje y lo anuncia como estado de carga', (
    tester,
  ) async {
    await tester.pumpWidget(
      _en(const CargandoVera(mensaje: 'Cargando tus movimientos')),
    );
    expect(find.text('Cargando tus movimientos'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Cargando tus movimientos',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el esqueleto de movimientos se dibuja sin desbordar a 320', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _en(const EsqueletoMovimientos(filas: 6), reducir: true),
    );
    expect(find.byKey(const Key('esqueleto_movimientos')), findsOneWidget);
    expect(find.byType(EsqueletoVera), findsNWidgets(6 * 4));
    expect(tester.takeException(), isNull);
  });
}
