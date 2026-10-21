import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
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

void main() {
  testWidgets(
    'sin consentimiento muestra el texto y al aceptar habilita el chat',
    (t) async {
      final vistos = await _montar(t, autorizado: false, sobre: []);
      expect(find.text('Antes de empezar'), findsOneWidget);
      expect(find.text('Vera usa IA para ayudarte.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await t.tap(find.text('Aceptar y continuar'));
      await t.pump();
      await t.pump();

      final post = vistos.lastWhere((r) => r.method == 'POST');
      expect(jsonDecode(post.body)['version_texto'], 'v1');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Antes de empezar'), findsNothing);
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
}
