import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/data/grabador_voz.dart';
import 'package:vera/features/asistente/data/lector_kokoro.dart';
import 'package:vera/features/asistente/data/lector_voz.dart';
import 'package:vera/features/asistente/data/reproductor_audio.dart';
import 'package:vera/features/asistente/presentation/asistente_screen.dart';

import '../home/presentation/cargar_roboto.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

class _GrabadorFalso implements GrabadorDeVoz {
  bool permiso = false;
  bool permisoTrasPedir = true;
  int pedidos = 0;
  int iniciadas = 0;
  int canceladas = 0;
  int detenidas = 0;
  void Function()? tope;

  @override
  set onTope(void Function()? alcanzado) => tope = alcanzado;

  @override
  Future<bool> tienePermiso({bool pedir = true}) async {
    if (!pedir) return permiso;
    pedidos++;
    permiso = permisoTrasPedir;
    return permiso;
  }

  @override
  Future<void> iniciar() async => iniciadas++;

  @override
  Future<Uint8List?> detener() async {
    detenidas++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> cancelar() async => canceladas++;

  @override
  Future<void> dispose() async {}
}

class _LectorFalso implements LectorDeVoz {
  final leidos = <String>[];
  int detenciones = 0;
  int disposes = 0;
  void Function()? _fin;

  @override
  Future<void> leer(String texto, {required void Function() alTerminar}) async {
    leidos.add(texto);
    _fin = alTerminar;
  }

  @override
  Future<void> detener() async {
    detenciones++;
    _fin?.call();
    _fin = null;
  }

  void terminar() {
    _fin?.call();
    _fin = null;
  }

  @override
  Future<void> dispose() async => disposes++;
}

class _ReproductorFalso implements ReproductorDeAudio {
  final reproducidos = <Uint8List>[];
  int detenciones = 0;

  /// Con [sonando] el audio no termina solo: dura hasta que alguien lo detiene.
  bool sonando = false;
  Completer<void>? _enCurso;

  @override
  Future<void> reproducir(Uint8List wav) async {
    reproducidos.add(wav);
    if (!sonando) return;
    final c = _enCurso = Completer<void>();
    await c.future;
  }

  @override
  Future<void> detener() async {
    detenciones++;
    final c = _enCurso;
    _enCurso = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> dispose() async {}
}

/// WAV mínimo válido para el contrato del cliente: cabecera RIFF/WAVE y algo de audio.
Uint8List _wavMinimo() {
  final b = Uint8List(100);
  b.setRange(0, 4, 'RIFF'.codeUnits);
  b.setRange(8, 12, 'WAVE'.codeUnits);
  return b;
}

class _PreferenciaFalsa implements PreferenciaLectura {
  _PreferenciaFalsa(this.valor);
  bool? valor;

  @override
  Future<bool?> elegida() async => valor;

  @override
  Future<void> guardar(bool activada) async => valor = activada;
}

Map<String, Object?> _respuesta(String texto, {String? transcripcion}) => {
  'success': true,
  'data': {
    'conversacion_id': 'c1',
    'mensaje_id': 'm1',
    'texto': texto,
    'transcripcion': ?transcripcion,
    'creado_en': '2026-10-15T14:17:00-05:00',
  },
  'error': null,
  'meta': null,
};

class _Montaje {
  _Montaje(
    this.vistos,
    this.grabador,
    this.lector,
    this.preferencia,
    this.reproductor,
  );
  final List<http.Request> vistos;
  final _GrabadorFalso grabador;
  final _LectorFalso lector;
  final _PreferenciaFalsa preferencia;
  final _ReproductorFalso reproductor;

  Iterable<http.Request> get sintesis =>
      vistos.where((r) => r.url.path == '/v1/vera/sintetizar');

