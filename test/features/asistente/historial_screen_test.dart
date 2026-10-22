import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/historial_screen.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _conv(int n) => {
  'id': 'c$n',
  'titulo': 'Conversación $n',
  'ultima_actividad': '2026-10-15T14:17:00-05:00',
  'creada_en': '2026-10-15T14:00:00-05:00',
};

Map<String, Object?> _pagina(
  List<Map<String, Object?>> items, {
  String? cursor,
}) => {
  'success': true,
  'data': items,
  'error': null,
  'meta': {'next_cursor': cursor, 'has_more': cursor != null},
};

http.Response _fallo(int status, String code) => _json({
  'success': false,
  'data': null,
  'error': {'code': code, 'message': 'x'},
  'meta': null,
}, status);

class _Montaje {
  _Montaje(this.vistos);
  final List<http.Request> vistos;

  Iterable<http.Request> get borrados =>
      vistos.where((r) => r.method == 'DELETE');
  Iterable<http.Request> get listados => vistos.where((r) => r.method == 'GET');
}

Future<_Montaje> _montar(
  WidgetTester t,
  http.Response Function(http.Request) responder,
) async {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
    vistos.add(r);
    return responder(r);
  });
  final repo = AsistenteRepository(
    client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
  );
  await t.pumpWidget(
    MaterialApp(home: HistorialAsistenteScreen(repository: repo)),
  );
  await t.pump();
  await t.pump();
  return _Montaje(vistos);
}

/// Desliza la fila hasta descartarla; el diálogo aparece al terminar la animación.
Future<void> _deslizar(WidgetTester t, String titulo) async {
  await t.drag(find.text(titulo), const Offset(-700, 0));
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _confirmarBorrado(WidgetTester t) async {
  await t.tap(find.text('Borrar').last);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('lista las conversaciones con título y fecha', (t) async {
    await _montar(t, (_) => _json(_pagina([_conv(1), _conv(2)]), 200));

    expect(find.text('Conversación 1'), findsOneWidget);
    expect(find.text('Conversación 2'), findsOneWidget);
    expect(find.textContaining('15/10/2026'), findsWidgets);
  });

  testWidgets('sin conversaciones muestra el estado vacío y no un error', (
    t,
  ) async {
    await _montar(t, (_) => _json(_pagina(const []), 200));

    expect(find.text('Aún no has hablado con Vera.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('un error en la consulta ofrece Reintentar', (t) async {
    var intentos = 0;
    await _montar(t, (_) {
      intentos++;
      return intentos == 1
          ? _fallo(500, 'InternalError')
          : _json(_pagina([_conv(1)]), 200);
    });

    expect(find.text('Reintentar'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    await t.pump();
    await t.pump();

    expect(find.text('Conversación 1'), findsOneWidget);
  });

  testWidgets('pagina por cursor al desplazarse hasta el final', (t) async {
    final m = await _montar(t, (r) {
      if (r.url.queryParameters['cursor'] == 'p2') {
        return _json(_pagina([_conv(100)]), 200);
      }
      return _json(
        _pagina([for (var i = 1; i <= 30; i++) _conv(i)], cursor: 'p2'),
        200,
      );
    });
    expect(m.listados, hasLength(1));

    await t.drag(find.byType(ListView), const Offset(0, -5000));
    await t.pump();
    await t.pump();

    expect(m.listados, hasLength(2));
    expect(m.listados.last.url.queryParameters['cursor'], 'p2');
  });

  testWidgets(
    'si falla una página siguiente muestra Reintentar sin perder la lista',
    (t) async {
      var segundaVez = false;
      await _montar(t, (r) {
        if (r.url.queryParameters['cursor'] == 'p2') {
          if (!segundaVez) {
            segundaVez = true;
            return _fallo(500, 'InternalError');
          }
          return _json(_pagina([_conv(100)]), 200);
        }
        return _json(
          _pagina([for (var i = 1; i <= 30; i++) _conv(i)], cursor: 'p2'),
          200,
        );
      });

      await t.drag(find.byType(ListView), const Offset(0, -5000));
      await t.pump();
      await t.pump();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Conversación 30'), findsOneWidget);

      await t.tap(find.text('Reintentar'));
      await t.pump();
      await t.pump();
      expect(find.text('Conversación 100'), findsOneWidget);
    },
  );

  testWidgets('borrar una conversación pide confirmación y la quita', (
    t,
  ) async {
    final m = await _montar(t, (r) {
      if (r.method == 'DELETE') return http.Response('', 204);
      return _json(_pagina([_conv(1), _conv(2)]), 200);
    });

    await _deslizar(t, 'Conversación 1');
    expect(find.text('¿Borrar esta conversación?'), findsOneWidget);
    expect(m.borrados, isEmpty);

    await _confirmarBorrado(t);

    expect(m.borrados.single.url.path, '/v1/vera/conversaciones/c1');
    expect(find.text('Conversación 1'), findsNothing);
    expect(find.text('Conversación 2'), findsOneWidget);
  });

  testWidgets('cancelar la confirmación no borra nada', (t) async {
    final m = await _montar(t, (_) => _json(_pagina([_conv(1)]), 200));

    await _deslizar(t, 'Conversación 1');
    await t.tap(find.text('Cancelar'));
    await t.pump();
    await t.pump();

    expect(m.borrados, isEmpty);
    expect(find.text('Conversación 1'), findsOneWidget);
  });

  testWidgets('un borrado fallido no la quita y el aviso permite reintentar', (
    t,
  ) async {
    var borrados = 0;
    final m = await _montar(t, (r) {
      if (r.method == 'DELETE') {
        borrados++;
        return borrados == 1
            ? _fallo(500, 'InternalError')
            : http.Response('', 204);
      }
      return _json(_pagina([_conv(1)]), 200);
    });

    await _deslizar(t, 'Conversación 1');
    await _confirmarBorrado(t);

    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Conversación 1'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await t.tap(find.text('Reintentar'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));

    expect(m.borrados, hasLength(2));
    expect(find.text('Conversación 1'), findsNothing);
  });

  testWidgets('borrar todo llama al DELETE y deja el historial vacío', (
    t,
  ) async {
    final m = await _montar(t, (r) {
      if (r.method == 'DELETE') return http.Response('', 204);
      return _json(_pagina([_conv(1), _conv(2)]), 200);
    });

    await t.tap(find.byTooltip('Borrar todo'));
    await t.pump();
    await t.pump();
    expect(find.text('¿Borrar todo el historial?'), findsOneWidget);
    await _confirmarBorrado(t);

    expect(m.borrados.single.url.path, '/v1/vera/conversaciones');
    expect(find.text('Aún no has hablado con Vera.'), findsOneWidget);
  });

  testWidgets('un borrado de todo fallido conserva la lista', (t) async {
    await _montar(t, (r) {
      if (r.method == 'DELETE') return _fallo(500, 'InternalError');
      return _json(_pagina([_conv(1)]), 200);
    });

    await t.tap(find.byTooltip('Borrar todo'));
    await t.pump();
    await t.pump();
    await _confirmarBorrado(t);

    expect(find.text('Conversación 1'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
