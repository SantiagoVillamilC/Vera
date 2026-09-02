import '../../core/network/api_client.dart';

class AuthService {
  const AuthService(this._apiClient);
  final ApiClient _apiClient;

  // Future<Map<String, dynamic>> login(String email, String password) =>
  //     _apiClient.post('/auth/login', body: {'email': email, 'password': password});
}
