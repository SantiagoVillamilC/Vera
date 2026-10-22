import 'package:vera/core/format/fechas.dart';

/// Hacia dónde salió el dinero. El monto de la API siempre viene positivo.
enum DireccionMovimiento { entrada, salida }

/// Escalón de la cascada que asignó la categoría.
enum OrigenCategoria {
  memoria,
  contraparteInterna,
  mcc,
  catalogo,
  lexico,
  tfidf,
  llm,
  manual,
  sinCategoria,
  desconocido,
}

const _origenes = <String, OrigenCategoria>{
  'memoria': OrigenCategoria.memoria,
  'contraparte_interna': OrigenCategoria.contraparteInterna,
  'mcc': OrigenCategoria.mcc,
  'catalogo': OrigenCategoria.catalogo,
  'lexico': OrigenCategoria.lexico,
  'tfidf': OrigenCategoria.tfidf,
  'llm': OrigenCategoria.llm,
  'manual': OrigenCategoria.manual,
  'sin_categoria': OrigenCategoria.sinCategoria,
};

/// Etiqueta corta del origen, la que ve el usuario. Vacía cuando no aporta.
String etiquetaDeOrigen(OrigenCategoria origen) => switch (origen) {
  OrigenCategoria.memoria => 'Tu corrección',
  OrigenCategoria.contraparteInterna => 'Contacto',
  OrigenCategoria.mcc => 'Comercio',
  OrigenCategoria.catalogo => 'Catálogo',
  OrigenCategoria.lexico => 'Descripción',
  OrigenCategoria.tfidf => 'Clasificador',
  OrigenCategoria.llm => 'Vera',
  OrigenCategoria.manual => 'Manual',
  OrigenCategoria.sinCategoria || OrigenCategoria.desconocido => '',
};

/// Código de la categoría que representa un movimiento sin clasificar.
const codigoSinCategoria = 'sin_categoria';

/// Una fila de `GET /v1/inteligencia/movimientos`.
class MovimientoEnriquecido {
  const MovimientoEnriquecido({
    required this.transaccionId,
    required this.ocurridoEn,
    required this.moneda,
    required this.direccion,
    required this.montoCentavos,
    required this.contraparte,
    required this.contraparteResuelta,
    required this.categoria,
    required this.categoriaNombre,
    required this.origenCategoria,
    this.descripcion,
  });

  factory MovimientoEnriquecido.fromJson(Map<String, dynamic> json) {
    final crudo = json['monto_centavos']?.toString() ?? '0';
    return MovimientoEnriquecido(
      transaccionId: json['transaccion_id']?.toString() ?? '',
      ocurridoEn: DateTime.parse(json['ocurrido_en'] as String).toUtc(),
      moneda: json['moneda']?.toString() ?? 'COP',
      direccion: json['direccion'] == 'entrada'
          ? DireccionMovimiento.entrada
          : DireccionMovimiento.salida,
      montoCentavos: BigInt.parse(crudo),
      contraparte: json['contraparte']?.toString() ?? '',
      contraparteResuelta: json['contraparte_resuelta'] as bool? ?? false,
      descripcion: json['descripcion'] as String?,
      categoria: json['categoria']?.toString() ?? codigoSinCategoria,
      categoriaNombre: json['categoria_nombre']?.toString() ?? 'Sin categoría',
      origenCategoria:
          _origenes[json['origen_categoria']?.toString()] ??
          OrigenCategoria.desconocido,
    );
  }

  /// Identificador de la transacción. Sirve para el POST, nunca se dibuja.
  final String transaccionId;

  /// Instante del movimiento en UTC. Se muestra con [enLocal].
  final DateTime ocurridoEn;
  final String moneda;
  final DireccionMovimiento direccion;

  /// Monto en centavos, siempre positivo: el signo sale de [direccion].
  final BigInt montoCentavos;
  final String contraparte;
  final bool contraparteResuelta;
  final String? descripcion;
  final String categoria;
  final String categoriaNombre;
  final OrigenCategoria origenCategoria;

  bool get sinCategoria => categoria == codigoSinCategoria;

  bool get esIngreso => direccion == DireccionMovimiento.entrada;

  /// Monto con el signo de la dirección, para el formateador de pesos.
  BigInt get montoConSigno => esIngreso ? montoCentavos : -montoCentavos;

  /// Nombre visible de la fila. Nunca es un identificador de cuenta.
  String get titulo =>
      contraparte.trim().isEmpty ? 'Movimiento' : contraparte.trim();

  DateTime enLocal({Duration? offset}) => aLocal(ocurridoEn, offset: offset);
}

/// Lo que devuelve `POST /v1/inteligencia/movimientos/{id}/correcciones`.
class CorreccionAplicada {
  const CorreccionAplicada({
    required this.filasCambiadas,
    required this.movimiento,
  });

  factory CorreccionAplicada.fromJson(Map<String, dynamic> json) =>
      CorreccionAplicada(
        filasCambiadas: (json['filas_cambiadas'] as num?)?.toInt() ?? 0,
        movimiento: MovimientoEnriquecido.fromJson(
          json['movimiento'] as Map<String, dynamic>,
        ),
      );

  /// Filas recalculadas, contando una vez cada una. Un reintento idéntico da 0.
  final int filasCambiadas;
  final MovimientoEnriquecido movimiento;
}

/// Elección del usuario en la hoja de corrección.
class CorreccionElegida {
  const CorreccionElegida({this.categoria, this.nombreComercio});

  final String? categoria;
  final String? nombreComercio;

  bool get vacia =>
      (categoria == null || categoria!.isEmpty) &&
      (nombreComercio == null || nombreComercio!.trim().isEmpty);
}

/// Una categoría de `GET /v1/inteligencia/resumen`: lo gastado en el mes.
class GastoDeCategoria {
  const GastoDeCategoria({
    required this.codigo,
    required this.nombre,
    required this.totalCentavos,
  });

  factory GastoDeCategoria.fromJson(Map<String, dynamic> json) =>
      GastoDeCategoria(
        codigo: json['codigo']?.toString() ?? codigoSinCategoria,
        nombre: json['nombre']?.toString() ?? 'Sin categoría',
        totalCentavos: BigInt.parse(json['total_centavos']?.toString() ?? '0'),
      );

  final String codigo;
  final String nombre;
  final BigInt totalCentavos;
}

/// Gasto del mes por categoría, de la más grande a la más chica.
class ResumenDelMes {
  const ResumenDelMes({
    required this.mes,
    required this.totalCentavos,
    required this.categorias,
  });

  factory ResumenDelMes.fromJson(Map<String, dynamic> json) {
    final categorias = [
      for (final c in (json['categorias'] as List?) ?? const [])
        GastoDeCategoria.fromJson(c as Map<String, dynamic>),
    ]..sort((a, b) => b.totalCentavos.abs().compareTo(a.totalCentavos.abs()));
    return ResumenDelMes(
      mes: json['mes']?.toString() ?? '',
      totalCentavos: BigInt.parse(json['total_centavos']?.toString() ?? '0'),
      categorias: categorias,
    );
  }

  /// Mes calendario `YYYY-MM`.
  final String mes;
  final BigInt totalCentavos;
  final List<GastoDeCategoria> categorias;
}
