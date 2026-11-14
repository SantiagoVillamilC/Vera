import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Lectura de la vista enriquecida y corrección de categorías.
/// El Bearer y el refresh los maneja el [ApiClient] autenticado.
class InteligenciaRepository {
  InteligenciaRepository({ApiClient? client, SessionStore? session})
    : _client =
          client ??
          ApiClient(
            baseUrl: AppConfig.baseUrl,
            session: session ?? defaultSessionStore,
            onSessionExpired: expireAppSession,
          );

  final ApiClient _client;

  /// GET /v1/inteligencia/movimientos?limit=
  /// Una sola página: para la demo basta con las 50 más recientes.
  Future<List<MovimientoEnriquecido>> listarMovimientos({
    int limit = 50,
  }) async {
    final raw = await _client.get(
      '/v1/inteligencia/movimientos',
      queryParams: {'limit': '$limit'},
    );
    final data = (raw['data'] as List?) ?? const [];
    return [
      for (final fila in data)
        MovimientoEnriquecido.fromJson(fila as Map<String, dynamic>),
    ];
  }

  /// GET /v1/inteligencia/resumen
  /// Gasto de un mes (`YYYY-MM`, America/Bogota) por categoría. Sin [mes], el mes en curso.
  Future<ResumenDelMes> resumen({String? mes}) async {
    final raw = await _client.get(
      '/v1/inteligencia/resumen',
      queryParams: {'mes': ?mes},
    );
    return ResumenDelMes.fromJson(
      (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// GET /v1/inteligencia/avisos
  ///
  /// Sin [mes] devuelve la bandeja del mes en curso según el reloj del
  /// servidor. Con [mes] (`YYYY-MM`) devuelve los vigentes de ese mes, sin
  /// paginar: ese parámetro no se combina con `limite`, `cursor` ni `estado`,
  /// que responden 400.
  Future<List<Aviso>> listarAvisos({String? mes}) async {
    final raw = await _client.get(
      '/v1/inteligencia/avisos',
      queryParams: {'mes': ?mes},
    );
    final data = (raw['data'] as List?) ?? const [];
    return [
      for (final fila in data) Aviso.fromJson(fila as Map<String, dynamic>),
    ];
  }

  /// GET /v1/inteligencia/avisos/{id}
  ///
  /// Devuelve el aviso esté descartado o no: la respuesta no trae marca de
  /// estado. La bandeja pasa el objeto que ya tiene, así que esto solo hace
  /// falta al entrar al detalle por enlace directo.
  Future<Aviso> obtenerAviso(String id) async {
    final raw = await _client.get('/v1/inteligencia/avisos/$id');
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Aviso.fromJson(data);
  }

  /// POST /v1/inteligencia/avisos/{id}/descartar
  ///
  /// Idempotente y sin cuerpo: repetirlo devuelve el primer instante. No borra
  /// el aviso, libera cupo del periodo y el aviso no se vuelve a emitir, así
  /// que la persistencia la garantiza el servidor y la app no guarda nada.
  /// Responde 409 `DescarteAnteriorAlAlta` si el aviso se creó después del
  /// reloj del servidor.
  Future<AvisoDescartado> descartarAviso(String id) async {
    final raw = await _client.post(
      '/v1/inteligencia/avisos/$id/descartar',
      const {},
    );
    final data = (raw['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AvisoDescartado.fromJson(data);
  }

  /// POST /v1/inteligencia/movimientos/{transaccion_id}/correcciones
  /// Reaplica la memoria privada: los movimientos del mismo comercio cambian
  /// también, y [CorreccionAplicada.filasCambiadas] dice cuántos fueron.
  Future<CorreccionAplicada> corregir({
    required String transaccionId,
    String? categoria,
    String? nombreComercio,
  }) async {
    final nombre = nombreComercio?.trim();
    final cuerpo = <String, dynamic>{
      if (categoria != null && categoria.isNotEmpty) 'categoria': categoria,
      if (nombre != null && nombre.isNotEmpty) 'nombre_comercio': nombre,
    };
    final raw = await _client.post(
      '/v1/inteligencia/movimientos/$transaccionId/correcciones',
      cuerpo,
    );
    final data = raw['data'] as Map<String, dynamic>? ?? raw;
    return CorreccionAplicada.fromJson(data);
  }
}
