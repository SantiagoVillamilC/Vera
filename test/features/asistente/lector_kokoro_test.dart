import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/lector_kokoro.dart';
import 'package:vera/features/asistente/data/lector_voz.dart';
import 'package:vera/features/asistente/data/reproductor_audio.dart';

/// El "WAV" de las pruebas son los bytes UTF-8 del trozo, para saber qué suena.
Uint8List _audioDe(String texto) => Uint8List.fromList(utf8.encode(texto));
String _textoDe(Uint8List audio) => utf8.decode(audio);

class _Reproductor implements ReproductorDeAudio {
  _Reproductor(this.eventos);
  final List<String> eventos;
  final _pendientes = <Completer<void>>[];
  int activos = 0;
  int maxActivos = 0;
  int detenciones = 0;
  bool autoTerminar = false;
  Object? falla;

  @override
  Future<void> reproducir(Uint8List wav) async {
    if (falla != null) throw falla!;
    activos++;
    if (activos > maxActivos) maxActivos = activos;
    eventos.add('play:${_textoDe(wav)}');
    final c = Completer<void>();
    _pendientes.add(c);
    if (autoTerminar) scheduleMicrotask(() => terminarActual());
    await c.future;
    activos--;
    eventos.add('fin:${_textoDe(wav)}');
  }

  void terminarActual() {
    if (_pendientes.isEmpty) return;
    final c = _pendientes.removeAt(0);
    if (!c.isCompleted) c.complete();
  }

  @override
  Future<void> detener() async {
    detenciones++;
    for (final c in _pendientes) {
      if (!c.isCompleted) c.complete();
    }
    _pendientes.clear();
  }

  @override
  Future<void> dispose() => detener();
}

class _Respaldo implements LectorDeVoz {
  _Respaldo(this.eventos, this.reproductor);
  final List<String> eventos;
  final _Reproductor reproductor;
  final leidos = <String>[];
  int detenciones = 0;
  int solapes = 0;
  void Function()? _fin;

  @override
  Future<void> leer(String texto, {required void Function() alTerminar}) async {
    if (reproductor.activos > 0) solapes++;
    leidos.add(texto);
    eventos.add('tts:$texto');
    _fin = alTerminar;
  }

  void terminar() {
    final f = _fin;
    _fin = null;
    f?.call();
  }

  @override
  Future<void> detener() async {
    detenciones++;
    terminar();
  }

  @override
  Future<void> dispose() async {}
}

class _Banco {
  _Banco({int maxTrozos = 2, int maxCaracteres = 20, PausaDeSintesis? pausa}) {
    reproductor = _Reproductor(eventos);
    respaldo = _Respaldo(eventos, reproductor);
    this.pausa = pausa ?? PausaDeSintesis(ahora: () => reloj ?? DateTime(2026));
    lector = LectorKokoro(
      sintetizar: _sintetizar,
      reproductor: reproductor,
      respaldo: respaldo,
      maxTrozos: maxTrozos,
      maxCaracteresTrozo: maxCaracteres,
      pausa: this.pausa,
      registrar: registros.add,
    );
  }

  final eventos = <String>[];
  final registros = <String>[];
  final pedidos = <String>[];
  DateTime? reloj;
  late final _Reproductor reproductor;
  late final _Respaldo respaldo;
  late final PausaDeSintesis pausa;
  late final LectorKokoro lector;
  int terminaciones = 0;

  /// Cada pedido se resuelve con esta función, que por defecto devuelve el audio del trozo.
  Future<Uint8List?> Function(String texto, int indice)? manejar;

  Future<Uint8List?> _sintetizar(String texto) {
    final i = pedidos.length;
    pedidos.add(texto);
    eventos.add('pedir:$texto');
    return manejar != null ? manejar!(texto, i) : Future.value(_audioDe(texto));
  }

  Future<void> leer(String texto) =>
      lector.leer(texto, alTerminar: () => terminaciones++);

  Future<void> asentar() => pumpEventQueue();
}

