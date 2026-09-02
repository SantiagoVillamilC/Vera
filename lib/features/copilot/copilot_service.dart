import '../../core/network/api_client.dart';

class CopilotService {
  const CopilotService(this._apiClient);
  final ApiClient _apiClient;

  // Future<Map<String, dynamic>> sendMessage(String message) =>
  //     _apiClient.post('/copilot', body: {'message': message});
}
