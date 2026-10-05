import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> saveTokens({required String access, required String refresh});
  Future<void> clear();
}

class FlutterSecureStorageSessionStore implements SessionStore {
  const FlutterSecureStorageSessionStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  static const keyAccessToken = 'access_token';
  static const keyRefreshToken = 'refresh_token';
  static const keyNombreCompleto = 'nombre_completo';
  static const keyTipoCuenta = 'tipo_cuenta';

  Future<String?> readNombreCompleto() =>
      _storage.read(key: keyNombreCompleto);

  Future<String?> readTipoCuenta() => _storage.read(key: keyTipoCuenta);

  @override
  Future<String?> readAccess() => _storage.read(key: keyAccessToken);

  @override
  Future<String?> readRefresh() => _storage.read(key: keyRefreshToken);

  @override
  Future<void> saveTokens({required String access, required String refresh}) =>
      Future.wait([
        _storage.write(key: keyAccessToken, value: access),
        _storage.write(key: keyRefreshToken, value: refresh),
      ]);

  @override
  Future<void> clear() => Future.wait([
        _storage.delete(key: keyAccessToken),
        _storage.delete(key: keyRefreshToken),
        _storage.delete(key: keyNombreCompleto),
        _storage.delete(key: keyTipoCuenta),
      ]);
}

/// Instancia por defecto compartida por los repositorios.
const SessionStore defaultSessionStore = FlutterSecureStorageSessionStore();

/// Sesion global de la app: la comparten el router y los repositorios por defecto.
final SessionNotifier appSession = SessionNotifier();

/// Callback de los ApiClient por defecto cuando la sesion expira.
void expireAppSession() => appSession.setAuthenticated(false);

/// Estado de sesion observable para el router.
class SessionNotifier extends ChangeNotifier {
  bool _authenticated = false;

  bool get authenticated => _authenticated;

  Future<void> load(SessionStore store) async {
    final access = await store.readAccess();
    setAuthenticated(access != null && access.isNotEmpty);
  }

  void setAuthenticated(bool value) {
    if (_authenticated == value) return;
    _authenticated = value;
    notifyListeners();
  }
}
