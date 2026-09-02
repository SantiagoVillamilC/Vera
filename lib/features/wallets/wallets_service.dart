import '../../core/network/api_client.dart';

class WalletsService {
  const WalletsService(this._apiClient);
  final ApiClient _apiClient;

  // Future<Map<String, dynamic>> fetchWallets() => _apiClient.get('/wallets');
}
