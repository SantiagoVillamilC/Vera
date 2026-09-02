import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage {
  const PinStorage(this._storage);
  final FlutterSecureStorage _storage;
  Future<void> save(String pin) => _storage.write(key: 'pin', value: pin);
  Future<String?> read() => _storage.read(key: 'pin');
}
