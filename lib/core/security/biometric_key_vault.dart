import 'dart:convert';
import 'dart:typed_data';

import 'package:biometric_storage/biometric_storage.dart';

/// Bóveda de la clave que protege el refresh. Guardar y liberar exigen
/// biometría del dispositivo (Keystore en Android, Keychain en iOS).
abstract class BiometricKeyVault {
  /// Falso si el dispositivo no tiene biometría disponible y enrolada.
  Future<bool> isAvailable();

  /// Guarda la clave. Pide biometría y lanza si el usuario la cancela o falla.
  Future<void> store(List<int> key);

  /// Pide biometría y devuelve la clave, o null si se canceló, falló o la
  /// clave ya no es válida (por ejemplo, cambió el enrolamiento).
  Future<Uint8List?> release();

  Future<void> delete();
}

class BiometricStorageKeyVault implements BiometricKeyVault {
  BiometricStorageKeyVault([BiometricStorage? storage])
    : _storage = storage ?? BiometricStorage();

  final BiometricStorage _storage;

  static const _name = 'vera_refresh_key';
  static const _prompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: 'Desbloquea Vera',
      negativeButton: 'Cancelar',
    ),
    iosPromptInfo: IosPromptInfo(
      saveTitle: 'Activa el desbloqueo biométrico',
      accessTitle: 'Desbloquea Vera',
    ),
  );

  Future<BiometricStorageFile> _file() => _storage.getStorage(
    _name,
    options: StorageFileInitOptions(),
    promptInfo: _prompt,
  );

  @override
  Future<bool> isAvailable() async =>
      await _storage.canAuthenticate() == CanAuthenticateResponse.success;

  @override
  Future<void> store(List<int> key) async =>
      (await _file()).write(base64Encode(key));

  @override
  Future<Uint8List?> release() async {
    try {
      final encoded = await (await _file()).read();
      if (encoded == null) return null;
      return base64Decode(encoded);
    } on AuthException {
      return null;
    } on BiometricStorageException {
      return null;
    }
  }

  @override
  Future<void> delete() async => (await _file()).delete();
}
