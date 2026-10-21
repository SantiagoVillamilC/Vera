import 'dart:math';

import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/security/biometric_key_vault.dart';
import 'package:vera/core/security/refresh_cipher.dart';

/// Cerradura local sobre el refresh. Con la biometría habilitada, el refresh
/// se guarda cifrado con una clave que solo libera la bóveda biométrica
/// (Keystore/Keychain). La clave vive en memoria mientras la sesión está
/// desbloqueada, así la rotación del refresh se persiste sin pedir biometría
/// cada vez. El servidor nunca ve nada de esto.
class BiometricSessionStore implements SessionStore {
  BiometricSessionStore({
    SessionStore base = const FlutterSecureStorageSessionStore(),
    BiometricKeyVault? vault,
    RefreshCipher cipher = const RefreshCipher(),
  }) : _base = base,
       _vault = vault ?? BiometricStorageKeyVault(),
       _cipher = cipher;

  final SessionStore _base;
  final BiometricKeyVault _vault;
  final RefreshCipher _cipher;

  /// Marca de un refresh cifrado en disco.
  static const prefix = 'bio1:';

  List<int>? _key;

  Future<bool> isAvailable() async {
    try {
      return await _vault.isAvailable();
    } on Object {
      return false;
    }
  }

  /// Hay un refresh cifrado en disco, con o sin la clave en memoria.
  Future<bool> isEnrolled() async =>
      (await _base.readRefresh())?.startsWith(prefix) ?? false;

  /// Cold start: hay enrolamiento y todavía nadie liberó la clave.
  Future<bool> requiresUnlock() async => _key == null && await isEnrolled();

  /// Habilita la biometría sobre la sesión actual (desbloqueada). Devuelve
  /// false, sin cambiar nada, si no hay sesión o el usuario cancela.
  Future<bool> enable() async {
    final refresh = await _base.readRefresh();
    final access = await _base.readAccess();
    if (refresh == null || refresh.startsWith(prefix) || access == null) {
      return false;
    }
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    try {
      await _vault.store(key);
    } on Object {
      await _deleteVaultQuietly();
      return false;
    }
    try {
      await _base.saveTokens(
        access: access,
        refresh: prefix + await _cipher.encrypt(refresh, key),
      );
    } on Object {
      await _deleteVaultQuietly();
      rethrow;
    }
    _key = key;
    return true;
  }

  /// Pide biometría y deja la clave en memoria. False si se canceló o falló:
  /// en ese caso el refresh no se libera.
  Future<bool> unlock() async {
    final key = await _vault.release();
    if (key == null) return false;
    final raw = await _base.readRefresh();
    if (raw == null || !raw.startsWith(prefix)) return false;
    try {
      await _cipher.decrypt(raw.substring(prefix.length), key);
    } on Object {
      return false;
    }
    _key = key;
    return true;
  }

  /// Olvida la clave de memoria: el siguiente uso vuelve a exigir biometría.
  void lock() => _key = null;

  @override
  Future<String?> readRefresh() async {
    final raw = await _base.readRefresh();
    if (raw == null || !raw.startsWith(prefix)) return raw;
    final key = _key;
    if (key == null) return null;
    try {
      return await _cipher.decrypt(raw.substring(prefix.length), key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveTokens({required String access, required String refresh}) {
    final key = _key;
    if (key == null) return _base.saveTokens(access: access, refresh: refresh);
    return _cipher
        .encrypt(refresh, key)
        .then(
          (cifrado) =>
              _base.saveTokens(access: access, refresh: prefix + cifrado),
        );
  }

  @override
  Future<void> clear() async {
    final enrolled = await isEnrolled();
    _key = null;
    await _base.clear();
    if (enrolled) await _deleteVaultQuietly();
  }

  Future<void> _deleteVaultQuietly() async {
    try {
      await _vault.delete();
    } on Object {
      // Sin clave que borrar, el enrolamiento ya no existe.
    }
  }

  @override
  Future<String?> readAccess() => _base.readAccess();

  @override
  Future<SessionProfile> readProfile() => _base.readProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) =>
      _base.saveProfile(profile);

  @override
  Future<String?> readDepositoPendiente() => _base.readDepositoPendiente();

  @override
  Future<void> saveDepositoPendiente(String id) =>
      _base.saveDepositoPendiente(id);

  @override
  Future<void> clearDepositoPendiente() => _base.clearDepositoPendiente();
}
