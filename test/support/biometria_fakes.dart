import 'dart:typed_data';

import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/security/biometric_key_vault.dart';

/// SessionStore en memoria: hace de disco que sobrevive a "reiniciar la app".
class MemorySessionStore implements SessionStore {
  String? access;
  String? refresh;
  SessionProfile? perfil;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<SessionProfile> readProfile() async =>
      perfil ?? const SessionProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) async => perfil = profile;

  @override
  Future<String?> readDepositoPendiente() async => null;

  @override
  Future<void> saveDepositoPendiente(String id) async {}

  @override
  Future<void> clearDepositoPendiente() async {}

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    perfil = null;
  }
}

/// Bóveda en memoria. `aprobar` simula que la biometría pasa o falla.
class FakeKeyVault implements BiometricKeyVault {
  FakeKeyVault({this.disponible = true});

  bool disponible;
  bool aprobar = true;
  Uint8List? _key;
  int pedidos = 0;

  bool get tieneClave => _key != null;

  @override
  Future<bool> isAvailable() async => disponible;

  @override
  Future<void> store(List<int> key) async {
    pedidos++;
    if (!aprobar) throw StateError('biometría cancelada');
    _key = Uint8List.fromList(key);
  }

  @override
  Future<Uint8List?> release() async {
    pedidos++;
    return aprobar ? _key : null;
  }

  @override
  Future<void> delete() async => _key = null;
}
