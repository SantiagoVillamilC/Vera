import 'package:vera/features/inteligencia/data/aviso.dart';

/// A dónde lleva el botón principal de un aviso, y con qué etiqueta.
class DestinoDeAviso {
  const DestinoDeAviso({required this.ruta, this.rotuloPropio});

  /// Ruta del router de la app.
  final String ruta;

  /// Etiqueta cuando la del contrato no describe lo que hace el botón.
  /// Nula significa usar el campo `accion` del aviso.
  final String? rotuloPropio;
}

/// Tabla única de destinos, una fila por `accion_codigo`.
///
/// Es una propuesta construida con las pantallas que la app tiene hoy: no
/// existe una pantalla de pagos recurrentes ni un detalle de movimiento, y el
/// contrato recomienda la primera para `revisar_pagos` y `revisar_cobro`. Está
/// pendiente de confirmar con el equipo.
///
/// `revisar_ingreso` no abre la pestaña Movimientos filtrada a ingresos porque
/// ese filtro es estado interno de la pestaña (`_selectedFilter`) y no se
/// puede fijar desde una ruta: cae en el destino alternativo que da la tarjeta.
const destinosDeAviso = <AccionAviso, DestinoDeAviso>{
  // La etiqueta del contrato es «Ver los pagos que vencen», pero el destino
  // posible hoy es la recarga: el botón dice lo que de verdad hace.
  AccionAviso.revisarPagos: DestinoDeAviso(
    ruta: '/recargar',
    rotuloPropio: 'Recargar',
  ),
  AccionAviso.revisarIngreso: DestinoDeAviso(ruta: '/inteligencia'),
  AccionAviso.revisarCobro: DestinoDeAviso(ruta: '/inteligencia'),
  AccionAviso.revisarPresupuesto: DestinoDeAviso(ruta: '/estadisticas'),
  AccionAviso.revisarCategoria: DestinoDeAviso(ruta: '/inteligencia'),
  // Un código que la app no conoce no tiene destino: el aviso se muestra sin
  // botón de acción, nunca con un botón que no lleve a ningún lado.
  AccionAviso.desconocida: DestinoDeAviso(ruta: ''),
};

/// El destino de un aviso, o `null` si no hay ninguno que abrir.
DestinoDeAviso? destinoDe(Aviso aviso) {
  final codigo = aviso.accionCodigo;
  if (codigo == null) return null;
  final destino = destinosDeAviso[codigo];
  if (destino == null || destino.ruta.isEmpty) return null;
  return destino;
}

/// Etiqueta del botón principal: la propia del destino si la tiene, si no la
/// del contrato.
String? rotuloDeAccion(Aviso aviso) {
  final destino = destinoDe(aviso);
  if (destino == null) return null;
  final propio = destino.rotuloPropio;
  if (propio != null && propio.isNotEmpty) return propio;
  return aviso.accion.isEmpty ? null : aviso.accion;
}

/// Cómo se rotulan las cifras de un aviso. `monto_centavos` cambia de
/// significado según el tipo, así que no se puede rotular igual para los cinco.
class RotulosDeAviso {
  const RotulosDeAviso({
    required this.monto,
    required this.referencia,
    required this.fecha,
  });

  final String monto;

  /// Nulo en `cobro_nuevo`, que no trae línea base.
  final String? referencia;

  /// Qué significa `periodo` en este tipo.
  final String fecha;
}

/// Rótulos por tipo, según la tabla de la sección 2 del contrato.
RotulosDeAviso rotulosDe(TipoAviso tipo) => switch (tipo) {
  TipoAviso.pagoNoAlcanza => const RotulosDeAviso(
    monto: 'Tu saldo',
    referencia: 'Pagos que vencen',
    fecha: 'Fecha de pago',
  ),
  TipoAviso.caidaIngreso => const RotulosDeAviso(
    monto: 'Ingreso del mes',
    referencia: 'Lo habitual',
    fecha: 'Mes',
  ),
  TipoAviso.cobroNuevo => const RotulosDeAviso(
    monto: 'Valor del cobro',
    referencia: null,
    fecha: 'Fecha del cobro',
  ),
  TipoAviso.presupuestoAnticipado => const RotulosDeAviso(
    monto: 'Gasto del mes',
    referencia: 'Lo habitual',
    fecha: 'Mes',
  ),
  TipoAviso.categoriaSobreMedia => const RotulosDeAviso(
    monto: 'Gasto de la categoría',
    referencia: 'Lo habitual',
    fecha: 'Mes',
  ),
  // Un tipo nuevo: se muestran las cifras sin afirmar qué significan.
  TipoAviso.desconocido => const RotulosDeAviso(
    monto: 'Monto',
    referencia: 'Referencia',
    fecha: 'Periodo',
  ),
};
