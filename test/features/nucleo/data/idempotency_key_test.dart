import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

ApiException _api(int status, [String code = 'X']) =>
    ApiException(code: code, message: 'm', statusCode: status);

void main() {
  final destino = '+573001112233';
  final monto = BigInt.from(150000);

  late IdempotencyIntent intent;
  setUp(() {
    final uuid = Uuid();
    final rng = MathRNG(seed: 7);
    intent = IdempotencyIntent(
      generador: () => uuid.v4(config: V4Options(null, rng)),
    );
  });

  group('formato de la clave', () {
    test('es un UUID v4 válido de menos de 128 caracteres', () {
      for (var i = 0; i < 50; i++) {
        final k = IdempotencyIntent().keyFor(destino: destino, monto: monto);
        expect(_uuidV4.hasMatch(k), isTrue, reason: k);
        expect(k.length, lessThan(128));
      }
    });

    test('dos intenciones distintas generan claves distintas', () {
      final a = IdempotencyIntent().keyFor(destino: destino, monto: monto);
      final b = IdempotencyIntent().keyFor(destino: destino, monto: monto);
      expect(a, isNot(b));
    });
  });

  group('vida de la clave', () {
    test('misma clave mientras destino y monto no cambien', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      final b = intent.keyFor(destino: destino, monto: BigInt.from(150000));
      expect(b, a);
    });

    test('cerrar la hoja de revisión no renueva la clave', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      // Cerrar y volver a abrir la hoja solo vuelve a pedir la clave.
      final b = intent.keyFor(destino: destino, monto: monto);
      expect(b, a);
    });

    test('cambia al cambiar el destino', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      final b = intent.keyFor(destino: '+573009998877', monto: monto);
      expect(b, isNot(a));
    });

    test('cambia al cambiar el monto', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      final b = intent.keyFor(destino: destino, monto: monto + BigInt.one);
      expect(b, isNot(a));
    });

    final reutiliza = <String, Object>{
      'TimeoutException': TimeoutException('t'),
      'error de red': http.ClientException('sin red'),
      '500': _api(500, 'InternalError'),
      '502': _api(502),
      '503': _api(503, 'AuthUnavailable'),
      '504': _api(504, 'Timeout'),
      '429': _api(429, 'TooManyRequests'),
      'sin código de estado': const ApiException(code: 'X', message: 'm'),
      'respuesta ilegible (FormatException)': const FormatException('x'),
      '201 con cuerpo ilegible': const ApiException(
        code: 'InternalError',
        message: 'Respuesta inválida del servidor',
        statusCode: 201,
      ),
      '200 con cuerpo ilegible': const ApiException(
        code: 'InternalError',
        message: 'Respuesta inválida del servidor',
        statusCode: 200,
      ),
    };
    reutiliza.forEach((nombre, error) {
      test('reutiliza la clave tras $nombre', () {
        final a = intent.keyFor(destino: destino, monto: monto);
        intent.registrarError(error);
        expect(intent.keyFor(destino: destino, monto: monto), a);
      });
    });

    final renueva = <String, Object>{
      '400': _api(400, 'BadRequest'),
      '401': _api(401, 'Unauthorized'),
      '404': _api(404, 'RecipientNotFound'),
      '409': _api(409, 'IdempotencyConflict'),
      '422': _api(422, 'InsufficientFunds'),
    };
    renueva.forEach((nombre, error) {
      test('renueva la clave tras $nombre', () {
        final a = intent.keyFor(destino: destino, monto: monto);
        intent.registrarError(error);
        expect(intent.keyFor(destino: destino, monto: monto), isNot(a));
      });
    });

    test('renueva la clave tras cualquier 2xx', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      intent.registrarExito();
      expect(intent.keyFor(destino: destino, monto: monto), isNot(a));
    });

    test('tras un reintentable y un cambio de monto la clave cambia', () {
      final a = intent.keyFor(destino: destino, monto: monto);
      intent.registrarError(TimeoutException('t'));
      final b = intent.keyFor(destino: destino, monto: monto + BigInt.one);
      expect(b, isNot(a));
    });
  });
}
