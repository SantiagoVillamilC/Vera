import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Cifra el refresh con AES-256-GCM. La clave solo sale de la bóveda
/// biométrica, así que el texto guardado en disco no sirve sin biometría.
class RefreshCipher {
  const RefreshCipher();

  static const _nonceLength = 12;
  static const _macLength = 16;

  static final _algorithm = AesGcm.with256bits();

  Future<String> encrypt(String plain, List<int> key) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plain),
      secretKey: SecretKey(key),
    );
    return base64Encode(box.concatenation());
  }

  /// Lanza si la clave no corresponde o el texto fue alterado.
  Future<String> decrypt(String encoded, List<int> key) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(encoded),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    final bytes = await _algorithm.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(bytes);
  }
}
