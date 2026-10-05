import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  final llamadas = <({String celular, String contrasena})>[];
  Object? error;

  @override
  Future<LoginResult> login({
    required String celular,
    required String contrasena,
  }) async {
    llamadas.add((celular: celular, contrasena: contrasena));
    if (error != null) throw error!;
    return const LoginResult(
      accessToken: 'a',
      refreshToken: 'r',
      usuarioId: 'u',
      tipoCuenta: 'persona',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget Function() pantalla) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(path: '/inicio', builder: (_, _) => pantalla()),
      GoRoute(
        path: '/login/pin',
        builder: (_, _) => const Text('PANTALLA_PIN'),
      ),
      GoRoute(
        path: '/login/recovery',
        builder: (_, _) => const Text('PANTALLA_RECUPERAR'),
      ),
      GoRoute(path: '/home', builder: (_, _) => const Text('PANTALLA_HOME')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextFormField), texto);
  await tester.pump();
}

Future<void> _enviar(WidgetTester tester) async {
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pumpAndSettle();
}

void main() {
  group('LoginScreen', () {
    testWidgets('con 10 dígitos continúa a la pantalla de contraseña', (
      tester,
    ) async {
      await _pump(tester, () => const LoginScreen());
      await _escribir(tester, '3001234567');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA_PIN'), findsOneWidget);
    });
  });

  group('LoginScreen, campo de celular', () {
    String texto(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    testWidgets('no admite más de 10 dígitos', (tester) async {
      await _pump(tester, () => const LoginScreen());
      await _escribir(tester, '63105550404');

      expect(texto(tester), '6310555040');
    });

    testWidgets('un celular pegado con +57 queda en sus 10 dígitos', (
      tester,
    ) async {
      await _pump(tester, () => const LoginScreen());
      await _escribir(tester, '+57 310 555 0404');

      expect(texto(tester), '3105550404');
    });

    testWidgets('con 9 dígitos el botón sigue deshabilitado', (tester) async {
      await _pump(tester, () => const LoginScreen());
      await _escribir(tester, '310555040');

      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
    });
  });

  group('PinScreen (contraseña)', () {
    late _FakeAuthRepository repo;
    setUp(() => repo = _FakeAuthRepository());

    Future<void> abrir(WidgetTester tester) =>
        _pump(tester, () => PinScreen(phone: '3001234567', repository: repo));

    testWidgets('el texto dice contraseña y no PIN', (tester) async {
      await abrir(tester);
      expect(find.textContaining('PIN'), findsNothing);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    });

    testWidgets('el campo es oculto y el botón lo muestra y lo oculta', (
      tester,
    ) async {
      await abrir(tester);
      EditableText campo() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(campo().obscureText, isTrue);
      expect(campo().keyboardType, TextInputType.visiblePassword);
      expect(campo().autocorrect, isFalse);
      expect(campo().enableSuggestions, isFalse);
      expect(campo().autofillHints, contains('password'));

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(campo().obscureText, isFalse);

      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(campo().obscureText, isTrue);
    });

    testWidgets('con menos de 8 caracteres no envía', (tester) async {
      await abrir(tester);
      await _escribir(tester, 'a' * 7);
      await _enviar(tester);
      expect(repo.llamadas, isEmpty);
      expect(
        find.text('La contraseña debe tener al menos 8 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets('con más de 64 caracteres no envía', (tester) async {
      await abrir(tester);
      await _escribir(tester, 'a' * 65);
      await _enviar(tester);
      expect(repo.llamadas, isEmpty);
      expect(
        find.text('La contraseña debe tener como máximo 64 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets('con exactamente 8 caracteres envía', (tester) async {
      await abrir(tester);
      await _escribir(tester, 'Ab1\$ñ 9!');
      await _enviar(tester);
      expect(repo.llamadas, hasLength(1));
      expect(repo.llamadas.single.contrasena, 'Ab1\$ñ 9!');
      expect(repo.llamadas.single.celular, '3001234567');
    });

    testWidgets('con exactamente 64 caracteres envía', (tester) async {
      await abrir(tester);
      await _escribir(tester, 'a' * 64);
      await _enviar(tester);
      expect(repo.llamadas, hasLength(1));
    });

    testWidgets('el login exitoso navega a /home', (tester) async {
      await abrir(tester);
      await _escribir(tester, 'a' * 10);
      await _enviar(tester);
      expect(find.text('PANTALLA_HOME'), findsOneWidget);
    });

    testWidgets('InvalidCredentials se muestra en español', (tester) async {
      repo.error = const ApiException(
        code: 'InvalidCredentials',
        message: 'invalid credentials',
        statusCode: 401,
      );
      await abrir(tester);
      await _escribir(tester, 'a' * 10);
      await _enviar(tester);
      expect(
        find.text('El celular o la contraseña no son correctos.'),
        findsOneWidget,
      );
      expect(find.text('PANTALLA_HOME'), findsNothing);
    });

    testWidgets(
      'un ValidationError del servidor muestra el detalle del campo',
      (tester) async {
        repo.error = const ApiException(
          code: 'ValidationError',
          message: 'validation',
          statusCode: 400,
          details: [
            {'field': 'contrasena', 'rule': 'max', 'param': '64'},
          ],
        );
        await abrir(tester);
        await _escribir(tester, 'a' * 10);
        await _enviar(tester);
        expect(
          find.text('La contraseña debe tener como máximo 64 caracteres'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tras un error se puede reintentar', (tester) async {
      repo.error = const ApiException(
        code: 'InvalidCredentials',
        message: 'x',
        statusCode: 401,
      );
      await abrir(tester);
      await _escribir(tester, 'a' * 10);
      await _enviar(tester);
      repo.error = null;
      await _enviar(tester);
      expect(repo.llamadas, hasLength(2));
      expect(find.text('PANTALLA_HOME'), findsOneWidget);
    });

    testWidgets('los textos visibles no llevan rayas', (tester) async {
      await abrir(tester);
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(textos.contains(String.fromCharCode(0x2014)), isFalse);
      expect(textos.contains(String.fromCharCode(0x2013)), isFalse);
    });
  });
}
