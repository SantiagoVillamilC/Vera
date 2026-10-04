import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.details});
  final String code;
  final String message;
  final List<Map<String, dynamic>>? details;

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  static const _timeout = Duration(seconds: 15);

  Map<String, String> _headers({String? bearerToken}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .post(uri, headers: _headers(bearerToken: bearerToken), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseMap(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?>? queryParams,
    String? bearerToken,
  }) async {
    final filtered = queryParams?.entries
        .where((e) => e.value != null)
        .fold<Map<String, String>>({}, (m, e) => m..[e.key] = e.value!);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: filtered);
    final response = await http
        .get(uri, headers: _headers(bearerToken: bearerToken))
        .timeout(_timeout);
    return _parseRaw(response);
  }

  // Devuelve el body completo (data puede ser lista o mapa)
  Map<String, dynamic> _parseRaw(http.Response response) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException(code: 'InternalError', message: 'Respuesta inválida del servidor');
    }
    final success = body['success'] as bool? ?? false;
    if (!success) {
      final error = body['error'] as Map<String, dynamic>? ?? {};
      throw ApiException(
        code: error['code'] as String? ?? 'InternalError',
        message: error['message'] as String? ?? 'Error inesperado',
        details: (error['details'] as List?)?.cast<Map<String, dynamic>>(),
      );
    }
    return body;
  }

  // Para endpoints cuyo data es un objeto
  Map<String, dynamic> _parseMap(http.Response response) {
    final raw = _parseRaw(response);
    return raw['data'] as Map<String, dynamic>? ?? {};
  }
}
