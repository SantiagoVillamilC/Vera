import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/auth/presentation/register_screen.dart';

class _SesionNula implements SessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repositorio real sobre un cliente HTTP simulado: las pruebas del registro
/// miran el cuerpo que de verdad sale hacia el backend.
class _Servidor {
  final peticiones = <http.Request>[];
  http.Response Function(http.Request)? respuesta;

  AuthRepository get repo => AuthRepository(
    client: ApiClient(
      baseUrl: 'https://api.test',
      session: _SesionNula(),
      clientFactory: () => MockClient((req) async {
        peticiones.add(req);
        return (respuesta ?? _registroExitoso)(req);
      }),
    ),
    session: _SesionNula(),
  );

  Map<String, dynamic> get cuerpoDelRegistro =>
      jsonDecode(peticiones.single.body) as Map<String, dynamic>;
}

http.Response _registroExitoso(http.Request _) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'id': 'u1',
      'celular': '+573001234567',
      'desafio': {'challenge_id': 'c1'},
    },
  }),
  201,
  headers: {'content-type': 'application/json'},
);

http.Response _error(
  int status,
  String code, {
  List<Map<String, String>>? details,
}) => http.Response(
  jsonEncode({
    'success': false,
    'error': {'code': code, 'message': 'x', 'details': ?details},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

class _FakeOtpRepository implements AuthRepository {
  final reenvios = <String>[];
  final verificaciones = <String>[];
  Object? errorAlReenviar;
  Object? errorAlVerificar;

  @override
  Future<void> resendOtp({
    required String challengeId,
    String? proposito,
  }) async {
    reenvios.add(challengeId);
    if (errorAlReenviar != null) throw errorAlReenviar!;
  }

  @override
  Future<VerifyPhoneResult> verifyPhone({
    required String celular,
    required String codigo,
  }) async {
    verificaciones.add(codigo);
    if (errorAlVerificar != null) throw errorAlVerificar!;
    return const VerifyPhoneResult(
      id: 'u1',
      celular: '+573001234567',
      estado: 'activa',
      codigosRespaldo: ['AAAA-1111'],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Registro que no responde hasta que la prueba lo decida.
class _RegistroPendiente implements AuthRepository {
  final respuesta = Completer<RegisterResult>();
  var llamadas = 0;

  @override
  Future<RegisterResult> registerPersona({
    required String correo,
    required String contrasena,
    required String celular,
    required String nombreCompleto,
    required String tipoDocumento,
    required String numeroDocumento,
    required bool aceptaTratamientoDatos,
    required bool aceptaWhatsappOptin,
  }) {
    llamadas++;
    return respuesta.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(path: '/inicio', builder: (_, _) => pantalla),
      GoRoute(path: '/login', builder: (_, _) => const Text('PANTALLA_LOGIN')),
      GoRoute(
        path: '/login/recovery',
        builder: (_, _) => const Text('PANTALLA_RECUPERAR'),
      ),
      GoRoute(
        path: '/register/backup-codes',
        builder: (_, _) => const Text('PANTALLA_CODIGOS'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

/// Desmonta la pantalla y deja correr el último segundo del contador.
Future<void> _cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _escribir(WidgetTester tester, int indice, String texto) async {
  await tester.enterText(find.byType(TextFormField).at(indice), texto);
  await tester.pump();
}

Future<void> _continuar(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

const _nitValido = '900123456-8';

Future<void> _empresaPaso1(
  WidgetTester tester, {
  String nit = _nitValido,
}) async {
  await tester.tap(find.text('Empresa'));
  await tester.pump();
  await _continuar(tester);
  await _escribir(tester, 0, 'Centinela SAS');
  await _escribir(tester, 1, nit);
  await _escribir(tester, 2, 'empresa@correo.com');
  await _escribir(tester, 3, '3001234567');
}

Future<void> _empresaHastaContrasena(WidgetTester tester) async {
  await _empresaPaso1(tester);
  await _continuar(tester);
  await _escribir(tester, 0, 'Ana Gómez');
  await _escribir(tester, 1, '12345678');
  await _continuar(tester);
  await _escribir(tester, 0, 'contrasena-larga');
  await _escribir(tester, 1, 'contrasena-larga');
}

Future<void> _personaHastaContrasena(WidgetTester tester) async {
  await _continuar(tester);
  await _escribir(tester, 0, 'María García');
  await _escribir(tester, 1, 'maria@correo.com');
  await _escribir(tester, 2, '3001234567');
  await _continuar(tester);
  await _escribir(tester, 0, '12345678');
  await _escribir(tester, 1, '1990-01-31');
  await _continuar(tester);
  await _escribir(tester, 0, 'contrasena-larga');
  await _escribir(tester, 1, 'contrasena-larga');
}

final _casillaDatos = find.byKey(const Key('consentimiento_tratamiento_datos'));
final _casillaWhatsapp = find.byKey(const Key('consentimiento_whatsapp_optin'));
const _motivo = 'Marca las dos casillas para crear la cuenta.';

bool _marcada(WidgetTester tester, Finder casilla) =>
    tester
        .widget<CheckboxListTile>(
          find.descendant(of: casilla, matching: find.byType(CheckboxListTile)),
        )
        .value ??
    false;

GradientButton _botonCrear(WidgetTester tester) =>
    tester.widget<GradientButton>(
      find.widgetWithText(GradientButton, 'Crear cuenta'),
    );

Future<void> _marcarAmbas(WidgetTester tester) async {
  await tester.ensureVisible(_casillaDatos);
  await tester.tap(_casillaDatos);
  await tester.pump();
  await tester.ensureVisible(_casillaWhatsapp);
  await tester.tap(_casillaWhatsapp);
  await tester.pump();
}

void main() {
  group('consentimientos', () {
    testWidgets(
      'las casillas empiezan sin marcar y el botón queda deshabilitado con el motivo',
      (tester) async {
        await _pump(tester, RegisterScreen(repository: _Servidor().repo));
        await _empresaHastaContrasena(tester);

        expect(_casillaDatos, findsOneWidget);
        expect(_casillaWhatsapp, findsOneWidget);
        expect(_marcada(tester, _casillaDatos), isFalse);
        expect(_marcada(tester, _casillaWhatsapp), isFalse);
        expect(_botonCrear(tester).onPressed, isNull);
        expect(find.text(_motivo), findsOneWidget);
      },
    );

    testWidgets(
      'con una sola casilla sigue deshabilitado y con ambas se habilita',
      (tester) async {
        await _pump(tester, RegisterScreen(repository: _Servidor().repo));
        await _empresaHastaContrasena(tester);

        await tester.ensureVisible(_casillaDatos);
        await tester.tap(_casillaDatos);
        await tester.pump();
        expect(_marcada(tester, _casillaDatos), isTrue);
        expect(_botonCrear(tester).onPressed, isNull);
        expect(find.text(_motivo), findsOneWidget);

        await tester.ensureVisible(_casillaWhatsapp);
        await tester.tap(_casillaWhatsapp);
        await tester.pump();
        expect(_botonCrear(tester).onPressed, isNotNull);
        expect(find.text(_motivo), findsNothing);
      },
    );

    testWidgets(
      'empresa envía ambos consentimientos aceptados con versión v1',
      (tester) async {
        final servidor = _Servidor();
        await _pump(tester, RegisterScreen(repository: servidor.repo));
        await _empresaHastaContrasena(tester);
        await _marcarAmbas(tester);

        await tester.tap(find.text('Crear cuenta'));
        await tester.pumpAndSettle();

        final cuerpo = servidor.cuerpoDelRegistro;
        expect(cuerpo['tipo_cuenta'], 'empresa');
        expect(cuerpo['consentimientos'], [
          {
            'tipo': 'tratamiento_datos',
            'version_texto': 'v1',
            'aceptado': true,
          },
          {'tipo': 'whatsapp_optin', 'version_texto': 'v1', 'aceptado': true},
        ]);
        expect(find.text('Verifica tu número'), findsOneWidget);
        await _cerrar(tester);
      },
    );

    testWidgets(
      'persona envía ambos consentimientos aceptados con versión v1',
      (tester) async {
        final servidor = _Servidor();
        await _pump(tester, RegisterScreen(repository: servidor.repo));
        await _personaHastaContrasena(tester);
        await _marcarAmbas(tester);

        await tester.tap(find.text('Crear cuenta'));
        await tester.pumpAndSettle();

        final cuerpo = servidor.cuerpoDelRegistro;
        expect(cuerpo['tipo_cuenta'], 'persona');
        expect(cuerpo['consentimientos'], [
          {
            'tipo': 'tratamiento_datos',
            'version_texto': 'v1',
            'aceptado': true,
          },
          {'tipo': 'whatsapp_optin', 'version_texto': 'v1', 'aceptado': true},
        ]);
        await _cerrar(tester);
      },
    );
  });

  group('celular', () {
    Future<void> hastaContrasenaConCelular(
      WidgetTester tester,
      String celular,
    ) async {
      await _continuar(tester);
      await _escribir(tester, 0, 'María García');
      await _escribir(tester, 1, 'maria@correo.com');
      await _escribir(tester, 2, celular);
      await _continuar(tester);
      await _escribir(tester, 0, '12345678');
      await _escribir(tester, 1, '1990-01-31');
      await _continuar(tester);
      await _escribir(tester, 0, 'contrasena-larga');
      await _escribir(tester, 1, 'contrasena-larga');
    }

    testWidgets('el campo no admite más de 10 dígitos', (tester) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _continuar(tester);
      await _escribir(tester, 2, '63105550404');

      final campo = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(campo.controller!.text, '6310555040');
    });

    testWidgets('con 11 dígitos pegados el cuerpo lleva +57 y 10 dígitos', (
      tester,
    ) async {
      final servidor = _Servidor();
      await _pump(tester, RegisterScreen(repository: servidor.repo));
      await hastaContrasenaConCelular(tester, '63105550404');
      await _marcarAmbas(tester);

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      final celular = servidor.cuerpoDelRegistro['celular'] as String;
      expect(celular, matches(RegExp(r'^\+57\d{10}$')));
      await _cerrar(tester);
    });

    testWidgets('un celular pegado con el indicativo llega como +57 y 10', (
      tester,
    ) async {
      final servidor = _Servidor();
      await _pump(tester, RegisterScreen(repository: servidor.repo));
      await hastaContrasenaConCelular(tester, '+57 310 555 0404');
      await _marcarAmbas(tester);

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(servidor.cuerpoDelRegistro['celular'], '+573105550404');
      await _cerrar(tester);
    });
  });

  group('botón Atrás del sistema', () {
    Future<bool> atras(WidgetTester tester, {bool animando = false}) async {
      final manejado = await tester.binding.handlePopRoute();
      // El indicador de carga nunca se asienta, por eso un solo cuadro.
      animando ? await tester.pump() : await tester.pumpAndSettle();
      return manejado;
    }

    testWidgets('retrocede un paso y no sale del registro', (tester) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _continuar(tester);
      expect(find.text('Tus datos'), findsOneWidget);

      expect(await atras(tester), isTrue);

      expect(find.text('Tus datos'), findsNothing);
      expect(find.text('Persona natural'), findsOneWidget);
      expect(find.text('PANTALLA_LOGIN'), findsNothing);
    });

    testWidgets('desde la contraseña vuelve a la identidad', (tester) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _personaHastaContrasena(tester);
      expect(find.text('Crea tu contraseña'), findsOneWidget);

      expect(await atras(tester), isTrue);

      expect(find.text('Tu identidad'), findsOneWidget);
      expect(find.text('Crea tu contraseña'), findsNothing);
    });

    testWidgets('solo desde el primer paso sale, hacia el inicio de sesión', (
      tester,
    ) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));

      expect(await atras(tester), isTrue);

      expect(find.text('PANTALLA_LOGIN'), findsOneWidget);
    });

    testWidgets('mientras se crea la cuenta no retrocede ni sale', (
      tester,
    ) async {
      final repo = _RegistroPendiente();
      await _pump(tester, RegisterScreen(repository: repo));
      await _personaHastaContrasena(tester);
      await _marcarAmbas(tester);
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      expect(repo.llamadas, 1);

      expect(await atras(tester, animando: true), isTrue);

      expect(find.text('Crea tu contraseña'), findsOneWidget);
      expect(find.text('PANTALLA_LOGIN'), findsNothing);
      repo.respuesta.complete(
        const RegisterResult(id: 'u1', challengeId: 'c1', celular: '+57300'),
      );
      await tester.pump();
      await _cerrar(tester);
    });
  });

  group('límites de longitud', () {
    testWidgets('la contraseña admite como máximo 64 caracteres', (
      tester,
    ) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _empresaHastaContrasena(tester);

      await _escribir(tester, 0, 'a' * 70);
      final campo = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(campo.maxLength, 64);
      expect(campo.controller!.text.length, 64);
    });

    testWidgets('el nombre completo admite como máximo 200 caracteres', (
      tester,
    ) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _continuar(tester);

      await _escribir(tester, 0, 'a' * 250);
      final campo = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(campo.maxLength, 200);
      expect(campo.controller!.text.length, 200);
    });

    testWidgets('la razón social admite como máximo 200 caracteres', (
      tester,
    ) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await tester.tap(find.text('Empresa'));
      await tester.pump();
      await _continuar(tester);

      await _escribir(tester, 0, 'b' * 250);
      final campo = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(campo.maxLength, 200);
      expect(campo.controller!.text.length, 200);
    });
  });

  group('NIT', () {
    testWidgets(
      'un NIT con dígito de verificación incorrecto bloquea el paso',
      (tester) async {
        await _pump(tester, RegisterScreen(repository: _Servidor().repo));
        await _empresaPaso1(tester, nit: '9001234569');
        await _continuar(tester);
        expect(
          find.text('El NIT no es válido. Revisa el dígito de verificación.'),
          findsOneWidget,
        );
        expect(find.text('Tu identidad'), findsNothing);
      },
    );

    testWidgets('un NIT válido del backend deja avanzar', (tester) async {
      await _pump(tester, RegisterScreen(repository: _Servidor().repo));
      await _empresaPaso1(tester);
      await _continuar(tester);
      expect(find.text('Tu identidad'), findsOneWidget);
      expect(find.textContaining('El NIT no es válido'), findsNothing);
    });
  });

  group('errores por campo del servidor', () {
    Future<void> enviarYMirar(
      WidgetTester tester,
      List<Map<String, String>> details,
    ) async {
      final servidor = _Servidor()
        ..respuesta = (_) => _error(422, 'ValidationError', details: details);
      await _pump(tester, RegisterScreen(repository: servidor.repo));
      await _empresaHastaContrasena(tester);
      await _marcarAmbas(tester);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'celular e164 (prefijos 306 a 308) muestra el texto en español',
      (tester) async {
        await enviarYMirar(tester, [
          {'field': 'celular', 'rule': 'e164'},
        ]);
        expect(find.text('El número de celular no es válido'), findsOneWidget);
        expect(find.text(mensajeValidacionGeneral), findsNothing);
      },
    );

    testWidgets('nombre con dígitos muestra el campo y la regla', (
      tester,
    ) async {
      await enviarYMirar(tester, [
        {'field': 'nombre_completo', 'rule': 'nombre'},
      ]);
      expect(
        find.text(
          'El nombre completo no es válido, usa solo letras sin números ni símbolos',
        ),
        findsOneWidget,
      );
    });
  });

  group('OtpRegisterScreen', () {
    late _FakeOtpRepository repo;
    setUp(() => repo = _FakeOtpRepository());

    Future<void> abrir(WidgetTester tester) => _pump(
      tester,
      OtpRegisterScreen(
        correo: 'a@b.co',
        celular: '3001234567',
        challengeId: 'c1',
        repository: repo,
      ),
    );

    Future<void> esperarEnfriamiento(WidgetTester tester) async {
      expect(find.text('Reenviar en 60s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Reenviar código'), findsOneWidget);
    }

    testWidgets(
      'un reenvío exitoso usa el challenge vigente y reinicia el contador',
      (tester) async {
        await abrir(tester);
        await esperarEnfriamiento(tester);

        await tester.tap(find.text('Reenviar código'));
        await tester.pump();

        expect(repo.reenvios, ['c1']);
        expect(find.text('Reenviar en 60s'), findsOneWidget);
        expect(find.text('Reenviar código'), findsNothing);
        await _cerrar(tester);
        await tester.pump(const Duration(seconds: 61));
      },
    );

    for (final caso in <(String, Object, String)>[
      (
        'OtpResendCooldown',
        const ApiException(code: 'OtpResendCooldown', message: 'x'),
        mensajeDeError(
          const ApiException(code: 'OtpResendCooldown', message: 'x'),
        ),
      ),
      (
        'TooManyRequests',
        const ApiException(
          code: 'TooManyRequests',
          message: 'x',
          statusCode: 429,
        ),
        mensajeDeError(
          const ApiException(code: 'TooManyRequests', message: 'x'),
        ),
      ),
      ('un fallo de red', http.ClientException('sin red'), mensajeSinRed),
    ]) {
      testWidgets('${caso.$1} se muestra y no reinicia el contador', (
        tester,
      ) async {
        repo.errorAlReenviar = caso.$2;
        await abrir(tester);
        await esperarEnfriamiento(tester);

        await tester.tap(find.text('Reenviar código'));
        await tester.pump();
        await tester.pump();

        expect(repo.reenvios, ['c1']);
        expect(find.text(caso.$3), findsOneWidget);
        expect(find.text('Reenviar en 60s'), findsNothing);
        expect(find.text('Reenviar código'), findsOneWidget);
        await _cerrar(tester);
      });
    }

    testWidgets(
      'los textos de enfriamiento y límite no prometen un minuto exacto',
      (tester) async {
        const cooldown = ApiException(code: 'OtpResendCooldown', message: 'x');
        const limite = ApiException(code: 'TooManyRequests', message: 'x');
        expect(mensajeDeError(cooldown), contains('cerca de un minuto'));
        expect(mensajeDeError(limite), contains('más tarde'));
        expect(mensajeDeError(limite), isNot(contains('minuto')));
      },
    );

    testWidgets(
      'OtpTooManyResends deshabilita reenviar y verificar y ofrece dos salidas',
      (tester) async {
        repo.errorAlReenviar = const ApiException(
          code: 'OtpTooManyResends',
          message: 'x',
        );
        await abrir(tester);
        await esperarEnfriamiento(tester);
        await tester.tap(find.text('Reenviar código'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Reenviar código'), findsNothing);
        expect(find.text('1'), findsNothing);
        expect(
          find.textContaining('Esta verificación ya no puede continuar'),
          findsOneWidget,
        );
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.text('Recuperar mi cuenta'), findsOneWidget);

        await tester.tap(find.text('Recuperar mi cuenta'));
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA_RECUPERAR'), findsOneWidget);
        await _cerrar(tester);
      },
    );

    testWidgets(
      'ChallengeInvalid al verificar lleva al mismo callejón con salida a /login',
      (tester) async {
        repo.errorAlVerificar = const ApiException(
          code: 'ChallengeInvalid',
          message: 'x',
        );
        await abrir(tester);
        for (var i = 0; i < 6; i++) {
          await tester.tap(find.text('1'));
          await tester.pump();
        }
        await tester.pump();

        expect(repo.verificaciones, ['111111']);
        expect(find.text('Reenviar en 60s'), findsNothing);
        expect(find.text('Recuperar mi cuenta'), findsOneWidget);

        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA_LOGIN'), findsOneWidget);
        await _cerrar(tester);
      },
    );
  });
}
