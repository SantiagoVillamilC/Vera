import '../../core/network/api_client.dart';

class ReceiptsService {
  const ReceiptsService(this._apiClient);
  final ApiClient _apiClient;

  // Future<Map<String, dynamic>> uploadReceipt(Map<String, dynamic> body) =>
  //     _apiClient.post('/receipts', body: body);
}
