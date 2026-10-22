import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/app_config.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/auth/data/auth_repository.dart';
import 'package:vera/features/nucleo/data/idempotency_intent.dart';
import 'package:vera/features/nucleo/data/llave_bre_b.dart';

/// Marcador fijo de destino: la clave de una recarga se amarra solo al monto.
const depositoDestinoMarcador = 'deposito';

class NucleoRepository {
  /// [session] construye el ApiClient por defecto y guarda el depósito
  /// pendiente. El Bearer y el refresh los maneja el ApiClient autenticado.
  /// [recargaIntent] y [envioLlaveIntent] son instancias separadas de
  /// IdempotencyIntent, una por flujo.
  NucleoRepository({
    ApiClient? client,
    SessionStore? session,
    IdempotencyIntent? recargaIntent,
    IdempotencyIntent? envioLlaveIntent,
  })  : _client = client ??
            ApiClient(
              baseUrl: AppConfig.baseUrl,
              session: session ?? defaultSessionStore,
              onSessionExpired: expireAppSession,
            ),
        _session = session ??
            (client == null ? defaultSessionStore : client.session),
        _recargaIntent = recargaIntent ?? IdempotencyIntent(),
        _envioLlaveIntent = envioLlaveIntent ?? IdempotencyIntent();

  final ApiClient _client;
  final SessionStore? _session;
  final IdempotencyIntent _recargaIntent;
  final IdempotencyIntent _envioLlaveIntent;

  Future<DepositoConPago>? _recargando;
  Future<EnvioPorLlave>? _enviandoPorLlave;

  // ── Saldo ─────────────────────────────────────────────────────

  /// GET /v1/saldo
  /// Devuelve el saldo disponible en centavos (string a BigInt).
  Future<MontoCalculado> getSaldo() async {
    final raw = await _client.get('/v1/saldo');
    return MontoCalculado.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
  }

  /// GET /v1/kyc/estado
  /// Producto, estado de KYC y, cuando el backend los envía, los límites.
  Future<KycEstado> getKycEstado() async {
    final raw = await _client.get('/v1/kyc/estado');
    return KycEstado.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
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
  Future<DepositoConPago> crearDeposito({
    required String monto,
    required String idempotencyKey,
  }) async {
    final raw = await _client.post(
      '/v1/depositos',
      {'monto': monto, 'moneda': 'COP', 'idempotency_key': idempotencyKey},
    );
    return DepositoConPago.fromJson(raw);
  }

  /// Recarga con la clave de idempotencia de la intención vigente. Un segundo
  /// toque mientras hay uno en vuelo recibe el mismo resultado, sin otro POST.
  /// Si el depósito queda pendiente, guarda su id en la sesión.
  Future<DepositoConPago> recargar(BigInt monto) {
    final enVuelo = _recargando;
    if (enVuelo != null) return enVuelo;
    final futuro = _recargar(monto).whenComplete(() => _recargando = null);
    return _recargando = futuro;
  }

  Future<DepositoConPago> _recargar(BigInt monto) async {
    final key = _recargaIntent.keyFor(
      destino: depositoDestinoMarcador,
      monto: monto,
    );
    final DepositoConPago deposito;
    try {
      deposito = await crearDeposito(
        monto: monto.toString(),
        idempotencyKey: key,
      );
    } on Object catch (e) {
      _recargaIntent.registrarError(e);
      rethrow;
    }
    _recargaIntent.registrarExito();
    if (!deposito.estado.esTerminal) {
      await _session?.saveDepositoPendiente(deposito.id);
    }
    return deposito;
  }

  /// Id del depósito pendiente de la sesión actual, si lo hay.
  Future<String?> depositoPendienteId() async =>
      _session?.readDepositoPendiente();

  /// GET /v1/depositos/{id}
  /// En un estado terminal borra el depósito pendiente de la sesión.
  Future<Deposito> getDeposito(String id) async {
    final raw = await _client.get('/v1/depositos/$id');
    final deposito =
        Deposito.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
    if (deposito.estado.esTerminal) {
      await _session?.clearDepositoPendiente();
    }
    return deposito;
  }

  // ── Transferencias ────────────────────────────────────────────

  /// GET /v1/destinatarios?celular=
  /// [celularE164] ya normalizado. El nombre llega enmascarado desde el
  /// servidor y se muestra tal cual. 404 RecipientNotFound sube como ApiException.
  Future<Destinatario> getDestinatario(String celularE164) async {
    final raw = await _client.get(
      '/v1/destinatarios',
      queryParams: {'celular': celularE164},
    );
    return Destinatario.fromJson(raw['data'] as Map<String, dynamic>? ?? raw);
  }

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
  /// Envía por llave de Bre-B. [tipoLlave] es uno de los cinco códigos de
  /// TipoLlaveBreB (documento, celular, correo, alfanumerico, comercio), un
  /// tipo distinto responde 422.
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

  /// Envío por llave con la clave de idempotencia de la intención vigente,
  /// amarrada al tipo, la llave recortada y el monto. Lanza FormatException si
  /// la llave no tiene la forma del tipo. Un segundo toque en vuelo recibe el
  /// mismo resultado.
  Future<EnvioPorLlave> enviarPorLlave({
    required TipoLlaveBreB tipo,
    required String llave,
    required BigInt monto,
  }) async {
    final valor = normalizarLlave(tipo, llave);
    if (valor == null) {
      throw FormatException('La llave no tiene la forma del tipo', llave);
    }
    final enVuelo = _enviandoPorLlave;
    if (enVuelo != null) return enVuelo;
    final futuro = _enviarPorLlave(tipo, valor, monto)
        .whenComplete(() => _enviandoPorLlave = null);
    return await (_enviandoPorLlave = futuro);
  }

  Future<EnvioPorLlave> _enviarPorLlave(
    TipoLlaveBreB tipo,
    String valor,
    BigInt monto,
  ) async {
    final key = _envioLlaveIntent.keyFor(
      destino: '${tipo.codigo}:$valor',
      monto: monto,
    );
    try {
      final envio = await transferirInterbancaria(
        tipoLlave: tipo.codigo,
        llave: valor,
        monto: monto.toString(),
        idempotencyKey: key,
      );
      _envioLlaveIntent.registrarExito();
      return envio;
    } on Object catch (e) {
      _envioLlaveIntent.registrarError(e);
      rethrow;
    }
  }
}

const maxLongitudDestino = 320;

/// Normaliza el destino como celular E.164. Devuelve null si está vacío, no
/// tiene dígitos o excede [maxLongitudDestino].
String? normalizarDestino(String raw) {
  final texto = raw.trim();
  if (texto.isEmpty || texto.length > maxLongitudDestino) return null;
  if (!RegExp(r'\d').hasMatch(texto)) return null;
  final e164 = AuthRepository.toE164(texto);
  return e164.length > maxLongitudDestino ? null : e164;
}

// ── Modelos ───────────────────────────────────────────────────────────────────

/// Nombre visible del destinatario, ya enmascarado por el servidor.
class Destinatario {
  const Destinatario({required this.nombre});
  final String nombre;

