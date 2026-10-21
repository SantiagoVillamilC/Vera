import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';
import 'package:vera/features/nucleo/data/transferencia_mensajes.dart';

void main() {
  group('resultadoDeEstado', () {
    test('solo confirmada es éxito', () {
      for (final e in EstadoTransferencia.values) {
        expect(
          resultadoDeEstado(e).exito,
          e == EstadoTransferencia.confirmada,
          reason: '$e',
        );
      }
    });

    test('los 7 estados y el desconocido tienen mensaje propio', () {
      final mensajes = {
        for (final e in EstadoTransferencia.values) resultadoDeEstado(e).mensaje,
      };
      expect(mensajes.length, EstadoTransferencia.values.length);
      for (final m in mensajes) {
        expect(m, isNotEmpty);
      }
    });

    test('indeterminada, reservada, creada y despachada piden revisar el historial',
        () {
      for (final e in [
        EstadoTransferencia.indeterminada,
        EstadoTransferencia.reservada,
        EstadoTransferencia.creada,
        EstadoTransferencia.despachada,
        EstadoTransferencia.desconocido,
      ]) {
        final m = resultadoDeEstado(e).mensaje.toLowerCase();
        expect(m, contains('historial'), reason: '$e');
        expect(m, isNot(contains('intenta de nuevo')), reason: '$e');
        expect(m, isNot(contains('vuelve a enviar')), reason: '$e');
      }
    });

    test('fallida y compensada son avisos no exitosos', () {
      expect(resultadoDeEstado(EstadoTransferencia.fallida).exito, isFalse);
      expect(resultadoDeEstado(EstadoTransferencia.compensada).exito, isFalse);
    });

    test('ningún mensaje usa raya larga, corta ni punto y coma', () {
      for (final e in EstadoTransferencia.values) {
        final m = resultadoDeEstado(e).mensaje;
        expect(m, isNot(contains(String.fromCharCode(0x2014))));
        expect(m, isNot(contains(String.fromCharCode(0x2013))));
        expect(m, isNot(contains(';')));
      }
    });
  });

  group('mensajeDeErrorEnvio', () {
    const reintento =
        'No pudimos confirmar el envío. Vuelve a intentarlo, no se duplicará.';
    const conexion = 'Error de conexión. Intenta de nuevo.';

    test('500 InternalError sugiere reintentar', () {
      expect(
        mensajeDeErrorEnvio(const ApiException(
          code: 'InternalError',
          message: 'm',
          statusCode: 500,
        )),
        reintento,
      );
    });

    test('503 y otros 5xx sugieren reintentar', () {
      for (final s in [502, 503, 504]) {
        expect(
          mensajeDeErrorEnvio(
            ApiException(code: 'AuthUnavailable', message: 'm', statusCode: s),
          ),
          reintento,
          reason: '$s',
        );
      }
    });

    test('timeout y red usan el mensaje de conexión exacto', () {
      expect(mensajeDeErrorEnvio(TimeoutException('t')), conexion);
      expect(mensajeDeErrorEnvio(http.ClientException('x')), conexion);
    });

    test('los demás códigos van por mensajeDeError', () {
      expect(
        mensajeDeErrorEnvio(const ApiException(
          code: 'InsufficientFunds',
          message: 'm',
          statusCode: 422,
        )),
        'No tienes saldo suficiente para esta operación.',
      );
      expect(
        mensajeDeErrorEnvio(const ApiException(
          code: 'IdempotencyConflict',
          message: 'm',
          statusCode: 409,
        )),
        'Esta operación ya se envió con datos diferentes. Inicia una nueva.',
      );
    });
  });
}
