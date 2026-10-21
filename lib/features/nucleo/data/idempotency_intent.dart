import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/widgets/estado_vista.dart';

/// Clave de idempotencia de la intención de envío actual.
///
/// La clave solo cambia cuando llega una respuesta definitiva del servidor o
/// cuando cambian destino o monto. Cerrar la hoja de revisión no la toca: si
/// el resultado anterior fue desconocido, reintentar con la misma clave evita
/// duplicar el envío.
class IdempotencyIntent {
  /// [generador] permite inyectar claves deterministas en pruebas. Por defecto
  /// usa UUID v4 de la librería con el generador criptográfico explícito.
  IdempotencyIntent({String Function()? generador})
      : _generador = generador ?? _uuidSeguro;

  static const _uuid = Uuid();

  static String _uuidSeguro() =>
      _uuid.v4(config: V4Options(null, const CryptoRNG()));

  final String Function() _generador;

  String? _key;
  String? _destino;
  BigInt? _monto;

  /// Devuelve la clave vigente para [destino] y [monto]. Si cambió alguno de
  /// los dos (o no hay clave), genera una nueva.
  String keyFor({required String destino, required BigInt monto}) {
    final vigente = _key;
    if (vigente != null && _destino == destino && _monto == monto) {
      return vigente;
    }
    _destino = destino;
    _monto = monto;
    return _key = _generador();
  }

  /// Cualquier 2xx, sea cual sea el estado del envío.
  void registrarExito() => _renovar();

  /// Resultado desconocido o reintentable conserva la clave. Cualquier otra
  /// respuesta del servidor la renueva.
  void registrarError(Object error) {
    if (!_esReintentable(error)) _renovar();
  }

  void _renovar() {
    _key = null;
    _destino = null;
    _monto = null;
  }

  static bool _esReintentable(Object error) {
    if (esErrorDeRed(error)) return true;
    if (error is ApiException) {
      final s = error.statusCode;
      // Sin código de estado no sabemos qué pasó: se conserva la clave.
      // Un código menor a 400 (por ejemplo un 201 con cuerpo ilegible) significa
      // que la transferencia puede existir y el cliente no leyó su estado.
      return s == null || s < 400 || s >= 500 || s == 429;
    }
    // Cualquier otro fallo (por ejemplo una respuesta 2xx ilegible) deja el
    // resultado sin confirmar.
    return true;
  }
}
