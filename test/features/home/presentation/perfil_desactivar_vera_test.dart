import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';

import 'fake_session_store.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _consent({required bool autorizado}) => {
  'success': true,
  'data': {
    'tipo': 'asistente_ia',
    'version_texto': 'v3',
    'texto': 'texto',
    'autorizado': autorizado,
  },
  'error': null,
  'meta': null,
};

/// Monta Perfil con el consentimiento en el estado dado. Devuelve las peticiones que no son
/// la consulta inicial del consentimiento.
Future<List<http.Request>> _abrir(
  WidgetTester t, {
  required bool autorizado,
  http.Response Function(http.Request)? sobre,
}) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
    if (r.method == 'GET' && r.url.path == '/v1/auth/consents') {
      return _json(_consent(autorizado: autorizado), 200);
    }
    vistos.add(r);
    return sobre != null ? sobre(r) : http.Response('', 204);
  });
  final repo = AsistenteRepository(
    client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
  );
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PerfilTab(session: FakeSessionStore(), asistente: repo),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return vistos;
}

Future<void> _pulsar(WidgetTester t, String texto) async {
  await t.tap(find.text(texto).last);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('sin consentimiento vigente no se ofrece desactivar a Vera', (
    t,
  ) async {
    await _abrir(t, autorizado: false);

    expect(find.byKey(const Key('desactivar_vera')), findsNothing);
  });

  testWidgets('desactivar registra la revocación con la versión vigente', (
    t,
  ) async {
    final vistos = await _abrir(t, autorizado: true);

    await t.tap(find.byKey(const Key('desactivar_vera')));
    await t.pump();
    expect(find.text('¿Desactivar a Vera?'), findsOneWidget);
    expect(vistos, isEmpty);

    await _pulsar(t, 'Desactivar');

    final post = vistos.first;
    expect(post.method, 'POST');
    expect(post.url.path, '/v1/auth/consents');
    expect(jsonDecode(post.body), {
      'tipo': 'asistente_ia',
      'version_texto': 'v3',
      'aceptado': false,
      'accion': 'revocar',
      'metodo': 'app',
    });
    expect(find.text('¿Borrar también tu historial?'), findsOneWidget);
    expect(find.byKey(const Key('desactivar_vera')), findsNothing);
  });

  testWidgets('puede conservar el historial', (t) async {
    final vistos = await _abrir(t, autorizado: true);

    await t.tap(find.byKey(const Key('desactivar_vera')));
    await t.pump();
    await _pulsar(t, 'Desactivar');
    await _pulsar(t, 'Conservar');

    expect(vistos.where((r) => r.method == 'DELETE'), isEmpty);
  });

  testWidgets('puede borrar también el historial', (t) async {
    final vistos = await _abrir(t, autorizado: true);

    await t.tap(find.byKey(const Key('desactivar_vera')));
    await t.pump();
    await _pulsar(t, 'Desactivar');
    await _pulsar(t, 'Borrar historial');

    final borrado = vistos.where((r) => r.method == 'DELETE').single;
    expect(borrado.url.path, '/v1/vera/conversaciones');
  });

  testWidgets('cancelar no revoca nada', (t) async {
    final vistos = await _abrir(t, autorizado: true);

    await t.tap(find.byKey(const Key('desactivar_vera')));
    await t.pump();
    await _pulsar(t, 'Cancelar');

    expect(vistos, isEmpty);
    expect(find.byKey(const Key('desactivar_vera')), findsOneWidget);
  });

  testWidgets(
    'si la revocación falla se informa, se puede reintentar y Vera sigue activa',
    (t) async {
      var intentos = 0;
      final vistos = await _abrir(
        t,
        autorizado: true,
        sobre: (r) {
          if (r.url.path == '/v1/auth/consents') {
            intentos++;
            if (intentos == 1) {
              return _json({
                'success': false,
                'data': null,
                'error': {'code': 'InternalError', 'message': 'x'},
                'meta': null,
              }, 500);
            }
            return _json({
              'success': true,
              'data': {},
              'error': null,
              'meta': null,
            }, 201);
          }
          return http.Response('', 204);
        },
      );

      await t.tap(find.byKey(const Key('desactivar_vera')));
      await t.pump();
      await _pulsar(t, 'Desactivar');
      await t.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const Key('desactivar_vera')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await t.tap(find.text('Reintentar'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));

      expect(vistos.where((r) => r.method == 'POST'), hasLength(2));
      expect(find.byKey(const Key('desactivar_vera')), findsNothing);
    },
  );
}
