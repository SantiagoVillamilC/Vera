import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? client,
    SessionStore? session,
    SessionNotifier? sessionNotifier,
  })  : _session = session ?? defaultSessionStore,
        // Con el cliente por defecto el repositorio notifica a la sesión global.
        _sessionNotifier =
            sessionNotifier ?? (client == null ? appSession : null),
        _client = client ??
            ApiClient(
              baseUrl: AppConfig.baseUrl,
              session: session ?? defaultSessionStore,
              onSessionExpired: expireAppSession,
            );

  final ApiClient _client;
  final SessionStore _session;
  final SessionNotifier? _sessionNotifier;

  // ── Token + session storage ────────────────────────────────────
  Future<void> saveTokens({required String access, required String refresh}) =>
      _session.saveTokens(access: access, refresh: refresh);

  Future<String?> getAccessToken() => _session.readAccess();
  Future<String?> getRefreshToken() => _session.readRefresh();

  Future<SessionProfile> getProfile() => _session.readProfile();

  /// Nombre de la persona o, si no hay, la razón social.
  Future<String?> getNombreAMostrar() async =>
      (await _session.readProfile()).nombreAMostrar;

  Future<String?> getTipoCuenta() async =>
      (await _session.readProfile()).tipoCuenta;

  Future<void> clearTokens() => _session.clear();

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
    // Orden estricto: el router construye el Home al autenticar, así que
    // el perfil ya debe estar guardado para entonces.
    await saveTokens(access: result.accessToken, refresh: result.refreshToken);
    await _session.saveProfile(SessionProfile(
      nombreCompleto: result.nombreCompleto,
      razonSocial: result.razonSocial,
      tipoCuenta: result.tipoCuenta,
    ));
    _sessionNotifier?.setAuthenticated(true);
    return result;
  }

  // ── Register ──────────────────────────────────────────────────
  /// El backend exige tratamiento_datos y whatsapp_optin aceptados, ambos con
  /// version_texto v1 (ConsentRequired en caso contrario).
  static const versionConsentimientos = 'v1';

  static List<ConsentimientoInput> _consentimientosRequeridos({
    required bool aceptaTratamientoDatos,
    required bool aceptaWhatsappOptin,
  }) {
    if (!aceptaTratamientoDatos || !aceptaWhatsappOptin) {
      throw ArgumentError(
        'El registro exige aceptar tratamiento_datos y whatsapp_optin.',
      );
    }
    return const [
      ConsentimientoInput(
        tipo: 'tratamiento_datos',
        versionTexto: versionConsentimientos,
        aceptado: true,
      ),
      ConsentimientoInput(
        tipo: 'whatsapp_optin',
        versionTexto: versionConsentimientos,
        aceptado: true,
      ),
    ];
  }

  Future<RegisterResult> registerPersona({
    required String correo,
    required String contrasena,
    required String celular,
    required String nombreCompleto,
    required String tipoDocumento,
    required String numeroDocumento,
    required bool aceptaTratamientoDatos,
    required bool aceptaWhatsappOptin,
  }) async {
    final consentimientos = _consentimientosRequeridos(
      aceptaTratamientoDatos: aceptaTratamientoDatos,
      aceptaWhatsappOptin: aceptaWhatsappOptin,
    );
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
    required bool aceptaTratamientoDatos,
    required bool aceptaWhatsappOptin,
  }) async {
    final consentimientos = _consentimientosRequeridos(
      aceptaTratamientoDatos: aceptaTratamientoDatos,
      aceptaWhatsappOptin: aceptaWhatsappOptin,
    );
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

  /// Reenvía el código sobre el mismo desafío: el challenge_id no cambia.
  /// El contrato (openapi.yaml, ResendOtpRequest) solo acepta challenge_id y el
  /// backend rechaza campos desconocidos, por eso `proposito` no se envía: es
  /// solo contexto del llamador (el servidor lo devuelve en la respuesta).
  Future<void> resendOtp({required String challengeId, String? proposito}) =>
      _client.post('/v1/auth/otp/resend', {'challenge_id': challengeId});

  // ── Session ───────────────────────────────────────────────────
  /// Cierra la sesión en el servidor (204) y SIEMPRE borra la local.
  /// Un fallo de red se ignora porque el logout local ya basta. Cualquier
  /// otro error (por ejemplo un 500) se propaga después de limpiar.
  Future<void> logout() async {
    try {
      final refresh = await getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        final access = await getAccessToken();
        await _client.post(
          '/v1/auth/logout',
          {'refresh_token': refresh},
          bearerToken: access,
          auth: access != null,
        );
      }
    } on SocketException {
      // Sin red: la sesión local se borra igual.
    } on TimeoutException {
      // Igual que sin red.
    } on http.ClientException {
      // Igual que sin red.
    } finally {
      try {
        await clearTokens();
      } finally {
        _sessionNotifier?.setAuthenticated(false);
      }
    }
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
