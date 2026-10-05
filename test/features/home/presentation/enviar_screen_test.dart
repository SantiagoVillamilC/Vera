import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/home/presentation/enviar_screen.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';
import 'package:vera/features/nucleo/data/transferencia_mensajes.dart';

class _FakeRepo implements NucleoRepository {
  Future<Destinatario> Function(String celular) onDestinatario =
      (_) async => const Destinatario(nombre: 'Jorge R.');
  Future<MontoCalculado> Function() onMaximo = () async => MontoCalculado(
        montoCentavos: BigInt.from(1234567),
        moneda: 'COP',
        calculadoEn: DateTime(2026),
      );
  Future<Transferencia> Function() onTransferir =
      () async => _transferencia(EstadoTransferencia.confirmada);

  final destinatarioCalls = <String>[];
  final transferirCalls = <({String destino, String monto, String key})>[];

  @override
  Future<Destinatario> getDestinatario(String celularE164) {
    destinatarioCalls.add(celularE164);
    return onDestinatario(celularE164);
  }

  @override
  Future<MontoCalculado> getMontoMaximo() => onMaximo();

  @override
  Future<Transferencia> transferir({
    required String destino,
    required String monto,
    required String idempotencyKey,
  }) {
    transferirCalls.add((destino: destino, monto: monto, key: idempotencyKey));
    return onTransferir();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Transferencia _transferencia(EstadoTransferencia estado) => Transferencia(
      id: 't1',
      destino: '+573001234567',
      montoCentavos: BigInt.from(100),
      moneda: 'COP',
      estado: estado,
      creadaEn: DateTime(2026),
      actualizadaEn: DateTime(2026),
    );

ApiException _api(String code, int status) =>
    ApiException(code: code, message: 'x', statusCode: status);

Future<void> _pump(
  WidgetTester tester,
  _FakeRepo repo, [
  IdempotencyIntent? intent,
]) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: EnviarScreen(repository: repo, intent: intent),
    ),
  );
}

Future<void> _llenar(
  WidgetTester tester, {
  String celular = '3001234567',
  String pesos = '5000',
}) async {
  await tester.enterText(find.byType(TextField).at(0), celular);
  await tester.enterText(find.byType(TextField).at(1), pesos);
  await tester.pump();
}

Future<void> _revisar(WidgetTester tester) async {
  await tester.tap(find.text('Revisar envío'));
  await tester.pumpAndSettle();
}

bool _confirmarHabilitado(WidgetTester tester) =>
    tester.widget<GestureDetector>(find.byKey(const Key('confirmar'))).onTap !=
    null;

Future<void> _confirmar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirmar')));
  await tester.pumpAndSettle();
}