const _a = 'Frase uno aquí.';
const _b = 'Frase dos aquí.';
const _c = 'Frase tres aquí.';
const _d = 'Frase cuatro aquí.';
const _e = 'Frase cinco aquí.';

void main() {
  group('éxito', () {
    test('sintetiza, reproduce y avisa una sola vez al terminar', () async {
      final t = _Banco()..reproductor.autoTerminar = true;

      await t.leer(_a);
      await t.asentar();

      expect(t.eventos, ['pedir:$_a', 'play:$_a', 'fin:$_a']);
      expect(t.respaldo.leidos, isEmpty);
      expect(t.terminaciones, 1);
    });

    test('un texto vacío termina de inmediato sin pedir nada', () async {
      final t = _Banco();

      await t.leer('   ');
      await t.asentar();

      expect(t.pedidos, isEmpty);
      expect(t.terminaciones, 1);
    });
  });

  group('respaldo con flutter_tts', () {
    test(
      'un error de la API lee todo el texto con la voz del teléfono',
      () async {
        final t = _Banco()
          ..manejar = (_, _) async => throw const ApiException(
            code: 'AssistantUnavailable',
            message: 'x',
            statusCode: 503,
          );

        await t.leer('$_a $_b');
        await t.asentar();

        expect(t.respaldo.leidos, ['$_a $_b']);
        expect(t.terminaciones, 0);
        t.respaldo.terminar();
        await t.asentar();
        expect(t.terminaciones, 1);
      },
    );

    test('el degradado (null) también cae al teléfono', () async {
      final t = _Banco()..manejar = (_, _) async => null;

      await t.leer(_a);
      await t.asentar();

      expect(t.respaldo.leidos, [_a]);
    });

    test('un timeout cae al teléfono', () async {
      final t = _Banco()
        ..manejar = (_, _) async => throw TimeoutException('lento');

      await t.leer(_a);
      await t.asentar();

      expect(t.respaldo.leidos, [_a]);
    });

    test('un fallo de red cae al teléfono sin lanzar', () async {
      final t = _Banco()..manejar = (_, _) async => throw Exception('sin red');

      await t.leer(_a);
      await t.asentar();

      expect(t.respaldo.leidos, [_a]);
    });

    test('un reproductor que falla cae al teléfono con ese trozo', () async {
      final t = _Banco()..reproductor.falla = StateError('códec');

      await t.leer('$_a $_b');
      await t.asentar();

      expect(t.respaldo.leidos, ['$_a $_b']);
    });

    test('si falla el segundo trozo, el teléfono sigue desde ahí', () async {
      final t = _Banco(maxTrozos: 3)
        ..manejar = (texto, i) async => i == 1 ? null : _audioDe(texto);

      await t.leer('$_a $_b $_c');
      await t.asentar();
      t.reproductor.terminarActual();
      await t.asentar();

      expect(t.eventos.where((e) => e.startsWith('play:')), ['play:$_a']);
      expect(t.respaldo.leidos, ['$_b $_c']);
    });

    test('el registro de depuración no incluye el texto', () async {
      final t = _Banco()
        ..manejar = (_, _) async => throw const ApiException(
          code: 'AssistantUnavailable',
          message: 'x',
          statusCode: 503,
        );

      await t.leer(_a);
      await t.asentar();

      expect(t.registros, isNotEmpty);
      expect(t.registros.any((r) => r.contains('Frase')), isFalse);
    });
  });

  group('pausa tras un fallo', () {
    test('un 429 respeta Retry-After y luego vuelve a intentar', () async {
      final t = _Banco()
        ..reloj = DateTime(2026, 11, 15, 10)
        ..manejar = (_, _) async => throw const ApiException(
          code: 'TooManyRequests',
          message: 'x',
          statusCode: 429,
          headers: {'retry-after': '120'},
        );

      await t.leer(_a);
      await t.asentar();
      t.respaldo.terminar();
      expect(t.pedidos.length, 1);

      // Dentro de la pausa va directo al teléfono, sin gastar cuota.
      t.reloj = DateTime(2026, 11, 15, 10, 1);
      await t.leer(_b);
      await t.asentar();
      expect(t.pedidos.length, 1);
      expect(t.respaldo.leidos, [_a, _b]);
      t.respaldo.terminar();

      // Pasados los 120 s vuelve a pedir.
      t.reloj = DateTime(2026, 11, 15, 10, 2, 1);
      t.manejar = null;
      t.reproductor.autoTerminar = true;
      await t.leer(_c);
      await t.asentar();
      expect(t.pedidos.length, 2);
      expect(t.respaldo.leidos, [_a, _b]);
    });

    test('sin Retry-After legible la pausa del 429 es de un minuto', () async {
      final t = _Banco()
        ..reloj = DateTime(2026, 11, 15, 10)
        ..manejar = (_, _) async => throw const ApiException(
          code: 'TooManyRequests',
          message: 'x',
          statusCode: 429,
        );
      await t.leer(_a);
      await t.asentar();
      t.respaldo.terminar();

      t.reloj = DateTime(2026, 11, 15, 10, 0, 59);
      expect(t.pausa.activa, isTrue);
      t.reloj = DateTime(2026, 11, 15, 10, 1, 1);
      expect(t.pausa.activa, isFalse);
    });

    test('un 401 o un 403 pausan varios minutos', () async {
      for (final estado in [401, 403]) {
        final t = _Banco()
          ..reloj = DateTime(2026, 11, 15, 10)
          ..manejar = (_, _) async =>
              throw ApiException(code: 'X', message: 'x', statusCode: estado);
        await t.leer(_a);
        await t.asentar();
        t.respaldo.terminar();

        t.reloj = DateTime(2026, 11, 15, 10, 4);
        expect(t.pausa.activa, isTrue, reason: '$estado');
        t.reloj = DateTime(2026, 11, 15, 10, 6);
        expect(t.pausa.activa, isFalse, reason: '$estado');
      }
    });

    test('un fallo corriente o un degradado pausan unos segundos', () async {
      final t = _Banco()
        ..reloj = DateTime(2026, 11, 15, 10)
        ..manejar = (_, _) async => null;
      await t.leer(_a);
      await t.asentar();
      t.respaldo.terminar();

      t.reloj = DateTime(2026, 11, 15, 10, 0, 30);
      expect(t.pausa.activa, isTrue);
      t.reloj = DateTime(2026, 11, 15, 10, 1);
      expect(t.pausa.activa, isFalse);
    });

    test('un éxito no deja pausa', () async {
      final t = _Banco()..reproductor.autoTerminar = true;

      await t.leer(_a);
      await t.asentar();

      expect(t.pausa.activa, isFalse);
    });

    test('la pausa se comparte entre lectores que usan la misma instancia', () {
      final pausa = PausaDeSintesis(ahora: () => DateTime(2026));
      pausa.pausar(const Duration(minutes: 1));

      final otra = _Banco(pausa: pausa);

      expect(otra.pausa.activa, isTrue);
    });
  });

  group('textos largos', () {
    test('se trocean y suenan en orden', () async {
      final t = _Banco(maxTrozos: 3)..reproductor.autoTerminar = true;

      await t.leer('$_a $_b $_c');
      await t.asentar();

      expect(t.pedidos, [_a, _b, _c]);
      expect(t.eventos.where((e) => e.startsWith('play:')), [
        'play:$_a',
        'play:$_b',
        'play:$_c',
      ]);
      expect(t.terminaciones, 1);
    });

    test('pide el siguiente trozo mientras suena el actual', () async {
      final t = _Banco(maxTrozos: 3);

      await t.leer('$_a $_b $_c');
      await t.asentar();

      // Suena el primero (sin terminar) y el segundo ya está pedido.
      expect(t.eventos, ['pedir:$_a', 'pedir:$_b', 'play:$_a']);

      t.reproductor.terminarActual();
      await t.asentar();
      expect(
        t.eventos.indexOf('fin:$_a'),
        lessThan(t.eventos.indexOf('play:$_b')),
      );
      expect(t.pedidos, [_a, _b, _c]);
    });

    test('nunca suenan dos audios a la vez ni el teléfono encima', () async {
      final t = _Banco(maxTrozos: 2)..reproductor.autoTerminar = true;

      await t.leer('$_a $_b $_c $_d');
      await t.asentar();
      t.respaldo.terminar();

      expect(t.reproductor.maxActivos, 1);
      expect(t.respaldo.solapes, 0);
    });

    test(
      'pasado el tope de trozos el resto lo lee el teléfono, al final',
      () async {
        final t = _Banco(maxTrozos: 2)..reproductor.autoTerminar = true;

        await t.leer('$_a $_b $_c $_d $_e');
        await t.asentar();

        expect(t.pedidos, [_a, _b]);
        expect(t.eventos.last, 'tts:$_c $_d $_e');
        expect(
          t.eventos.indexOf('fin:$_b'),
          lessThan(t.eventos.indexOf('tts:$_c $_d $_e')),
        );
        expect(t.terminaciones, 0);
        t.respaldo.terminar();
        await t.asentar();
        expect(t.terminaciones, 1);
      },
    );

    test('el tope por defecto es de dos trozos de menos de 400 caracteres', () {
      expect(LectorKokoro.maxTrozosPorDefecto, 2);
    });
  });

  group('cancelación', () {
    test(
      'detener corta el audio, avisa una vez y el trozo en vuelo no suena',
      () async {
        final t = _Banco(maxTrozos: 3);
        final tardio = Completer<Uint8List?>();
        t.manejar = (texto, i) =>
            i == 1 ? tardio.future : Future.value(_audioDe(texto));

        await t.leer('$_a $_b $_c');
        await t.asentar();
        expect(t.eventos, contains('play:$_a'));

        await t.lector.detener();
        expect(t.reproductor.detenciones, greaterThan(0));
        expect(t.terminaciones, 1);

        tardio.complete(_audioDe(_b));
        await t.asentar();

        expect(t.eventos.where((e) => e.startsWith('play:')), ['play:$_a']);
        expect(t.respaldo.leidos, isEmpty);
        expect(t.terminaciones, 1);
      },
    );

    test('empezar otra lectura anula la anterior sin solaparse', () async {
      final t = _Banco(maxTrozos: 3);

      await t.leer('$_a $_b $_c');
      await t.asentar();
      t.reproductor.autoTerminar = true;
      await t.leer(_d);
      await t.asentar();

      final suenan = t.eventos.where((e) => e.startsWith('play:')).toList();
      expect(suenan, ['play:$_a', 'play:$_d']);
      expect(t.reproductor.maxActivos, 1);
      // La lectura anulada no avisa: el turno nuevo ya es el dueño del estado.
      expect(t.terminaciones, 1);
    });

    test(
      'detener mientras espera la respuesta del backend no reproduce nada',
      () async {
        final t = _Banco();
        final lento = Completer<Uint8List?>();
        t.manejar = (_, _) => lento.future;

        await t.leer(_a);
        await t.asentar();
        await t.lector.detener();
        lento.complete(_audioDe(_a));
        await t.asentar();

        expect(t.reproductor.maxActivos, 0);
        expect(t.respaldo.leidos, isEmpty);
        expect(t.terminaciones, 1);
      },
    );

    test('detener durante el teléfono lo detiene y avisa una vez', () async {
      final t = _Banco()..manejar = (_, _) async => null;

      await t.leer(_a);
      await t.asentar();
      await t.lector.detener();

      expect(t.respaldo.detenciones, greaterThan(0));
      expect(t.terminaciones, 1);
    });

    test(
      'dispose corta el audio y el teléfono sin avisar a la pantalla',
      () async {
        final t = _Banco(maxTrozos: 3);

        await t.leer('$_a $_b $_c');
        await t.asentar();
        await t.lector.dispose();
        await t.asentar();

        expect(t.reproductor.detenciones, greaterThan(0));
        expect(t.eventos.where((e) => e.startsWith('play:')), ['play:$_a']);
      },
    );
  });
}
