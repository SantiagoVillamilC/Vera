import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/recovery_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  final reenvios = <({String challengeId, String? proposito})>[];
  int recoveryRequests = 0;
  Object? errorReenvio;

  @override
  Future<void> resendOtp({
    required String challengeId,
    String? proposito,
  }) async {
    reenvios.add((challengeId: challengeId, proposito: proposito));
    if (errorReenvio != null) throw errorReenvio!;
  }

  @override
  Future<String> recoveryRequest({required String correo}) async {
    recoveryRequests++;
    return 'ch-nuevo';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiException _error(String code, [int status = 429]) =>
    ApiException(code: code, message: code, statusCode: status);

Future<GoRouter> _abrir(WidgetTester tester, _FakeAuthRepository repo) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (_, _) => RecoveryOtpScreen(
          correo: 'ana@correo.com',
          challengeId: 'ch-vigente',
          repository: repo,
        ),
      ),
      GoRoute(
        path: '/login/recovery',
        builder: (_, _) => const Text('PANTALLA_RECUPERAR'),
      ),
      GoRoute(path: '/login', builder: (_, _) => const Text('PANTALLA_LOGIN')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  return router;
}

Future<void> _esperarContador(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Desmonta la pantalla y deja correr el último temporizador del contador.
Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tocarReenviar(WidgetTester tester) async {
  await tester.tap(find.text('Reenviar código'));
  await tester.pump();
  await tester.pump();
}

void main() {
  late _FakeAuthRepository repo;
  setUp(() => repo = _FakeAuthRepository());

  testWidgets('el reenvío usa el challenge_id vigente con propósito de recuperación', (
    tester,
  ) async {
    await _abrir(tester, repo);
    expect(find.text('Reenviar código en 60s'), findsOneWidget);
    await _esperarContador(tester);
    await _tocarReenviar(tester);

    expect(repo.reenvios, hasLength(1));
    expect(repo.reenvios.single.challengeId, 'ch-vigente');
    expect(repo.reenvios.single.proposito, 'recuperacion');
    expect(repo.recoveryRequests, 0);
    await _cerrar(tester);
  });

  testWidgets('el contador de 60 s se reinicia solo tras un 200', (
    tester,
  ) async {
    await _abrir(tester, repo);
    await _esperarContador(tester);
    await _tocarReenviar(tester);

    expect(find.text('Reenviar código en 60s'), findsOneWidget);
    expect(find.text('Reenviar código'), findsNothing);
    await _cerrar(tester);
  });

  testWidgets('OtpResendCooldown avisa y no reinicia el contador', (
    tester,
  ) async {
    repo.errorReenvio = _error('OtpResendCooldown');
    await _abrir(tester, repo);
    await _esperarContador(tester);
    await _tocarReenviar(tester);

    expect(
      find.text('Espera cerca de un minuto antes de pedir otro código.'),
      findsOneWidget,
    );
    expect(find.text('Reenviar código'), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsNothing);
  });

  testWidgets('TooManyRequests pide intentar más tarde y no reinicia el contador', (
    tester,
  ) async {
    repo.errorReenvio = _error('TooManyRequests');
    await _abrir(tester, repo);
    await _esperarContador(tester);
    await _tocarReenviar(tester);

    expect(
      find.text('Hiciste demasiadas solicitudes. Intenta de nuevo más tarde.'),
      findsOneWidget,
    );
    expect(find.text('Reenviar código'), findsOneWidget);
    expect(find.textContaining('un minuto'), findsNothing);
  });

  for (final codigo in ['OtpTooManyResends', 'ChallengeInvalid']) {
    testWidgets('$codigo deshabilita el reenvío y ofrece salidas', (
      tester,
    ) async {
      repo.errorReenvio = _error(codigo, codigo == 'ChallengeInvalid' ? 400 : 429);
      await _abrir(tester, repo);
      await _esperarContador(tester);
      await _tocarReenviar(tester);

      expect(find.text('Reenviar código'), findsNothing);
      expect(find.textContaining('Reenviar código en'), findsNothing);
      expect(find.text('Volver a empezar'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  }

  testWidgets('Volver a empezar lleva a /login/recovery', (tester) async {
    repo.errorReenvio = _error('OtpTooManyResends');
    final router = await _abrir(tester, repo);
    await _esperarContador(tester);
    await _tocarReenviar(tester);
    await tester.tap(find.text('Volver a empezar'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/login/recovery',
    );
    expect(find.text('PANTALLA_RECUPERAR'), findsOneWidget);
  });

  testWidgets('Iniciar sesión lleva a /login', (tester) async {
    repo.errorReenvio = _error('ChallengeInvalid', 400);
    final router = await _abrir(tester, repo);
    await _esperarContador(tester);
    await _tocarReenviar(tester);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
  });
}
