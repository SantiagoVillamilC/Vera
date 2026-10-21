import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';

import 'fake_session_store.dart';

Future<List<http.Request>> _abrir(
  WidgetTester t,
  http.Response Function(http.Request) responder,
) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
    if (r.method == 'GET' && r.url.path == '/v1/auth/consents') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'tipo': 'asistente_ia',
            'version_texto': 'v1',
            'texto': 'texto',
            'autorizado': false,
          },
          'error': null,
          'meta': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    vistos.add(r);
    return responder(r);
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

void main() {
  testWidgets('Borrar historial de Vera pide confirmación y llama al DELETE', (
    t,
  ) async {
    final vistos = await _abrir(t, (_) => http.Response('', 204));

    await t.tap(find.byKey(const Key('borrar_historial_vera')));
    await t.pump();
    expect(find.text('¿Borrar el historial de Vera?'), findsOneWidget);
    expect(vistos, isEmpty);

    await t.tap(find.text('Borrar').last);
    await t.pump();
    await t.pump();

    expect(vistos.single.method, 'DELETE');
    expect(vistos.single.url.path, '/v1/vera/conversaciones');
    expect(find.text('Historial de Vera borrado.'), findsOneWidget);
  });

  testWidgets('cancelar no llama al servidor', (t) async {
    final vistos = await _abrir(t, (_) => http.Response('', 204));

    await t.tap(find.byKey(const Key('borrar_historial_vera')));
    await t.pump();
    await t.tap(find.text('Cancelar'));
    await t.pump();

    expect(vistos, isEmpty);
  });

  testWidgets('un error se informa y permite reintentar', (t) async {
    var llamadas = 0;
    final vistos = await _abrir(t, (_) {
      llamadas++;
      return llamadas == 1
          ? http.Response(
              jsonEncode({
                'success': false,
                'data': null,
                'error': {'code': 'InternalError', 'message': 'x'},
                'meta': null,
              }),
              500,
              headers: {'content-type': 'application/json'},
            )
          : http.Response('', 204);
    });

    await t.tap(find.byKey(const Key('borrar_historial_vera')));
    await t.pump();
    await t.tap(find.text('Borrar').last);
    await t.pump();
    await t.pump();

    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Reintentar'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));

    expect(vistos, hasLength(2));
    // El aviso de éxito espera a que el de error termine de salir.
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Historial de Vera borrado.'), findsOneWidget);
  });
}
