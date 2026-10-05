import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/platform/url_opener.dart';
import 'package:vera/features/home/presentation/recargar_screen.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import 'fake_session_store.dart';

const _intervalo = Duration(seconds: 10);
const _tope = Duration(seconds: 60);

class _FakeRepo implements NucleoRepository {
  Future<DepositoConPago> Function(BigInt monto) onRecargar =
      (_) async => _conPago('https://pago.test/d1');
  Future<Deposito> Function(String id) onGet =
      (_) async => _deposito(EstadoDeposito.pendiente);

  final recargarCalls = <BigInt>[];
  final getCalls = <String>[];

  @override
  Future<DepositoConPago> recargar(BigInt monto) {
    recargarCalls.add(monto);
    return onRecargar(monto);
  }

  @override
  Future<Deposito> getDeposito(String id) {
    getCalls.add(id);
    return onGet(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOpener implements UrlOpener {
  bool resultado = true;
  final abiertas = <Uri>[];

  @override
  Future<bool> abrir(Uri uri) async {
    abiertas.add(uri);
    return resultado;
  }
}

DepositoConPago _conPago(String url, {String id = 'd1'}) => DepositoConPago(
      id: id,
      referencia: 'REF-1',
      montoCentavos: BigInt.from(5000000),
      moneda: 'COP',
      estado: EstadoDeposito.pendiente,
      creadaEn: DateTime.utc(2026),
      urlPago: url,
    );

Deposito _deposito(EstadoDeposito estado, {String id = 'd1'}) => Deposito(
      id: id,
      referencia: 'REF-1',
      montoCentavos: BigInt.from(5000000),
      moneda: 'COP',
      estado: estado,
      creadaEn: DateTime.utc(2026),
    );

ApiException _noEncontrado() => const ApiException(
      code: 'DepositNotFound',
      message: 'x',
      statusCode: 404,
    );

class _Entorno {
  final repo = _FakeRepo();
  final opener = _FakeOpener();
  final session = FakeSessionStore();
}

Future<_Entorno> _pump(
  WidgetTester tester, {
  String? pendiente,
  void Function(_Entorno e)? preparar,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = _Entorno();
  e.session.pendingDeposit = pendiente;
  preparar?.call(e);
  await tester.pumpWidget(
    MaterialApp(
      home: RecargarScreen(
        repository: e.repo,
        urlOpener: e.opener,
        session: e.session,
        intervaloSondeo: _intervalo,
        topeSondeo: _tope,
      ),
    ),
  );
  await tester.pump();
  return e;
}

Future<void> _recargar(WidgetTester tester, {String pesos = '50000'}) async {
  await tester.enterText(find.byKey(const Key('monto')), pesos);
  await tester.pump();
  await tester.tap(find.byKey(const Key('recargar')));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('crear recarga', () {
    testWidgets('crea el depósito y abre url_pago una sola vez', (tester) async {
      final e = await _pump(tester);
      await _recargar(tester);

      expect(e.repo.recargarCalls, [BigInt.from(5000000)]);
      expect(e.opener.abiertas, [Uri.parse('https://pago.test/d1')]);
      expect(e.session.pendingDeposit, 'd1');
      expect(find.text(mensajeRecargaPendiente), findsOneWidget);
    });

    testWidgets('un doble toque hace una sola llamada', (tester) async {
      final completer = Completer<DepositoConPago>();
      final e = await _pump(tester, preparar: (e) {
        e.repo.onRecargar = (_) => completer.future;
      });
      await tester.enterText(find.byKey(const Key('monto')), '50000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('recargar')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('recargar')), warnIfMissed: false);
      await tester.pump();

      expect(e.repo.recargarCalls, hasLength(1));
      completer.complete(_conPago('https://pago.test/d1'));
      await tester.pump();
      await tester.pump();
      expect(e.opener.abiertas, hasLength(1));
    });

    testWidgets('sin monto válido no llama al repositorio', (tester) async {
      final e = await _pump(tester);
      await tester.tap(find.byKey(const Key('recargar')), warnIfMissed: false);
      await tester.pump();
      await tester.enterText(find.byKey(const Key('monto')), '0');
      await tester.pump();
      await tester.tap(find.byKey(const Key('recargar')), warnIfMissed: false);
      await tester.pump();
      expect(e.repo.recargarCalls, isEmpty);
    });

    testWidgets('una url que no es http ni https se rechaza y no se abre',
        (tester) async {
      final e = await _pump(tester, preparar: (e) {
        e.repo.onRecargar = (_) async => _conPago('javascript:alert(1)');
      });
      await _recargar(tester);

      expect(e.opener.abiertas, isEmpty);
      expect(find.byKey(const Key('respaldo-enlace')), findsOneWidget);
      expect(find.text(mensajeEnlaceInseguro), findsOneWidget);
      expect(find.byKey(const Key('copiar-enlace')), findsNothing);
    });

    testWidgets('si abrir devuelve false muestra el enlace y permite copiarlo',
        (tester) async {
      final copiado = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiado.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final e = await _pump(tester, preparar: (e) => e.opener.resultado = false);
      await _recargar(tester);

      expect(e.opener.abiertas, hasLength(1));
      expect(find.byKey(const Key('respaldo-enlace')), findsOneWidget);
      expect(find.text('https://pago.test/d1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copiar-enlace')));
      await tester.pump();
      expect(copiado, ['https://pago.test/d1']);
    });

    testWidgets('un error del servidor se muestra en español', (tester) async {
      final e = await _pump(tester, preparar: (e) {
        e.repo.onRecargar = (_) async => throw const ApiException(
              code: 'OperationLimitExceeded',
              message: 'x',
              statusCode: 422,
            );
      });
      await _recargar(tester);

      expect(find.text('El monto supera el límite permitido por operación.'),
          findsOneWidget);
      expect(e.opener.abiertas, isEmpty);
    });
  });

  group('sondeo', () {
    testWidgets('consulta cada intervalo y se detiene en estado terminal',
        (tester) async {
      final e = await _pump(tester);
      await _recargar(tester);
      expect(e.repo.getCalls, isEmpty);

      await tester.pump(_intervalo);
      expect(e.repo.getCalls, ['d1']);
      await tester.pump(_intervalo);
      expect(e.repo.getCalls, hasLength(2));

      e.repo.onGet = (_) async => _deposito(EstadoDeposito.confirmada);
      await tester.pump(_intervalo);
      expect(e.repo.getCalls, hasLength(3));
      expect(find.text(mensajeRecargaConfirmada), findsOneWidget);
      expect(e.session.pendingDeposit, isNull);

      await tester.pump(_intervalo * 3);
      expect(e.repo.getCalls, hasLength(3));
    });

    testWidgets('una petición a la vez', (tester) async {
      final lenta = Completer<Deposito>();
      final e = await _pump(tester);
      await _recargar(tester);
      e.repo.onGet = (_) => lenta.future;

      await tester.pump(_intervalo);
      await tester.pump(_intervalo);
      await tester.pump(_intervalo);
      expect(e.repo.getCalls, hasLength(1));

      lenta.complete(_deposito(EstadoDeposito.pendiente));
      await tester.pump();
      await tester.pump(_intervalo);
      expect(e.repo.getCalls, hasLength(2));
    });

    testWidgets('se detiene al hacer dispose', (tester) async {
      final e = await _pump(tester);
      await _recargar(tester);
      await tester.pump(_intervalo);
      expect(e.repo.getCalls, hasLength(1));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(_intervalo * 3);
      expect(e.repo.getCalls, hasLength(1));
    });

    testWidgets('al pasar a primer plano consulta el estado', (tester) async {
      final e = await _pump(tester);
      await _recargar(tester);
      expect(e.repo.getCalls, isEmpty);

      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(e.repo.getCalls, isEmpty);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(e.repo.getCalls, ['d1']);
    });

    testWidgets('tras el tope aparece Consultar de nuevo y el sondeo se detiene',
        (tester) async {
      final e = await _pump(tester);
      await _recargar(tester);
      expect(find.byKey(const Key('consultar-de-nuevo')), findsNothing);

      await tester.pump(_tope);
      await tester.pump();
      expect(find.text('Consultar de nuevo'), findsOneWidget);
      final llamadas = e.repo.getCalls.length;
      await tester.pump(_intervalo * 3);
      expect(e.repo.getCalls, hasLength(llamadas));

      await tester.tap(find.byKey(const Key('consultar-de-nuevo')));
      await tester.pump();
      await tester.pump();
      expect(e.repo.getCalls, hasLength(llamadas + 1));
      expect(find.byKey(const Key('consultar-de-nuevo')), findsNothing);
    });
  });

  group('retomar', () {
    testWidgets('con un depósito pendiente guardado consulta su estado',
        (tester) async {
      final e = await _pump(tester, pendiente: 'd9');

      expect(e.repo.getCalls, ['d9']);
      expect(find.text(mensajeRecargaPendiente), findsOneWidget);
      expect(find.byKey(const Key('monto')), findsNothing);
      expect(e.repo.recargarCalls, isEmpty);
    });

    testWidgets('un 404 DepositNotFound borra el pendiente y vuelve al formulario',
        (tester) async {
      final e = await _pump(tester, pendiente: 'viejo', preparar: (e) {
        e.repo.onGet = (_) async => throw _noEncontrado();
      });

      expect(e.session.pendingDeposit, isNull);
      expect(find.byKey(const Key('monto')), findsOneWidget);
      await tester.pump(_intervalo * 3);
      expect(e.repo.getCalls, ['viejo']);
    });

    for (final (titulo, error) in <(String, ApiException)>[
      (
        'un 404 con code NotFound',
        const ApiException(code: 'NotFound', message: 'x', statusCode: 404),
      ),
      (
        'un 404 con un code no reconocido',
        const ApiException(code: 'Otro', message: 'x', statusCode: 404),
      ),
      (
        'un 404 sin code',
        const ApiException(code: '', message: 'x', statusCode: 404),
      ),
      (
        'un code NotFound sin statusCode 404',
        const ApiException(code: 'NotFound', message: 'x', statusCode: 400),
      ),
    ]) {
      testWidgets('$titulo borra el pendiente y vuelve al formulario',
          (tester) async {
        final e = await _pump(tester, pendiente: 'viejo', preparar: (e) {
          e.repo.onGet = (_) async => throw error;
        });

        expect(e.session.pendingDeposit, isNull);
        expect(find.byKey(const Key('monto')), findsOneWidget);
        await tester.pump(_intervalo * 3);
        expect(e.repo.getCalls, ['viejo']);
      });
    }

    testWidgets('un error 500 al retomar conserva el pendiente',
        (tester) async {
      final e = await _pump(tester, pendiente: 'd9', preparar: (e) {
        e.repo.onGet = (_) async => throw const ApiException(
              code: 'InternalError',
              message: 'x',
              statusCode: 500,
            );
      });

      expect(e.session.pendingDeposit, 'd9');
      expect(find.byKey(const Key('monto')), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('un error de red al retomar permite reintentar', (tester) async {
      var falla = true;
      final e = await _pump(tester, pendiente: 'd9', preparar: (e) {
        e.repo.onGet = (_) async {
          if (falla) throw TimeoutException('x');
          return _deposito(EstadoDeposito.pendiente, id: 'd9');
        };
      });
      expect(find.text('Reintentar'), findsOneWidget);
      expect(e.session.pendingDeposit, 'd9');

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expect(find.text(mensajeRecargaPendiente), findsOneWidget);
    });
  });

  group('mensajes de estado terminal', () {
    final casos = <(EstadoDeposito, String)>[
      (EstadoDeposito.confirmada, mensajeRecargaConfirmada),
      (EstadoDeposito.rechazada, mensajeRecargaRechazada),
      (EstadoDeposito.expirada, mensajeRecargaExpirada),
    ];
    for (final (estado, mensaje) in casos) {
      testWidgets('muestra el mensaje de ${estado.name} y borra el pendiente',
          (tester) async {
        final e = await _pump(tester, pendiente: 'd9', preparar: (e) {
          e.repo.onGet = (_) async => _deposito(estado, id: 'd9');
        });

        expect(find.text(mensaje), findsOneWidget);
        expect(e.session.pendingDeposit, isNull);
        await tester.pump(_intervalo * 3);
        expect(e.repo.getCalls, hasLength(1));
      });
    }

    test('los mensajes no llevan rayas largas ni cortas ni punto y coma', () {
      final raya = String.fromCharCode(0x2014);
      final cortaRaya = String.fromCharCode(0x2013);
      for (final m in [
        mensajeRecargaConfirmada,
        mensajeRecargaRechazada,
        mensajeRecargaExpirada,
        mensajeRecargaPendiente,
        mensajeEnlaceInseguro,
      ]) {
        expect(m.contains(raya), isFalse);
        expect(m.contains(cortaRaya), isFalse);
        expect(m.contains(';'), isFalse);
      }
    });
  });
}
