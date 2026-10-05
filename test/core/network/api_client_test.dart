import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';

class FakeSessionStore implements SessionStore {
  FakeSessionStore({this.access, this.refresh});

  String? access;
  String? refresh;
  int clearCalls = 0;
  int saveCalls = 0;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    saveCalls++;
    this.access = access;
    this.refresh = refresh;
  }

  

  @override
  Future<SessionProfile> readProfile() async => const SessionProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) async {}

@override
  Future<void> clear() async {
    clearCalls++;
    access = null;
    refresh = null;
  }
}

typedef Handler = Future<http.Response> Function(http.Request request);

class TrackingClient extends http.BaseClient {
  TrackingClient(this.handler);

  final Handler handler;
  int closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final req = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes;
    final res = await handler(req);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }

  @override
  void close() {
    closeCalls++;
  }
}

http.Response ok(Object data, {int status = 200}) => http.Response(
      jsonEncode({'success': true, 'data': data, 'error': null}),
      status,
    );

http.Response fail(int status, String code, [String message = 'msg']) =>
    http.Response(
      jsonEncode({
        'success': false,
        'data': null,
        'error': {'code': code, 'message': message},
      }),
      status,
    );

void main() {
  late List<TrackingClient> clients;
  late List<http.Request> requests;
  late FakeSessionStore session;
  late int expired;

  ApiClient build(
    Handler handler, {
    SessionStore? store,
    Duration? shortTimeout,
    Duration? moneyTimeout,
  }) {
    return ApiClient(
      baseUrl: 'http://x',
      clientFactory: () {
        final c = TrackingClient((req) {
          requests.add(req);
          return handler(req);
        });
        clients.add(c);
        return c;
      },
      session: store,
      onSessionExpired: () => expired++,
      shortTimeout: shortTimeout,
      moneyTimeout: moneyTimeout,
    );
  }

  setUp(() {
    clients = [];
    requests = [];
    expired = 0;
    session = FakeSessionStore(access: 'old', refresh: 'r1');
  });

  group('401 con refresh', () {
    test('refresca, guarda ambos tokens y reintenta una vez', () async {
      final api = build((req) async {
        if (req.url.path == '/v1/auth/refresh') {
          expect(jsonDecode(req.body), {'refresh_token': 'r1'});
          expect(req.headers.containsKey('Authorization'), isFalse);
          return ok({'access_token': 'new', 'refresh_token': 'r2'});
        }
        if (req.headers['Authorization'] == 'Bearer old') {
          return fail(401, 'Unauthorized');
        }
        expect(req.headers['Authorization'], 'Bearer new');
        return ok({'saldo': '10'});
      }, store: session);

      final data = await api.get('/v1/saldo');

      expect(data['data'], {'saldo': '10'});
      expect(session.access, 'new');
      expect(session.refresh, 'r2');
      expect(requests.where((r) => r.url.path == '/v1/saldo').length, 2);
      expect(expired, 0);
    });

    test('varias 401 concurrentes hacen un solo refresh', () async {
      var refreshes = 0;
      final api = build((req) async {
        if (req.url.path == '/v1/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return ok({'access_token': 'new', 'refresh_token': 'r2'});
        }
        if (req.headers['Authorization'] == 'Bearer old') {
          return fail(401, 'Unauthorized');
        }
        return ok({'ok': true});
      }, store: session);

      final results = await Future.wait([
        api.get('/v1/a'),
        api.get('/v1/b'),
        api.get('/v1/c'),
      ]);

      expect(refreshes, 1);
      expect(results.length, 3);
      expect(session.access, 'new');
    });

    test('refresh fallido limpia sesion, notifica y lanza el error original',
        () async {
      final api = build((req) async {
        if (req.url.path == '/v1/auth/refresh') {
          return fail(401, 'RefreshReused', 'reuso');
        }
        return fail(401, 'Unauthorized', 'original');
      }, store: session);

      await expectLater(
        api.get('/v1/saldo'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'Unauthorized')
              .having((e) => e.message, 'message', 'original')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(session.clearCalls, 1);
      expect(expired, 1);
    });

    test('sin refresh token limpia sesion y notifica', () async {
      session.refresh = null;
      final api = build((req) async => fail(401, 'Unauthorized'),
          store: session);

      await expectLater(api.get('/v1/saldo'), throwsA(isA<ApiException>()));
      expect(session.clearCalls, 1);
      expect(expired, 1);
      expect(requests.length, 1);
    });

    test('el reintento que vuelve a dar 401 no entra en bucle', () async {
      var refreshes = 0;
      final api = build((req) async {
        if (req.url.path == '/v1/auth/refresh') {
          refreshes++;
          return ok({'access_token': 'new', 'refresh_token': 'r2'});
        }
        return fail(401, 'Unauthorized');
      }, store: session);

      await expectLater(api.get('/v1/saldo'), throwsA(isA<ApiException>()));
      expect(refreshes, 1);
      expect(requests.where((r) => r.url.path == '/v1/saldo').length, 2);
    });

    test('401 de login no refresca ni cierra sesion', () async {
      final api = build(
        (req) async => fail(401, 'InvalidCredentials'),
        store: session,
      );

      await expectLater(
        api.post('/v1/auth/login', {'celular': '1'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'InvalidCredentials'),
        ),
      );
      expect(requests.length, 1);
      expect(session.clearCalls, 0);
      expect(expired, 0);
    });

    test('401 en rutas publicas nunca refresca', () async {
      final api = build((req) async => fail(401, 'X'), store: session);
      for (final path in [
        '/v1/auth/refresh',
        '/v1/auth/register',
        '/v1/auth/register/verify-phone',
        '/v1/auth/recovery/request',
        '/v1/auth/otp/resend',
      ]) {
        await expectLater(
            api.post(path, {}), throwsA(isA<ApiException>()));
      }
      expect(requests.length, 5);
      expect(expired, 0);
    });
  });

  group('respuestas', () {
    test('204 sin cuerpo es exito y post devuelve mapa vacio', () async {
      final api = build((req) async => http.Response('', 204));
      expect(await api.post('/v1/auth/otp/resend', {}), isEmpty);
    });

    test('parseo de errores conserva code, message, details y statusCode',
        () async {
      final api = build((req) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'ValidationError',
                'message': 'mal',
                'details': [
                  {'field': 'celular', 'message': 'requerido'},
                ],
              },
            }),
            422,
          ));

      await expectLater(
        api.post('/v1/auth/register', {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'ValidationError')
              .having((e) => e.details?.first['field'], 'field', 'celular')
              .having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });

    test('cuerpo invalido da InternalError', () async {
      final api = build((req) async => http.Response('<html>', 502));
      await expectLater(
        api.get('/v1/x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'InternalError')),
      );
    });
  });

  group('logout', () {
    test('POST con Bearer y refresh_token en el cuerpo, 204', () async {
      final api = build((req) async => http.Response('', 204), store: session);

      await api.logout();

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/v1/auth/logout');
      expect(req.headers['Authorization'], 'Bearer old');
      expect(jsonDecode(req.body), {'refresh_token': 'r1'});
    });
  });

  group('Bearer', () {
    test('se agrega solo en rutas autenticadas', () async {
      final api = build((req) async => ok({}), store: session);

      await api.get('/v1/saldo');
      await api.post('/v1/auth/login', {});
      await api.post('/v1/auth/register', {});

      expect(requests[0].headers['Authorization'], 'Bearer old');
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
      expect(requests[2].headers.containsKey('Authorization'), isFalse);
    });

    test('bearerToken explicito tiene prioridad', () async {
      final api = build((req) async => ok({}), store: session);
      await api.get('/v1/saldo', bearerToken: 'explicit');
      expect(requests.single.headers['Authorization'], 'Bearer explicit');
    });

    test('auth false suprime el Bearer y sin sesion no hay Bearer', () async {
      final api = build((req) async => ok({}), store: session);
      await api.get('/v1/saldo', auth: false);
      final bare = build((req) async => ok({}));
      await bare.get('/v1/saldo');
      expect(requests[0].headers.containsKey('Authorization'), isFalse);
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
    });
  });

  group('timeouts', () {
    test('al agotarse el timeout se cierra el cliente', () async {
      final hang = Completer<http.Response>();
      final api = build(
        (req) => hang.future,
        shortTimeout: const Duration(milliseconds: 30),
      );

      await expectLater(api.get('/v1/x'), throwsA(isA<TimeoutException>()));
      expect(clients.single.closeCalls, 1);
    });

    test('cierra el cliente tras una respuesta normal', () async {
      final api = build((req) async => ok({}));
      await api.get('/v1/x');
      expect(clients.single.closeCalls, 1);
    });

    test('dinero usa un timeout mayor que el corto', () async {
      final hang = Completer<http.Response>();
      const short = Duration(milliseconds: 30);
      const money = Duration(milliseconds: 400);
      final api = build((req) => hang.future,
          shortTimeout: short, moneyTimeout: money);

      var sw = Stopwatch()..start();
      await expectLater(api.post('/v1/otro', {}), throwsA(isA<TimeoutException>()));
      final shortElapsed = sw.elapsed;

      for (final path in [
        '/v1/transferencias',
        '/v1/transferencias/interbancarias',
        '/v1/depositos',
      ]) {
        sw = Stopwatch()..start();
        await expectLater(api.post(path, {}), throwsA(isA<TimeoutException>()));
        expect(sw.elapsed, greaterThanOrEqualTo(money));
        expect(sw.elapsed, greaterThan(shortElapsed));
      }
      expect(clients.every((c) => c.closeCalls == 1), isTrue);
    });

    test('los defaults son 20 s y 70 s', () {
      expect(ApiClient.defaultShortTimeout, const Duration(seconds: 20));
      expect(ApiClient.defaultMoneyTimeout, const Duration(seconds: 70));
      expect(ApiClient.isMoneyPath('POST', '/v1/depositos'), isTrue);
      expect(ApiClient.isMoneyPath('GET', '/v1/depositos'), isFalse);
      expect(ApiClient.isMoneyPath('GET', '/v1/depositos/1'), isFalse);
    });
  });

  group('SessionNotifier', () {
    test('load lee una vez y setAuthenticated notifica', () async {
      final notifier = SessionNotifier();
      var notified = 0;
      notifier.addListener(() => notified++);

      await notifier.load(FakeSessionStore(access: 'a', refresh: 'r'));
      expect(notifier.authenticated, isTrue);

      notifier.setAuthenticated(false);
      expect(notifier.authenticated, isFalse);
      expect(notified, 2);
    });
  });
}