  factory Destinatario.fromJson(Map<String, dynamic> j) {
    final nombre = j['nombre'];
    if (nombre is! String) {
      throw FormatException('Campo "nombre" ausente', nombre);
    }
    return Destinatario(nombre: nombre);
  }
}

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

/// Estado de KYC del contexto activo. Hoy el backend responde `limites` vacío
/// (auth no calcula dinero), así que el tope y el disponible del mes son
/// opcionales: los nombres `tope_mensual` y `disponible_mes` (centavos como
/// string) son los esperados cuando el backend los exponga.
class KycEstado {
  const KycEstado({
    required this.producto,
    required this.estadoKyc,
    this.topeMensual,
    this.disponibleMes,
  });

  final String producto;
  final String estadoKyc;
  final BigInt? topeMensual;
  final BigInt? disponibleMes;

  bool get esBajoMonto => producto == 'bajo_monto';
  bool get tieneLimites => topeMensual != null && disponibleMes != null;

  factory KycEstado.fromJson(Map<String, dynamic> j) {
    final limites = j['limites'];
    final mapa = limites is Map<String, dynamic> ? limites : const {};
    return KycEstado(
      producto: j['producto'] as String? ?? '',
      estadoKyc: j['estado_kyc'] as String? ?? '',
      topeMensual: _montoOpcional(mapa['tope_mensual']),
      disponibleMes: _montoOpcional(mapa['disponible_mes']),
    );
  }
}

BigInt? _montoOpcional(Object? raw) =>
    raw is String && _enteroRe.hasMatch(raw) ? BigInt.parse(raw) : null;

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
        MotivoLinea.devolucionGravamen => 'Devolución del GMF',
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

