import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/app/router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

/// Imita lo que hace el repositorio real: registra la llamada, borra la sesión
/// local y avisa al notificador global.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.store, this.notifier);

  final FakeSessionStore store;
  final SessionNotifier notifier;
  int logoutCalls = 0;
  Object? errorTrasLimpiar;

  @override
  Future<void> logout() async {
    logoutCalls++;
    await store.clear();
    notifier.setAuthenticated(false);
    if (errorTrasLimpiar != null) throw errorTrasLimpiar!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _ubicacion(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  late SessionNotifier session;
  late FakeSessionStore store;
  late _FakeAuthRepository auth;
  late GoRouter router;

  Future<void> abrirPerfil(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    session = SessionNotifier()..setAuthenticated(true);
    store = FakeSessionStore(
      access: 'a',
      refresh: 'r',
      profile: const SessionProfile(
        nombreCompleto: 'María Pérez',
        tipoCuenta: 'persona',
      ),
    );
    auth = _FakeAuthRepository(store, session);
    router = buildRouter(
      session,
      authRepository: auth,
      sessionStore: store,
      nucleoRepository: FakeNucleoRepository(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_ubicacion(router), '/home');
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Perfil muestra el nombre guardado en vez de Mi cuenta', (
    tester,
  ) async {
    await abrirPerfil(tester);
    expect(find.text('María Pérez'), findsWidgets);
    expect(find.text('Mi cuenta'), findsNothing);
  });

  testWidgets('cerrar sesión llama al repositorio, borra el perfil y vuelve a /login', (
    tester,
  ) async {
    await abrirPerfil(tester);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.logoutCalls, 1);
    expect(session.authenticated, isFalse);
    expect(_ubicacion(router), '/login');
    expect(store.profile.nombreCompleto, isNull);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  testWidgets('un error del servidor al cerrar sesión no rompe la pantalla', (
    tester,
  ) async {
    await abrirPerfil(tester);
    auth.errorTrasLimpiar = const ApiException(
      code: 'InternalError',
      message: 'boom',
      statusCode: 500,
    );
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.logoutCalls, 1);
    expect(_ubicacion(router), '/login');
    expect(tester.takeException(), isNull);
  });
}
