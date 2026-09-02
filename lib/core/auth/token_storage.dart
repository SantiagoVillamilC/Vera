import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  const TokenStorage(this._storage);
  final FlutterSecureStorage _storage;
  Future<void> save(String token) => _storage.write(key: 'jwt', value: token);
  Future<String?> read() => _storage.read(key: 'jwt');
  Future<void> clear() => _storage.delete(key: 'jwt');
}
