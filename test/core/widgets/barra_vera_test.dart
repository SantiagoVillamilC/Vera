import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/widgets/barra_vera.dart';

import '../../features/home/presentation/cargar_roboto.dart';

Future<void> _pump(
  WidgetTester tester, {
  int indice = 0,
  ValueChanged<int>? alElegir,
  VoidCallback? alAbrirVera,
  Size size = const Size(390, 844),
  double escala = 1,
}) async {
  // Con la fuente de pruebas cada letra mide un cuadrado y el layout no es el real.
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
      home: Scaffold(
        bottomNavigationBar: BarraVera(
          indice: indice,
          alElegir: alElegir ?? (_) {},
          alAbrirVera: alAbrirVera ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('solo el destino activo muestra su nombre', (tester) async {
    await _pump(tester, indice: 1);

    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Tarjetas'), findsNothing);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('tocar un destino avisa su índice', (tester) async {
    final elegidos = <int>[];
    await _pump(tester, alElegir: elegidos.add);

    await tester.tap(find.byKey(const Key('nav_movimientos')));
    await tester.tap(find.byKey(const Key('nav_tarjetas')));
    await tester.tap(find.byKey(const Key('nav_perfil')));

    expect(elegidos, [1, 3, 4]);
  });

  testWidgets('el orbe abre a Vera y no cuenta como destino', (tester) async {
    final elegidos = <int>[];
    var abierta = 0;
    await _pump(tester, alElegir: elegidos.add, alAbrirVera: () => abierta++);

    await tester.tap(find.byKey(const Key('boton_vera')));

    expect(abierta, 1);
    expect(elegidos, isEmpty);
  });

  testWidgets('el orbe muestra el micrófono', (tester) async {
    await _pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('boton_vera')),
        matching: find.byIcon(Icons.mic_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cada destino y el orbe tienen etiqueta semántica', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);

    for (final etiqueta in [
      'Inicio',
      'Movimientos',
      'Tarjetas',
      'Perfil',
      'Hablar con Vera',
    ]) {
      expect(find.bySemanticsLabel(etiqueta), findsOneWidget, reason: etiqueta);
    }
    handle.dispose();
  });

  testWidgets('el orbe no tapa a ningún destino con ninguno activo', (
    tester,
  ) async {
    for (final indice in [0, 1, 3, 4]) {
      await _pump(tester, indice: indice);
      final orbe = tester.getRect(find.byKey(const Key('boton_vera')));
      for (final llave in [
        'nav_inicio',
        'nav_movimientos',
        'nav_tarjetas',
        'nav_perfil',
      ]) {
        final destino = tester.getRect(find.byKey(Key(llave)));
        expect(
          orbe.overlaps(destino),
          isFalse,
          reason: '$llave con el índice $indice activo',
        );
      }
    }
  });

  testWidgets('no desborda a 320 de ancho ni con letra grande', (tester) async {
    for (final indice in [0, 1, 3, 4]) {
      await _pump(
        tester,
        indice: indice,
        size: const Size(320, 640),
        escala: 1.3,
      );
      expect(tester.takeException(), isNull, reason: 'índice $indice');
    }
  });

  testWidgets(
    'al elegir un destino se agranda con animación y aparece su nombre',
    (tester) async {
      await cargarRoboto();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final indice = ValueNotifier<int>(0);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: indice,
              builder: (_, i, _) => BarraVera(
                indice: i,
                alElegir: (n) => indice.value = n,
                alAbrirVera: () {},
              ),
            ),
          ),
        ),
      );
      final inicial = tester
          .getSize(find.byKey(const Key('nav_tarjetas')))
          .width;
      expect(find.text('Tarjetas'), findsNothing);

      await tester.tap(find.byKey(const Key('nav_tarjetas')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final aMedias = tester
          .getSize(find.byKey(const Key('nav_tarjetas')))
          .width;
      await tester.pumpAndSettle();
      final final_ = tester
          .getSize(find.byKey(const Key('nav_tarjetas')))
          .width;

      expect(aMedias, greaterThan(inicial));
      expect(aMedias, lessThan(final_));
      expect(find.text('Tarjetas'), findsOneWidget);
      // El ícono del destino elegido crece.
      final escala = tester
          .widget<AnimatedScale>(
            find
                .descendant(
                  of: find.byKey(const Key('nav_tarjetas')),
                  matching: find.byType(AnimatedScale),
                )
                .last,
          )
          .scale;
      expect(escala, greaterThan(1));
      // Y el anterior vuelve a su tamaño y pierde el nombre.
      expect(find.text('Inicio'), findsNothing);
    },
  );

  testWidgets('al pasar el cursor o mantener pulsado, el botón se agranda', (
    tester,
  ) async {
    await _pump(tester);
    double escala() => tester
        .widget<AnimatedScale>(
          find
              .descendant(
                of: find.byKey(const Key('nav_perfil')),
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;
    expect(escala(), 1);

    final raton = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await raton.addPointer(location: Offset.zero);
    addTearDown(raton.removePointer);
    await raton.moveTo(tester.getCenter(find.byKey(const Key('nav_perfil'))));
    await tester.pumpAndSettle();
    expect(escala(), greaterThan(1));

    await raton.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(escala(), 1);

    final dedo = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('nav_perfil'))),
    );
    await tester.pump();
    expect(escala(), greaterThan(1));
    await dedo.up();
    await tester.pumpAndSettle();
    expect(escala(), 1);
  });
}
