import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';

class NucleoRepository {
  /// [session] solo se usa para construir el ApiClient por defecto. El Bearer
  /// y el refresh los maneja el ApiClient autenticado.
  NucleoRepository({ApiClient? client, SessionStore? session})
      : _client = client ??
            ApiClient(
              baseUrl: AppConfig.baseUrl,
              session: session ?? defaultSessionStore,
              onSessionExpired: expireAppSession,
            );

  final ApiClient _client;

  // ── Saldo ─────────────────────────────────────────────────────

  /// GET /v1/saldo
  /// Devuelve el saldo disponible en centavos (string a BigInt).
  Future<MontoCalculado> getSaldo() async {
    final raw = await _client.get('/v1/saldo');
    return MontoCalculado.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
  }

  /// GET /v1/transferencias/maximo
  /// Monto máximo enviable sin quedar sin saldo por el GMF.
  Future<MontoCalculado> getMontoMaximo() async {
    final raw = await _client.get('/v1/transferencias/maximo');
    return MontoCalculado.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
  }

  // ── Movimientos ───────────────────────────────────────────────

  /// GET /v1/movimientos?limit=&cursor=
  /// Historial paginado del más nuevo al más viejo.
  /// [cursor] = entry_id del último movimiento recibido (para la siguiente página).
  Future<MovimientosPage> getMovimientos({int limit = 50, int? cursor}) async {
    final raw = await _client.get(
      '/v1/movimientos',
      queryParams: {
        'limit': '$limit',
        if (cursor != null) 'cursor': '$cursor',
      },
    );
    final data = (raw['data'] as List?) ?? [];
    final meta = raw['meta'] as Map<String, dynamic>? ?? {};
    return MovimientosPage(
      items: data
          .cast<Map<String, dynamic>>()
          .map(Movimiento.fromJson)
          .toList(),
      nextCursor: meta['next_cursor'] as int?,
      hasMore: meta['has_more'] as bool? ?? false,
    );
  }

  // ── Depósitos (Recargar) ──────────────────────────────────────

  /// POST /v1/depositos
  /// Crea una intención de depósito. [monto] en centavos como string.
  /// [idempotencyKey] debe ser único por intento (usar UUID v4).
  Future<Deposito> crearDeposito({
    required String monto,
    required String idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/v1/depositos',
      {'monto': monto, 'moneda': 'COP', 'idempotency_key': idempotencyKey},
    );
    return Deposito.fromJson(raw);
  }

  /// GET /v1/depositos/{id}
  Future<Deposito> getDeposito(String id) async {
    final raw = await _client.get('/v1/depositos/$id');
    return Deposito.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
  }

  // ── Transferencias ────────────────────────────────────────────

  /// POST /v1/transferencias
  /// Envía dinero a otro usuario Vera.
  /// [destino] celular u otro identificador del destinatario.
  /// [monto] en centavos como string.
  /// [idempotencyKey] debe ser único por intento (usar UUID v4).
  Future<Transferencia> transferir({
    required String destino,
    required String monto,
    required String idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/v1/transferencias',
      {
        'destino': destino,
        'monto': monto,
        'moneda': 'COP',
        'idempotency_key': idempotencyKey,
      },
    );
    return Transferencia.fromJson(raw);
  }

