import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/recovery_screen.dart';
import 'package:vera/features/auth/presentation/register_screen.dart';

import '../../home/presentation/cargar_roboto.dart';

// Pantallas de registro y recuperación en alturas bajas con el teclado abierto.
// Los tamaños son en dp (devicePixelRatio 1). El teclado simulado mide 320 dp,
// como el de Gboard en una pantalla de 640 dp, y la barra de estado 24 dp.
const _bajo = Size(360, 640);
const _alto = Size(411, 914);
const _teclado = 340.0;
const _barraEstado = 24.0;

class _FakeOtpRepository implements AuthRepository {
  final reenvios = <String>[];

  @override
  Future<void> resendOtp({
    required String challengeId,
    String? proposito,
  }) async {
    reenvios.add(challengeId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _montar(
  WidgetTester tester,
  Widget pantalla, {
  required Size dp,
  double teclado = 0,
  double barraEstado = _barraEstado,
}) async {
  await cargarRoboto();
  tester.view.physicalSize = dp;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: teclado);
  tester.view.padding = FakeViewPadding(top: barraEstado);
  tester.view.viewPadding = FakeViewPadding(top: barraEstado);
  addTearDown(tester.view.reset);
  final tema = AppTheme.dark.copyWith(
    textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
  );
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(path: '/inicio', builder: (_, _) => pantalla),
      GoRoute(path: '/login', builder: (_, _) => const Text('PANTALLA_LOGIN')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(theme: tema, routerConfig: router));
  await tester.pump();
}

/// Cierra la pantalla y deja correr el contador de reenvío de la pantalla OTP.
Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 61));
}

Future<void> _escribir(WidgetTester tester, int indice, String texto) async {
  await tester.enterText(find.byType(TextFormField).at(indice), texto);
  await tester.pump();
}

/// Verifica que [finder] queda a la vista: dentro de la pantalla, sobre el
/// teclado y, si está en un área desplazable, dentro de su ventana visible.
void _esAlcanzable(WidgetTester tester, Finder finder, Size dp, double teclado) {
  expect(finder, findsOneWidget);
  final r = tester.getRect(finder);
  expect(r.top, greaterThanOrEqualTo(0), reason: 'sobresale por arriba');
  expect(r.bottom, lessThanOrEqualTo(dp.height - teclado),
      reason: 'queda bajo el teclado o fuera de pantalla');
  expect(r.left, greaterThanOrEqualTo(0));
  expect(r.right, lessThanOrEqualTo(dp.width));
  final areas = find.ancestor(
    of: finder,
    matching: find.byType(SingleChildScrollView),
  );
  if (areas.evaluate().isNotEmpty) {
    final v = tester.getRect(areas.first);
    expect(r.top, greaterThanOrEqualTo(v.top - 0.5),
        reason: 'queda recortado por arriba del área desplazable');
    expect(r.bottom, lessThanOrEqualTo(v.bottom + 0.5),
        reason: 'queda recortado por abajo del área desplazable');
  }
}

/// El desplegable de tipo de documento fija un `TextStyle` sin familia, que en
/// las pruebas cae a la fuente Ahem (cada letra es un cuadrado) y desborda de
/// lado a 360 dp. En el dispositivo no ocurre (capturas `360-17` y `360-20`).
void _descartarOverflowDelDesplegable(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    expect(error.toString(), contains('overflowed by'));
    expect(error.toString(), contains('on the right'));
  }
}

