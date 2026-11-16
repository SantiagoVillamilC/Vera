import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Lo que el lector de Kokoro necesita de un reproductor. Permite probarlo sin audio real.
abstract interface class ReproductorDeAudio {
  /// Reproduce un WAV y se completa cuando termina o cuando [detener] lo corta. Lanza si el audio
  /// no se pudo reproducir.
  Future<void> reproducir(Uint8List wav);

  Future<void> detener();

  Future<void> dispose();
}

/// Reproduce el WAV desde memoria con `audioplayers`: no escribe nada en disco.
///
/// El reproductor nativo se crea al primer uso, así que construir esta clase no toca el plugin.
class ReproductorAudioplayers implements ReproductorDeAudio {
  AudioPlayer? _player;
  Completer<void>? _enCurso;
  StreamSubscription<void>? _fin;

  /// Margen sobre la duración del WAV antes de dar la reproducción por perdida.
  static const _margen = Duration(seconds: 4);

  /// PCM16 mono a 24 kHz del contrato: 48 000 bytes por segundo.
  static const _bytesPorSegundo = 48000;

  @override
  Future<void> reproducir(Uint8List wav) async {
    await detener();
    final player = _player ??= AudioPlayer();
    final completer = Completer<void>();
    _enCurso = completer;
    _fin = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await player.play(BytesSource(wav, mimeType: 'audio/wav'));
      // `play` carga la fuente y luego reanuda: un `detener` que llegó durante la carga ya
      // pasó antes del `resume`, así que el audio arrancó pese a la cancelación.
      if (!identical(_enCurso, completer)) {
        await player.stop();
        return;
      }
      final duracion = Duration(
        milliseconds: (wav.length * 1000 / _bytesPorSegundo).ceil(),
      );
      await completer.future.timeout(duracion + _margen, onTimeout: () {});
    } finally {
      await _fin?.cancel();
      _fin = null;
      if (identical(_enCurso, completer)) _enCurso = null;
    }
  }

  @override
  Future<void> detener() async {
    final pendiente = _enCurso;
    _enCurso = null;
    if (pendiente != null && !pendiente.isCompleted) pendiente.complete();
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await detener();
    await _player?.dispose();
    _player = null;
  }
}
