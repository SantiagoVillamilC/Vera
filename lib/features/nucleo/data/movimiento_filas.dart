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

Iterable<BigInt> _montos(Iterable<Movimiento> ms) =>
    ms.expand((m) => m.lineas).map((l) => l.montoCentavos);

/// Suma de las líneas positivas (incluye devoluciones y devolución del GMF).
BigInt totalIngresos(Iterable<Movimiento> movimientos) => _montos(movimientos)
    .where((c) => c > BigInt.zero)
    .fold(BigInt.zero, (a, c) => a + c);

/// Suma en positivo de las líneas negativas (el GMF cuenta como gasto).
BigInt totalGastos(Iterable<Movimiento> movimientos) => _montos(movimientos)
    .where((c) => c < BigInt.zero)
    .fold(BigInt.zero, (a, c) => a - c);
