import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/llave_bre_b.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import '../../home/presentation/fake_session_store.dart';

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status);

http.Response _error(int status, String code) => _json(status, {
      'success': false,
      'data': null,
      'error': {'code': code, 'message': 'm'},
      'meta': null,
    });

Map<String, dynamic> _deposito({String estado = 'pendiente'}) => {
      'id': 'd1',
      'referencia': 'DEP-1',
      'monto': '500000',
      'moneda': 'COP',
      'estado': estado,
      'creada_en': '2026-10-05T10:00:00Z',
    };

http.Response _creado() => _json(201, {
      'success': true,
      'data': {..._deposito(), 'url_pago': 'https://pse.test/pagar'},
    });

http.Response _envioCreado() => _json(201, {
      'success': true,
      'data': {
        'id': 'e1',
        'tipo_llave': 'celular',
        'llave': '3001112233',
        'monto': '150000',
        'moneda': 'COP',
        'estado': 'confirmada',
        'creada_en': '2026-10-05T10:00:00Z',
        'actualizada_en': '2026-10-05T10:00:01Z',
      },
    });

class _Harness {
  _Harness(this.responder) {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      session: session,
      clientFactory: () => MockClient((req) async {
        paths.add('${req.method} ${req.url.path}');
        if (req.method == 'POST') {
          cuerpos.add(jsonDecode(req.body) as Map<String, dynamic>);
        }
        return responder(req);
      }),
    );
    repo = NucleoRepository(
      client: client,
      session: session,
      recargaIntent: IdempotencyIntent(),
      envioLlaveIntent: IdempotencyIntent(),
    );
  }

  final Future<http.Response> Function(http.Request) responder;
  final session = FakeSessionStore(access: 'tok', refresh: 'ref');
  final paths = <String>[];
  final cuerpos = <Map<String, dynamic>>[];
  late final NucleoRepository repo;

  List<Object?> get claves => [for (final c in cuerpos) c['idempotency_key']];
}

