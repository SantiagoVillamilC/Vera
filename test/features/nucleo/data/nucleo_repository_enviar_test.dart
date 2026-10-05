import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

class _FakeSession implements SessionStore {
  @override
  Future<String?> readAccess() async => 'tok';

  @override
  Future<String?> readRefresh() async => 'ref';

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  

  @override
  Future<SessionProfile> readProfile() async => const SessionProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) async {}

  @override
  Future<String?> readDepositoPendiente() async => null;

  @override
  Future<void> saveDepositoPendiente(String id) async {}

  @override
  Future<void> clearDepositoPendiente() async {}

  @override
  Future<void> clear() async {}
}

NucleoRepository _build(Future<http.Response> Function(http.Request) handler) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    session: _FakeSession(),
    clientFactory: () => MockClient(handler),
  );
  return NucleoRepository(client: client);
}

http.Response _json(int status, Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), status);

http.Response _error(int status, String code) => _json(status, {
      'success': false,
      'data': null,
      'error': {'code': code, 'message': 'm'},
      'meta': null,
    });

http.Response _creada(String estado) => _json(201, {
      'success': true,
      'data': {
        'id': 't1',
        'destino': '+573001112233',
        'monto': '150000',
        'moneda': 'COP',
        'estado': estado,
        'creada_en': '2026-10-05T10:00:00Z',
        'actualizada_en': '2026-10-05T10:00:01Z',
      },
    });

void main() {
  group('normalizarDestino', () {
    test('convierte celular local de 10 dígitos a E.164', () {
      expect(normalizarDestino('300 111 2233'), '+573001112233');
    });

    test('respeta un número con prefijo 57', () {
      expect(normalizarDestino('+57 300 111 2233'), '+573001112233');
    });

    test('devuelve null si está vacío o solo tiene espacios', () {
      expect(normalizarDestino(''), isNull);
      expect(normalizarDestino('   '), isNull);
    });

    test('devuelve null si excede 320 caracteres', () {
      expect(normalizarDestino('3' * 321), isNull);
      // El "+" que agrega E.164 cuenta dentro de los 320.
      expect(normalizarDestino('3' * 319), isNotNull);
      expect(normalizarDestino('3' * 320), isNull);
    });

    test('devuelve null si no hay dígitos', () {
      expect(normalizarDestino('abc'), isNull);
    });
  });

  group('getDestinatario', () {
    test('envía el parámetro celular y devuelve el nombre tal como llega',
        () async {
      Uri? uri;
      final repo = _build((req) async {
        uri = req.url;
        return _json(200, {
          'success': true,
          'data': {'nombre': 'Laura R.'},
        });
      });
      final d = await repo.getDestinatario('+573001112233');
      expect(uri!.path, '/v1/destinatarios');
      expect(uri!.queryParameters, {'celular': '+573001112233'});
      expect(d.nombre, 'Laura R.');
    });

    test('404 RecipientNotFound se propaga como ApiException', () async {
      final repo = _build((req) async => _error(404, 'RecipientNotFound'));
      await expectLater(
        repo.getDestinatario('+573001112233'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'RecipientNotFound')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('getMontoMaximo', () {
    test('conserva el BigInt exacto aunque no sea múltiplo de 100', () async {
      final repo = _build((req) async => _json(200, {
            'success': true,
            'data': {
              'monto': '9007199254740993',
              'moneda': 'COP',
              'calculado_en': '2026-10-05T10:00:00Z',
            },
          }));
      final m = await repo.getMontoMaximo();
      expect(m.montoCentavos, BigInt.parse('9007199254740993'));
      expect(m.montoCentavos % BigInt.from(100), isNot(BigInt.zero));
    });
  });

  group('transferir con IdempotencyIntent', () {
    const destino = '+573001112233';
    final monto = BigInt.from(150000);

    late List<String> claves;
    late List<Map<String, dynamic>> cuerpos;
    late IdempotencyIntent intent;

    setUp(() {
      claves = [];
      cuerpos = [];
      intent = IdempotencyIntent();
    });

    /// Un intento de envío como lo haría la pantalla.
    Future<void> intentar(
      NucleoRepository repo,
    ) async {
      final key = intent.keyFor(destino: destino, monto: monto);
      try {
        await repo.transferir(
          destino: destino,
          monto: monto.toString(),
          idempotencyKey: key,
        );
        intent.registrarExito();
      } on Object catch (e) {
        intent.registrarError(e);
      }
    }

    NucleoRepository respondiendo(Future<http.Response> Function() r) =>
        _build((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          cuerpos.add(body);
          claves.add(body['idempotency_key'] as String);
          return r();
        });

    test('conserva el contrato: monto como string de centavos y clave',
        () async {
      final repo = respondiendo(() async => _creada('confirmada'));
      await intentar(repo);
      expect(cuerpos.single['monto'], '150000');
      expect(cuerpos.single['destino'], destino);
      expect(cuerpos.single['moneda'], 'COP');
      expect(cuerpos.single['idempotency_key'], isA<String>());
    });

    final reintentables = <String, Future<http.Response> Function()>{
      'timeout': () async => throw TimeoutException('t'),
      'error de red': () async => throw http.ClientException('sin red'),
      '500': () async => _error(500, 'InternalError'),
      '503': () async => _error(503, 'AuthUnavailable'),
      '429': () async => _error(429, 'TooManyRequests'),
    };
    reintentables.forEach((nombre, r) {
      test('misma clave en el reintento tras $nombre', () async {
        final repo = respondiendo(r);
        await intentar(repo);
        await intentar(repo);
        expect(claves.length, 2);
        expect(claves[1], claves[0]);
      });
    });

    test('201 con cuerpo no JSON conserva la clave tras registrarError',
        () async {
      final repo = respondiendo(() async => http.Response('<html>ok</html>', 201));
      final key = intent.keyFor(destino: destino, monto: monto);
      Object? error;
      try {
        await repo.transferir(
          destino: destino,
          monto: monto.toString(),
          idempotencyKey: key,
        );
      } on Object catch (e) {
        error = e;
      }
      expect(
        error,
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 201),
      );
      intent.registrarError(error!);
      expect(intent.keyFor(destino: destino, monto: monto), key);
    });

    test('clave nueva tras 201 de cualquier estado', () async {
      for (final estado in [
        'confirmada',
        'fallida',
        'indeterminada',
        'reservada',
        'compensada',
      ]) {
        claves.clear();
        intent = IdempotencyIntent();
        final repo = respondiendo(() async => _creada(estado));
        await intentar(repo);
        await intentar(repo);
        expect(claves[1], isNot(claves[0]), reason: estado);
      }
    });

    test('clave nueva tras 422', () async {
      final repo = respondiendo(() async => _error(422, 'InsufficientFunds'));
      await intentar(repo);
      await intentar(repo);
      expect(claves[1], isNot(claves[0]));
    });

    test('clave nueva tras 409 IdempotencyConflict', () async {
      final repo =
          respondiendo(() async => _error(409, 'IdempotencyConflict'));
      await intentar(repo);
      await intentar(repo);
      expect(claves[1], isNot(claves[0]));
    });

    test('cerrar la hoja de revisión no llama a nada y conserva la clave',
        () async {
      final repo = respondiendo(() async => throw TimeoutException('t'));
      await intentar(repo);
      final antes = intent.keyFor(destino: destino, monto: monto);
      final despues = intent.keyFor(destino: destino, monto: monto);
      expect(claves.length, 1);
      expect(despues, antes);
      expect(antes, claves.single);
    });
  });
}
