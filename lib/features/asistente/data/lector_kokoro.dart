import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/asistente/data/lector_voz.dart';
import 'package:vera/features/asistente/data/reproductor_audio.dart';
import 'package:vera/features/asistente/data/troceador_texto.dart';

/// Pide el WAV de un trozo de texto. Devuelve null cuando el backend no tiene audio (degradado) y
/// lanza ante cualquier otro fallo. Es `AsistenteRepository.sintetizar`.
typedef Sintetizador = Future<Uint8List?> Function(String texto);

/// Ventana en la que no se vuelve a pedir audio al backend tras un fallo.
///
/// La cuota de voz del usuario (10 por hora por defecto) la comparte el micrófono, y cada petición
/// la gasta aunque falle o salga de la caché. Sin esta pausa, un pod apagado o una cuota agotada
/// harían esperar y gastar un intento en cada respuesta. Se comparte entre pantallas.
class PausaDeSintesis {
  PausaDeSintesis({DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  static final compartida = PausaDeSintesis();

  final DateTime Function() _ahora;
  DateTime? _hasta;

  bool get activa => _hasta != null && _ahora().isBefore(_hasta!);

  void reanudar() => _hasta = null;

  void pausar(Duration duracion) {
    final nueva = _ahora().add(duracion);
    final actual = _hasta;
    if (actual == null || nueva.isAfter(actual)) _hasta = nueva;
  }
}

/// Lee las respuestas de Vera con la voz Kokoro del backend y, si falla, con la del teléfono.
///
/// El texto se parte en trozos que caben en `/v1/vera/sintetizar`. Se piden como máximo
/// [maxTrozos] y se reproducen en orden, pidiendo el siguiente mientras suena el actual y sin
/// que dos audios se solapen. El resto del texto, y todo si el backend falla, lo lee [respaldo]
/// cuando termina el audio. Un fallo es silencioso para la persona: solo deja un registro de
/// depuración sin el texto.
class LectorKokoro implements LectorDeVoz {
  LectorKokoro({
    required this.sintetizar,
    required this.reproductor,
    required this.respaldo,
    this.maxTrozos = maxTrozosPorDefecto,
    this.maxCaracteresTrozo = maxCaracteresPorTrozo,
    PausaDeSintesis? pausa,
    void Function(String)? registrar,
  }) : pausa = pausa ?? PausaDeSintesis.compartida,
       _registrar = registrar ?? _registrarEnDepuracion;

  /// Trozos que se piden a Kokoro por respuesta. Cada petición gasta una de las 10 de voz por hora
  /// que comparte el micrófono: con 2, un turno de voz largo cuesta 3 y uno corto (hasta unos 240
  /// caracteres, lo normal con las instrucciones de brevedad) cuesta 2. Lo que sobra lo lee el teléfono.
  static const maxTrozosPorDefecto = 2;

  final Sintetizador sintetizar;
  final ReproductorDeAudio reproductor;
  final LectorDeVoz respaldo;
  final int maxTrozos;
  final int maxCaracteresTrozo;
  final PausaDeSintesis pausa;
  final void Function(String) _registrar;

  static const _pausaFallo = Duration(seconds: 45);
  static const _pausaSesion = Duration(minutes: 5);
  static const _pausaCuotaPorDefecto = Duration(seconds: 60);
  static const _pausaCuotaMaxima = Duration(hours: 1);

  _Sesion? _actual;

  static void _registrarEnDepuracion(String mensaje) {
    if (kDebugMode) debugPrint('[LectorKokoro] $mensaje');
  }

  @override
  Future<void> leer(String texto, {required void Function() alTerminar}) async {
    final anterior = _actual;
    if (anterior != null) await _cancelar(anterior, avisar: false);
    final sesion = _Sesion(alTerminar);
    _actual = sesion;
    unawaited(_ejecutar(sesion, texto));
  }

  @override
  Future<void> detener() async {
    final sesion = _actual;
    if (sesion != null) await _cancelar(sesion, avisar: true);
  }

  @override
  Future<void> dispose() async {
    final sesion = _actual;
    if (sesion != null) await _cancelar(sesion, avisar: false);
    await reproductor.dispose();
    await respaldo.dispose();
  }

  Future<void> _cancelar(_Sesion sesion, {required bool avisar}) async {
    sesion.cancelada = true;
    if (identical(_actual, sesion)) _actual = null;
    if (avisar) sesion.avisar();
    await reproductor.detener();
    if (sesion.enRespaldo) await respaldo.detener();
  }

  Future<void> _ejecutar(_Sesion sesion, String texto) async {
    try {
      final trozos = partirEnTrozos(texto, maxCaracteres: maxCaracteresTrozo);
      if (trozos.isEmpty) return _terminar(sesion);

      final enKokoro = pausa.activa ? 0 : math.min(maxTrozos, trozos.length);
      Future<Uint8List?>? siguiente = enKokoro > 0 ? _pedir(trozos[0]) : null;
      var i = 0;
      for (; i < enKokoro; i++) {
        final audio = await siguiente;
        if (sesion.cancelada) return;
        if (audio == null) break;
        siguiente = i + 1 < enKokoro ? _pedir(trozos[i + 1]) : null;
        if (!await _reproducir(audio)) break;
        if (sesion.cancelada) return;
      }

      final resto = trozos.skip(i).join(' ');
      if (resto.isEmpty) return _terminar(sesion);
      await _leerConRespaldo(sesion, resto);
    } catch (e) {
      _registrar('lectura interrumpida: ${e.runtimeType}');
      if (!sesion.cancelada) _terminar(sesion);
    }
  }

  void _terminar(_Sesion sesion) {
    if (identical(_actual, sesion)) _actual = null;
    sesion.avisar();
  }

  Future<void> _leerConRespaldo(_Sesion sesion, String texto) async {
    if (sesion.cancelada) return;
    final fin = Completer<void>();
    sesion.enRespaldo = true;
    await respaldo.leer(
      texto,
      alTerminar: () {
        if (!fin.isCompleted) fin.complete();
      },
    );
    // Cancelada mientras el respaldo se configuraba: su stop llegó antes del speak.
    if (sesion.cancelada) await respaldo.detener();
    await fin.future;
    sesion.enRespaldo = false;
    if (!sesion.cancelada) _terminar(sesion);
  }

  /// Verdadero si el audio sonó hasta el final. Falso si el reproductor falló.
  Future<bool> _reproducir(Uint8List audio) async {
    try {
      await reproductor.reproducir(audio);
      return true;
    } catch (e) {
      _registrar('reproducción fallida: ${e.runtimeType}');
      pausa.pausar(_pausaFallo);
      return false;
    }
  }

  /// Nunca lanza: cualquier fallo es un null y deja la pausa puesta.
  Future<Uint8List?> _pedir(String trozo) async {
    try {
      final audio = await sintetizar(trozo);
      if (audio == null || audio.isEmpty) {
        _registrar('sin audio del backend (degradado)');
        pausa.pausar(_pausaFallo);
        return null;
      }
      return audio;
    } on ApiException catch (e) {
      _registrar('síntesis rechazada: ${e.statusCode}');
      pausa.pausar(_pausaDe(e));
      return null;
    } catch (e) {
      _registrar('síntesis fallida: ${e.runtimeType}');
      pausa.pausar(_pausaFallo);
      return null;
    }
  }

  Duration _pausaDe(ApiException e) => switch (e.statusCode) {
    429 => _esperaDeCuota(e.headers?['retry-after']),
    401 || 403 => _pausaSesion,
    _ => _pausaFallo,
  };

  Duration _esperaDeCuota(String? retryAfter) {
    final segundos = int.tryParse(retryAfter ?? '');
    if (segundos == null || segundos < 1) return _pausaCuotaPorDefecto;
    final espera = Duration(seconds: segundos);
    return espera > _pausaCuotaMaxima ? _pausaCuotaMaxima : espera;
  }
}

/// Una lectura en curso: lo que se cancela o se avisa a la pantalla, una sola vez.
class _Sesion {
  _Sesion(this._alTerminar);

  final void Function() _alTerminar;
  bool cancelada = false;
  bool enRespaldo = false;
  bool _avisada = false;

  void avisar() {
    if (_avisada) return;
    _avisada = true;
    _alTerminar();
  }
}
