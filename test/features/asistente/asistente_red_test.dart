import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_mensajes.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

const _respuesta = {
  'success': true,
  'data': {
    'conversacion_id': 'c1',
    'mensaje_id': 'm1',
    'texto': 'Hola',
    'creado_en': '2026-10-15T14:17:00-05:00',
  },
  'error': null,
  'meta': null,
};

http.Response _json(Object body, int status, [Map<String, String>? h]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

AsistenteRepository _repo(MockClient mock) => AsistenteRepository(
  client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
);

void main() {
  test('enviarTexto manda Idempotency-Key y el cuerpo del contrato', () async {
    late http.Request visto;
    final repo = _repo(
      MockClient((r) async {
        visto = r;
        return _json(_respuesta, 200);
      }),
    );
    final r = await repo.enviarTexto(
      texto: 'hola',
      idempotencyKey: 'clave-1',
      conversacionId: null,
    );
    expect(r.texto, 'Hola');
    expect(visto.url.path, '/v1/vera/mensajes');
    expect(visto.headers['Idempotency-Key'], 'clave-1');
    expect(jsonDecode(visto.body), {'conversacion_id': null, 'texto': 'hola'});
  });

  test('enviarVoz manda formato m4a y Idempotency-Key', () async {
    late http.Request visto;
    final repo = _repo(
      MockClient((r) async {
        visto = r;
        return _json(_respuesta, 200);
      }),
    );
    await repo.enviarVoz(
      audioM4a: Uint8List.fromList([1, 2, 3]),
      idempotencyKey: 'clave-2',
    );
    final body = jsonDecode(visto.body) as Map<String, dynamic>;
    expect(visto.url.path, '/v1/vera/mensajes/voz');
    expect(visto.headers['Idempotency-Key'], 'clave-2');
    expect(body['formato'], 'm4a');
    expect(base64Decode(body['audio'] as String), [1, 2, 3]);
  });

  test(
    'el cursor opaco viaja tal cual y el 204 del borrado no falla',
    () async {
      final vistos = <http.Request>[];
      final repo = _repo(
        MockClient((r) async {
          vistos.add(r);
          if (r.method == 'DELETE') return http.Response('', 204);
          return _json({
            'success': true,
            'data': <Object>[],
            'error': null,
            'meta': {'limit': 50, 'next_cursor': null, 'has_more': false},
          }, 200);
        }),
      );
      await repo.listarConversaciones(cursor: 'abc==.123');
      await repo.borrarConversacion('c1');
      expect(vistos.first.url.queryParameters['cursor'], 'abc==.123');
      expect(vistos.last.method, 'DELETE');
      expect(vistos.last.url.path, '/v1/vera/conversaciones/c1');
    },
  );

  test(
    'consulta el consentimiento con tipo=asistente_ia y lo otorga',
    () async {
      final vistos = <http.Request>[];
      final repo = _repo(
        MockClient((r) async {
          vistos.add(r);
          if (r.method == 'GET') {
            return _json({
              'success': true,
              'data': {
                'tipo': 'asistente_ia',
                'version_texto': 'v1',
                'texto': 'Texto legal',
                'autorizado': false,
              },
              'error': null,
              'meta': null,
            }, 200);
          }
          return _json({
            'success': true,
            'data': {},
            'error': null,
            'meta': null,
          }, 201);
        }),
      );
      final c = await repo.consultarConsentimiento();
      await repo.otorgarConsentimiento(c.versionTexto);
      expect(vistos.first.url.queryParameters['tipo'], 'asistente_ia');
      expect(jsonDecode(vistos.last.body), {
        'tipo': 'asistente_ia',
        'version_texto': 'v1',
        'aceptado': true,
        'accion': 'otorgar',
        'metodo': 'app',
      });
    },
  );

  test(
    'un 429 conserva Retry-After y el mensaje dice cuánto esperar',
    () async {
      final repo = _repo(
        MockClient(
          (_) async => _json(
            {
              'success': false,
              'data': null,
              'error': {'code': 'TooManyRequests', 'message': 'limit'},
              'meta': null,
            },
            429,
            {'retry-after': '90'},
          ),
        ),
      );
      Object? error;
      try {
        await repo.enviarTexto(texto: 'hola', idempotencyKey: 'k');
      } catch (e) {
        error = e;
      }
      expect(error, isA<ApiException>());
      expect((error! as ApiException).headers?['retry-after'], '90');
      expect(mensajeDeErrorAsistente(error), contains('2 min'));
      expect(esErrorReintentable(error), isFalse);
    },
  );

  test('qué errores se reintentan con la misma clave', () {
    ApiException e(String code, int s) =>
        ApiException(code: code, message: '', statusCode: s);
    expect(esErrorReintentable(TimeoutException('x')), isTrue);
    expect(esErrorReintentable(http.ClientException('x')), isTrue);
    expect(esErrorReintentable(e('AssistantUnavailable', 503)), isTrue);
    expect(esErrorReintentable(e('Timeout', 504)), isTrue);
    expect(esErrorReintentable(e('ConversationBusy', 409)), isTrue);
    expect(esErrorReintentable(e('AudioNotUnderstood', 422)), isFalse);
    expect(esErrorReintentable(e('ConsentRequired', 403)), isFalse);
    expect(esErrorReintentable(e('IdempotencyConflict', 409)), isFalse);
  });

  test('cada envío genera una clave UUID distinta', () {
    final a = nuevaClaveEnvio();
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(nuevaClaveEnvio(), isNot(a));
  });
}
