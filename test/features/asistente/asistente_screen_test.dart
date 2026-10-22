import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/asistente_screen.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<List<http.Request>> _montar(
  WidgetTester t, {
  required bool autorizado,
  required List<http.Response Function(http.Request)> sobre,
}) async {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
    vistos.add(r);
    if (r.method == 'GET' && r.url.path == '/v1/auth/consents') {
      return _json({
        'success': true,
        'data': {
          'tipo': 'asistente_ia',
          'version_texto': 'v1',
          'texto': 'Vera usa IA para ayudarte.',
          'autorizado': autorizado,
        },
        'error': null,
        'meta': null,
      }, 200);
    }
    if (r.url.path == '/v1/auth/consents') {
      return _json({
        'success': true,
        'data': {},
        'error': null,
        'meta': null,
      }, 201);
    }
    return sobre.removeAt(0)(r);
  });
  final repo = AsistenteRepository(
    client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
  );
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: AsistenteScreen(repository: repo),
    ),
  );
  await t.pump();
  await t.pump();
  return vistos;
}

Map<String, Object?> _ok(String texto) => {
  'success': true,
  'data': {
    'conversacion_id': 'c1',
    'mensaje_id': 'm1',
    'texto': texto,
    'creado_en': '2026-10-15T14:17:00-05:00',
  },
  'error': null,
  'meta': null,
};

/// Por defecto se habla: para escribir hay que abrir el teclado.
Future<void> abrirTeclado(WidgetTester t) async {
  if (find.byType(TextField).evaluate().isNotEmpty) return;
  await t.tap(find.byKey(const Key('abrir_teclado')));
  await t.pump();
}

