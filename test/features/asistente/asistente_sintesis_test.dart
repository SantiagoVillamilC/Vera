import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

import '../home/presentation/fake_session_store.dart';

/// WAV PCM16 mono a 24 kHz con [muestras] muestras en silencio.
Uint8List _wav([int muestras = 240]) {
  final datos = muestras * 2;
  final b = BytesBuilder();
  void texto(String s) => b.add(ascii.encode(s));
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  texto('RIFF');
  u32(36 + datos);
  texto('WAVE');
  texto('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(24000);
  u32(48000);
  u16(2);
  u16(16);
  texto('data');
  u32(datos);
  b.add(Uint8List(datos));
  return b.toBytes();
}

http.Response _audio(Uint8List bytes) =>
    http.Response.bytes(bytes, 200, headers: {'content-type': 'audio/wav'});

http.Response _degradado() => http.Response(
  jsonEncode({
    'success': true,
    'data': {'audio_disponible': false, 'voz_local': true},
    'error': null,
    'meta': null,
  }),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'x-vera-audio': 'no-disponible',
  },
);

http.Response _error(int status, String code, [Map<String, String>? h]) =>
    http.Response(
      jsonEncode({
        'success': false,
        'data': null,
        'error': {'code': code, 'message': 'x'},
        'meta': null,
      }),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

AsistenteRepository _repo(
  Future<http.Response> Function(http.Request) manejar, {
  FakeSessionStore? session,
}) => AsistenteRepository(
  client: ApiClient(
    baseUrl: 'http://x',
    session: session ?? FakeSessionStore(access: 'tok', refresh: 'ref'),
    clientFactory: () => MockClient(manejar),
  ),
);

void main() {
  group('sintetizar', () {
    test('envía POST con el texto y el Bearer, y devuelve el WAV', () async {
      late http.Request visto;
      final wav = _wav();
      final repo = _repo((r) async {
        visto = r;
        return _audio(wav);
      });

      final audio = await repo.sintetizar('Hola, soy Vera.');

      expect(audio, wav);
      expect(visto.method, 'POST');
      expect(visto.url.path, '/v1/vera/sintetizar');
      expect(visto.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(visto.body), {'texto': 'Hola, soy Vera.'});
      expect(visto.headers['Accept'], contains('audio/wav'));
      expect(visto.headers.containsKey('X-Vera-Token'), isFalse);
    });

    test(
      'el 200 JSON degradado devuelve null y no se toma por audio',
      () async {
        final repo = _repo((_) async => _degradado());

        expect(await repo.sintetizar('Hola'), isNull);
      },
    );

    test(
      'la cabecera X-Vera-Audio basta para tratarlo como degradado',
      () async {
        final repo = _repo(
          (_) async => http.Response.bytes(
            _wav(),
            200,
            headers: {
              'content-type': 'audio/wav',
              'x-vera-audio': 'no-disponible',
            },
          ),
        );

        expect(await repo.sintetizar('Hola'), isNull);
      },
    );

    test(
      'un 200 con audio/wav pero bytes que no son WAV devuelve null',
      () async {
        final repo = _repo((_) async => _audio(Uint8List.fromList([1, 2, 3])));

        expect(await repo.sintetizar('Hola'), isNull);
      },
    );

    test('un 200 con cuerpo vacío devuelve null', () async {
      final repo = _repo((_) async => _audio(Uint8List(0)));

      expect(await repo.sintetizar('Hola'), isNull);
    });

    test('un WAV que solo trae la cabecera se descarta', () async {
      final repo = _repo((_) async => _audio(_wav(0)));

      expect(await repo.sintetizar('Hola'), isNull);
    });

    test('el 429 llega como ApiException con Retry-After', () async {
      final repo = _repo(
        (_) async => _error(429, 'TooManyRequests', {'retry-after': '120'}),
      );

      await expectLater(
        repo.sintetizar('Hola'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 429)
              .having((e) => e.headers?['retry-after'], 'retry', '120'),
        ),
      );
    });

    test('el 503 y el 422 llegan como ApiException', () async {
      for (final (status, code) in [
        (503, 'AssistantUnavailable'),
        (422, 'ValidationError'),
        (403, 'ConsentRequired'),
      ]) {
        final repo = _repo((_) async => _error(status, code));
        await expectLater(
          repo.sintetizar('Hola'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.code, 'code', code),
          ),
        );
      }
    });

    test('un 401 renueva la sesión y reintenta una vez', () async {
      var llamadas = 0;
      final session = FakeSessionStore(access: 'viejo', refresh: 'r1');
      final repo = _repo((r) async {
        if (r.url.path == '/v1/auth/refresh') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'access_token': 'nuevo', 'refresh_token': 'r2'},
              'error': null,
              'meta': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        llamadas++;
        if (r.headers['Authorization'] == 'Bearer viejo') {
          return _error(401, 'Unauthorized');
        }
        return _audio(_wav());
      }, session: session);

      expect(await repo.sintetizar('Hola'), isNotNull);
      expect(llamadas, 2);
      expect(session.access, 'nuevo');
    });

    test('pasado el plazo lanza TimeoutException', () async {
      final repo = _repo((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _audio(_wav());
      });

      await expectLater(
        repo.sintetizar('Hola', timeout: const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
      'un fallo de red se propaga para que el lector use el respaldo',
      () async {
        final repo = _repo((_) async => throw http.ClientException('sin red'));

        await expectLater(
          repo.sintetizar('Hola'),
          throwsA(isA<http.ClientException>()),
        );
      },
    );
  });

  group('plazo por defecto', () {
    test('es de entre 10 y 12 segundos', () {
      expect(
        AsistenteRepository.timeoutSintesis.inMilliseconds,
        inInclusiveRange(10000, 12000),
      );
    });
  });
}
