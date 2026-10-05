import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Perfil mínimo de la cuenta que se conserva con la sesión.
class SessionProfile {
  const SessionProfile({
    this.nombreCompleto,
    this.razonSocial,
    this.tipoCuenta,
  });

  final String? nombreCompleto;
  final String? razonSocial;
  final String? tipoCuenta;

  /// Nombre a mostrar: el nombre de la persona o, si no hay, la razón social.
  String? get nombreAMostrar => nombreCompleto ?? razonSocial;
}

abstract class SessionStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> saveTokens({required String access, required String refresh});
  Future<SessionProfile> readProfile();
  Future<void> saveProfile(SessionProfile profile);

  /// Borra tokens y perfil.
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
  static const keyRazonSocial = 'razon_social';
  static const keyTipoCuenta = 'tipo_cuenta';

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
  Future<SessionProfile> readProfile() async {
    final valores = await Future.wait([
      _storage.read(key: keyNombreCompleto),
      _storage.read(key: keyRazonSocial),
      _storage.read(key: keyTipoCuenta),
    ]);
    return SessionProfile(
      nombreCompleto: valores[0],
      razonSocial: valores[1],
      tipoCuenta: valores[2],
    );
  }

  @override
  Future<void> saveProfile(SessionProfile profile) => Future.wait([
        _writeOrDelete(keyNombreCompleto, profile.nombreCompleto),
        _writeOrDelete(keyRazonSocial, profile.razonSocial),
        _writeOrDelete(keyTipoCuenta, profile.tipoCuenta),
      ]);

  Future<void> _writeOrDelete(String key, String? value) =>
      value == null || value.isEmpty
          ? _storage.delete(key: key)
          : _storage.write(key: key, value: value);

  @override
  Future<void> clear() => Future.wait([
        _storage.delete(key: keyAccessToken),
        _storage.delete(key: keyRefreshToken),
        _storage.delete(key: keyNombreCompleto),
        _storage.delete(key: keyRazonSocial),
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
