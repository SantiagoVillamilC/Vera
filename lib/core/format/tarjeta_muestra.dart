import 'package:flutter/material.dart';

/// Datos de muestra de la tarjeta de débito. No hay endpoint de tarjetas en el
/// contrato: la pestaña Tarjetas y la tarjeta mini del Home leen de aquí para
/// no contradecirse.
const tarjetaMuestraRotulo = 'Vera Débito';
const tarjetaMuestraNumero = '•••• •••• •••• 4417';
const tarjetaMuestraVencimiento = '12/27';
const tarjetaMuestraTipo = 'Visa Débito';
const tarjetaMuestraEstado = 'Activa';

/// Nombre impreso en la tarjeta cuando la sesión no tiene perfil.
const nombreTarjetaGenerico = 'TU NOMBRE';

/// Movimiento de muestra hecho con la tarjeta. Conceptos genéricos, sin marcas.
typedef MovimientoTarjetaMuestra = ({
  IconData icono,
  String concepto,
  String fecha,
  int centavos,
});

const movimientosTarjetaMuestra = <MovimientoTarjetaMuestra>[
  (
    icono: Icons.restaurant_rounded,
    concepto: 'Restaurante',
    fecha: 'Hoy 14:23',
    centavos: 3250000,
  ),
  (
    icono: Icons.play_circle_outline_rounded,
    concepto: 'Suscripción de streaming',
    fecha: 'Ayer',
    centavos: 3490000,
  ),
  (
    icono: Icons.local_gas_station_rounded,
    concepto: 'Combustible',
    fecha: 'Hace 3 días',
    centavos: 8500000,
  ),
];
