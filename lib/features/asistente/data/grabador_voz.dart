import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

/// Graba un clip m4a (AAC) acotado a los límites del contrato de voz.
///
/// A 64 kbps, 60 s pesan ~480 KB, por debajo de los 700 KB permitidos.
class GrabadorVoz {
  final _recorder = AudioRecorder();
  Timer? _tope;
  String? _ruta;

  /// Se dispara cuando se alcanza el tope de duración y la grabación se detiene sola.
  void Function()? onTope;

  Future<bool> tienePermiso() => _recorder.hasPermission();

  Future<void> iniciar() async {
    final dir = await getTemporaryDirectory();
    _ruta = '${dir.path}/vera_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: _ruta!,
    );
    _tope = Timer(
      LimitesAudio.maxDuracion - const Duration(seconds: 1),
      () => onTope?.call(),
    );
  }

  /// Detiene y devuelve los bytes del clip, o null si no hay grabación.
  Future<Uint8List?> detener() async {
    _tope?.cancel();
    final ruta = await _recorder.stop() ?? _ruta;
    _ruta = null;
    if (ruta == null) return null;
    final f = File(ruta);
    try {
      return await f.readAsBytes();
    } finally {
      if (await f.exists()) await f.delete();
    }
  }

  /// Detiene y descarta el clip.
  Future<void> cancelar() async {
    _tope?.cancel();
    final ruta = await _recorder.stop() ?? _ruta;
    _ruta = null;
    if (ruta != null) {
      final f = File(ruta);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> dispose() async {
    _tope?.cancel();
    await _recorder.dispose();
  }
}