void main() {
  final monto = BigInt.from(500000);

  group('crearDeposito y getDeposito', () {
    test('crearDeposito devuelve DepositoConPago con url_pago', () async {
      final h = _Harness((_) async => _creado());
      final d = await h.repo.crearDeposito(
        monto: '500000',
        idempotencyKey: 'k1',
      );
      expect(d.urlPago, 'https://pse.test/pagar');
      expect(h.cuerpos.single['idempotency_key'], 'k1');
    });

    test('un POST sin url_pago lanza FormatException', () async {
      final h = _Harness((_) async => _json(201, {
            'success': true,
            'data': _deposito(),
          }));
      await expectLater(
        h.repo.crearDeposito(monto: '500000', idempotencyKey: 'k1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('getDeposito parsea la respuesta sin url_pago', () async {
      final h = _Harness((_) async => _json(200, {
            'success': true,
            'data': _deposito(estado: 'confirmada'),
          }));
      final d = await h.repo.getDeposito('d1');
      expect(d.estado, EstadoDeposito.confirmada);
      expect(h.paths.single, 'GET /v1/depositos/d1');
    });
  });

  group('clave de idempotencia de la recarga', () {
    test('misma clave tras un 503', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1 ? _error(503, 'X') : _creado());
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.recargar(monto);
      expect(h.claves[0], h.claves[1]);
    });

    test('misma clave tras un 429', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1 ? _error(429, 'X') : _creado());
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.recargar(monto);
      expect(h.claves[0], h.claves[1]);
    });

    test('misma clave tras un 500', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1 ? _error(500, 'X') : _creado());
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.recargar(monto);
      expect(h.claves[0], h.claves[1]);
    });

    test('misma clave tras un timeout y tras un fallo de red', () async {
      var n = 0;
      final h = _Harness((_) async {
        n++;
        if (n == 1) throw TimeoutException('t');
        if (n == 2) throw http.ClientException('sin red');
        return _creado();
      });
      await expectLater(h.repo.recargar(monto), throwsA(isA<TimeoutException>()));
      await expectLater(
        h.repo.recargar(monto),
        throwsA(isA<http.ClientException>()),
      );
      await h.repo.recargar(monto);
      expect(h.claves.toSet().length, 1);
    });

    test('misma clave tras un 2xx ilegible', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1
          ? _json(201, {'success': true, 'data': _deposito()})
          : _creado());
      await expectLater(
        h.repo.recargar(monto),
        throwsA(isA<FormatException>()),
      );
      await h.repo.recargar(monto);
      expect(h.claves[0], h.claves[1]);
    });

    test('clave nueva tras un 422', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1 ? _error(422, 'X') : _creado());
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.recargar(monto);
      expect(h.claves[0], isNot(h.claves[1]));
    });

    test('clave nueva tras un éxito', () async {
      final h = _Harness((_) async => _creado());
      await h.repo.recargar(monto);
      await h.repo.recargar(monto);
      expect(h.claves[0], isNot(h.claves[1]));
    });

    test('clave nueva al cambiar el monto', () async {
      final h = _Harness((_) async => _error(503, 'X'));
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await expectLater(
        h.repo.recargar(BigInt.from(600000)),
        throwsA(isA<ApiException>()),
      );
      expect(h.claves[0], isNot(h.claves[1]));
    });

    test('guardia de vuelo: dos toques seguidos hacen un solo POST', () async {
      final espera = Completer<http.Response>();
      final h = _Harness((_) => espera.future);
      final a = h.repo.recargar(monto);
      final b = h.repo.recargar(monto);
      await Future<void>.delayed(Duration.zero);
      espera.complete(_creado());
      await Future.wait([a, b]);
      expect(h.cuerpos, hasLength(1));
    });

    test('la guardia se libera tras un error', () async {
      var n = 0;
      final h = _Harness((_) async => ++n == 1 ? _error(503, 'X') : _creado());
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.recargar(monto);
      expect(h.cuerpos, hasLength(2));
    });

    test('recarga y envío por llave usan instancias separadas', () async {
      var n = 0;
      final h = _Harness((req) async {
        n++;
        if (req.url.path == '/v1/depositos') return _error(503, 'X');
        return _envioCreado();
      });
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      await h.repo.enviarPorLlave(
        tipo: TipoLlaveBreB.celular,
        llave: '3001112233',
        monto: monto,
      );
      await expectLater(h.repo.recargar(monto), throwsA(isA<ApiException>()));
      expect(n, 3);
      // El envío intermedio no renovó ni robó la clave de la recarga.
      expect(h.claves[0], h.claves[2]);
      expect(h.claves[1], isNot(h.claves[0]));
    });
  });

  group('envío por llave', () {
    test('valida y recorta la llave, y envía tipo_llave', () async {
      final h = _Harness((_) async => _envioCreado());
      await h.repo.enviarPorLlave(
        tipo: TipoLlaveBreB.celular,
        llave: ' 3001112233 ',
        monto: BigInt.from(150000),
      );
      expect(h.cuerpos.single['tipo_llave'], 'celular');
      expect(h.cuerpos.single['llave'], '3001112233');
      expect(h.cuerpos.single['monto'], '150000');
    });

    test('una llave inválida lanza sin llamar a la red', () async {
      final h = _Harness((_) async => _envioCreado());
      await expectLater(
        h.repo.enviarPorLlave(
          tipo: TipoLlaveBreB.celular,
          llave: '+573001112233',
          monto: BigInt.from(150000),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(h.paths, isEmpty);
    });

    test('misma clave tras un 503 y nueva al cambiar la llave', () async {
      var n = 0;
      final h = _Harness((_) async => ++n <= 1 ? _error(503, 'X') : _envioCreado());
      final m = BigInt.from(150000);
      await expectLater(
        h.repo.enviarPorLlave(
          tipo: TipoLlaveBreB.celular,
          llave: '3001112233',
          monto: m,
        ),
        throwsA(isA<ApiException>()),
      );
      await h.repo.enviarPorLlave(
        tipo: TipoLlaveBreB.celular,
        llave: '3001112233',
        monto: m,
      );
      expect(h.claves[0], h.claves[1]);
      await h.repo.enviarPorLlave(
        tipo: TipoLlaveBreB.celular,
        llave: '3009998877',
        monto: m,
      );
      expect(h.claves[2], isNot(h.claves[1]));
    });
  });

  group('depósito pendiente', () {
    test('recargar guarda el id del depósito pendiente', () async {
      final h = _Harness((_) async => _creado());
      await h.repo.recargar(monto);
      expect(h.session.pendingDeposit, 'd1');
      expect(await h.repo.depositoPendienteId(), 'd1');
    });

    test('getDeposito en estado terminal borra el pendiente', () async {
      for (final estado in ['confirmada', 'rechazada', 'expirada']) {
        final h = _Harness((_) async => _json(200, {
              'success': true,
              'data': _deposito(estado: estado),
            }));
        h.session.pendingDeposit = 'd1';
        await h.repo.getDeposito('d1');
        expect(h.session.pendingDeposit, isNull, reason: estado);
      }
    });

    test('getDeposito pendiente o desconocido conserva el id', () async {
      for (final estado in ['pendiente', 'reversada']) {
        final h = _Harness((_) async => _json(200, {
              'success': true,
              'data': _deposito(estado: estado),
            }));
        h.session.pendingDeposit = 'd1';
        await h.repo.getDeposito('d1');
        expect(h.session.pendingDeposit, 'd1', reason: estado);
      }
    });

    test('clear() del FakeSessionStore borra el pendiente', () async {
      final s = FakeSessionStore()..pendingDeposit = 'd1';
      await s.clear();
      expect(await s.readDepositoPendiente(), isNull);
    });

    test('clear() del almacén real borra la clave del pendiente', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      const store = FlutterSecureStorageSessionStore();
      await store.saveDepositoPendiente('d9');
      expect(await store.readDepositoPendiente(), 'd9');
      await store.clear();
      expect(await store.readDepositoPendiente(), isNull);
      await store.saveDepositoPendiente('d9');
      await store.clearDepositoPendiente();
      expect(await store.readDepositoPendiente(), isNull);
    });
  });
}
