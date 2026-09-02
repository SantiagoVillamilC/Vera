import '../../core/network/api_client.dart';

class TransfersService {
  const TransfersService(this._apiClient);
  final ApiClient _apiClient;

  // Future<Map<String, dynamic>> sendTransfer(Map<String, dynamic> body) =>
  //     _apiClient.post('/transactions', body: body);
}