Color? _fondoSnack(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor;

void main() {
  testWidgets('el campo es Celular y ya no habla de nombre', (tester) async {
    await _pump(tester, _FakeRepo());
    expect(find.text('Celular'), findsOneWidget);
    expect(find.text('Celular o nombre'), findsNothing);
    expect(find.text('Jorge Ramírez'), findsNothing);
    expect(find.text('Sin comisión · Llega inmediato'), findsNothing);
  });

  testWidgets('un celular de 10 dígitos llega como +57 al destinatario y al envío',
      (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(repo.destinatarioCalls, ['+573001234567']);
    expect(repo.transferirCalls.single.destino, '+573001234567');
    expect(repo.transferirCalls.single.monto, '500000');
  });

  testWidgets('el campo de celular limita a 320 caracteres', (tester) async {
    await _pump(tester, _FakeRepo());
    await tester.enterText(find.byType(TextField).at(0), '3' * 400);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(field.controller!.text.length, 320);
  });

  testWidgets('enviar el máximo manda los centavos exactos sin redondear',
      (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await tester.enterText(find.byType(TextField).at(0), '3001234567');
    await tester.tap(find.text('Enviar el máximo'));
    await tester.pumpAndSettle();
    await _revisar(tester);

    expect(find.text('\$12.345,67'), findsWidgets);
    await _confirmar(tester);
    expect(repo.transferirCalls.single.monto, '1234567');
  });

  testWidgets('si el usuario edita después del máximo, se usan pesos por 100',
      (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await tester.enterText(find.byType(TextField).at(0), '3001234567');
    await tester.tap(find.text('Enviar el máximo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '2500');
    await tester.pump();
    await _revisar(tester);
    await _confirmar(tester);
    expect(repo.transferirCalls.single.monto, '250000');
  });

  testWidgets('un error al pedir el máximo muestra el mensaje y no llena el monto',
      (tester) async {
    final repo = _FakeRepo()..onMaximo = () async => throw _api('InternalError', 500);
    await _pump(tester, repo);
    await tester.tap(find.text('Enviar el máximo'));
    await tester.pumpAndSettle();
    expect(find.text('Tuvimos un problema de nuestro lado. Intenta más tarde.'),
        findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('la hoja deshabilita Confirmar hasta que el destinatario responde 200',
      (tester) async {
    final repo = _FakeRepo();
    final c = Completer<Destinatario>();
    repo.onDestinatario = (_) => c.future;
    await _pump(tester, repo);
    await _llenar(tester);
    await tester.tap(find.text('Revisar envío'));
    await tester.pump();
    await tester.pump();

    expect(_confirmarHabilitado(tester), isFalse);
    c.complete(const Destinatario(nombre: 'Maria L***'));
    await tester.pumpAndSettle();

    expect(find.text('Maria L***'), findsOneWidget);
    expect(find.text('\$5.000'), findsWidgets);
    expect(_confirmarHabilitado(tester), isTrue);
  });

  testWidgets('un 404 muestra el mensaje en español y no permite confirmar',
      (tester) async {
    final repo = _FakeRepo()
      ..onDestinatario = (_) async => throw _api('RecipientNotFound', 404);
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);

    expect(find.text('No encontramos al destinatario. Revisa los datos.'),
        findsOneWidget);
    expect(_confirmarHabilitado(tester), isFalse);
    await _confirmar(tester);
    expect(repo.transferirCalls, isEmpty);
  });

  testWidgets('un error de red en la consulta ofrece reintentar', (tester) async {
    final repo = _FakeRepo();
    var intento = 0;
    repo.onDestinatario = (_) async {
      intento++;
      if (intento == 1) throw TimeoutException('lento');
      return const Destinatario(nombre: 'Ana P***');
    };
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);

    expect(_confirmarHabilitado(tester), isFalse);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana P***'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);
  });

  testWidgets('un timeout deja Confirmar habilitado y el reintento usa la misma clave',
      (tester) async {
    final repo = _FakeRepo();
    var intento = 0;
    repo.onTransferir = () async {
      intento++;
      if (intento == 1) throw TimeoutException('lento');
      return _transferencia(EstadoTransferencia.confirmada);
    };
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(find.text('Error de conexión. Intenta de nuevo.'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);

    await _confirmar(tester);
    expect(repo.transferirCalls, hasLength(2));
    expect(repo.transferirCalls[1].key, repo.transferirCalls[0].key);
  });

  testWidgets('el reintento reutiliza la clave aunque se cierre y reabra la hoja',
      (tester) async {
    final repo = _FakeRepo();
    var intento = 0;
    repo.onTransferir = () async {
      intento++;
      if (intento == 1) throw TimeoutException('lento');
      return _transferencia(EstadoTransferencia.confirmada);
    };
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await _revisar(tester);
    await _confirmar(tester);

    expect(repo.transferirCalls, hasLength(2));
    expect(repo.transferirCalls[1].key, repo.transferirCalls[0].key);
  });

  testWidgets('tras un envío exitoso la clave se renueva', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(repo.transferirCalls, hasLength(2));
    expect(repo.transferirCalls[1].key, isNot(repo.transferirCalls[0].key));
  });

  testWidgets('tras un 422 la clave se renueva', (tester) async {
    final repo = _FakeRepo();
    var intento = 0;
    repo.onTransferir = () async {
      intento++;
      if (intento == 1) throw _api('InsufficientFunds', 422);
      return _transferencia(EstadoTransferencia.confirmada);
    };
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(find.text('No tienes saldo suficiente para esta operación.'),
        findsOneWidget);
    await _confirmar(tester);
    expect(repo.transferirCalls[1].key, isNot(repo.transferirCalls[0].key));
  });

  testWidgets('un 5xx conserva la clave y muestra el mensaje de reintento',
      (tester) async {
    final repo = _FakeRepo();
    var intento = 0;
    repo.onTransferir = () async {
      intento++;
      if (intento == 1) throw _api('InternalError', 500);
      return _transferencia(EstadoTransferencia.confirmada);
    };
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(find.text(mensajeReintentoEnvio), findsOneWidget);
    await _confirmar(tester);
    expect(repo.transferirCalls[1].key, repo.transferirCalls[0].key);
  });

  testWidgets('solo confirmada usa SnackBar verde', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);
    await _confirmar(tester);

    expect(find.text(resultadoDeEstado(EstadoTransferencia.confirmada).mensaje),
        findsOneWidget);
    expect(_fondoSnack(tester), AppColors.accentGreen);
  });

  for (final estado in EstadoTransferencia.values
      .where((e) => e != EstadoTransferencia.confirmada)) {
    testWidgets('el estado ${estado.name} no usa verde y muestra el mensaje',
        (tester) async {
      final repo = _FakeRepo()
        ..onTransferir = () async => _transferencia(estado);
      await _pump(tester, repo);
      await _llenar(tester);
      await _revisar(tester);
      await _confirmar(tester);

      expect(find.text(resultadoDeEstado(estado).mensaje), findsOneWidget);
      expect(_fondoSnack(tester), isNot(AppColors.accentGreen));
    });
  }

  testWidgets('un doble toque durante el vuelo hace una sola llamada',
      (tester) async {
    final repo = _FakeRepo();
    final c = Completer<Transferencia>();
    repo.onTransferir = () => c.future;
    await _pump(tester, repo);
    await _llenar(tester);
    await _revisar(tester);

    await tester.tap(find.byKey(const Key('confirmar')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmar')), warnIfMissed: false);
    await tester.pump();

    expect(repo.transferirCalls, hasLength(1));
    c.complete(_transferencia(EstadoTransferencia.confirmada));
    await tester.pumpAndSettle();
    expect(repo.transferirCalls, hasLength(1));
  });
}
