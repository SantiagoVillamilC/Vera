import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';
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