Future<void> enviarTexto(WidgetTester t, String m) async {
  await abrirTeclado(t);
  await t.enterText(find.byType(TextField), m);
  await t.pump();
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets(
    'sin consentimiento muestra la activación y no el chat ni el campo de texto',
    (t) async {
      final vistos = await _montar(t, autorizado: false, sobre: []);

      expect(find.text('Activa a Vera'), findsOneWidget);
      expect(find.text('Qué hace Vera'), findsOneWidget);
      expect(
        find.text('Tu dinero solo se mueve con tu confirmación'),
        findsOneWidget,
      );
      expect(find.text('Usa un proveedor externo de IA'), findsOneWidget);
      expect(find.text('Datos y conservación'), findsOneWidget);
      expect(find.text('Texto completo (versión v1)'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(vistos.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  testWidgets('el texto completo del servidor se muestra al pedirlo', (
    t,
  ) async {
    await _montar(t, autorizado: false, sobre: []);
    expect(find.text('Vera usa IA para ayudarte.'), findsNothing);

    await t.tap(find.byKey(const Key('ver_texto_completo')));
    await t.pump();

    expect(find.text('Vera usa IA para ayudarte.'), findsOneWidget);
  });

  testWidgets(
    'Activar Vera registra el consentimiento y recién entonces abre el chat',
    (t) async {
      final vistos = await _montar(t, autorizado: false, sobre: []);

      await t.tap(find.text('Activar Vera'));
      await t.pump();
      await t.pump();

      final post = vistos.lastWhere((r) => r.method == 'POST');
      expect(post.url.path, '/v1/auth/consents');
      expect(jsonDecode(post.body)['tipo'], 'asistente_ia');
      expect(jsonDecode(post.body)['version_texto'], 'v1');
      expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
      expect(find.text('Activa a Vera'), findsNothing);
    },
  );

  testWidgets('Ahora no vuelve atrás sin registrar el consentimiento', (
    t,
  ) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final vistos = <http.Request>[];
    final mock = MockClient((r) async {
      vistos.add(r);
      return _json({
        'success': true,
        'data': {
          'tipo': 'asistente_ia',
          'version_texto': 'v1',
          'texto': 'Texto',
          'autorizado': false,
        },
        'error': null,
        'meta': null,
      }, 200);
    });
    final repo = AsistenteRepository(
      client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/asistente'),
              child: const Text('abrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/asistente',
          builder: (_, _) => AsistenteScreen(repository: repo),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(find.text('Activa a Vera'), findsOneWidget);

    await t.tap(find.text('Ahora no'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.text('abrir'), findsOneWidget);
    expect(vistos.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
    'si registrar el consentimiento falla informa y no abre el chat',
    (t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var posts = 0;
      final mock = MockClient((r) async {
        if (r.method == 'GET') {
          return _json({
            'success': true,
            'data': {
              'tipo': 'asistente_ia',
              'version_texto': 'v1',
              'texto': 'Texto',
              'autorizado': false,
            },
            'error': null,
            'meta': null,
          }, 200);
        }
        posts++;
        if (posts == 1) throw http.ClientException('sin red');
        return _json({
          'success': true,
          'data': {},
          'error': null,
          'meta': null,
        }, 201);
      });
      final repo = AsistenteRepository(
        client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
      );
      await t.pumpWidget(MaterialApp(home: AsistenteScreen(repository: repo)));
      await t.pump();
      await t.pump();

      await t.tap(find.text('Activar Vera'));
      await t.pump();
      await t.pump();

      expect(find.text(mensajeSinRed), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);

      await t.tap(find.text('Reintentar'));
      await t.pump();
      await t.pump();

      expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
    },
  );

  testWidgets(
    'si falla la consulta del consentimiento el chat se ve pero no deja enviar y ofrece reintentar',
    (t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final vistos = <http.Request>[];
      var consultas = 0;
      final mock = MockClient((r) async {
        vistos.add(r);
        consultas++;
        if (consultas == 1) throw http.ClientException('sin red');
        return _json({
          'success': true,
          'data': {
            'tipo': 'asistente_ia',
            'version_texto': 'v1',
            'texto': 'Texto',
            'autorizado': true,
          },
          'error': null,
          'meta': null,
        }, 200);
      });
      final repo = AsistenteRepository(
        client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
      );
      await t.pumpWidget(MaterialApp(home: AsistenteScreen(repository: repo)));
      await t.pump();
      await t.pump();

      // El chat se ve, con su saludo y sugerencias, pero sin campo para escribir.
      expect(find.text('¿En qué te ayudo hoy?'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(mensajeSinRed), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Una sugerencia no envía nada sin consentimiento verificado.
      await t.tap(find.text('¿Cuánto tengo disponible?'));
      await t.pump();
      expect(vistos.where((r) => r.method == 'POST'), isEmpty);

      await t.tap(find.text('Reintentar'));
      await t.pump();
      await t.pump();

      expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
      expect(find.text(mensajeSinRed), findsNothing);
    },
  );

  testWidgets(
    'ConsentRequired al enviar presenta la activación y conserva el texto',
    (t) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var vigente = true;
      final mock = MockClient((r) async {
        if (r.method == 'GET') {
          return _json({
            'success': true,
            'data': {
              'tipo': 'asistente_ia',
              'version_texto': vigente ? 'v1' : 'v2',
              'texto': 'Texto',
              'autorizado': vigente,
            },
            'error': null,
            'meta': null,
          }, 200);
        }
        if (r.url.path == '/v1/auth/consents') {
          return _json({
            'success': true,
            'data': {},
            'error': null,
            'meta': null,
          }, 201);
        }
        // El servidor ya no reconoce el consentimiento al llegar el mensaje.
        vigente = false;
        return _json({
          'success': false,
          'data': null,
          'error': {'code': 'ConsentRequired', 'message': 'x'},
          'meta': null,
        }, 403);
      });
      final repo = AsistenteRepository(
        client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
      );
      await t.pumpWidget(MaterialApp(home: AsistenteScreen(repository: repo)));
      await t.pump();
      await t.pump();

      await enviarTexto(t, 'cuanto tengo');
      await t.pump();

      expect(find.text('Activa a Vera'), findsOneWidget);
      expect(find.text('Texto completo (versión v2)'), findsOneWidget);
      expect(
        find.text('Debes aceptar los términos requeridos para continuar.'),
        findsNothing,
      );
      expect(find.text('cuanto tengo'), findsNothing);

      vigente = true;
      await t.tap(find.text('Activar Vera'));
      await t.pump();
      await t.pump();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'cuanto tengo',
      );
    },
  );

  testWidgets('un 503 ofrece reintentar con la misma clave y no duplica', (
    t,
  ) async {
    final vistos = await _montar(
      t,
      autorizado: true,
      sobre: [
        (_) => _json({
          'success': false,
          'data': null,
          'error': {'code': 'AssistantUnavailable', 'message': 'x'},
          'meta': null,
        }, 503),
        (_) => _json(_ok('Tu saldo es \$1.250.000'), 200),
      ],
    );
    await abrirTeclado(t);
    await t.enterText(find.byType(TextField), 'cuanto tengo');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await t.pump();

    expect(find.text('Reintentar'), findsOneWidget);
    final boton = find.ancestor(
      of: find.text('Reintentar'),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );
    expect(boton, findsOneWidget);
    await t.tap(boton);
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }

    final envios = vistos
        .where((r) => r.url.path == '/v1/vera/mensajes')
        .toList();
    expect(envios, hasLength(2));
    expect(envios[0].headers['Idempotency-Key'], isNotEmpty);
    expect(
      envios[1].headers['Idempotency-Key'],
      envios[0].headers['Idempotency-Key'],
    );
    expect(envios[1].body, envios[0].body);
    expect(find.text('Tu saldo es \$1.250.000'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('cuanto tengo'), findsOneWidget);
  });

  testWidgets(
    'un mensaje nuevo después de un error definitivo usa otra clave',
    (t) async {
      final vistos = await _montar(
        t,
        autorizado: true,
        sobre: [
          (_) => _json({
            'success': false,
            'data': null,
            'error': {'code': 'ValidationError', 'message': 'x'},
            'meta': null,
          }, 422),
          (_) => _json(_ok('ok'), 200),
        ],
      );
      Future<void> enviar(String m) async {
        await abrirTeclado(t);
        await t.enterText(find.byType(TextField), m);
        await t.pump();
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pump();
        await t.pump();
      }

      await enviar('uno');
      expect(find.text('Reintentar'), findsNothing);
      await enviar('dos');
      final claves = vistos
          .where((r) => r.url.path == '/v1/vera/mensajes')
          .map((r) => r.headers['Idempotency-Key'])
          .toList();
      expect(claves, hasLength(2));
      expect(claves[0], isNot(claves[1]));
    },
  );

  test('las llamadas a la IA esperan 60 segundos', () {
    expect(AsistenteRepository.timeoutIa, const Duration(seconds: 60));
  });

  testWidgets(
    'un 429 por cupo informa cuándo volver, conserva el texto y permite reenviar',
    (t) async {
      final vistos = await _montar(
        t,
        autorizado: true,
        sobre: [
          (_) => http.Response(
            jsonEncode({
              'success': false,
              'data': null,
              'error': {'code': 'TooManyRequests', 'message': 'x'},
              'meta': null,
            }),
            429,
            headers: {'content-type': 'application/json', 'retry-after': '120'},
          ),
          (_) => _json(_ok('listo'), 200),
        ],
      );
      await enviarTexto(t, 'cuanto tengo');

      expect(find.text('cuanto tengo'), findsOneWidget);
      expect(find.text('No enviado'), findsOneWidget);
      expect(find.textContaining('en 2 min'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await t.tap(find.text('Reintentar'));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      final envios = vistos
          .where((r) => r.url.path == '/v1/vera/mensajes')
          .toList();
      expect(envios, hasLength(2));
      expect(
        envios[1].headers['Idempotency-Key'],
        envios[0].headers['Idempotency-Key'],
      );
      expect(find.text('listo'), findsOneWidget);
      expect(find.text('No enviado'), findsNothing);
    },
  );

  testWidgets('sin conexión marca el mensaje como no enviado', (t) async {
    await _montar(
      t,
      autorizado: true,
      sobre: [(_) => throw http.ClientException('sin red')],
    );
    await enviarTexto(t, 'hola vera');

    expect(find.text('hola vera'), findsOneWidget);
    expect(find.text('No enviado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('la respuesta de Vera se anuncia al lector de pantalla', (
    t,
  ) async {
    final semantica = t.ensureSemantics();
    await _montar(
      t,
      autorizado: true,
      sobre: [(_) => _json(_ok('Tienes mucho'), 200)],
    );
    await enviarTexto(t, 'cuanto tengo');

    final nodo = t.getSemantics(find.text('Tienes mucho'));
    expect(nodo.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantica.dispose();
  });
}
