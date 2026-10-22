import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/home/presentation/home_screen.dart';

import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

const _teselas = [
  'acceso_categorias',
  'acceso_estadisticas',
  'acceso_historial_vera',
];

Future<void> _pump(
  WidgetTester tester, {
  bool reducirMovimiento = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: reducirMovimiento),
        child: child!,
      ),
      home: HomeScreen(
        repository: FakeNucleoRepository(),
        session: FakeSessionStore(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Offset _posicion(WidgetTester tester, String llave) =>
    tester.getTopLeft(find.byKey(Key(llave)));

void main() {
  testWidgets('las teselas entran subiendo y con aparición gradual', (
    tester,
  ) async {
    await _pump(tester);
    final alPrincipio = _posicion(tester, _teselas.first);
    final opacidadInicial = tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(Key(_teselas.first)),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    await tester.pump(const Duration(milliseconds: 1200));

    final alFinal = _posicion(tester, _teselas.first);
    // Sube hasta su sitio y termina totalmente visible.
    expect(opacidadInicial, lessThan(0.5));
    expect(alPrincipio.dy, greaterThan(alFinal.dy - 4));
    final opacidadFinal = tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(Key(_teselas.first)),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(opacidadFinal, 1.0);
  });

  testWidgets('después de entrar siguen flotando fuera de fase', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 1500));

    final antes = [for (final t in _teselas) _posicion(tester, t).dy];
    await tester.pump(const Duration(milliseconds: 900));
    final despues = [for (final t in _teselas) _posicion(tester, t).dy];

    for (var i = 0; i < _teselas.length; i++) {
      expect(despues[i], isNot(closeTo(antes[i], 0.01)), reason: _teselas[i]);
    }
    // No se mueven al unísono: cada una va en un punto distinto de su vaivén.
    final desplazamientos = [for (var i = 0; i < 3; i++) despues[i] - antes[i]];
    expect(desplazamientos[0], isNot(closeTo(desplazamientos[1], 0.01)));
  });

  testWidgets('el vaivén se mantiene dentro de unos pocos píxeles', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    final base = _posicion(tester, _teselas.first).dy;
    var minimo = base;
    var maximo = base;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final y = _posicion(tester, _teselas.first).dy;
      if (y < minimo) minimo = y;
      if (y > maximo) maximo = y;
    }

    expect(maximo - minimo, lessThan(9));
    expect(maximo - minimo, greaterThan(3));
  });

  testWidgets('con reducir movimiento las teselas quedan quietas', (
    tester,
  ) async {
    await _pump(tester, reducirMovimiento: true);
    await tester.pump(const Duration(milliseconds: 1500));

    final antes = [for (final t in _teselas) _posicion(tester, t)];
    await tester.pump(const Duration(milliseconds: 900));
    final despues = [for (final t in _teselas) _posicion(tester, t)];

    expect(despues, antes);
  });

  testWidgets('el movimiento termina solo y no deja animaciones colgadas', (
    tester,
  ) async {
    await _pump(tester);

    // pumpAndSettle falla si queda una animación que no acaba.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(minutes: 10),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('al tocar una tesela se hunde mientras está presionada', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    final tesela = find.byKey(const Key('acceso_estadisticas'));
    double escala() => tester
        .widget<AnimatedScale>(
          find.descendant(of: tesela, matching: find.byType(AnimatedScale)),
        )
        .scale;
    expect(escala(), 1.0);

    final gesto = await tester.startGesture(tester.getCenter(tesela));
    // Flutter avisa de «tap down» tras una breve espera, para distinguirlo de un deslizamiento.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(escala(), lessThan(1.0));

    await gesto.cancel();
    await tester.pump();
    expect(escala(), 1.0);
  });
}
