import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

class _FakeSession implements SessionStore {
  _FakeSession({this.access, this.refresh});

  String? access;
  String? refresh;
  int clearCalls = 0;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    access = null;
    refresh = null;
  }
}

void main() {
  late _FakeSession session;
  late SessionNotifier notifier;
  late List<http.Request> requests;

  AuthRepository build(Future<http.Response> Function(http.Request) handler) {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      session: session,
      clientFactory: () => MockClient((req) {
        requests.add(req);
        return handler(req);
      }),
    );
    return AuthRepository(
      client: client,
      session: session,
      sessionNotifier: notifier,
    );
  }

  setUp(() {
    session = _FakeSession(access: 'acc-1', refresh: 'ref-1');
    notifier = SessionNotifier()..setAuthenticated(true);
    requests = [];
  });

  test('logout envia Bearer y refresh_token, acepta 204 y borra la sesion',
      () async {
    final repo = build((req) async => http.Response('', 204));

    await repo.logout();

    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.toString(), 'https://api.test/v1/auth/logout');
    expect(req.headers['Authorization'], 'Bearer acc-1');
    expect(jsonDecode(req.body), {'refresh_token': 'ref-1'});
    expect(session.access, isNull);
    expect(session.refresh, isNull);
    expect(session.clearCalls, 1);
    expect(notifier.authenticated, isFalse);
  });

  test('con error 500 borra la sesion local y propaga el error', () async {
    final repo = build((req) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'InternalError', 'message': 'boom'},
          }),
          500,
        ));

    await expectLater(
      repo.logout(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
    );

    expect(session.access, isNull);
    expect(session.refresh, isNull);
    expect(notifier.authenticated, isFalse);
  });

  test('con error de red borra la sesion local y no propaga', () async {
    final repo = build((req) async => throw http.ClientException('sin red'));

    await repo.logout();

    expect(session.access, isNull);
    expect(session.refresh, isNull);
    expect(notifier.authenticated, isFalse);
  });

  test('con timeout borra la sesion local y no propaga', () async {
    final client = ApiClient(
      baseUrl: 'https://api.test',
      session: session,
      shortTimeout: const Duration(milliseconds: 10),
      clientFactory: () => MockClient(
        (req) => Completer<http.Response>().future,
      ),
    );
    final repo = AuthRepository(
      client: client,
      session: session,
      sessionNotifier: notifier,
    );

    await repo.logout();

    expect(session.access, isNull);
    expect(notifier.authenticated, isFalse);
  });

  test('sin refresh_token no llama al servidor pero limpia la sesion',
      () async {
    session.refresh = null;
    final repo = build((req) async => http.Response('', 204));

    await repo.logout();

    expect(requests, isEmpty);
    expect(session.access, isNull);
    expect(notifier.authenticated, isFalse);
  });

  test('los getters delegan en el SessionStore', () async {
    final repo = build((req) async => http.Response('', 204));

    expect(await repo.getAccessToken(), 'acc-1');
    expect(await repo.getRefreshToken(), 'ref-1');
    await repo.saveTokens(access: 'a2', refresh: 'r2');
    expect(session.access, 'a2');
    await repo.clearTokens();
    expect(session.access, isNull);
  });
}
