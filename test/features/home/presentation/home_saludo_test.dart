import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/app/router.dart';
import 'package:vera/core/network/session_store.dart';

import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

Future<void> _abrirHome(WidgetTester tester, SessionProfile perfil) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = SessionNotifier()..setAuthenticated(true);
  final router = buildRouter(
    session,
    sessionStore: FakeSessionStore(access: 'a', refresh: 'r', profile: perfil),
    nucleoRepository: FakeNucleoRepository(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
  expect(
    router.routerDelegate.currentConfiguration.uri.path,
    '/home',
  );
}

void main() {
  testWidgets('el home saluda con el nombre guardado', (tester) async {
    await _abrirHome(
      tester,
      const SessionProfile(
        nombreCompleto: 'María Pérez',
        tipoCuenta: 'persona',
      ),
    );
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.textContaining('Elisa'), findsNothing);
  });

  testWidgets('el home usa la razón social si solo hay razón social', (
    tester,
  ) async {
    await _abrirHome(
      tester,
      const SessionProfile(razonSocial: 'Cafetería Ñandú S.A.S.'),
    );
    expect(find.text('Cafetería Ñandú S.A.S.'), findsOneWidget);
    expect(find.textContaining('Elisa'), findsNothing);
  });

  testWidgets('el home usa un saludo genérico si no hay nada guardado', (
    tester,
  ) async {
    await _abrirHome(tester, const SessionProfile());
    expect(find.text('Hola'), findsOneWidget);
    expect(find.textContaining('Elisa'), findsNothing);
  });

  testWidgets('un nombre vacío cuenta como no guardado', (tester) async {
    await _abrirHome(
      tester,
      const SessionProfile(nombreCompleto: '  ', razonSocial: 'Mi Empresa'),
    );
    expect(find.text('Mi Empresa'), findsOneWidget);
  });
}
