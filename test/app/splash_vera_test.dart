import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/app/splash_vera.dart';

void main() {
  testWidgets('muestra el logo de Vera hasta que todo está listo', (
    tester,
  ) async {
    final listo = Completer<void>();
    var appCreada = 0;
    await tester.pumpWidget(
      Arranque(
        preparar: () => listo.future,
        esperaMinima: const Duration(milliseconds: 300),
        app: () {
          appCreada++;
          return const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('la app'),
          );
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const Key('splash_vera')), findsOneWidget);
    expect(find.byKey(const Key('cargando_vera')), findsOneWidget);
    expect(find.text('vera'), findsOneWidget);
    // Aunque pasó la espera mínima, falta preparar: la app no se construye todavía.
    expect(appCreada, 0);

    listo.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('la app'), findsOneWidget);
    expect(find.byKey(const Key('splash_vera')), findsNothing);
    expect(appCreada, 1);
  });

  testWidgets('no se queda en el splash si preparar falla', (tester) async {
    await tester.pumpWidget(
      Arranque(
        preparar: () async => throw StateError('sin almacenamiento'),
        esperaMinima: const Duration(milliseconds: 100),
        app: () => const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('la app'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('la app'), findsOneWidget);
  });

  testWidgets('la espera mínima evita que el logo parpadee', (tester) async {
    await tester.pumpWidget(
      Arranque(
        preparar: () async {},
        esperaMinima: const Duration(seconds: 2),
        app: () => const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('la app'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('la app'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('la app'), findsOneWidget);
  });
}
