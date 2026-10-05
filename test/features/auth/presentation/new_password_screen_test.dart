import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/recovery_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  final llamadas = <({String resetToken, String nuevaContrasena})>[];
  Object? error;

  @override
  Future<void> recoveryReset({
    required String resetToken,
    required String nuevaContrasena,
  }) async {
    llamadas.add((resetToken: resetToken, nuevaContrasena: nuevaContrasena));
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _abrir(WidgetTester tester, _FakeAuthRepository repo) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(
        path: '/inicio',
        builder: (_, _) => NewPinScreen(resetToken: 'tok-1', repository: repo),
      ),
      GoRoute(path: '/login', builder: (_, _) => const Text('PANTALLA_LOGIN')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

Future<void> _llenar(WidgetTester tester, String nueva, String confirma) async {
  final campos = find.byType(TextFormField);
  expect(campos, findsNWidgets(2));
  await tester.enterText(campos.at(0), nueva);
  await tester.enterText(campos.at(1), confirma);
  await tester.pump();
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.tap(find.text('Guardar contraseña'));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeAuthRepository repo;
  setUp(() => repo = _FakeAuthRepository());

  testWidgets('pide la contraseña dos veces con campos ocultos', (
    tester,
  ) async {
    await _abrir(tester, repo);
    expect(find.textContaining('PIN'), findsNothing);
    final editables = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(editables, hasLength(2));
    for (final e in editables) {
      expect(e.obscureText, isTrue);
      expect(e.keyboardType, TextInputType.visiblePassword);
      expect(e.autocorrect, isFalse);
      expect(e.enableSuggestions, isFalse);
    }
  });

  testWidgets('el botón de cada campo muestra y oculta el texto', (
    tester,
  ) async {
    await _abrir(tester, repo);
    await tester.tap(find.byTooltip('Mostrar contraseña').first);
    await tester.pump();
    final editables = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(editables.first.obscureText, isFalse);
  });

  testWidgets('con menos de 8 caracteres no envía', (tester) async {
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 7, 'a' * 7);
    await _guardar(tester);
    expect(repo.llamadas, isEmpty);
    expect(
      find.text('La contraseña debe tener al menos 8 caracteres'),
      findsWidgets,
    );
  });

  testWidgets('con más de 64 caracteres no envía', (tester) async {
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 65, 'a' * 65);
    await _guardar(tester);
    expect(repo.llamadas, isEmpty);
    expect(
      find.text('La contraseña debe tener como máximo 64 caracteres'),
      findsWidgets,
    );
  });

  testWidgets('si no coinciden no envía y avisa', (tester) async {
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 10, 'b' * 10);
    await _guardar(tester);
    expect(repo.llamadas, isEmpty);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('con 8 caracteres iguales envía nueva_contrasena y va a /login', (
    tester,
  ) async {
    await _abrir(tester, repo);
    await _llenar(tester, 'Ab1\$ñ 9!', 'Ab1\$ñ 9!');
    await _guardar(tester);
    expect(repo.llamadas, hasLength(1));
    expect(repo.llamadas.single.resetToken, 'tok-1');
    expect(repo.llamadas.single.nuevaContrasena, 'Ab1\$ñ 9!');
    expect(find.text('PANTALLA_LOGIN'), findsOneWidget);
  });

  testWidgets('con 64 caracteres envía', (tester) async {
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 64, 'a' * 64);
    await _guardar(tester);
    expect(repo.llamadas, hasLength(1));
  });

  testWidgets('ResetInvalid se muestra en español', (tester) async {
    repo.error = const ApiException(
      code: 'ResetInvalid',
      message: 'reset invalid',
      statusCode: 400,
    );
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 10, 'a' * 10);
    await _guardar(tester);
    expect(
      find.text(
        'El enlace para restablecer la contraseña no es válido o ya venció.',
      ),
      findsOneWidget,
    );
    expect(find.text('PANTALLA_LOGIN'), findsNothing);
  });

  testWidgets('un ValidationError del servidor muestra el detalle del campo', (
    tester,
  ) async {
    repo.error = const ApiException(
      code: 'ValidationError',
      message: 'validation',
      statusCode: 400,
      details: [
        {'field': 'nueva_contrasena', 'rule': 'min', 'param': '8'},
      ],
    );
    await _abrir(tester, repo);
    await _llenar(tester, 'a' * 10, 'a' * 10);
    await _guardar(tester);
    expect(
      find.text('La contraseña debe tener al menos 8 caracteres'),
      findsOneWidget,
    );
  });
}