  factory LineaMovimiento.fromJson(Map<String, dynamic> j) {
    final motivo = j['motivo'];
    if (motivo is! String) {
      throw FormatException('Campo "motivo" ausente', motivo);
    }
    return LineaMovimiento(
      montoCentavos: _parseMonto(j['monto']),
      // Un motivo nuevo del backend no debe dejar en blanco todo el historial.
      motivo: MotivoLinea.fromString(motivo),
    );
  }
}

class Movimiento {
  const Movimiento({
    required this.entryId,
    required this.ocurridoEn,
    required this.registradoEn,
    required this.moneda,
    required this.lineas,
  });

  final int entryId;
  final DateTime ocurridoEn;
  final DateTime registradoEn;
  final String moneda;
  final List<LineaMovimiento> lineas;

  /// Línea principal: la primera que no sea gravamen ni devolución de gravamen.
  /// Sin líneas devuelve una línea neutra en cero con motivo desconocido.
  LineaMovimiento get lineaPrincipal {
    if (lineas.isEmpty) {
      return LineaMovimiento(
        montoCentavos: BigInt.zero,
        motivo: MotivoLinea.desconocido,
      );
    }
    return lineas.firstWhere(
      (l) =>
          l.motivo != MotivoLinea.gravamen &&
          l.motivo != MotivoLinea.devolucionGravamen,
      orElse: () => lineas.first,
    );
  }

  /// Monto neto del movimiento (suma de todas las líneas). Una transferencia
  /// compensada suma cero: no usarlo para mostrar, ver filasDe.
  BigInt get montoNeto =>
      lineas.fold(BigInt.zero, (acc, l) => acc + l.montoCentavos);

  factory Movimiento.fromJson(Map<String, dynamic> j) {
    final entryId = j['entry_id'];
    final moneda = j['moneda'];
    final lineas = j['lineas'];
    if (entryId is! int) {
      throw FormatException('Campo "entry_id" ausente', entryId);
    }
    if (moneda is! String) {
      throw FormatException('Campo "moneda" ausente', moneda);
    }
    if (lineas is! List) {
      throw FormatException('Campo "lineas" ausente', lineas);
    }
    return Movimiento(
      entryId: entryId,
      ocurridoEn: _parseFecha(j['ocurrido_en'], 'ocurrido_en'),
      registradoEn: _parseFecha(j['registrado_en'], 'registrado_en'),
      moneda: moneda,
      lineas: [
        for (final l in lineas)
          if (l is Map<String, dynamic>)
            LineaMovimiento.fromJson(l)
          else
            throw FormatException('Línea de movimiento inválida', l),
      ],
    );
  }
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
/// Los cuatro primeros son el enum del contrato, un valor nuevo del backend
/// cae en [desconocido] sin lanzar.
enum EstadoDeposito {
  pendiente,
  confirmada,
  rechazada,
  expirada,
  desconocido;

  static EstadoDeposito fromJson(Object? raw) => switch (raw) {
        'pendiente' => EstadoDeposito.pendiente,
        'confirmada' => EstadoDeposito.confirmada,
        'rechazada' => EstadoDeposito.rechazada,
        'expirada' => EstadoDeposito.expirada,
        _ => EstadoDeposito.desconocido,
      };

  /// Ya no cambiará: confirmada, rechazada o expirada.
  bool get esTerminal => switch (this) {
        EstadoDeposito.confirmada ||
        EstadoDeposito.rechazada ||
        EstadoDeposito.expirada =>
          true,
        _ => false,
      };
}

/// Esquema Deposito, la respuesta del GET /v1/depositos/{id} (sin url_pago).
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
        estado: EstadoDeposito.fromJson(j['estado']),
        creadaEn: _parseFecha(j['creada_en'], 'creada_en'),
      );
}

/// Esquema DepositoConPago, la respuesta del POST /v1/depositos: trae url_pago.
class DepositoConPago extends Deposito {
  const DepositoConPago({
    required super.id,
    required super.referencia,
    required super.montoCentavos,
    required super.moneda,
    required super.estado,
    required super.creadaEn,
    required this.urlPago,
  });

  final String urlPago;

  factory DepositoConPago.fromJson(Map<String, dynamic> j) {
    final base = Deposito.fromJson(j);
    final urlPago = j['url_pago'];
    if (urlPago is! String || urlPago.isEmpty) {
      throw FormatException('Campo "url_pago" ausente', urlPago);
    }
    return DepositoConPago(
      id: base.id,
      referencia: base.referencia,
      montoCentavos: base.montoCentavos,
      moneda: base.moneda,
      estado: base.estado,
      creadaEn: base.creadaEn,
      urlPago: urlPago,
    );
  }
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