  /// POST /v1/transferencias/interbancarias
  /// Envía por llave (CVU, celular de otra entidad, etc.).
  Future<EnvioPorLlave> transferirInterbancaria({
    required String tipoLlave,
    required String llave,
    required String monto,
    required String idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/v1/transferencias/interbancarias',
      {
        'tipo_llave': tipoLlave,
        'llave': llave,
        'monto': monto,
        'moneda': 'COP',
        'idempotency_key': idempotencyKey,
      },
    );
    return EnvioPorLlave.fromJson(raw);
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────

final _enteroRe = RegExp(r'^-?\d+$');

/// Los montos viajan como string decimal entero. BigInt evita perder
/// precision por encima de 2^53. Un campo ausente o no numerico lanza.
BigInt _parseMonto(Object? raw, [String campo = 'monto']) {
  if (raw is! String || !_enteroRe.hasMatch(raw)) {
    throw FormatException('Campo "$campo" ausente o no numerico', raw);
  }
  return BigInt.parse(raw);
}

DateTime _parseFecha(Object? raw, String campo) {
  final parsed = raw is String ? DateTime.tryParse(raw) : null;
  if (parsed == null) {
    throw FormatException('Campo "$campo" ausente o no es una fecha', raw);
  }
  return parsed;
}

/// Saldo o monto máximo calculado por el backend.
class MontoCalculado {
  const MontoCalculado({
    required this.montoCentavos,
    required this.moneda,
    required this.calculadoEn,
  });

  /// Centavos parseados desde el string del backend (ej. "18000000").
  final BigInt montoCentavos;
  final String moneda;
  final DateTime calculadoEn;

  factory MontoCalculado.fromJson(Map<String, dynamic> j) => MontoCalculado(
        montoCentavos: _parseMonto(j['monto']),
        moneda: j['moneda'] as String? ?? 'COP',
        calculadoEn: _parseFecha(j['calculado_en'], 'calculado_en'),
      );
}

/// Motivos posibles de una línea de movimiento.
enum MotivoLinea {
  deposito,
  transferenciaRecibida,
  envio,
  gravamen,
  devolucion,
  devolucionGravamen,
  desconocido;

  static MotivoLinea fromString(String s) => switch (s) {
        'deposito' => MotivoLinea.deposito,
        'transferencia_recibida' => MotivoLinea.transferenciaRecibida,
        'envio' => MotivoLinea.envio,
        'gravamen' => MotivoLinea.gravamen,
        'devolucion' => MotivoLinea.devolucion,
        'devolucion_gravamen' => MotivoLinea.devolucionGravamen,
        _ => MotivoLinea.desconocido,
      };

  String get label => switch (this) {
        MotivoLinea.deposito => 'Depósito',
        MotivoLinea.transferenciaRecibida => 'Transferencia recibida',
        MotivoLinea.envio => 'Envío',
        MotivoLinea.gravamen => 'GMF',
        MotivoLinea.devolucion => 'Devolución',
        MotivoLinea.devolucionGravamen => 'Dev. GMF',
        MotivoLinea.desconocido => 'Movimiento',
      };

  bool get esIngreso => switch (this) {
        MotivoLinea.deposito => true,
        MotivoLinea.transferenciaRecibida => true,
        MotivoLinea.devolucion => true,
        MotivoLinea.devolucionGravamen => true,
        _ => false,
      };
}

class LineaMovimiento {
  const LineaMovimiento({required this.montoCentavos, required this.motivo});

  /// Positivo = a favor de la subcuenta, negativo = en contra.
  final BigInt montoCentavos;
  final MotivoLinea motivo;

  factory LineaMovimiento.fromJson(Map<String, dynamic> j) => LineaMovimiento(
        montoCentavos: _parseMonto(j['monto']),
        motivo: MotivoLinea.fromString(j['motivo'] as String? ?? ''),
      );
}

class Movimiento {
  const Movimiento({
    required this.entryId,
    required this.ocurridoEn,
    required this.moneda,
    required this.lineas,
  });

  final int entryId;
  final DateTime ocurridoEn;
  final String moneda;
  final List<LineaMovimiento> lineas;

  /// Línea principal: la primera que no sea gravamen ni devolución de gravamen.
  LineaMovimiento get lineaPrincipal =>
      lineas.firstWhere(
        (l) => l.motivo != MotivoLinea.gravamen && l.motivo != MotivoLinea.devolucionGravamen,
        orElse: () => lineas.first,
      );

  /// Monto neto del movimiento (suma de todas las líneas).
  BigInt get montoNeto =>
      lineas.fold(BigInt.zero, (acc, l) => acc + l.montoCentavos);

  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
        entryId: j['entry_id'] as int? ?? 0,
        ocurridoEn: _parseFecha(j['ocurrido_en'], 'ocurrido_en'),
        moneda: j['moneda'] as String? ?? 'COP',
        lineas: (j['lineas'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(LineaMovimiento.fromJson)
            .toList(),
      );
}

class MovimientosPage {
  const MovimientosPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
  final List<Movimiento> items;
  final int? nextCursor;
  final bool hasMore;
}

/// Estados posibles de un depósito.
enum EstadoDeposito { pendiente, confirmada, rechazada, expirada, desconocido }

class Deposito {
  const Deposito({
    required this.id,
    required this.referencia,
    required this.montoCentavos,
    required this.moneda,
    required this.estado,
    required this.creadaEn,
  });

  final String id;
  final String referencia;
  final BigInt montoCentavos;
  final String moneda;
  final EstadoDeposito estado;
  final DateTime creadaEn;

  factory Deposito.fromJson(Map<String, dynamic> j) => Deposito(
        id: j['id'] as String? ?? '',
        referencia: j['referencia'] as String? ?? '',
        montoCentavos: _parseMonto(j['monto']),
        moneda: j['moneda'] as String? ?? 'COP',
        estado: switch (j['estado'] as String? ?? '') {
          'pendiente' => EstadoDeposito.pendiente,
          'confirmada' => EstadoDeposito.confirmada,
          'rechazada' => EstadoDeposito.rechazada,
          'expirada' => EstadoDeposito.expirada,
          _ => EstadoDeposito.desconocido,
        },
        creadaEn: _parseFecha(j['creada_en'], 'creada_en'),
      );
}

/// Estados posibles de una transferencia o envío por llave.
enum EstadoTransferencia {
  creada, reservada, despachada, confirmada, fallida, indeterminada, compensada, desconocido
}

EstadoTransferencia _parseEstadoTransferencia(String s) => switch (s) {
      'creada' => EstadoTransferencia.creada,
      'reservada' => EstadoTransferencia.reservada,
      'despachada' => EstadoTransferencia.despachada,
      'confirmada' => EstadoTransferencia.confirmada,
      'fallida' => EstadoTransferencia.fallida,
      'indeterminada' => EstadoTransferencia.indeterminada,
      'compensada' => EstadoTransferencia.compensada,
      _ => EstadoTransferencia.desconocido,
    };

class Transferencia {
  const Transferencia({
    required this.id,
    required this.destino,
    required this.montoCentavos,
    required this.moneda,
    required this.estado,
    required this.creadaEn,
    required this.actualizadaEn,
  });

  final String id;
  final String destino;
  final BigInt montoCentavos;
  final String moneda;
  final EstadoTransferencia estado;
  final DateTime creadaEn;
  final DateTime actualizadaEn;

  factory Transferencia.fromJson(Map<String, dynamic> j) => Transferencia(
        id: j['id'] as String? ?? '',
        destino: j['destino'] as String? ?? '',
        montoCentavos: _parseMonto(j['monto']),
        moneda: j['moneda'] as String? ?? 'COP',
        estado: _parseEstadoTransferencia(j['estado'] as String? ?? ''),
        creadaEn: _parseFecha(j['creada_en'], 'creada_en'),
        actualizadaEn: _parseFecha(j['actualizada_en'], 'actualizada_en'),
      );
}

class EnvioPorLlave {
  const EnvioPorLlave({
    required this.id,
    required this.tipoLlave,
    required this.llave,
    required this.montoCentavos,
    required this.moneda,
    required this.estado,
    required this.creadaEn,
    required this.actualizadaEn,
  });

  final String id;
  final String tipoLlave;
  final String llave;
  final BigInt montoCentavos;
  final String moneda;
  final EstadoTransferencia estado;
  final DateTime creadaEn;
  final DateTime actualizadaEn;

  factory EnvioPorLlave.fromJson(Map<String, dynamic> j) => EnvioPorLlave(
        id: j['id'] as String? ?? '',
        tipoLlave: j['tipo_llave'] as String? ?? '',
        llave: j['llave'] as String? ?? '',
        montoCentavos: _parseMonto(j['monto']),
        moneda: j['moneda'] as String? ?? 'COP',
        estado: _parseEstadoTransferencia(j['estado'] as String? ?? ''),
        creadaEn: _parseFecha(j['creada_en'], 'creada_en'),
        actualizadaEn: _parseFecha(j['actualizada_en'], 'actualizada_en'),
      );
}
