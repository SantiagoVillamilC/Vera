/// Modelos de `GET /v1/inteligencia/avisos`.
///
/// Los montos viajan como cadena y se leen a [BigInt], igual que en
/// `MovimientoEnriquecido`: pasan de 2^53 y un `double` los redondearía.
library;

/// Los cinco tipos que emite el backend hoy, más el comodín.
///
/// Un sexto tipo no debe romper el parseo: cae en [desconocido] y el aviso se
/// sigue pintando con su título y su texto, que vienen del servidor.
enum TipoAviso {
  pagoNoAlcanza,
  caidaIngreso,
  cobroNuevo,
  presupuestoAnticipado,
  categoriaSobreMedia,
  desconocido,
}

const _tipos = <String, TipoAviso>{
  'pago_no_alcanza': TipoAviso.pagoNoAlcanza,
  'caida_ingreso': TipoAviso.caidaIngreso,
  'cobro_nuevo': TipoAviso.cobroNuevo,
  'presupuesto_anticipado': TipoAviso.presupuestoAnticipado,
  'categoria_sobre_media': TipoAviso.categoriaSobreMedia,
};

/// Código estable del destino de la acción. `accion` es la etiqueta visible y
/// puede cambiar de redacción; esto es la llave que decide a dónde se va.
///
/// Es opcional en el esquema: un backend anterior no lo envía. Sin código
/// conocido el aviso se muestra sin botón de acción.
enum AccionAviso {
  revisarPagos,
  revisarIngreso,
  revisarCobro,
  revisarPresupuesto,
  revisarCategoria,
  desconocida,
}

const _acciones = <String, AccionAviso>{
  'revisar_pagos': AccionAviso.revisarPagos,
  'revisar_ingreso': AccionAviso.revisarIngreso,
  'revisar_cobro': AccionAviso.revisarCobro,
  'revisar_presupuesto': AccionAviso.revisarPresupuesto,
  'revisar_categoria': AccionAviso.revisarCategoria,
};

/// Una tarjeta de `GET /v1/inteligencia/avisos`.
class Aviso {
  const Aviso({
    required this.id,
    required this.tipo,
    required this.clave,
    required this.periodo,
    required this.severidadCentavos,
    required this.montoCentavos,
    required this.prioridad,
    required this.titulo,
    required this.texto,
    required this.porque,
    required this.accion,
    required this.accionCodigo,
    required this.creadoEn,
    this.referenciaCentavos,
    this.transaccionId,
  });

  factory Aviso.fromJson(Map<String, dynamic> json) {
    BigInt monto(Object? v, {BigInt? siFalta}) =>
        v == null ? (siFalta ?? BigInt.zero) : BigInt.parse(v.toString());
    return Aviso(
      id: json['id']?.toString() ?? '',
      tipo: _tipos[json['tipo']?.toString()] ?? TipoAviso.desconocido,
      clave: json['clave']?.toString() ?? '',
      periodo: json['periodo']?.toString() ?? '',
      severidadCentavos: monto(json['severidad_centavos']),
      montoCentavos: monto(json['monto_centavos']),
      // Ausente en cobro_nuevo: es opcional en el esquema, no nulo.
      referenciaCentavos: json['referencia_centavos'] == null
          ? null
          : monto(json['referencia_centavos']),
      prioridad: switch (json['prioridad']) {
        final int n => n,
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      titulo: json['titulo']?.toString() ?? '',
      texto: json['texto']?.toString() ?? '',
      porque: json['porque']?.toString() ?? '',
      accion: json['accion']?.toString() ?? '',
      accionCodigo: json['accion_codigo'] == null
          ? null
          : _acciones[json['accion_codigo'].toString()] ??
                AccionAviso.desconocida,
      transaccionId: json['transaccion_id']?.toString(),
      creadoEn:
          DateTime.tryParse(json['creado_en']?.toString() ?? '')?.toUtc() ??
          DateTime.utc(1970),
    );
  }

  final String id;
  final TipoAviso tipo;

  /// Identidad interna del hecho. No se muestra: sirve para filtrar localmente.
  final String clave;

  /// Mes al que **pertenece** el hecho, `YYYY-MM-DD`. No es el día de entrega:
  /// `caida_ingreso` guarda el día 1 del mes anterior.
  final String periodo;

  /// Ordena dentro de una prioridad. No es un nivel: es un monto en centavos.
  final BigInt severidadCentavos;

  /// Cambia de significado según el tipo: en `pago_no_alcanza` es el saldo.
  final BigInt montoCentavos;

  /// Línea base con la que se compara. Ausente en `cobro_nuevo`.
  final BigInt? referenciaCentavos;

  /// De 1 a 5, de más urgente a menos.
  final int prioridad;
  final String titulo;
  final String texto;
  final String porque;

  /// Etiqueta visible del botón de acción.
  final String accion;

  /// Destino del botón. Nulo si el backend no lo envía.
  final AccionAviso? accionCodigo;

  /// Nulo en los cinco tipos de hoy.
  final String? transaccionId;
  final DateTime creadoEn;

  /// Mes del periodo, `YYYY-MM`, para agrupar la bandeja.
  String get mes => periodo.length >= 7 ? periodo.substring(0, 7) : periodo;

  /// Si se puede dibujar el botón de acción: hace falta la etiqueta y un
  /// destino que la app sepa abrir.
  bool get tieneAccion =>
      accion.isNotEmpty &&
      accionCodigo != null &&
      accionCodigo != AccionAviso.desconocida;

  /// Orden del servidor, que la app reproduce al unir dos meses: prioridad
  /// ascendente y, dentro de ella, severidad descendente.
  static int comparar(Aviso a, Aviso b) {
    final porPrioridad = a.prioridad.compareTo(b.prioridad);
    if (porPrioridad != 0) return porPrioridad;
    final porSeveridad = b.severidadCentavos.compareTo(a.severidadCentavos);
    if (porSeveridad != 0) return porSeveridad;
    final porClave = a.clave.compareTo(b.clave);
    return porClave != 0 ? porClave : a.id.compareTo(b.id);
  }
}

/// Respuesta de `POST /v1/inteligencia/avisos/{id}/descartar`.
class AvisoDescartado {
  const AvisoDescartado({required this.id, required this.descartadoEn});

  factory AvisoDescartado.fromJson(Map<String, dynamic> json) =>
      AvisoDescartado(
        id: json['id']?.toString() ?? '',
        descartadoEn:
            DateTime.tryParse(
              json['descartado_en']?.toString() ?? '',
            )?.toUtc() ??
            DateTime.utc(1970),
      );

  final String id;
  final DateTime descartadoEn;
}
