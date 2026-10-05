import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

class _FakeSession implements SessionStore {
  _FakeSession(this.eventos);

  final List<String> eventos;
  String? access;
  String? refresh;
  SessionProfile? perfil;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    eventos.add('tokens');
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<SessionProfile> readProfile() async =>
      perfil ?? const SessionProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) async {
    eventos.add('perfil');
    perfil = profile;
  }

  @override
  Future<String?> readDepositoPendiente() async => null;

  @override
  Future<void> saveDepositoPendiente(String id) async {}

  @override
  Future<void> clearDepositoPendiente() async {}

  @override
  Future<void> clear() async {
    eventos.add('clear');
    access = null;
    refresh = null;
    perfil = null;
  }
}

Map<String, dynamic> _loginJson({
  String tipo = 'persona',
  String? nombre,
  String? razon,
}) => {
  'success': true,
  'data': {
    'access_token': 'acc',
    'refresh_token': 'ref',
    'usuario': {
      'id': 'u1',
      'tipo_cuenta': tipo,
      'nombre_completo': ?nombre,
      'razon_social': ?razon,
    },
  },
  'error': null,
  'meta': {},
};

void main() {
  late List<String> eventos;
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

  http.Response ok(Map<String, dynamic> data) => http.Response(
    jsonEncode({'success': true, 'data': data, 'error': null, 'meta': {}}),
    200,
  );

  setUp(() {
    eventos = [];
    session = _FakeSession(eventos);
    notifier = SessionNotifier()
      ..addListener(() => eventos.add('autenticado:${notifier.authenticated}'));
    requests = [];
  });

  group('login', () {
    test('guarda tokens, luego el perfil y solo después autentica', () async {
      final repo = build(
        (_) async =>
            http.Response(jsonEncode(_loginJson(nombre: 'Ana Pérez')), 200),
      );

      await repo.login(celular: '3001234567', contrasena: 'ClaveSegura1');

      expect(eventos, ['tokens', 'perfil', 'autenticado:true']);
      expect(requests.single.url.toString(), 'https://api.test/v1/auth/login');
    });

    test('persiste nombre_completo y tipo_cuenta de una persona', () async {
      final repo = build(
        (_) async =>
            http.Response(jsonEncode(_loginJson(nombre: 'Ana Pérez')), 200),
      );

      await repo.login(celular: '3001234567', contrasena: 'ClaveSegura1');

      expect(session.perfil?.nombreCompleto, 'Ana Pérez');
      expect(session.perfil?.razonSocial, isNull);
      expect(session.perfil?.tipoCuenta, 'persona');
      expect(await repo.getNombreAMostrar(), 'Ana Pérez');
      expect(await repo.getTipoCuenta(), 'persona');
    });

    test(
      'persiste razon_social de una empresa y la muestra como nombre',
      () async {
        final repo = build(
          (_) async => http.Response(
            jsonEncode(_loginJson(tipo: 'empresa', razon: 'Acme S.A.S.')),
            200,
          ),
        );

        await repo.login(celular: '3001234567', contrasena: 'ClaveSegura1');

        expect(session.perfil?.razonSocial, 'Acme S.A.S.');
        expect(session.perfil?.nombreCompleto, isNull);
        expect(session.perfil?.tipoCuenta, 'empresa');
        expect(await repo.getNombreAMostrar(), 'Acme S.A.S.');
      },
    );

    test('no autentica si falla el login', () async {
      final repo = build(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {'code': 'InvalidCredentials', 'message': 'x'},
            'meta': {},
          }),
          401,
        ),
      );

      await expectLater(
        repo.login(celular: '3001234567', contrasena: 'ClaveSegura1'),
        throwsA(isA<ApiException>()),
      );

      expect(eventos, isEmpty);
      expect(notifier.authenticated, isFalse);
    });
  });

  group('registro', () {
    final consentimientos = [
      {'tipo': 'tratamiento_datos', 'version_texto': 'v1', 'aceptado': true},
      {'tipo': 'whatsapp_optin', 'version_texto': 'v1', 'aceptado': true},
    ];

    Map<String, dynamic> respuestaRegistro() => {
      'id': 'u1',
      'celular': '+573001234567',
      'desafio': {'challenge_id': 'c1'},
    };

    test(
      'persona envía ambos consentimientos aceptados con versión v1',
      () async {
        final repo = build((_) async => ok(respuestaRegistro()));

        await repo.registerPersona(
          correo: 'a@b.co',
          contrasena: 'ClaveSegura1',
          celular: '3001234567',
          nombreCompleto: 'Ana Pérez',
          tipoDocumento: 'CC',
          numeroDocumento: '123456',
          aceptaTratamientoDatos: true,
          aceptaWhatsappOptin: true,
        );

        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(requests.single.url.path, '/v1/auth/register');
        expect(body['tipo_cuenta'], 'persona');
        expect(body['consentimientos'], consentimientos);
      },
    );

    test(
      'empresa envía ambos consentimientos aceptados con versión v1',
      () async {
        final repo = build((_) async => ok(respuestaRegistro()));

        await repo.registerEmpresa(
          razonSocial: 'Acme S.A.S.',
          nit: '900123456',
          correo: 'a@b.co',
          contrasena: 'ClaveSegura1',
          celular: '3001234567',
          repNombre: 'Ana Pérez',
          repTipoDoc: 'CC',
          repNumDoc: '123456',
          aceptaTratamientoDatos: true,
          aceptaWhatsappOptin: true,
        );

        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['tipo_cuenta'], 'empresa');
        expect(body['consentimientos'], consentimientos);
      },
    );

    test('no se construye un registro sin ambos consentimientos', () async {
      final repo = build((_) async => ok(respuestaRegistro()));

      Future<void> persona({required bool datos, required bool whatsapp}) =>
          repo.registerPersona(
            correo: 'a@b.co',
            contrasena: 'ClaveSegura1',
            celular: '3001234567',
            nombreCompleto: 'Ana Pérez',
            tipoDocumento: 'CC',
            numeroDocumento: '123456',
            aceptaTratamientoDatos: datos,
            aceptaWhatsappOptin: whatsapp,
          );

      await expectLater(
        persona(datos: false, whatsapp: true),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        persona(datos: true, whatsapp: false),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repo.registerEmpresa(
          razonSocial: 'Acme',
          nit: '9001',
          correo: 'a@b.co',
          contrasena: 'ClaveSegura1',
          celular: '3001234567',
          repNombre: 'Ana',
          repTipoDoc: 'CC',
          repNumDoc: '1',
          aceptaTratamientoDatos: true,
          aceptaWhatsappOptin: false,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('resendOtp', () {
    test('hace POST a /v1/auth/otp/resend solo con challenge_id', () async {
      final repo = build(
        (_) async => ok({
          'challenge_id': 'c1',
          'expira_en_segundos': 300,
          'proposito': 'registro',
        }),
      );

      await repo.resendOtp(challengeId: 'c1', proposito: 'registro');

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'https://api.test/v1/auth/otp/resend');
      expect(jsonDecode(req.body), {'challenge_id': 'c1'});
    });

    test('propaga el código de error del servidor', () async {
      final repo = build(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {'code': 'OtpResendCooldown', 'message': 'x'},
            'meta': {},
          }),
          429,
        ),
      );

      await expectLater(
        repo.resendOtp(challengeId: 'c1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'OtpResendCooldown',
          ),
        ),
      );
    });
  });

  group('limpieza de perfil', () {
    setUp(() {
      session
        ..access = 'a'
        ..refresh = 'r'
        ..perfil = const SessionProfile(
          nombreCompleto: 'Ana',
          tipoCuenta: 'persona',
        );
    });

    test('clearTokens borra tokens y perfil', () async {
      final repo = build((_) async => http.Response('', 204));

      await repo.clearTokens();

      expect(session.perfil, isNull);
      expect(await repo.getNombreAMostrar(), isNull);
    });

    test('logout borra el perfil', () async {
      final repo = build((_) async => http.Response('', 204));

      await repo.logout();

      expect(session.perfil, isNull);
      expect(await repo.getTipoCuenta(), isNull);
    });
  });

  group('FlutterSecureStorageSessionStore', () {
    test('conserva las claves de almacenamiento y clear borra todo', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = FlutterSecureStorageSessionStore();

      await store.saveProfile(
        const SessionProfile(razonSocial: 'Acme', tipoCuenta: 'empresa'),
      );
      const raw = FlutterSecureStorage();
      expect(await raw.read(key: 'razon_social'), 'Acme');
      expect(await raw.read(key: 'tipo_cuenta'), 'empresa');
      expect(await raw.read(key: 'nombre_completo'), isNull);

      await store.saveProfile(
        const SessionProfile(nombreCompleto: 'Ana', tipoCuenta: 'persona'),
      );
      expect(await raw.read(key: 'nombre_completo'), 'Ana');
      expect(await raw.read(key: 'razon_social'), isNull);

      await store.saveTokens(access: 'a', refresh: 'r');
      await store.clear();
      expect(await raw.readAll(), isEmpty);
      expect((await store.readProfile()).nombreAMostrar, isNull);
    });
  });
}
