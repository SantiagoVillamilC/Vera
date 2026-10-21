import 'dart:convert';
import 'dart:typed_data';

import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Límites del clip de voz fijados por el contrato (`EnviarAudioVeraRequest`).
abstract final class LimitesAudio {
  static const maxDuracion = Duration(seconds: 60);
  static const maxBytes = 700 * 1024;
  static const maxCaracteresBase64 = 960000;
  static const formato = 'm4a';
}

/// El clip supera los límites del contrato; se detecta antes de llamar al backend.
class AudioFueraDeLimiteException implements Exception {
  const AudioFueraDeLimiteException();
}

/// Cliente del asistente Vera (tag `asistente` de `api/openapi.yaml`).
///
/// Los handlers del backend responden 501 `NotImplemented` hasta que se implementen; ese caso llega
/// como [ApiException] con `code == 'NotImplemented'`.
class AsistenteRepository {
  /// El Bearer y el refresh los maneja el ApiClient autenticado.
  AsistenteRepository({ApiClient? client})
    : _client =
          client ??
          ApiClient(
            baseUrl: AppConfig.baseUrl,
            session: defaultSessionStore,
            onSessionExpired: expireAppSession,
          );

  final ApiClient _client;

  /// Las llamadas que esperan a la IA o a la transcripción tardan más que el resto.
  static const _timeoutIa = Duration(seconds: 45);

  // ── Mensajes ──────────────────────────────────────────────────

