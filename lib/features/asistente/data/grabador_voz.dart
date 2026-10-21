import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

/// Lo que la pantalla necesita de un grabador. Permite probarla sin el micrófono real.
abstract interface class GrabadorDeVoz {
  /// Se dispara cuando se alcanza el tope de duración y la grabación se detiene sola.
  set onTope(void Function()? alcanzado);

  /// Con [pedir] falso solo consulta: no abre el diálogo del sistema.
  Future<bool> tienePermiso({bool pedir = true});

  Future<void> iniciar();

  /// Detiene y devuelve los bytes del clip, o null si no hay grabación.
  Future<Uint8List?> detener();

  /// Detiene y descarta el clip.
  Future<void> cancelar();

  Future<void> dispose();
}

/// Graba un clip m4a (AAC) acotado a los límites del contrato de voz.
///
/// A 64 kbps, 60 s pesan ~480 KB, por debajo de los 700 KB permitidos.
class GrabadorVoz implements GrabadorDeVoz {
  final _recorder = AudioRecorder();
  Timer? _tope;
  String? _ruta;

  void Function()? _onTope;

  @override
  set onTope(void Function()? alcanzado) => _onTope = alcanzado;

  @override
  Future<bool> tienePermiso({bool pedir = true}) =>
      _recorder.hasPermission(request: pedir);

  @override
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
      () => _onTope?.call(),
    );
  }

  @override
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

  @override
  Future<void> cancelar() async {
    _tope?.cancel();
    final ruta = await _recorder.stop() ?? _ruta;
    _ruta = null;
    if (ruta != null) {
      final f = File(ruta);
      if (await f.exists()) await f.delete();
    }
  }

  @override
  Future<void> dispose() async {
    _tope?.cancel();
    await _recorder.dispose();
  }
}