Future<void> _traer(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('registro, pasos 1 a 3 con teclado en $_bajo', () {
    testWidgets('paso 1 sin overflow y con el botón alcanzable', (tester) async {
      await _montar(tester, const RegisterScreen(), dp: _bajo, teclado: _teclado);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _escribir(tester, 0, 'María García');
      await _escribir(tester, 1, 'maria@correo.com');
      await _escribir(tester, 2, '3001234567');
      await _traer(tester, find.text('Continuar'));
      _esAlcanzable(tester, find.text('Continuar'), _bajo, _teclado);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu identidad'), findsOneWidget);
      _descartarOverflowDelDesplegable(tester);
    });

    testWidgets('paso 3 sin overflow y con campos y botón alcanzables',
        (tester) async {
      await _montar(tester, const RegisterScreen(), dp: _bajo, teclado: _teclado);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 0, 'María García');
      await _escribir(tester, 1, 'maria@correo.com');
      await _escribir(tester, 2, '3001234567');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await _escribir(tester, 0, '12345678');
      await _escribir(tester, 1, '1990-01-31');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      _descartarOverflowDelDesplegable(tester);
      await tester.showKeyboard(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      expect(find.text('Crea tu contraseña'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final i in [0, 1]) {
        await _traer(tester, find.byType(TextFormField).at(i));
        _esAlcanzable(
          tester,
          find.byType(TextFormField).at(i),
          _bajo,
          _teclado,
        );
      }
      await _traer(tester, find.byKey(const Key('consentimiento_whatsapp_optin')));
      expect(tester.takeException(), isNull);
      await _traer(tester, find.text('Crear cuenta'));
      _esAlcanzable(tester, find.text('Crear cuenta'), _bajo, _teclado);
    });
  });

  group('verifica tu número en $_bajo', () {
    testWidgets('sin overflow, con el 0 y Reenviar alcanzables', (tester) async {
      final repo = _FakeOtpRepository();
      await _montar(
        tester,
        OtpRegisterScreen(
          correo: 'a@b.co',
          celular: '3001234567',
          challengeId: 'c1',
          repository: repo,
        ),
        dp: _bajo,
      );

      expect(tester.takeException(), isNull);
      await _traer(tester, find.text('0'));
      _esAlcanzable(tester, find.text('0'), _bajo, 0);
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 61));
      await _traer(tester, find.text('Reenviar código'));
      _esAlcanzable(tester, find.text('Reenviar código'), _bajo, 0);
      await tester.tap(find.text('Reenviar código'));
      await tester.pump();

      expect(repo.reenvios, ['c1']);
      expect(tester.takeException(), isNull);
      await _cerrar(tester);
    });
  });

  group('separación mínima entre bloques en $_bajo', () {
    testWidgets('verifica tu número: los puntos no tocan el teclado numérico',
        (tester) async {
      await _montar(
        tester,
        OtpRegisterScreen(
          correo: 'a@b.co',
          celular: '3001234567',
          challengeId: 'c1',
          repository: _FakeOtpRepository(),
        ),
        dp: _bajo,
      );

      final puntos = tester.getRect(find.byType(PinDots));
      final teclas = tester.getRect(find.byType(NumPad));
      expect(teclas.top - puntos.bottom, greaterThanOrEqualTo(20));
      await _cerrar(tester);
    });

    testWidgets('recuperar contraseña: el campo no queda pegado al botón',
        (tester) async {
      await _montar(tester, const RecoveryScreen(), dp: _bajo, teclado: _teclado);
      await tester.pumpAndSettle();

      final campo = tester.getRect(find.byType(TextFormField));
      final boton = tester.getRect(find.byType(GradientButton));
      expect(boton.top - campo.bottom, greaterThanOrEqualTo(20));
    });
  });

  group('recuperar contraseña en $_bajo con teclado', () {
    testWidgets('sin overflow, con el campo y el botón alcanzables',
        (tester) async {
      await _montar(tester, const RecoveryScreen(), dp: _bajo, teclado: _teclado);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _traer(tester, find.byType(TextFormField));
      _esAlcanzable(tester, find.byType(TextFormField), _bajo, _teclado);
      await _traer(tester, find.text('Enviar código'));
      _esAlcanzable(tester, find.text('Enviar código'), _bajo, _teclado);

      // Un toque real en el botón: con el campo vacío valida y avisa.
      await tester.tap(find.text('Enviar código'));
      await tester.pump();
      expect(find.text('Ingresa tu correo'), findsOneWidget);
    });
  });

  group('el diseño en $_alto no cambia (medidas de antes de la corrección)', () {
    // Rects tomados del código anterior con Roboto, sin barra de estado.
    void casi(Rect r, double l, double t, double rr, double b) {
      expect(r.left, closeTo(l, 0.6));
      expect(r.top, closeTo(t, 0.6));
      expect(r.right, closeTo(rr, 0.6));
      expect(r.bottom, closeTo(b, 0.6));
    }

    for (final (teclado, botonBottom) in [(0.0, 861.0), (_teclado, 521.0)]) {
      testWidgets('registro, paso 1, teclado $teclado', (tester) async {
        await _montar(tester, const RegisterScreen(),
            dp: _alto, teclado: teclado, barraEstado: 0);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        casi(tester.getRect(find.text('Tus datos')), 28, 107, 155, 152);
        casi(tester.getRect(find.byType(TextFormField).first), 28, 239, 383, 298);
        casi(tester.getRect(find.text('Continuar')), 169.4, botonBottom - 24,
            241.6, botonBottom);
      });
    }

    for (final (teclado, botonBottom) in [(0.0, 857.0), (_teclado, 517.0)]) {
      testWidgets('recuperar contraseña, teclado $teclado', (tester) async {
        await _montar(tester, const RecoveryScreen(),
            dp: _alto, teclado: teclado, barraEstado: 0);
        await tester.pumpAndSettle();

        casi(tester.getRect(find.text('Recuperar contraseña')), 28, 192, 312.6, 237);
        casi(tester.getRect(find.byType(TextFormField)), 28, 348, 383, 407);
        casi(tester.getRect(find.text('Enviar código')), 155.4, botonBottom - 24,
            255.6, botonBottom);
      });
    }

    testWidgets('verifica tu número', (tester) async {
      await _montar(
        tester,
        OtpRegisterScreen(
          correo: 'a@b.co',
          celular: '3001234567',
          challengeId: 'c1',
          repository: _FakeOtpRepository(),
        ),
        dp: _alto,
        barraEstado: 0,
      );

      casi(tester.getRect(find.text('Verifica tu número')), 101.8, 252.5, 309.2, 291.5);
      casi(tester.getRect(find.text('0')), 197.9, 758.3, 213.1, 800.3);
      casi(tester.getRect(find.text('Reenviar en 60s')), 154.3, 837.3, 256.7, 858.3);
      await _cerrar(tester);
    });
  });

  group('en $_alto con teclado el botón sigue a la vista sin desplazar', () {
    testWidgets('registro, paso 1', (tester) async {
      await _montar(tester, const RegisterScreen(), dp: _alto, teclado: _teclado);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _esAlcanzable(tester, find.text('Continuar'), _alto, _teclado);
    });

    testWidgets('recuperar contraseña', (tester) async {
      await _montar(tester, const RecoveryScreen(), dp: _alto, teclado: _teclado);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _esAlcanzable(tester, find.text('Enviar código'), _alto, _teclado);
    });
  });
}
