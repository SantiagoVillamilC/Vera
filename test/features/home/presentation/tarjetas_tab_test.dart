import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/tarjeta_muestra.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/home/presentation/home_screen.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';

import 'cargar_roboto.dart';
import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

const _avisoMuestra = 'Datos de muestra (WIP)';

Future<void> _pump(
  WidgetTester tester, {
  FakeSessionStore? session,
  Size size = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
}) async {
  if (fuenteReal) await cargarRoboto();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: TarjetasTab(session: session ?? FakeSessionStore()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('la tarjeta muestra el nombre del perfil y no ELISA',
      (tester) async {
    final session = FakeSessionStore(
      profile: const SessionProfile(nombreCompleto: 'Ana Prueba'),
    );
    await _pump(tester, session: session);

    expect(find.text('ANA PRUEBA'), findsOneWidget);
    expect(find.textContaining('ELISA'), findsNothing);
    expect(find.textContaining('Elisa'), findsNothing);
    expect(find.text(nombreTarjetaGenerico), findsNothing);
  });

  testWidgets('con razón social usa la razón social', (tester) async {
    final session = FakeSessionStore(
      profile: const SessionProfile(razonSocial: 'Taller Ejemplo SAS'),
    );
    await _pump(tester, session: session);

    expect(find.text('TALLER EJEMPLO SAS'), findsOneWidget);
  });

  testWidgets('sin perfil la tarjeta dice TU NOMBRE', (tester) async {
    await _pump(tester);

    expect(find.text('TU NOMBRE'), findsOneWidget);
    expect(find.textContaining('ELISA'), findsNothing);
  });

  testWidgets('las constantes compartidas tienen el valor acordado', (_) async {
    expect(tarjetaMuestraRotulo, 'Vera Débito');
    expect(tarjetaMuestraNumero, '•••• •••• •••• 4417');
    expect(tarjetaMuestraVencimiento, '12/27');
    expect(tarjetaMuestraTipo, 'Visa Débito');
    expect(nombreTarjetaGenerico, 'TU NOMBRE');
  });

  testWidgets('muestra número, vencimiento, tipo y estado de muestra',
      (tester) async {
    await _pump(tester);

    expect(find.text(tarjetaMuestraNumero), findsNWidgets(2));
    expect(find.text(tarjetaMuestraVencimiento), findsOneWidget);
    expect(find.text(tarjetaMuestraTipo), findsOneWidget);
    expect(find.text(tarjetaMuestraRotulo), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);
    expect(find.textContaining('●'), findsNothing);
  });

  testWidgets('los movimientos con tarjeta son genéricos y sin marcas',
      (tester) async {
    await _pump(tester);

    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('Suscripción de streaming'), findsOneWidget);
    expect(find.text('Combustible'), findsOneWidget);
    expect(find.text('-\$32.500'), findsOneWidget);
    expect(find.text('-\$34.900'), findsOneWidget);
    expect(find.text('-\$85.000'), findsOneWidget);
    for (final marca in [
      'Rappi',
      'Amazon',
      'Prime',
      'Netflix',
      'Gasolina BP',
      'BP',
      'Mercado',
      'D1',
    ]) {
      expect(find.textContaining(marca), findsNothing);
    }
  });

  testWidgets('muestra el aviso Datos de muestra (WIP)', (tester) async {
    await _pump(tester);

    expect(find.text(_avisoMuestra), findsOneWidget);
    expect(find.text('Mis Tarjetas'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);
  });

  testWidgets('el Home y la pestaña muestran el mismo número y nombre',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: FakeNucleoRepository(),
          session: FakeSessionStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(tarjetaMuestraNumero), findsOneWidget);
    expect(find.text(tarjetaMuestraRotulo), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);

    await tester.tap(find.text('Tarjetas'));
    await tester.pump();
    await tester.pump();

    expect(find.text(tarjetaMuestraNumero), findsNWidgets(2));
    expect(find.text(tarjetaMuestraRotulo), findsOneWidget);
  });

  testWidgets('a 320x640 no hay desborde de RenderFlex', (tester) async {
    await _pump(
      tester,
      session: FakeSessionStore(
        profile: const SessionProfile(
          nombreCompleto: 'Nombre Muy Largo Para Una Tarjeta Angosta',
        ),
      ),
      size: const Size(320, 640),
      fuenteReal: true,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320x640 con textScaleFactor 1.3 no hay desborde',
      (tester) async {
    await _pump(
      tester,
      session: FakeSessionStore(
        profile: const SessionProfile(
          nombreCompleto: 'Nombre Muy Largo Para Una Tarjeta Angosta',
        ),
      ),
      size: const Size(320, 640),
      escala: 1.3,
      fuenteReal: true,
    );

    expect(tester.takeException(), isNull);
  });
}
