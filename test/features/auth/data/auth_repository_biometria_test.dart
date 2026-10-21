import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/biometric_session_store.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

import '../../../support/biometria_fakes.dart';

void main() {
  late MemorySessionStore disco;
  late FakeKeyVault boveda;
  late BiometricSessionStore store;
  late SessionNotifier notifier;
  late List<http.Request> requests;

  AuthRepository build(Future<http.Response> Function(http.Request) handler) =>
      AuthRepository(
        client: ApiClient(
          baseUrl: 'https://api.test',
          session: store,
          clientFactory: () => MockClient((req) {
            requests.add(req);
            return handler(req);
          }),
        ),
        session: store,
        sessionNotifier: notifier,
      );

  http.Response par() => http.Response(
        jsonEncode({
          'success': true,
          'data': {'access_token': 'acc-2', 'refresh_token': 'ref-2'},
        }),
        200,
      );

  http.Response error(int status, String code) => http.Response(
        jsonEncode({
          'success': false,
          'error': {'code': code, 'message': 'x'},
        }),
        status,
      );

  setUp(() async {
    disco = MemorySessionStore()
      ..access = 'acc-1'
      ..refresh = 'ref-1';
    boveda = FakeKeyVault();
    await BiometricSessionStore(base: disco, vault: boveda).enable();
    // Reinicio de la app: la sesión queda bloqueada.
    store = BiometricSessionStore(base: disco, vault: boveda);
    notifier = SessionNotifier()..setLocked(true);
    requests = [];
  });

  test('biometría válida renueva en silencio y desbloquea', () async {
    final repo = build((req) async => par());

    expect(
      await repo.desbloquearConBiometria(),
      DesbloqueoBiometrico.desbloqueado,
    );

    expect(requests.single.url.path, '/v1/auth/refresh');
    expect(jsonDecode(requests.single.body), {'refresh_token': 'ref-1'});
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(await store.readRefresh(), 'ref-2');
    expect(notifier.locked, isFalse);
    expect(notifier.authenticated, isTrue);
  });

  test('biometría cancelada no toca el servidor ni libera el refresh', () async {
    boveda.aprobar = false;
    final repo = build((req) async => par());

    expect(
      await repo.desbloquearConBiometria(),
      DesbloqueoBiometrico.cancelado,
    );

    expect(requests, isEmpty);
    expect(await store.readRefresh(), isNull);
    expect(notifier.locked, isTrue);
  });

  test('refresh vencido exige el login completo y borra el enrolamiento', () async {
    final repo = build((req) async => error(401, 'RefreshInvalid'));

    expect(
      await repo.desbloquearConBiometria(),
      DesbloqueoBiometrico.sesionVencida,
    );

    expect(disco.refresh, isNull);
    expect(boveda.tieneClave, isFalse);
    expect(notifier.locked, isFalse);
    expect(notifier.authenticated, isFalse);
  });

  test('sin red conserva el enrolamiento y vuelve a exigir biometría', () async {
    final repo = build((req) async => throw const SocketException('sin red'));

    expect(await repo.desbloquearConBiometria(), DesbloqueoBiometrico.sinRed);

    expect(notifier.locked, isTrue);
    expect(await store.readRefresh(), isNull);
    expect(await store.isEnrolled(), isTrue);
  });

  test('abandonar la sesión bloqueada limpia todo', () async {
    final repo = build((req) async => par());

    await repo.abandonarSesionBloqueada();

    expect(await store.isEnrolled(), isFalse);
    expect(boveda.tieneClave, isFalse);
    expect(notifier.locked, isFalse);
  });
}
