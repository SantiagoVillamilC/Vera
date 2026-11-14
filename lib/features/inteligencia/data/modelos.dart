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
///
/// `sinCategoria` queda vacía a propósito: su nombre depende del escalón, así
/// que lo resuelve [senalDeCategoria]. `llm` y `manual` no se nombran porque el
/// backend dejó de emitirlos con la migración 0032; el enum los conserva solo
/// para no romperse con datos viejos.
String etiquetaDeOrigen(OrigenCategoria origen) => switch (origen) {
  OrigenCategoria.memoria => 'Tu corrección',
  OrigenCategoria.contraparteInterna => 'Cargo de la billetera',
  OrigenCategoria.mcc => 'Tipo de comercio (MCC)',
  OrigenCategoria.catalogo => 'Catálogo de marcas',
  OrigenCategoria.lexico => 'Palabras del nombre',
  OrigenCategoria.tfidf => 'Modelo de texto (TF-IDF)',
  OrigenCategoria.llm ||
  OrigenCategoria.manual ||
  OrigenCategoria.sinCategoria ||
  OrigenCategoria.desconocido => '',
};

/// Señal de la cascada que decidió la categoría de un movimiento.
///
/// [chip] es el nombre corto que se pinta y [explicacion] lo que se abre al
/// tocarlo. [esAbstencion] distingue «el modelo miró y prefirió no arriesgar»
/// de «ninguna señal aplicó»: se dibuja con estilo neutro, porque es parte del
/// diseño de la cascada y no un error.
class SenalDeCategoria {
  const SenalDeCategoria({
    required this.chip,
    required this.explicacion,
    this.esAbstencion = false,
  });

  final String chip;
  final String explicacion;
  final bool esAbstencion;
}

const _explicaciones = <OrigenCategoria, String>{
  OrigenCategoria.memoria:
      'Vera usó la categoría que tú elegiste antes para este comercio o esta '
      'persona.',
  OrigenCategoria.contraparteInterna:
      'Es una comisión o el impuesto GMF que cobra la propia plataforma, por '
      'eso va en comisiones y costos financieros.',
  OrigenCategoria.mcc:
      'El comercio informó su tipo de negocio en el pago por QR y ese código '
      'define la categoría.',
  OrigenCategoria.catalogo:
      'El comercio está en una lista de marcas conocidas que ya tiene su '
      'categoría.',
  OrigenCategoria.lexico:
      'El nombre del comercio contiene una palabra que apunta a una sola '
      'categoría.',
  OrigenCategoria.tfidf:
      'Un modelo local comparó el nombre del comercio con ejemplos y propuso '
      'esta categoría.',
};

/// La señal de un movimiento, o `null` cuando no hay chip que mostrar.
///
/// Los seis primeros escalones se deciden solo con [origen], porque el escalón
/// equivale a su orden. El escalón únicamente hace falta para separar los dos
/// `sin_categoria`: 6 es la abstención del clasificador y 7 es que ninguna
/// señal aplicó. Sin escalón, o con uno fuera de 1 a 7, cae en «Sin categoría».
SenalDeCategoria? senalDeCategoria(OrigenCategoria origen, int? escalon) {
  if (origen == OrigenCategoria.sinCategoria) {
    final abstencion = escalon == 6;
    return SenalDeCategoria(
      chip: abstencion ? 'Sin categoría, Vera no adivina' : 'Sin categoría',
      explicacion: abstencion
          ? 'Vera analizó el nombre y prefirió no arriesgar una categoría. '
                'Puedes asignarla tú.'
          : 'Ninguna señal alcanzó para decidirla. Puedes asignarla tú.',
      esAbstencion: abstencion,
    );
  }
  final chip = etiquetaDeOrigen(origen);
  final explicacion = _explicaciones[origen];
  if (chip.isEmpty || explicacion == null) return null;
  return SenalDeCategoria(chip: chip, explicacion: explicacion);
}

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
    this.escalon,
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
      escalon: switch (json['escalon']) {
        final int n => n,
        final num n => n.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      },
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

  /// Escalón de la cascada, de 1 a 7. Nulo con un backend que no lo envíe.
  final int? escalon;

  bool get sinCategoria => categoria == codigoSinCategoria;

  /// Qué señal decidió la categoría. Nula cuando no hay chip que mostrar.
  SenalDeCategoria? get senal => senalDeCategoria(origenCategoria, escalon);

  /// La categoría la propuso la cascada y el usuario todavía no la confirmó.
  ///
  /// Memoria, contraparte interna y corrección manual son hechos. MCC, catálogo,
  /// léxico, TF-IDF y LLM son sugerencias que se pueden confirmar o corregir.
  bool get categoriaSugerida => switch (origenCategoria) {
        OrigenCategoria.mcc ||
        OrigenCategoria.catalogo ||
        OrigenCategoria.lexico ||
        OrigenCategoria.tfidf ||
        OrigenCategoria.llm =>
          !sinCategoria,
        _ => false,
      };

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
    this.cupoAvisos,
    this.avisosEmitidos,
  });

  factory ResumenDelMes.fromJson(Map<String, dynamic> json) {
    final categorias = [
      for (final c in (json['categorias'] as List?) ?? const [])
        GastoDeCategoria.fromJson(c as Map<String, dynamic>),
    ]..sort((a, b) => b.totalCentavos.abs().compareTo(a.totalCentavos.abs()));
    int? entero(Object? v) => switch (v) {
      final int n => n,
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
    return ResumenDelMes(
      mes: json['mes']?.toString() ?? '',
      totalCentavos: BigInt.parse(json['total_centavos']?.toString() ?? '0'),
      categorias: categorias,
      cupoAvisos: entero(json['cupo_avisos']),
      avisosEmitidos: entero(json['avisos_emitidos']),
    );
  }

  /// Mes calendario `YYYY-MM`.
  final String mes;
  final BigInt totalCentavos;
  final List<GastoDeCategoria> categorias;

  /// Tope de avisos del mes. Se configura por entorno: 3 por defecto y 5 en la
  /// demo, así que la app nunca fija el número. Nulo si el backend no lo envía.
  final int? cupoAvisos;

  /// Avisos ya emitidos este mes. Cuenta solo el mes en curso.
  final int? avisosEmitidos;

  /// El mes llegó a su tope y no se emiten más avisos hasta descartar uno.
  bool get cupoLleno {
    final cupo = cupoAvisos;
    final emitidos = avisosEmitidos;
    return cupo != null && emitidos != null && cupo > 0 && emitidos >= cupo;
  }
}
