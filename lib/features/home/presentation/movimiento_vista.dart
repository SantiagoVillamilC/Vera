import 'package:flutter/material.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/nucleo/data/movimiento_filas.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Una línea de un movimiento con su instante ya en hora local.
typedef FilaLocal = ({FilaMovimiento fila, DateTime local});

/// Único constructor de filas para el preview del home y para la pestaña de
/// movimientos. [ingreso] null = todas, true = solo positivas, false = solo
/// negativas.
List<FilaLocal> construirFilas(
  Iterable<Movimiento> movimientos, {
  Duration? offset,
  bool? ingreso,
}) =>
    [
      for (final m in movimientos)
        for (final f in filasDe(m))
          if (ingreso == null || f.esIngreso == ingreso)
            (fila: f, local: aLocal(m.ocurridoEn, offset: offset)),
    ];

/// Hora actual en la misma zona que las filas, para decidir Hoy y Ayer.
DateTime ahoraLocal({Duration? offset}) =>
    aLocal(DateTime.now().toUtc(), offset: offset);

int _dias(DateTime d) => DateTime.utc(d.year, d.month, d.day)
    .difference(DateTime.utc(1970))
    .inDays;

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic', //
];
const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String encabezadoDeFecha(DateTime local, DateTime ahora) {
  final diff = _dias(ahora) - _dias(local);
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${_diasSemana[local.weekday - 1]} ${local.day} ${_meses[local.month - 1]}';
}

String formatHora(DateTime local) {
  final h = local.hour;
  final m = local.minute.toString().padLeft(2, '0');
  final periodo = h < 12 ? 'am' : 'pm';
  final hora12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hora12:$m $periodo';
}

String formatFechaCorta(DateTime local, DateTime ahora) {
  final diff = _dias(ahora) - _dias(local);
  if (diff == 0) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return 'Hoy $h:$m';
  }
  if (diff == 1) return 'Ayer';
  return '${local.day} ${_meses[local.month - 1]}';
}

IconData iconoDeMotivo(MotivoLinea motivo) => switch (motivo) {
      MotivoLinea.deposito => Icons.arrow_downward_rounded,
      MotivoLinea.transferenciaRecibida => Icons.arrow_downward_rounded,
      MotivoLinea.envio => Icons.arrow_upward_rounded,
      MotivoLinea.gravamen => Icons.account_balance_rounded,
      MotivoLinea.devolucion => Icons.refresh_rounded,
      MotivoLinea.devolucionGravamen => Icons.refresh_rounded,
      MotivoLinea.desconocido => Icons.swap_horiz_rounded,
    };

/// Texto del monto con el signo de la línea. Una línea en cero no lleva signo.
String montoConSigno(BigInt centavos) {
  if (centavos == BigInt.zero) return formatPesos(centavos);
  return '${centavos.isNegative ? '-' : '+'}${formatPesos(centavos.abs())}';
}

class MovimientoFilaTile extends StatelessWidget {
  const MovimientoFilaTile({
    super.key,
    required this.fila,
    required this.subtitulo,
    this.mostrarTipo = false,
  });

  final FilaMovimiento fila;
  final String subtitulo;
  final bool mostrarTipo;

  @override
  Widget build(BuildContext context) {
    final esIngreso = fila.esIngreso;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: esIngreso
                  ? AppColors.accentGreen.withAlpha(20)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: esIngreso
                    ? AppColors.accentGreen.withAlpha(50)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              iconoDeMotivo(fila.motivo),
              color:
                  esIngreso ? AppColors.accentGreen : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fila.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                montoConSigno(fila.montoCentavos),
                style: TextStyle(
                  color: esIngreso
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (mostrarTipo) ...[
                const SizedBox(height: 2),
                Text(
                  esIngreso ? 'Ingreso' : 'Gasto',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
