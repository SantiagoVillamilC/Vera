import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';

class AuthRepository {
  AuthRepository()
      : _client = ApiClient(baseUrl: AppConfig.baseUrl),
        _storage = const FlutterSecureStorage();

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyNombreCompleto = 'nombre_completo';
  static const _keyTipoCuenta = 'tipo_cuenta';

  // ── Token + session storage ────────────────────────────────────
  Future<void> saveTokens({required String access, required String refresh}) =>
      Future.wait([
        _storage.write(key: _keyAccessToken, value: access),
        _storage.write(key: _keyRefreshToken, value: refresh),
      ]);

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getNombreCompleto() => _storage.read(key: _keyNombreCompleto);
  Future<String?> getTipoCuenta() => _storage.read(key: _keyTipoCuenta);

  Future<void> clearTokens() => Future.wait([
        _storage.delete(key: _keyAccessToken),
        _storage.delete(key: _keyRefreshToken),
        _storage.delete(key: _keyNombreCompleto),
        _storage.delete(key: _keyTipoCuenta),
      ]);

  // ── Helpers ───────────────────────────────────────────────────
  static String toE164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('57') && digits.length == 12) return '+$digits';
    if (digits.length == 10) return '+57$digits';
    return '+$digits';
  }

  // ── Login ─────────────────────────────────────────────────────
  Future<LoginResult> login({
    required String celular,
    required String contrasena,
  }) async {
    final data = await _client.post('/v1/auth/login', {
      'celular': toE164(celular),
      'contrasena': contrasena,
    });
    final result = LoginResult.fromJson(data);
    await saveTokens(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  // ── Register ──────────────────────────────────────────────────
  Future<RegisterResult> registerPersona({
    required String correo,
    required String contrasena,
    required String celular,
    required String nombreCompleto,
    required String tipoDocumento,
    required String numeroDocumento,
    required List<ConsentimientoInput> consentimientos,
  }) async {
    final data = await _client.post('/v1/auth/register', {
      'tipo_cuenta': 'persona',
      'correo': correo,
      'contrasena': contrasena,
      'celular': toE164(celular),
      'nombre_completo': nombreCompleto,
      'tipo_documento': tipoDocumento,
      'numero_documento': numeroDocumento,
      'consentimientos': consentimientos.map((c) => c.toJson()).toList(),
    });
    return RegisterResult.fromJson(data);
  }

  Future<RegisterResult> registerEmpresa({
    required String razonSocial,
    required String nit,
    required String correo,
    required String contrasena,
    required String celular,
    required String repNombre,
    required String repTipoDoc,
    required String repNumDoc,
    required List<ConsentimientoInput> consentimientos,
  }) async {
    final data = await _client.post('/v1/auth/register', {
      'tipo_cuenta': 'empresa',
      'razon_social': razonSocial,
      'nit': nit,
      'correo': correo,
      'contrasena': contrasena,
      'celular': toE164(celular),
      'representante_legal': {
        'nombre_completo': repNombre,
        'tipo_documento': repTipoDoc,
        'numero_documento': repNumDoc,
      },
      'consentimientos': consentimientos.map((c) => c.toJson()).toList(),
    });
    return RegisterResult.fromJson(data);
  }

  Future<VerifyPhoneResult> verifyPhone({
    required String celular,
    required String codigo,
  }) async {
    final data = await _client.post('/v1/auth/register/verify-phone', {
      'celular': toE164(celular),
      'codigo': codigo,
    });
    return VerifyPhoneResult.fromJson(data);
  }

  Future<void> resendOtp({required String challengeId}) =>
      _client.post('/v1/auth/otp/resend', {'challenge_id': challengeId});

  // ── Session ───────────────────────────────────────────────────
  Future<void> logout() async {
    final refresh = await getRefreshToken();
    if (refresh != null) {
      try {
        await _client.post('/v1/auth/logout', {'refresh_token': refresh});
      } catch (_) {}
    }
    await clearTokens();
  }

  // ── Recovery ──────────────────────────────────────────────────
  Future<String> recoveryRequest({required String correo}) async {
    final data = await _client.post('/v1/auth/recovery/request', {'correo': correo});
    return data['challenge_id'] as String;
  }

  Future<String> recoveryVerify({
    required String challengeId,
    required String codigo,
    required String codigoRespaldo,
  }) async {
    final data = await _client.post('/v1/auth/recovery/verify', {
      'challenge_id': challengeId,
      'codigo': codigo,
      'segundo_metodo': {'tipo': 'codigo_respaldo', 'codigo': codigoRespaldo},
    });
    return data['reset_token'] as String;
  }

  Future<void> recoveryReset({
    required String resetToken,
    required String nuevaContrasena,
  }) =>
      _client.post('/v1/auth/recovery/reset', {
        'reset_token': resetToken,
        'nueva_contrasena': nuevaContrasena,
      });
}

// ── Models ────────────────────────────────────────────────────────

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.usuarioId,
    required this.tipoCuenta,
    this.nombreCompleto,
    this.razonSocial,
  });

  final String accessToken;
  final String refreshToken;
  final String usuarioId;
  final String tipoCuenta;
  final String? nombreCompleto;
  final String? razonSocial;

  factory LoginResult.fromJson(Map<String, dynamic> j) {
    final usuario = j['usuario'] as Map<String, dynamic>? ?? {};
    return LoginResult(
      accessToken: j['access_token'] as String,
      refreshToken: j['refresh_token'] as String,
      usuarioId: usuario['id'] as String? ?? '',
      tipoCuenta: usuario['tipo_cuenta'] as String? ?? 'persona',
      nombreCompleto: usuario['nombre_completo'] as String?,
      razonSocial: usuario['razon_social'] as String?,
    );
  }
}

class RegisterResult {
  const RegisterResult({
    required this.id,
    required this.challengeId,
    required this.celular,
  });

  final String id;
  final String challengeId;
  final String celular;

  factory RegisterResult.fromJson(Map<String, dynamic> j) {
    final desafio = j['desafio'] as Map<String, dynamic>? ?? {};
    return RegisterResult(
      id: j['id'] as String? ?? '',
      challengeId: desafio['challenge_id'] as String? ?? '',
      celular: j['celular'] as String? ?? '',
    );
  }
}

class VerifyPhoneResult {
  const VerifyPhoneResult({
    required this.id,
    required this.celular,
    required this.estado,
    required this.codigosRespaldo,
  });

  final String id;
  final String celular;
  final String estado;
  final List<String> codigosRespaldo;

  factory VerifyPhoneResult.fromJson(Map<String, dynamic> j) => VerifyPhoneResult(
        id: j['id'] as String? ?? '',
        celular: j['celular'] as String? ?? '',
        estado: j['estado'] as String? ?? '',
        codigosRespaldo: (j['codigos_respaldo'] as List?)?.cast<String>() ?? [],
      );
}

class ConsentimientoInput {
  const ConsentimientoInput({
    required this.tipo,
    required this.versionTexto,
    required this.aceptado,
  });

  final String tipo;
  final String versionTexto;
  final bool aceptado;

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'version_texto': versionTexto,
        'aceptado': aceptado,
      };
}
