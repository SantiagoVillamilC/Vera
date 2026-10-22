import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/data/grabador_voz.dart';
import 'package:vera/features/asistente/presentation/asistente_screen.dart';

import '../home/presentation/cargar_roboto.dart';
import '../home/presentation/fake_session_store.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

class _GrabadorMudo implements GrabadorDeVoz {
  @override
  set onTope(void Function()? alcanzado) {}

  @override
  Future<bool> tienePermiso({bool pedir = true}) async => true;

  @override
  Future<void> iniciar() async {}

  @override
  Future<Uint8List?> detener() async => null;

  @override
  Future<void> cancelar() async {}

  @override
  Future<void> dispose() async {}
}

Map<String, Object?> _respuesta(String texto) => {
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

Future<List<http.Request>> _montar(
  WidgetTester t, {
  SessionProfile? perfil,
  String respuesta = 'Listo',
  Size size = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
  bool reducirMovimiento = false,
  Widget Function(AsistenteScreen pantalla)? envolver,
}) async {
  if (fuenteReal) await cargarRoboto();
  t.view.physicalSize = size;
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
          'texto': 'Texto',
          'autorizado': true,
        },
        'error': null,
        'meta': null,
      }, 200);
    }
    return _json(_respuesta(respuesta), 200);
  });
  final pantalla = AsistenteScreen(
    repository: AsistenteRepository(
      client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
    ),
    grabador: _GrabadorMudo(),
    session: FakeSessionStore(profile: perfil ?? const SessionProfile()),
  );
  await t.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
          disableAnimations: reducirMovimiento,
        ),
        child: child!,
      ),
      home: envolver != null ? envolver(pantalla) : pantalla,
    ),
  );
  await t.pump();
  await t.pump();
  await t.pump();
  return vistos;
}

void main() {
  testWidgets('saluda con el primer nombre y pregunta en qué ayudar', (
    t,
  ) async {
    await _montar(
      t,
      perfil: const SessionProfile(nombreCompleto: 'Valentina Ríos'),
    );

    expect(find.text('Hola, Valentina.'), findsOneWidget);
    expect(find.text('¿En qué te ayudo hoy?'), findsOneWidget);
  });

  testWidgets('sin nombre guardado el saludo no lleva nombre', (t) async {
    await _montar(t);

    expect(find.text('Hola.'), findsOneWidget);
  });

  testWidgets(
    'la cabecera muestra Vera Beta y las opciones de la conversación',
    (t) async {
      await _montar(t);

      expect(find.text('Vera'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.byTooltip('Nueva conversación'), findsOneWidget);
      expect(find.byTooltip('Historial'), findsOneWidget);
      expect(find.byTooltip('Leer las respuestas en voz alta'), findsOneWidget);
    },
  );

  testWidgets('por defecto se habla: micrófono grande y botón de teclado', (
    t,
  ) async {
    await _montar(t);

    expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
    expect(find.byKey(const Key('abrir_teclado')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'el teclado abre el campo de texto y Usar la voz vuelve al micrófono',
    (t) async {
      await _montar(t);

      await t.tap(find.byKey(const Key('abrir_teclado')));
      await t.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('boton_microfono')), findsNothing);

      await t.tap(find.byKey(const Key('usar_voz')));
      await t.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
    },
  );

  testWidgets('las sugerencias se envían como si se hubieran escrito', (
    t,
  ) async {
    final vistos = await _montar(t);

    await t.tap(find.text('¿Cuánto tengo disponible?'));
    await t.pump();
    await t.pump();

    final envio = vistos.singleWhere((r) => r.url.path == '/v1/vera/mensajes');
    expect(jsonDecode(envio.body)['texto'], '¿Cuánto tengo disponible?');
  });

  testWidgets('los montos de la respuesta de Vera van en negrita', (t) async {
    await _montar(t, respuesta: 'Llevas \$272.700 en domicilios este mes');
    await t.tap(find.text('¿Cuánto tengo disponible?'));
    await t.pump();
    await t.pump();
    await t.pump();

    final texto = t.widget<Text>(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.textSpan?.toPlainText().contains('Llevas') ?? false),
      ),
    );
    final spans = (texto.textSpan! as TextSpan).children!.cast<TextSpan>();
    final monto = spans.singleWhere((s) => s.text == '\$272.700');
    expect(monto.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('Cerrar vuelve a la pantalla anterior', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final mock = MockClient((r) async {
      if (r.url.path == '/v1/auth/consents') {
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
      }
      return _json(_respuesta('x'), 200);
    });
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
          builder: (_, _) => AsistenteScreen(
            repository: AsistenteRepository(
              client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
            ),
            grabador: _GrabadorMudo(),
            session: FakeSessionStore(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump();
    await t.pump();

    await t.tap(find.byKey(const Key('cerrar_vera')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.text('abrir'), findsOneWidget);
  });

  for (final escala in [1.0, 1.3]) {
    testWidgets('a 320x640 con escala $escala no desborda en voz ni en texto', (
      t,
    ) async {
      await _montar(
        t,
        size: const Size(320, 640),
        escala: escala,
        fuenteReal: true,
        perfil: const SessionProfile(nombreCompleto: 'Valentina Ríos'),
      );
      expect(t.takeException(), isNull);

      await t.tap(find.byKey(const Key('abrir_teclado')));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  }

  group('movimiento', () {
    List<double> barras(WidgetTester t) => [
      for (final w in t.widgetList<Container>(find.byType(Container)))
        if (w.constraints?.maxWidth == 4) w.constraints!.maxHeight,
    ];

    testWidgets('las ondas junto al micrófono suben y bajan', (t) async {
      await _montar(t);
      await t.pump(const Duration(milliseconds: 400));
      final antes = barras(t);
      await t.pump(const Duration(milliseconds: 450));
      final despues = barras(t);

      expect(antes, hasLength(8));
      expect(despues, isNot(antes));
    });

    testWidgets('el saludo y las sugerencias entran con un desvanecimiento', (
      t,
    ) async {
      await _montar(t);
      double opacidad(Finder f) => t
          .widget<Opacity>(
            find.ancestor(of: f, matching: find.byType(Opacity)).first,
          )
          .opacity;
      final saludo = find.byKey(const Key('saludo_vera'));
      final sugerencia = find.text('¿Cuánto tengo disponible?');

      await t.pump(const Duration(milliseconds: 100));
      final saludoAlPrincipio = opacidad(saludo);
      final sugerenciaAlPrincipio = opacidad(sugerencia);
      await t.pump(const Duration(seconds: 2));

      expect(saludoAlPrincipio, lessThan(1));
      expect(sugerenciaAlPrincipio, lessThan(1));
      expect(opacidad(saludo), 1.0);
      expect(opacidad(sugerencia), 1.0);
    });

    testWidgets('con reducir movimiento las ondas quedan quietas', (t) async {
      await _montar(t, reducirMovimiento: true);
      await t.pump(const Duration(milliseconds: 400));
      final antes = barras(t);
      await t.pump(const Duration(milliseconds: 450));

      expect(barras(t), antes);
    });
  });
}
