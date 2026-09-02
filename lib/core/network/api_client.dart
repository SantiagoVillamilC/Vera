import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Único punto de salida HTTP de la aplicación.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path) => _request(
        () => _dio.get<Map<String, dynamic>>(path),
      );

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      return (await request()).data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException(
        error.response?.statusMessage ?? error.message ?? 'Error de red',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
