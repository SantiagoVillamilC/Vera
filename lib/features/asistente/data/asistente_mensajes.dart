import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/widgets/estado_vista.dart';

const _uuid = Uuid();

/// Clave `Idempotency-Key` de un envío al asistente (UUID v4 con generador criptográfico).
/// Se reutiliza al reintentar exactamente el mismo mensaje o audio.
String nuevaClaveEnvio() =>
    _uuid.v4(config: V4Options(null, const CryptoRNG()));

/// Un fallo en el que el servidor pudo haber guardado el turno: se reintenta con la misma clave
/// y el backend devuelve la misma respuesta en vez de duplicarla.
bool esErrorReintentable(Object e) {
  if (esErrorDeRed(e)) return true;
  if (e is ApiException) {
    final s = e.statusCode ?? 0;
    return e.code == 'ConversationBusy' || s >= 500;
  }
  return false;
}

/// Un error tras el cual se ofrece reenviar el mismo mensaje: los reintentables y el 429 por cupo.
/// Con el 429 el servidor no guardó el turno, así que la misma clave no duplica nada.
bool esErrorReenviable(Object e) =>
    esErrorReintentable(e) ||
    (e is ApiException && e.code == 'TooManyRequests');

/// Mensaje en español para un error del asistente. El 429 de las cuotas del asistente trae
/// `Retry-After` con los segundos hasta poder reintentar.
String mensajeDeErrorAsistente(Object e) {
  if (e is ApiException && e.code == 'TooManyRequests') {
    final s = int.tryParse(e.headers?['retry-after'] ?? '');
    if (s != null && s > 0) {
      return 'Alcanzaste el límite de uso de Vera. Intenta de nuevo ${_espera(s)}.';
    }
  }
  return mensajeDeError(e);
}

String _espera(int s) {
  if (s < 60) return 'en $s segundos';
  if (s < 3600) return 'en ${(s / 60).ceil()} min';
  return 'en ${(s / 3600).ceil()} h';
}
