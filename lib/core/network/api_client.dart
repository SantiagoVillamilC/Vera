import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vera/core/network/session_store.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
    this.headers,
  });
  final String code;
  final String message;
  final List<Map<String, dynamic>>? details;
  final int? statusCode;

  /// Cabeceras de la respuesta de error, con nombres en minúscula (Retry-After, X-Conversacion-Id).
  final Map<String, String>? headers;

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client Function()? clientFactory,
    this.session,
    this.onSessionExpired,
    Duration? shortTimeout,
    Duration? moneyTimeout,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _shortTimeout = shortTimeout ?? defaultShortTimeout,
       _moneyTimeout = moneyTimeout ?? defaultMoneyTimeout;

  final String baseUrl;
  final http.Client Function() _clientFactory;
  final SessionStore? session;
  final void Function()? onSessionExpired;
  final Duration _shortTimeout;
  final Duration _moneyTimeout;

  static const defaultShortTimeout = Duration(seconds: 20);
  // El servidor corta las rutas de dinero a los 60 s, el cliente espera más.
  static const defaultMoneyTimeout = Duration(seconds: 70);

  static const _moneyPaths = {
    '/v1/transferencias',
    '/v1/transferencias/interbancarias',
    '/v1/depositos',
  };

  static const _refreshPath = '/v1/auth/refresh';

  Future<bool>? _refreshing;

  static bool isMoneyPath(String method, String path) =>
      method == 'POST' && _moneyPaths.contains(path);

  /// Rutas que nunca llevan Bearer automático ni disparan refresh.
  static bool isPublicPath(String path) =>
      path == '/v1/auth/login' ||
      path == _refreshPath ||
      path.startsWith('/v1/auth/register') ||
      path.startsWith('/v1/auth/recovery/') ||
      path.startsWith('/v1/auth/otp/');

  /// Una llamada es autenticada si `auth` es true, si se pasa `bearerToken`
  /// o, sin ninguno de los dos, si hay SessionStore y la ruta no es pública.
  /// `auth: false` fuerza una llamada sin Bearer.
  bool _isAuthenticated(String path, String? bearerToken, bool? auth) {
    if (auth != null) return auth;
    if (bearerToken != null) return true;
    return session != null && !isPublicPath(path);
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
    bool? auth,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    final response = await _request(
      'POST',
      Uri.parse('$baseUrl$path'),
      path: path,
      body: jsonEncode(body),
      bearerToken: bearerToken,
      auth: auth,
      timeout: timeout,
      extraHeaders: headers,
    );
    return _parseMap(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?>? queryParams,
    String? bearerToken,
    bool? auth,
    Duration? timeout,
  }) async {
    final filtered = queryParams?.entries
        .where((e) => e.value != null)
        .fold<Map<String, String>>({}, (m, e) => m..[e.key] = e.value!);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: filtered);
    final response = await _request(
      'GET',
      uri,
      path: path,
      bearerToken: bearerToken,
      auth: auth,
      timeout: timeout,
    );
    return _parseRaw(response);
  }

  /// DELETE sin cuerpo. Los borrados responden 204.
  Future<void> delete(
    String path, {
    String? bearerToken,
    bool? auth,
    Duration? timeout,
  }) async {
    final response = await _request(
      'DELETE',
      Uri.parse('$baseUrl$path'),
      path: path,
      bearerToken: bearerToken,
      auth: auth,
      timeout: timeout,
    );
    _parseRaw(response);
  }

  /// POST /v1/auth/logout con Bearer y {refresh_token}, responde 204.
  /// No intenta refrescar: un 401 aquí solo significa que la sesión ya no sirve.
  Future<void> logout() async {
    final refresh = await session?.readRefresh();
    if (refresh == null) return;
    final access = await session?.readAccess();
    final response = await _request(
      'POST',
      Uri.parse('$baseUrl/v1/auth/logout'),
      path: '/v1/auth/logout',
      body: jsonEncode({'refresh_token': refresh}),
      bearerToken: access,
      auth: access != null,
      allowRefresh: false,
    );
    _parseMap(response);
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    required String path,
    String? body,
    String? bearerToken,
    bool? auth,
    Duration? timeout,
    bool allowRefresh = true,
    Map<String, String>? extraHeaders,
  }) async {
    final authenticated = _isAuthenticated(path, bearerToken, auth);
    final effectiveTimeout =
        timeout ?? (isMoneyPath(method, path) ? _moneyTimeout : _shortTimeout);

    var token = bearerToken;
    if (authenticated && token == null) token = await session?.readAccess();

    final response = await _send(
      method,
      uri,
      body: body,
      token: authenticated ? token : null,
      timeout: effectiveTimeout,
      extraHeaders: extraHeaders,
    );
    if (response.statusCode != 401 ||
        !authenticated ||
        !allowRefresh ||
        session == null ||
        isPublicPath(path)) {
      return response;
    }

    final refreshed = await _refreshOnce(sentToken: token);
    if (!refreshed) throw _toException(response);

    final newToken = await session?.readAccess();
    return _send(
      method,
      uri,
      body: body,
      token: newToken,
      timeout: effectiveTimeout,
      extraHeaders: extraHeaders,
    );
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    required String? body,
    required String? token,
    required Duration timeout,
    Map<String, String>? extraHeaders,
  }) async {
    final client = _clientFactory();
    try {
      final headers = {..._headers(token), ...?extraHeaders};
      final future = switch (method) {
        'GET' => client.get(uri, headers: headers),
        'DELETE' => client.delete(uri, headers: headers),
        _ => client.post(uri, headers: headers, body: body),
      };
      return await future.timeout(timeout);
    } finally {
      client.close();
    }
  }

  /// Single-flight: todas las 401 concurrentes esperan el mismo Future.
  Future<bool> _refreshOnce({required String? sentToken}) {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh(sentToken).whenComplete(() => _refreshing = null);
    _refreshing = future;
    return future;
  }

  Future<bool> _doRefresh(String? sentToken) async {
    final store = session!;
    try {
      final current = await store.readAccess();
      // Otra petición ya roto los tokens después de enviar esta.
      if (current != null && sentToken != null && current != sentToken) {
        return true;
      }
      final refresh = await store.readRefresh();
      if (refresh == null || refresh.isEmpty) {
        await _expire();
        return false;
      }
      final response = await _send(
        'POST',
        Uri.parse('$baseUrl$_refreshPath'),
        body: jsonEncode({'refresh_token': refresh}),
        token: null,
        timeout: _shortTimeout,
      );
      final data = _parseMap(response);
      final access = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;
      if (access == null || newRefresh == null) {
        await _expire();
        return false;
      }
      await store.saveTokens(access: access, refresh: newRefresh);
      return true;
    } on Object {
      await _expire();
      return false;
    }
  }

  Future<void> _expire() async {
    try {
      await session?.clear();
    } finally {
      onSessionExpired?.call();
    }
  }

  ApiException _toException(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return ApiException(
        code: 'InternalError',
        message: 'Respuesta inválida del servidor',
        statusCode: response.statusCode,
        headers: response.headers,
      );
    }
    final error = body['error'] as Map<String, dynamic>? ?? {};
    return ApiException(
      code: error['code'] as String? ?? 'InternalError',
      message: error['message'] as String? ?? 'Error inesperado',
      details: (error['details'] as List?)?.cast<Map<String, dynamic>>(),
      statusCode: response.statusCode,
      headers: response.headers,
    );
  }

  // Devuelve el body completo (data puede ser lista o mapa)
  Map<String, dynamic> _parseRaw(http.Response response) {
    if (response.statusCode == 204) {
      return {'success': true, 'data': <String, dynamic>{}};
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw _toException(response);
    }
    final success = body['success'] as bool? ?? false;
    if (!success) throw _toException(response);
    return body;
  }

  // Para endpoints cuyo data es un objeto
  Map<String, dynamic> _parseMap(http.Response response) {
    final raw = _parseRaw(response);
    return raw['data'] as Map<String, dynamic>? ?? {};
  }
}
