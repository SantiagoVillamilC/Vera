import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.details});
  final String code;
  final String message;
  final List<Map<String, dynamic>>? details;

  @override
  String toString() => 'ApiException($code): $message';
}

class NoNetworkException implements Exception {
  const NoNetworkException();
}

// Mensajes de error en español por código del backend (F0).
const _errorMessages = {
  'SaldoInsuficiente': 'Saldo insuficiente para realizar esta operación.',
  'MontoInvalido': 'El monto ingresado no es válido.',
  'DestinoNoEncontrado': 'El destinatario no fue encontrado en Vera.',
  'IdempotencyConflict': 'Esta operación ya fue procesada anteriormente.',
  'LimiteKYC': 'Esta operación supera el límite de tu cuenta.',
  'RielNoDisponible': 'El servicio de pagos no está disponible. Intenta más tarde.',
  'CustodioNoDisponible': 'El servicio de custodia no está disponible. Intenta más tarde.',
  'Unauthorized': 'Sesión expirada. Inicia sesión nuevamente.',
  'TokenInvalido': 'Sesión expirada. Inicia sesión nuevamente.',
  'TokenExpirado': 'Sesión expirada. Inicia sesión nuevamente.',
  'RefreshInvalido': 'Sesión expirada. Inicia sesión nuevamente.',
  'UsuarioNoEncontrado': 'Usuario no encontrado.',
  'CuentaBloqueada': 'Tu cuenta está bloqueada. Contacta soporte.',
  'OperacionNoPermitida': 'Esta operación no está permitida en tu cuenta.',
  'InternalError': 'Error inesperado del servidor. Intenta más tarde.',
};

String _translateError(String code, String backendMessage) =>
    _errorMessages[code] ?? backendMessage;

class ApiClient {
  ApiClient({
    required this.baseUrl,
    /// Llamado cuando hay un 401. Debe intentar refrescar el token y
    /// devolver el nuevo access_token, o null si el refresh falló.
    this.tokenRefresher,
    /// Llamado cuando el refresh también devuelve 401 (sesión terminada).
    this.onSessionExpired,
  });

  final String baseUrl;
  final Future<String?> Function()? tokenRefresher;
  final void Function()? onSessionExpired;

  static const _timeout = Duration(seconds: 15);

  Map<String, String> _headers({String? bearerToken}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      };

  // ── POST ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;
    try {
      response = await http
          .post(uri, headers: _headers(bearerToken: bearerToken), body: jsonEncode(body))
          .timeout(_timeout);
    } on SocketException {
      throw const NoNetworkException();
    } on TimeoutException {
      throw const NoNetworkException();
    }

    if (response.statusCode == 401 && bearerToken != null) {
      final newToken = await _tryRefresh();
      if (newToken == null) return {}; // onSessionExpired ya fue llamado
      final retry = await http
          .post(uri, headers: _headers(bearerToken: newToken), body: jsonEncode(body))
          .timeout(_timeout);
      return _parseMap(retry, isRetry: true);
    }
    return _parseMap(response);
  }

  // ── GET ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?>? queryParams,
    String? bearerToken,
  }) async {
    final filtered = queryParams?.entries
        .where((e) => e.value != null)
        .fold<Map<String, String>>({}, (m, e) => m..[e.key] = e.value!);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: filtered);

    http.Response response;
    try {
      response = await http
          .get(uri, headers: _headers(bearerToken: bearerToken))
          .timeout(_timeout);
    } on SocketException {
      throw const NoNetworkException();
    } on TimeoutException {
      throw const NoNetworkException();
    }

    if (response.statusCode == 401 && bearerToken != null) {
      final newToken = await _tryRefresh();
      if (newToken == null) return {};
      final retry = await http
          .get(uri, headers: _headers(bearerToken: newToken))
          .timeout(_timeout);
      return _parseRaw(retry, isRetry: true);
    }
    return _parseRaw(response);
  }

  // ── Token refresh ─────────────────────────────────────────────

  Future<String?> _tryRefresh() async {
    if (tokenRefresher == null) {
      onSessionExpired?.call();
      return null;
    }
    try {
      final newToken = await tokenRefresher!();
      if (newToken == null) {
        onSessionExpired?.call();
        return null;
      }
      return newToken;
    } catch (_) {
      onSessionExpired?.call();
      return null;
    }
  }

  // ── Parsers ───────────────────────────────────────────────────

  Map<String, dynamic> _parseRaw(http.Response response, {bool isRetry = false}) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException(code: 'InternalError', message: 'Respuesta inválida del servidor.');
    }
    final success = body['success'] as bool? ?? false;
    if (!success) {
      final error = body['error'] as Map<String, dynamic>? ?? {};
      final code = error['code'] as String? ?? 'InternalError';
      final rawMessage = error['message'] as String? ?? 'Error inesperado';
      if (response.statusCode == 401 && isRetry) {
        onSessionExpired?.call();
        throw ApiException(
          code: code,
          message: _translateError(code, rawMessage),
          details: (error['details'] as List?)?.cast<Map<String, dynamic>>(),
        );
      }
      throw ApiException(
        code: code,
        message: _translateError(code, rawMessage),
        details: (error['details'] as List?)?.cast<Map<String, dynamic>>(),
      );
    }
    return body;
  }

  Map<String, dynamic> _parseMap(http.Response response, {bool isRetry = false}) {
    final raw = _parseRaw(response, isRetry: isRetry);
    return raw['data'] as Map<String, dynamic>? ?? {};
  }
}
