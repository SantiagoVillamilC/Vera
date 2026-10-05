import 'package:vera/core/network/session_store.dart';

/// Almacén de sesión en memoria para pruebas de widget.
class FakeSessionStore implements SessionStore {
  FakeSessionStore({
    this.access,
    this.refresh,
    this.profile = const SessionProfile(),
  });

  String? access;
  String? refresh;
  SessionProfile profile;
  int clearCalls = 0;
  String? pendingDeposit;

  @override
  Future<String?> readDepositoPendiente() async => pendingDeposit;

  @override
  Future<void> saveDepositoPendiente(String id) async => pendingDeposit = id;

  @override
  Future<void> clearDepositoPendiente() async => pendingDeposit = null;

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
  Future<SessionProfile> readProfile() async => profile;

  @override
  Future<void> saveProfile(SessionProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    pendingDeposit = null;
    access = null;
    refresh = null;
    profile = const SessionProfile();
  }
}