  Iterable<http.Request> get voz =>
      vistos.where((r) => r.url.path == '/v1/vera/mensajes/voz');
}

Future<_Montaje> _montar(
  WidgetTester t, {
  List<http.Response Function(http.Request)> sobre = const [],
  bool? leer = false,
  bool kokoro = false,
  bool permiso = true,
  Future<void> Function()? abrirAjustes,
  Size tamano = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
}) async {
  if (fuenteReal) await cargarRoboto();
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final cola = [...sobre];
  final vistos = <http.Request>[];
  final mock = MockClient((r) async {
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
    vistos.add(r);
    return cola.removeAt(0)(r);
  });
  final grabador = _GrabadorFalso()..permiso = permiso;
  final lector = _LectorFalso();
  final reproductor = _ReproductorFalso();
  final preferencia = _PreferenciaFalsa(leer);
  await t.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: AsistenteScreen(
        repository: AsistenteRepository(
          client: ApiClient(baseUrl: 'http://x', clientFactory: () => mock),
        ),
        grabador: grabador,
        // Con [kokoro] se prueba el lector real del backend, con el teléfono como respaldo.
        lector: kokoro ? null : lector,
        reproductor: kokoro ? reproductor : null,
        lectorRespaldo: kokoro ? lector : null,
        preferenciaLectura: preferencia,
        abrirAjustes: abrirAjustes,
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return _Montaje(vistos, grabador, lector, preferencia, reproductor);
}

Future<void> _tocarMicrofono(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.mic_rounded).last);
  await t.pump();
  await t.pump();
}

Future<void> _grabarYEnviar(WidgetTester t, {int segundos = 3}) async {
  await _tocarMicrofono(t);
  for (var i = 0; i < segundos; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.tap(find.byIcon(Icons.stop_rounded).last);
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _escribirYEnviar(WidgetTester t, String m) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await t.tap(find.byKey(const Key('abrir_teclado')));
    await t.pump();
  }
  await t.enterText(find.byType(TextField), m);
  await t.pump();
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
  await t.pump();
}

void main() {
  setUp(() => PausaDeSintesis.compartida.reanudar());

  group('grabación', () {
    testWidgets('graba con indicador y tiempo, y permite cancelar', (t) async {
      final m = await _montar(t);
      await _tocarMicrofono(t);
      await t.pump(const Duration(seconds: 2));

      expect(m.grabador.iniciadas, 1);
      expect(find.text('00:02'), findsOneWidget);
      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);

      await t.tap(find.byTooltip('Descartar'));
      await t.pump();
      expect(m.grabador.canceladas, 1);
      expect(m.voz, isEmpty);
    });

    testWidgets('una grabación de menos de un segundo se descarta sin enviar', (
      t,
    ) async {
      final m = await _montar(t);
      await _tocarMicrofono(t);
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byIcon(Icons.stop_rounded).last);
      await t.pump();
      await t.pump();

      expect(m.voz, isEmpty);
    });

    testWidgets(
      'al detener envía el audio en base64 con formato y conversación',
      (t) async {
        final m = await _montar(
          t,
          sobre: [
            (_) => _json(
              _respuesta('Tienes mucho', transcripcion: 'cuánto tengo'),
              200,
            ),
          ],
        );
        await _grabarYEnviar(t);

        final cuerpo = jsonDecode(m.voz.single.body) as Map<String, dynamic>;
        expect(cuerpo['audio'], base64Encode([1, 2, 3]));
        expect(cuerpo['formato'], 'm4a');
        expect(cuerpo.containsKey('conversacion_id'), isTrue);
        expect(find.text('cuánto tengo'), findsOneWidget);
        expect(find.text('Tienes mucho'), findsOneWidget);
      },
    );

    testWidgets('al llegar al tope se detiene y se envía sola', (t) async {
      final m = await _montar(
        t,
        sobre: [(_) => _json(_respuesta('ok', transcripcion: 'hola'), 200)],
      );
      await _tocarMicrofono(t);
      await t.pump(const Duration(seconds: 5));
      m.grabador.tope!();
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      expect(m.grabador.detenidas, 1);
      expect(m.voz, hasLength(1));
    });
  });

  group('permiso del micrófono', () {
    testWidgets('lo explica antes de pedirlo y luego graba', (t) async {
      final m = await _montar(t, permiso: false);
      await _tocarMicrofono(t);

      expect(find.text('Vera necesita el micrófono'), findsOneWidget);
      expect(m.grabador.pedidos, 0);

      await t.tap(find.text('Continuar'));
      await t.pump();
      await t.pump();

      expect(m.grabador.pedidos, 1);
      expect(m.grabador.iniciadas, 1);
    });

    testWidgets(
      'si no acepta la explicación no se pide nada ni se bloquea el chat',
      (t) async {
        final m = await _montar(t, permiso: false);
        await _tocarMicrofono(t);
        await t.tap(find.text('Ahora no'));
        await t.pump();
        await t.pump();

        expect(m.grabador.pedidos, 0);
        expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
      },
    );

    testWidgets(
      'si lo niega informa, ofrece ajustes y escribir, y el chat sigue',
      (t) async {
        var ajustes = 0;
        final m = await _montar(
          t,
          permiso: false,
          abrirAjustes: () async => ajustes++,
        );
        m.grabador.permisoTrasPedir = false;
        await _tocarMicrofono(t);
        await t.tap(find.text('Continuar'));
        await t.pump();
        await t.pump();

        expect(
          find.textContaining('habilitarlo en los ajustes'),
          findsOneWidget,
        );
        expect(find.text('Escribir'), findsOneWidget);
        expect(find.byKey(const Key('boton_microfono')), findsOneWidget);
        expect(m.grabador.iniciadas, 0);

        await t.tap(find.text('Abrir ajustes'));
        await t.pump();
        expect(ajustes, 1);
      },
    );
  });

  group('audio no entendido', () {
    testWidgets('ofrece reintentar o escribir', (t) async {
      final m = await _montar(
        t,
        sobre: [
          (_) => _json({
            'success': false,
            'data': null,
            'error': {'code': 'AudioNotUnderstood', 'message': 'x'},
            'meta': null,
          }, 422),
        ],
      );
      await _grabarYEnviar(t);

      expect(
        find.text('No entendí el audio, repite o escribe.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Escribir'), findsOneWidget);

      final antes = m.grabador.iniciadas;
      await t.tap(find.text('Reintentar'));
      await t.pump();
      await t.pump();
      expect(m.grabador.iniciadas, antes + 1);
    });
  });

  group('lectura en voz alta', () {
    testWidgets(
      'con la lectura activada lee la respuesta y un toque la detiene',
      (t) async {
        final m = await _montar(
          t,
          leer: true,
          sobre: [
            (_) =>
                _json(_respuesta('Tienes mucho', transcripcion: 'cuánto'), 200),
          ],
        );
        await _grabarYEnviar(t);

        expect(m.lector.leidos, ['Tienes mucho']);
        expect(find.byKey(const Key('detener_lectura')), findsOneWidget);

        await t.tap(find.byKey(const Key('detener_lectura')));
        await t.pump();

        expect(m.lector.detenciones, 1);
        expect(find.byKey(const Key('detener_lectura')), findsNothing);
      },
    );

    testWidgets('con la lectura apagada no lee nada', (t) async {
      final m = await _montar(
        t,
        sobre: [
          (_) =>
              _json(_respuesta('Tienes mucho', transcripcion: 'cuánto'), 200),
        ],
      );
      await _grabarYEnviar(t);

      expect(m.lector.leidos, isEmpty);
    });

    testWidgets(
      'desactivar la lectura la guarda y las siguientes respuestas quedan en texto',
      (t) async {
        final m = await _montar(
          t,
          leer: true,
          sobre: [
            (_) => _json(_respuesta('Respuesta', transcripcion: 'hola'), 200),
          ],
        );
        await t.tap(find.byTooltip('Dejar de leer las respuestas en voz alta'));
        await t.pump();
        await t.pump();

        expect(m.preferencia.valor, isFalse);
        await _grabarYEnviar(t);
        expect(m.lector.leidos, isEmpty);
      },
    );

    testWidgets('activarla guarda la preferencia', (t) async {
      final m = await _montar(t);
      await t.tap(find.byTooltip('Leer las respuestas en voz alta'));
      await t.pump();
      await t.pump();

      expect(m.preferencia.valor, isTrue);
    });

    testWidgets('la preferencia guardada se aplica al abrir', (t) async {
      await _montar(t, leer: true);

      expect(
        find.byTooltip('Dejar de leer las respuestas en voz alta'),
        findsOneWidget,
      );
    });
  });

  group('respuesta hablada por defecto', () {
    testWidgets('sin elección, el turno de micrófono se habla', (t) async {
      final m = await _montar(
        t,
        leer: null,
        sobre: [
          (_) => _json(_respuesta('Tienes mucho', transcripcion: 'x'), 200),
        ],
      );
      await _grabarYEnviar(t);

      expect(m.lector.leidos, ['Tienes mucho']);
    });

    testWidgets('sin elección, el turno escrito no se habla', (t) async {
      final m = await _montar(
        t,
        leer: null,
        sobre: [(_) => _json(_respuesta('Tienes mucho'), 200)],
      );
      await _escribirYEnviar(t, 'cuánto tengo');

      expect(find.text('Tienes mucho'), findsOneWidget);
      expect(m.lector.leidos, isEmpty);
    });

    testWidgets('con la lectura encendida también se habla el turno escrito', (
      t,
    ) async {
      final m = await _montar(
        t,
        leer: true,
        sobre: [(_) => _json(_respuesta('Tienes mucho'), 200)],
      );
      await _escribirYEnviar(t, 'cuánto tengo');

      expect(m.lector.leidos, ['Tienes mucho']);
    });

    testWidgets('con la lectura apagada ni el micrófono se habla', (t) async {
      final m = await _montar(
        t,
        leer: false,
        sobre: [
          (_) => _json(_respuesta('Tienes mucho', transcripcion: 'x'), 200),
        ],
      );
      await _grabarYEnviar(t);

      expect(m.lector.leidos, isEmpty);
    });

    testWidgets(
      'sin elección el interruptor se ve encendido y al tocarlo apaga',
      (t) async {
        final m = await _montar(t, leer: null);
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

        await t.tap(find.byTooltip('Apagar la respuesta hablada'));
        await t.pump();
        await t.pump();

        expect(m.preferencia.valor, isFalse);
        expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

        await t.tap(find.byTooltip('Leer las respuestas en voz alta'));
        await t.pump();
        await t.pump();
        expect(m.preferencia.valor, isTrue);
      },
    );

    testWidgets('apagar el interruptor corta la lectura en curso', (t) async {
      final m = await _montar(
        t,
        leer: null,
        sobre: [(_) => _json(_respuesta('Hola', transcripcion: 'x'), 200)],
      );
      await _grabarYEnviar(t);
      expect(find.byKey(const Key('detener_lectura')), findsOneWidget);

      await t.tap(find.byTooltip('Apagar la respuesta hablada'));
      await t.pump();
      await t.pump();

      expect(m.lector.detenciones, 1);
      expect(find.byKey(const Key('detener_lectura')), findsNothing);
    });

    testWidgets('un turno nuevo corta la lectura que sigue sonando', (t) async {
      final m = await _montar(
        t,
        leer: true,
        sobre: [
          (_) => _json(_respuesta('Primera'), 200),
          (_) => _json(_respuesta('Segunda'), 200),
        ],
      );
      await _escribirYEnviar(t, 'uno');
      expect(m.lector.leidos, ['Primera']);

      await _escribirYEnviar(t, 'dos');

      expect(m.lector.detenciones, 1);
      expect(m.lector.leidos, ['Primera', 'Segunda']);
    });

    testWidgets('salir de la pantalla libera y corta el lector', (t) async {
      final m = await _montar(t, leer: true);

      await t.pumpWidget(const SizedBox());

      expect(m.lector.disposes, 1);
    });
  });

  group('respuesta hablada por el backend (Kokoro)', () {
    testWidgets('el turno de micrófono pide /sintetizar y reproduce el WAV', (
      t,
    ) async {
      final wav = _wavMinimo();
      final m = await _montar(
        t,
        leer: null,
        kokoro: true,
        sobre: [
          (_) => _json(_respuesta('Tienes mucho', transcripcion: 'x'), 200),
          (_) => http.Response.bytes(
            wav,
            200,
            headers: {'content-type': 'audio/wav'},
          ),
        ],
      );
      await _grabarYEnviar(t);
      await t.pump();
      await t.pump();

      expect(m.sintesis, hasLength(1));
      expect(jsonDecode(m.sintesis.single.body), {'texto': 'Tienes mucho'});
      expect(m.reproductor.reproducidos, [wav]);
      expect(m.lector.leidos, isEmpty);
    });

    testWidgets('con el backend degradado habla el teléfono', (t) async {
      final m = await _montar(
        t,
        leer: null,
        kokoro: true,
        sobre: [
          (_) => _json(_respuesta('Tienes mucho', transcripcion: 'x'), 200),
          (_) => http.Response(
            jsonEncode({
              'success': true,
              'data': {'audio_disponible': false, 'voz_local': true},
              'error': null,
              'meta': null,
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'x-vera-audio': 'no-disponible',
            },
          ),
        ],
      );
      await _grabarYEnviar(t);
      await t.pump();
      await t.pump();

      expect(m.reproductor.reproducidos, isEmpty);
      expect(m.lector.leidos, ['Tienes mucho']);
    });

    testWidgets('un 503 del backend también cae al teléfono sin avisar', (
      t,
    ) async {
      final m = await _montar(
        t,
        leer: null,
        kokoro: true,
        sobre: [
          (_) => _json(_respuesta('Tienes mucho', transcripcion: 'x'), 200),
          (_) => _json({
            'success': false,
            'data': null,
            'error': {'code': 'AssistantUnavailable', 'message': 'x'},
            'meta': null,
          }, 503),
        ],
      );
      await _grabarYEnviar(t);
      await t.pump();
      await t.pump();

      expect(m.lector.leidos, ['Tienes mucho']);
      expect(find.textContaining('AssistantUnavailable'), findsNothing);
    });

    testWidgets('el turno escrito sin elección no toca /sintetizar', (t) async {
      final m = await _montar(
        t,
        leer: null,
        kokoro: true,
        sobre: [(_) => _json(_respuesta('Tienes mucho'), 200)],
      );
      await _escribirYEnviar(t, 'cuánto tengo');
      await t.pump();

      expect(m.sintesis, isEmpty);
      expect(m.reproductor.reproducidos, isEmpty);
      expect(m.lector.leidos, isEmpty);
    });

    testWidgets('un turno nuevo corta el audio que suena', (t) async {
      final m = await _montar(
        t,
        leer: true,
        kokoro: true,
        sobre: [
          (_) => _json(_respuesta('Primera'), 200),
          (_) => http.Response.bytes(
            _wavMinimo(),
            200,
            headers: {'content-type': 'audio/wav'},
          ),
          (_) => _json(_respuesta('Segunda'), 200),
          (_) => http.Response.bytes(
            _wavMinimo(),
            200,
            headers: {'content-type': 'audio/wav'},
          ),
        ],
      );
      m.reproductor.sonando = true;
      await _escribirYEnviar(t, 'uno');
      await t.pump();
      await t.pump();
      expect(m.reproductor.reproducidos, hasLength(1));
      expect(m.reproductor.detenciones, 0);

      await _escribirYEnviar(t, 'dos');
      await t.pump();
      await t.pump();

      expect(m.reproductor.detenciones, greaterThan(0));
      expect(m.reproductor.reproducidos, hasLength(2));
    });
  });

  group('segundo plano y llamadas', () {
    testWidgets('cancelan la grabación y detienen la lectura', (t) async {
      final m = await _montar(
        t,
        leer: true,
        sobre: [(_) => _json(_respuesta('Hola', transcripcion: 'x'), 200)],
      );
      await _tocarMicrofono(t);
      await t.pump(const Duration(seconds: 2));

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump();

      expect(m.grabador.canceladas, 1);
      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
      expect(m.voz, isEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('detienen una lectura en curso', (t) async {
      final m = await _montar(
        t,
        leer: true,
        sobre: [(_) => _json(_respuesta('Hola', transcripcion: 'x'), 200)],
      );
      await _grabarYEnviar(t);
      expect(find.byKey(const Key('detener_lectura')), findsOneWidget);

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump();

      expect(m.lector.detenciones, 1);
      expect(find.byKey(const Key('detener_lectura')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });

  // La tarjeta de accesibilidad pide etiqueta semántica en los controles de
  // audio y que aguanten el tamaño de letra del sistema al máximo.
  group('accesibilidad de los controles de audio', () {
    testWidgets('escuchar y detener se anuncian al lector de pantalla', (
      t,
    ) async {
      final semantica = t.ensureSemantics();
      await _montar(
        t,
        leer: true,
        sobre: [(_) => _json(_respuesta('Hola', transcripcion: 'x'), 200)],
      );

      // Apagado y encendido el control dice qué va a hacer, no en qué estado
      // está: es lo que escucha quien no ve el icono.
      expect(
        t.getSemantics(
          find.byTooltip('Dejar de leer las respuestas en voz alta'),
        ),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          tooltip: 'Dejar de leer las respuestas en voz alta',
        ),
      );

      await _grabarYEnviar(t);

      expect(find.bySemanticsLabel('Detener la lectura'), findsOneWidget);
      expect(
        t.getSemantics(find.byKey(const Key('detener_lectura'))),
        matchesSemantics(
          isButton: true,
          label: 'Detener la lectura',
          hasTapAction: true,
        ),
      );
      semantica.dispose();
    });

    testWidgets('apagada la lectura, el control ofrece encenderla', (t) async {
      final semantica = t.ensureSemantics();
      await _montar(t);

      expect(
        t.getSemantics(find.byTooltip('Leer las respuestas en voz alta')),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          tooltip: 'Leer las respuestas en voz alta',
        ),
      );
      semantica.dispose();
    });

    for (final ancho in [320.0, 360.0]) {
      testWidgets(
        'a ${ancho.toInt()}x640 con letra 2.0 los controles no desbordan',
        (t) async {
          await _montar(
            t,
            leer: true,
            tamano: Size(ancho, 640),
            escala: 2,
            fuenteReal: true,
            sobre: [(_) => _json(_respuesta('Hola', transcripcion: 'x'), 200)],
          );
          await _grabarYEnviar(t);

          // El chip de «Leyendo…» es el control más ancho de la pantalla: si
          // algo se sale a 2.0, se sale aquí.
          expect(find.byKey(const Key('detener_lectura')), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  });
}
