import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/app/router.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/home/presentation/enviar_llave_screen.dart';
import 'package:vera/features/home/presentation/recargar_screen.dart';

import '../features/home/presentation/fake_nucleo_repository.dart';
import '../features/home/presentation/fake_session_store.dart';

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

void main() {
  late SessionNotifier session;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester, {required bool authenticated}) async {
    session = SessionNotifier()..setAuthenticated(authenticated);
    router = buildRouter(
      session,
      nucleoRepository: FakeNucleoRepository(),
      sessionStore: FakeSessionStore(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('arranque sin sesion abre /login', (tester) async {
    await pumpApp(tester, authenticated: false);
    expect(_location(router), '/login');
  });

  testWidgets('arranque con sesion abre /home', (tester) async {
    await pumpApp(tester, authenticated: true);
    expect(_location(router), '/home');
  });

  testWidgets('sin sesion /home redirige a /login', (tester) async {
    await pumpApp(tester, authenticated: false);
    router.go('/home');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
  });

  testWidgets('sin sesion /enviar y /estadisticas redirigen a /login',
      (tester) async {
    await pumpApp(tester, authenticated: false);
    router.go('/enviar');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
    router.go('/estadisticas');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
  });

  testWidgets('sin sesion /recargar y /enviar-llave redirigen a /login',
      (tester) async {
    await pumpApp(tester, authenticated: false);
    router.go('/recargar');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
    router.go('/enviar-llave');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
  });

  testWidgets('con sesion /recargar y /enviar-llave abren su pantalla',
      (tester) async {
    await pumpApp(tester, authenticated: true);
    router.go('/recargar');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_location(router), '/recargar');
    expect(find.byType(RecargarScreen), findsOneWidget);
    router.go('/enviar-llave');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_location(router), '/enviar-llave');
    expect(find.byType(EnviarLlaveScreen), findsOneWidget);
  });

  testWidgets('sin sesion /register es accesible', (tester) async {
    await pumpApp(tester, authenticated: false);
    router.go('/register');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/register');
  });

  testWidgets('sin sesion /login/recovery es accesible', (tester) async {
    await pumpApp(tester, authenticated: false);
    router.go('/login/recovery');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login/recovery');
  });

  testWidgets('con sesion /login redirige a /home', (tester) async {
    await pumpApp(tester, authenticated: true);
    router.go('/login');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/home');
  });

  testWidgets('el login exitoso lleva a /home', (tester) async {
    await pumpApp(tester, authenticated: false);
    session.setAuthenticated(true);
    router.go('/login');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/home');
  });

  testWidgets('al pasar authenticated a false se vuelve a /login',
      (tester) async {
    await pumpApp(tester, authenticated: true);
    expect(_location(router), '/home');
    session.setAuthenticated(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_location(router), '/login');
  });
}
