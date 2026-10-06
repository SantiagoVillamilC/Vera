import 'dart:math';

/// Genera una clave de idempotencia UUID v4 usando Random.secure().
/// F0: "cada intención de pago genera una idempotency_key (UUID) que se reusa
/// en reintentos hasta terminar bien o cancelar".
String generateUuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
  final hex =
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

/// Slot de idempotencia para una intención de pago.
/// Genera la clave la primera vez que se accede y la mantiene hasta
/// que se llama [clear] (operación exitosa o cancelada por el usuario).
///
/// Uso típico en un StatefulWidget:
/// ```dart
/// final _idempotency = IdempotencySlot();
///
/// // en el confirm handler:
/// await repo.transferir(idempotencyKey: _idempotency.key, ...);
/// _idempotency.clear(); // limpiar tras éxito
/// ```
class IdempotencySlot {
  String? _key;

  /// Clave actual (genera una nueva si no existe).
  String get key => _key ??= generateUuidV4();

  /// Descarta la clave actual. La próxima llamada a [key] genera una nueva.
  void clear() => _key = null;

  /// Indica si ya hay una clave generada (operación en curso).
  bool get hasKey => _key != null;
}
