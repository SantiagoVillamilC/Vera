import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Una línea de un movimiento lista para mostrar. El signo sale del monto.
class FilaMovimiento {
  const FilaMovimiento({
    required this.etiqueta,
    required this.montoCentavos,
    required this.esIngreso,
    required this.motivo,
  });

  final String etiqueta;

  /// Con el signo de la línea: negativo = gasto, positivo = ingreso.
  final BigInt montoCentavos;
  final bool esIngreso;
  final MotivoLinea motivo;
}

/// Una fila por línea, sin netear. Una transferencia compensada muestra la
/// salida y la devolución por separado, nunca un neto en cero.
List<FilaMovimiento> filasDe(Movimiento m) => [
      for (final l in m.lineas)
        FilaMovimiento(
          etiqueta: l.motivo.label,
          montoCentavos: l.montoCentavos,
          esIngreso: l.montoCentavos > BigInt.zero,
          motivo: l.motivo,
        ),
    ];

/// Saldos que cuentan para los totales de un movimiento. Dentro de un mismo
/// movimiento el envío se compensa con su devolución y el GMF con la
/// devolución del GMF: solo cuenta lo que queda de cada par (cero en una
/// compensación completa). El resto de las líneas cuenta una a una.
Iterable<BigInt> _saldosDelMovimiento(Movimiento m) {
  var envio = BigInt.zero;
  var gravamen = BigInt.zero;
  final otras = <BigInt>[];
  for (final l in m.lineas) {
    switch (l.motivo) {
      case MotivoLinea.envio || MotivoLinea.devolucion:
        envio += l.montoCentavos;
      case MotivoLinea.gravamen || MotivoLinea.devolucionGravamen:
        gravamen += l.montoCentavos;
      default:
        otras.add(l.montoCentavos);
    }
  }
  return [envio, gravamen, ...otras];
}

Iterable<BigInt> _saldos(Iterable<Movimiento> ms) =>
    ms.expand(_saldosDelMovimiento);

/// Suma de los saldos positivos. Una devolución no es un ingreso: solo
/// compensa el envío (o el GMF) de su propio movimiento.
BigInt totalIngresos(Iterable<Movimiento> movimientos) => _saldos(movimientos)
    .where((c) => c > BigInt.zero)
    .fold(BigInt.zero, (a, c) => a + c);

/// Suma en positivo de los saldos negativos (el GMF cuenta como gasto salvo
/// que se haya devuelto).
BigInt totalGastos(Iterable<Movimiento> movimientos) => _saldos(movimientos)
    .where((c) => c < BigInt.zero)
    .fold(BigInt.zero, (a, c) => a - c);
