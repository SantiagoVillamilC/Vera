import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lee en voz alta las respuestas de Vera con la voz en español del dispositivo.
abstract interface class LectorDeVoz {
  /// Empieza a leer [texto]. [alTerminar] se llama cuando la lectura acaba, se detiene o falla.
  Future<void> leer(String texto, {required void Function() alTerminar});

  Future<void> detener();

  Future<void> dispose();
}

/// Lectura con `flutter_tts`: la voz es la del sistema, sin costo de proveedor.
class LectorFlutterTts implements LectorDeVoz {
  LectorFlutterTts([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  void Function()? _alTerminar;
  bool _configurado = false;

  static const _idiomas = ['es-CO', 'es-MX', 'es-US', 'es-ES'];

  Future<void> _configurar() async {
    if (_configurado) return;
    _configurado = true;
    for (final idioma in _idiomas) {
      final disponible = await _tts.isLanguageAvailable(idioma);
      if (disponible == true || disponible == 1) {
        await _tts.setLanguage(idioma);
        break;
      }
    }
    void terminar() {
      final fin = _alTerminar;
      _alTerminar = null;
      fin?.call();
    }

    _tts.setCompletionHandler(terminar);
    _tts.setCancelHandler(terminar);
    _tts.setErrorHandler((_) => terminar());
  }

  @override
  Future<void> leer(String texto, {required void Function() alTerminar}) async {
    await _configurar();
    _alTerminar = alTerminar;
    await _tts.speak(texto);
  }

  @override
  Future<void> detener() async {
    await _tts.stop();
    final fin = _alTerminar;
    _alTerminar = null;
    fin?.call();
  }

  @override
  Future<void> dispose() => _tts.stop();
}

/// Preferencia de lectura en voz alta, guardada en el dispositivo.
abstract interface class PreferenciaLectura {
  Future<bool> activada();

  Future<void> guardar(bool activada);
}

class PreferenciaLecturaSegura implements PreferenciaLectura {
  const PreferenciaLecturaSegura([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  static const clave = 'asistente_leer_en_voz_alta';

  /// Apagada hasta que la persona la activa: que el teléfono hable solo sorprende.
  @override
  Future<bool> activada() async => await _storage.read(key: clave) == 'true';

  @override
  Future<void> guardar(bool activada) =>
      _storage.write(key: clave, value: activada ? 'true' : 'false');
}