  /// POST /v1/vera/mensajes
  /// [conversacionId] null abre una conversación nueva.
  /// [idempotencyKey] (UUID, ver `nuevaClaveEnvio`) se reutiliza al reintentar el mismo texto.
  Future<RespuestaAsistente> enviarTexto({
    required String texto,
    required String idempotencyKey,
    String? conversacionId,
  }) async {
    final raw = await _client.post(
      '/v1/vera/mensajes',
      {'conversacion_id': conversacionId, 'texto': texto},
      timeout: _timeoutIa,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return RespuestaAsistente.fromJson(raw);
  }

  /// POST /v1/vera/mensajes/voz
  /// [audioM4a] son los bytes del clip; se codifican en base64 aquí.
  /// Lanza [AudioFueraDeLimiteException] si el clip no cabe en los límites del contrato.
  /// [idempotencyKey] se reutiliza solo con el mismo audio y conversación.
  Future<RespuestaAsistente> enviarVoz({
    required Uint8List audioM4a,
    required String idempotencyKey,
    String? conversacionId,
  }) async {
    if (audioM4a.isEmpty || audioM4a.length > LimitesAudio.maxBytes) {
      throw const AudioFueraDeLimiteException();
    }
    final audio = base64Encode(audioM4a);
    if (audio.length > LimitesAudio.maxCaracteresBase64) {
      throw const AudioFueraDeLimiteException();
    }
    final raw = await _client.post(
      '/v1/vera/mensajes/voz',
      {
        'conversacion_id': conversacionId,
        'audio': audio,
        'formato': LimitesAudio.formato,
      },
      timeout: _timeoutIa,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return RespuestaAsistente.fromJson(raw);
  }

  // ── Conversaciones ────────────────────────────────────────────

  /// GET /v1/vera/conversaciones?limit=&cursor=
  /// De la más reciente a la más antigua. [cursor] es el `next_cursor` opaco de la página anterior:
  /// la app no lo interpreta.
  Future<PaginaVera<ConversacionVera>> listarConversaciones({
    int limit = 50,
    String? cursor,
  }) async {
    final raw = await _client.get(
      '/v1/vera/conversaciones',
      queryParams: {'limit': '$limit', 'cursor': ?cursor},
    );
    return PaginaVera.fromEnvelope(raw, ConversacionVera.fromJson);
  }

  /// GET /v1/vera/conversaciones/{id}/mensajes?limit=&cursor=
  /// Del más nuevo al más viejo: invertir la página para pintar el chat de arriba hacia abajo.
  Future<PaginaVera<MensajeVera>> listarMensajes(
    String conversacionId, {
    int limit = 50,
    String? cursor,
  }) async {
    final raw = await _client.get(
      '/v1/vera/conversaciones/$conversacionId/mensajes',
      queryParams: {'limit': '$limit', 'cursor': ?cursor},
    );
    return PaginaVera.fromEnvelope(raw, MensajeVera.fromJson);
  }

  /// DELETE /v1/vera/conversaciones/{id}. Cancela también sus acciones pendientes.
  Future<void> borrarConversacion(String id) async =>
      _client.delete('/v1/vera/conversaciones/$id');

  /// DELETE /v1/vera/conversaciones. Borra todas y cancela sus acciones pendientes.
  Future<void> borrarConversaciones() async =>
      _client.delete('/v1/vera/conversaciones');

  // ── Consentimiento de IA ──────────────────────────────────────

  /// GET /v1/auth/consents?tipo=asistente_ia
  /// Texto y versión vigentes, y si el usuario ya autorizó esa versión. Un cambio de versión
  /// exige una nueva aceptación.
  Future<ConsentimientoAsistente> consultarConsentimiento() async {
    final raw = await _client.get(
      '/v1/auth/consents',
      queryParams: {'tipo': 'asistente_ia'},
    );
    return ConsentimientoAsistente.fromJson(
      raw['data'] as Map<String, dynamic>? ?? {},
    );
  }

  /// POST /v1/auth/consents
  /// Acepta [versionTexto], que debe ser la vigente que devolvió [consultarConsentimiento].
  Future<void> otorgarConsentimiento(String versionTexto) async {
    await _client.post('/v1/auth/consents', {
      'tipo': 'asistente_ia',
      'version_texto': versionTexto,
      'aceptado': true,
      'accion': 'otorgar',
      'metodo': 'app',
    });
  }

  // ── Acciones pendientes ───────────────────────────────────────

  /// POST /v1/vera/acciones/{id}/codigo
  /// Pide el código de confirmación; solo si la acción tiene `requiereCodigo`.
  Future<DesafioAccion> solicitarCodigo(String accionId) async {
    final raw = await _client.post(
      '/v1/vera/acciones/$accionId/codigo',
      const {},
    );
    return DesafioAccion.fromJson(raw);
  }

  /// POST /v1/vera/acciones/{id}/confirmar
  /// Si `requiereCodigo`, enviar [desafioId] (de [solicitarCodigo]) y [codigo].
  /// Un `ConsentRequired` aquí significa que el backend ya canceló la acción.
  Future<AccionResuelta> confirmarAccion(
    String accionId, {
    String? desafioId,
    String? codigo,
  }) async {
    final raw = await _client.post('/v1/vera/acciones/$accionId/confirmar', {
      'desafio_id': ?desafioId,
      'codigo': ?codigo,
    }, timeout: _timeoutIa);
    return AccionResuelta.fromJson(raw);
  }

  /// POST /v1/vera/acciones/{id}/cancelar
  Future<AccionResuelta> cancelarAccion(String accionId) async {
    final raw = await _client.post(
      '/v1/vera/acciones/$accionId/cancelar',
      const {},
    );
    return AccionResuelta.fromJson(raw);
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────

DateTime _fecha(Object? v) =>
    DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

/// Página con cursor (`meta: {limit, next_cursor, has_more}`).
class PaginaVera<T> {
  const PaginaVera({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  factory PaginaVera.fromEnvelope(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final meta = envelope['meta'] as Map<String, dynamic>? ?? {};
    return PaginaVera(
      items: ((envelope['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList(),
      nextCursor: meta['next_cursor'] as String?,
      hasMore: meta['has_more'] as bool? ?? false,
    );
  }
}

/// Texto legal vigente del asistente y si el usuario ya lo autorizó.
class ConsentimientoAsistente {
  const ConsentimientoAsistente({
    required this.versionTexto,
    required this.texto,
    required this.autorizado,
  });

  final String versionTexto;
  final String texto;
  final bool autorizado;

  ConsentimientoAsistente autorizadoAhora() => ConsentimientoAsistente(
    versionTexto: versionTexto,
    texto: texto,
    autorizado: true,
  );

  factory ConsentimientoAsistente.fromJson(Map<String, dynamic> j) =>
      ConsentimientoAsistente(
        versionTexto: j['version_texto'] as String? ?? '',
        texto: j['texto'] as String? ?? '',
        autorizado: j['autorizado'] as bool? ?? false,
      );
}

enum EstadoAccion {
  pendiente,
  confirmada,
  cancelada,
  vencida,
  fallida,
  desconocido;

  static EstadoAccion fromString(String s) => switch (s) {
    'pendiente' => EstadoAccion.pendiente,
    'confirmada' => EstadoAccion.confirmada,
    'cancelada' => EstadoAccion.cancelada,
    'vencida' => EstadoAccion.vencida,
    'fallida' => EstadoAccion.fallida,
    _ => EstadoAccion.desconocido,
  };
}

enum TipoAccion {
  transferenciaInterna,
  transferenciaLlave,
  desconocido;

  static TipoAccion fromString(String s) => switch (s) {
    'transferencia_interna' => TipoAccion.transferenciaInterna,
    'transferencia_llave' => TipoAccion.transferenciaLlave,
    _ => TipoAccion.desconocido,
  };
}

class DestinatarioAccion {
  const DestinatarioAccion({required this.nombre, this.celularParcial});

  /// Nombre, llave o entidad ya enmascarados por el backend.
  final String nombre;
  final String? celularParcial;

  factory DestinatarioAccion.fromJson(Map<String, dynamic> j) =>
      DestinatarioAccion(
        nombre: j['nombre'] as String? ?? '',
        celularParcial: j['celular_parcial'] as String?,
      );
}

/// Tarjeta de confirmación de una transferencia preparada por el asistente.
/// La UI usa estos datos y no el texto del modelo.
class AccionPendiente {
  const AccionPendiente({
    required this.id,
    required this.estado,
    required this.tipo,
    required this.montoCentavos,
    required this.moneda,
    required this.requiereCodigo,
    required this.expiraEn,
    this.destinatario,
    this.llave,
    this.tipoLlave,
  });

  final String id;
  final EstadoAccion estado;
  final TipoAccion tipo;
  final DestinatarioAccion? destinatario;
  final String? llave;
  final String? tipoLlave;
  final BigInt montoCentavos;
  final String moneda;
  final bool requiereCodigo;
  final DateTime expiraEn;

  /// Se puede confirmar o cancelar: sigue pendiente y no ha vencido.
  bool get esAccionable =>
      estado == EstadoAccion.pendiente && DateTime.now().isBefore(expiraEn);

  factory AccionPendiente.fromJson(Map<String, dynamic> j) => AccionPendiente(
    id: j['id'] as String? ?? '',
    estado: EstadoAccion.fromString(j['estado'] as String? ?? ''),
    tipo: TipoAccion.fromString(j['tipo'] as String? ?? ''),
    destinatario: j['destinatario'] is Map<String, dynamic>
        ? DestinatarioAccion.fromJson(j['destinatario'] as Map<String, dynamic>)
        : null,
    llave: j['llave'] as String?,
    tipoLlave: j['tipo_llave'] as String?,
    montoCentavos: BigInt.tryParse(j['monto'] as String? ?? '') ?? BigInt.zero,
    moneda: j['moneda'] as String? ?? 'COP',
    requiereCodigo: j['requiere_codigo'] as bool? ?? false,
    expiraEn: _fecha(j['expira_en']),
  );
}

AccionPendiente? _accionOpcional(Object? v) =>
    v is Map<String, dynamic> ? AccionPendiente.fromJson(v) : null;

/// Respuesta a un mensaje de texto o de voz (`RespuestaAsistente`).
class RespuestaAsistente {
  const RespuestaAsistente({
    required this.conversacionId,
    required this.mensajeId,
    required this.texto,
    required this.creadoEn,
    this.transcripcion,
    this.accionPendiente,
  });

  final String conversacionId;
  final String mensajeId;
  final String texto;

  /// Solo en la ruta de voz: lo que el backend entendió del audio.
  final String? transcripcion;
  final DateTime creadoEn;
  final AccionPendiente? accionPendiente;

  factory RespuestaAsistente.fromJson(Map<String, dynamic> j) =>
      RespuestaAsistente(
        conversacionId: j['conversacion_id'] as String? ?? '',
        mensajeId: j['mensaje_id'] as String? ?? '',
        texto: j['texto'] as String? ?? '',
        transcripcion: j['transcripcion'] as String?,
        creadoEn: _fecha(j['creado_en']),
        accionPendiente: _accionOpcional(j['accion_pendiente']),
      );
}

enum RolMensaje { usuario, vera }

enum CanalMensaje { texto, voz }

class MensajeVera {
  const MensajeVera({
    required this.id,
    required this.rol,
    required this.canal,
    required this.texto,
    required this.creadoEn,
    this.accionPendiente,
  });

  final String id;
  final RolMensaje rol;
  final CanalMensaje canal;
  final String texto;
  final DateTime creadoEn;
  final AccionPendiente? accionPendiente;

  factory MensajeVera.fromJson(Map<String, dynamic> j) => MensajeVera(
    id: j['id'] as String? ?? '',
    rol: j['rol'] == 'usuario' ? RolMensaje.usuario : RolMensaje.vera,
    canal: j['canal'] == 'voz' ? CanalMensaje.voz : CanalMensaje.texto,
    texto: j['texto'] as String? ?? '',
    creadoEn: _fecha(j['creado_en']),
    accionPendiente: _accionOpcional(j['accion_pendiente']),
  );
}

class ConversacionVera {
  const ConversacionVera({
    required this.id,
    required this.titulo,
    required this.ultimaActividad,
    required this.creadaEn,
  });

  final String id;
  final String titulo;
  final DateTime ultimaActividad;
  final DateTime creadaEn;

  factory ConversacionVera.fromJson(Map<String, dynamic> j) => ConversacionVera(
    id: j['id'] as String? ?? '',
    titulo: j['titulo'] as String? ?? '',
    ultimaActividad: _fecha(j['ultima_actividad']),
    creadaEn: _fecha(j['creada_en']),
  );
}

/// Desafío del código de confirmación (`Desafio`, propósito `confirmacion_transferencia`).
class DesafioAccion {
  const DesafioAccion({
    required this.challengeId,
    required this.expiraEnSegundos,
  });

  final String challengeId;
  final int expiraEnSegundos;

  factory DesafioAccion.fromJson(Map<String, dynamic> j) => DesafioAccion(
    challengeId: j['challenge_id'] as String? ?? '',
    expiraEnSegundos: j['expira_en_segundos'] as int? ?? 0,
  );
}

/// Acción con su estado final y, si se ejecutó, la transferencia (`AccionResuelta`).
class AccionResuelta {
  const AccionResuelta({required this.accion, this.transferencia});

  final AccionPendiente accion;
  final Transferencia? transferencia;

  factory AccionResuelta.fromJson(Map<String, dynamic> j) => AccionResuelta(
    accion: AccionPendiente.fromJson(
      j['accion_pendiente'] as Map<String, dynamic>? ?? {},
    ),
    transferencia: j['transferencia'] is Map<String, dynamic>
        ? Transferencia.fromJson(j['transferencia'] as Map<String, dynamic>)
        : null,
  );
}
