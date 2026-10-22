import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/cargando_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/home/presentation/burbujas_categorias.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Serie de muestra de un período: ingresos y gastos por tramo, en centavos.
/// Los totales, las burbujas y la curva salen de aquí, así que siempre
/// coinciden. El contrato no tiene endpoint de estadísticas.
typedef _Serie = ({
  List<int> ingresos,
  List<int> gastos,
  List<String> etiquetas,
});

const _semana = (
  ingresos: [500000, 0, 1800000, 300000, 0, 900000, 0],
  gastos: [120000, 85000, 240000, 60000, 150000, 210000, 95000],
  etiquetas: ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
);

const _mes = (
  ingresos: [4100000, 5500000, 6200000, 5800000, 6700000, 5400000],
  gastos: [1300000, 1700000, 1500000, 1900000, 1600000, 1400000],
  etiquetas: ['5', '10', '15', '20', '25', '30'],
);

const _anio = (
  ingresos: [
    3000000, 3200000, 2800000, 3500000, 3100000, 3600000, //
    3300000, 3400000, 3200000, 3700000, 3500000, 4000000,
  ],
  gastos: [
    800000, 900000, 700000, 1000000, 800000, 1100000, //
    900000, 900000, 800000, 1200000, 1000000, 1100000,
  ],
  etiquetas: [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ],
);

const _series = <_Serie>[_semana, _mes, _anio];

int _suma(List<int> v) => v.fold(0, (a, b) => a + b);

/// Flujo neto acumulado normalizado a 0.15 a 0.95 para dibujar la curva.
List<double> _puntosDe(_Serie s) {
  final acumulado = <int>[];
  var corrido = 0;
  for (var i = 0; i < s.ingresos.length; i++) {
    corrido += s.ingresos[i] - s.gastos[i];
    acumulado.add(corrido);
  }
  final minimo = acumulado.reduce(math.min);
  final maximo = acumulado.reduce(math.max);
  if (maximo == minimo) return [for (final _ in acumulado) 0.5];
  return [
    for (final a in acumulado) 0.15 + 0.8 * (a - minimo) / (maximo - minimo),
  ];
}

const _maxFilas = 8;

// ─────────────────────────────────────────────────────────────────────────────

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({
    super.key,
    this.repository,
    this.inteligencia,
    this.offsetLocal,
  });

  /// Por defecto el repositorio real.
  final NucleoRepository? repository;
  final InteligenciaRepository? inteligencia;

  /// Solo para pruebas: zona horaria fija en lugar de la del equipo.
  final Duration? offsetLocal;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen>
    with SingleTickerProviderStateMixin {
  int _periodo = 1; // 0=Sem, 1=Mes, 2=Año
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  late final NucleoRepository _nucleo = widget.repository ?? NucleoRepository();
  BigInt? _saldoCentavos;
  Object? _errorSaldo;
  late Future<MovimientosPage> _movimientos;
  late final InteligenciaRepository _inteligencia =
      widget.inteligencia ?? InteligenciaRepository();
  late Future<ResumenDelMes> _resumen;
  late Future<ResumenDelMes?> _anterior;
  final String _mes = mesDeBogota(DateTime.now());

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
    _movimientos = _nucleo.getMovimientos(limit: 5);
    _resumen = _inteligencia.resumen();
    _anterior = _cargarAnterior();
    _cargarSaldo();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarSaldo() async {
    setState(() {
      _saldoCentavos = null;
      _errorSaldo = null;
    });
    try {
      final s = await _nucleo.getSaldo();
      if (mounted) setState(() => _saldoCentavos = s.montoCentavos);
    } catch (e) {
      if (mounted) setState(() => _errorSaldo = e);
    }
  }

  void _recargarMovimientos() {
    final siguiente = _nucleo.getMovimientos(limit: 5);
    setState(() {
      _movimientos = siguiente;
    });
  }

  /// El mes anterior solo sirve para comparar: si falla, la comparación simplemente no se muestra.
  Future<ResumenDelMes?> _cargarAnterior() async {
    try {
      return await _inteligencia.resumen(mes: mesAnterior(_mes));
    } catch (_) {
      return null;
    }
  }

  void _recargarResumen() {
    final siguiente = _inteligencia.resumen();
    final anterior = _cargarAnterior();
    setState(() {
      _resumen = siguiente;
      _anterior = anterior;
    });
  }

  void _setPeriodo(int p) {
    setState(() => _periodo = p);
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final serie = _series[_periodo];
    final ingresos = _suma(serie.ingresos);
    final gastos = _suma(serie.gastos);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.fondoAzul),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 14, 20, 0),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Volver',
                      excludeSemantics: true,
                      onTap: () => context.pop(),
                      child: GestureDetector(
                        key: const Key('volver'),
                        onTap: () => context.pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderGlass),
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Estadísticas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _PildoraMes(mes: _mes),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PeriodoSelector(selected: _periodo, onSelect: _setPeriodo),
                    const SizedBox(height: 22),
                    _HeroGasto(
                      mes: _mes,
                      resumen: _resumen,
                      anterior: _anterior,
                    ),
                    const SizedBox(height: 22),
                    _Balance(
                      saldoCentavos: _saldoCentavos,
                      error: _errorSaldo != null,
                    ),
                    if (_errorSaldo != null)
                      EstadoVista.deError(
                        _errorSaldo!,
                        mensaje: mensajeDeError(_errorSaldo!),
                        onReintentar: _cargarSaldo,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'Ingresos',
                        valorKey: const ValueKey('total-ingresos'),
                        centavos: ingresos,
                        color: AppColors.accentGreen,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        label: 'Gastos',
                        valorKey: const ValueKey('total-gastos'),
                        centavos: gastos,
                        color: AppColors.accentPink,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 220,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => _AreaChart(
                    points: _puntosDe(serie),
                    labels: serie.etiquetas,
                    progress: _anim.value,
                    burbujaIngresos: montoConSigno(BigInt.from(ingresos)),
                    burbujaGastos: montoConSigno(BigInt.from(-gastos)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SeccionCategorias(
                  futuro: _resumen,
                  onReintentar: _recargarResumen,
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Últimos movimientos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (context.canPop()) context.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gradientStart,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Ver todos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ListaMovimientos(
                  futuro: _movimientos,
                  offsetLocal: widget.offsetLocal,
                  onReintentar: _recargarMovimientos,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gastaste en el mes ─────────────────────────────────────────

/// Mes en curso, como la píldora de la cabecera. Es una etiqueta: la API solo resume un mes a la vez.
class _PildoraMes extends StatelessWidget {
  const _PildoraMes({required this.mes});

  final String mes;

  @override
  Widget build(BuildContext context) {
    final nombre = nombreDeMes(int.parse(mes.substring(5, 7)));
    return Container(
      key: const Key('pildora_mes'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            '${nombre[0].toUpperCase()}${nombre.substring(1)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Gastaste en octubre" con lo gastado de verdad en el mes y cómo va frente al anterior.
class _HeroGasto extends StatelessWidget {
  const _HeroGasto({
    required this.mes,
    required this.resumen,
    required this.anterior,
  });

  final String mes;
  final Future<ResumenDelMes> resumen;
  final Future<ResumenDelMes?> anterior;

  @override
  Widget build(BuildContext context) {
    final nombre = nombreDeMes(int.parse(mes.substring(5, 7)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gastaste en $nombre',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 17),
        ),
        const SizedBox(height: 4),
        FutureBuilder<ResumenDelMes>(
          future: resumen,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: EsqueletoVera(ancho: 230, alto: 40, radio: 14),
                ),
              );
            }
            if (snap.hasError) {
              // El error y el reintento viven en la sección de categorías, más abajo.
              return const Text(
                'No pudimos cargarlo',
                style: TextStyle(color: AppColors.textMuted, fontSize: 18),
              );
            }
            final total = snap.data!.totalCentavos.abs();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MontoConCentavos(centavos: total),
                const SizedBox(height: 12),
                FutureBuilder<ResumenDelMes?>(
                  future: anterior,
                  builder: (context, previo) {
                    final p = previo.data;
                    if (p == null || p.totalCentavos == BigInt.zero) {
                      return const SizedBox.shrink();
                    }
                    return _ChipComparacion(
                      actual: total,
                      anterior: p.totalCentavos.abs(),
                      mesAnterior: nombreDeMes(
                        int.parse(mesAnterior(mes).substring(5, 7)),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Monto grande con los centavos aparte y en gris, igual que el saldo del Home.
class _MontoConCentavos extends StatelessWidget {
  const _MontoConCentavos({required this.centavos});

  final BigInt centavos;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 44,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      height: 1.05,
    );
    final texto = formatPesos(centavos);
    final coma = texto.indexOf(',');
    final enteros = coma == -1 ? texto : texto.substring(0, coma);
    final resto = coma == -1 ? ',00' : texto.substring(coma);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        key: const Key('gasto_del_mes'),
        TextSpan(
          style: estilo,
          children: [
            TextSpan(text: enteros),
            TextSpan(
              text: resto,
              style: estilo.copyWith(color: Colors.white.withAlpha(110)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipComparacion extends StatelessWidget {
  const _ChipComparacion({
    required this.actual,
    required this.anterior,
    required this.mesAnterior,
  });

  final BigInt actual;
  final BigInt anterior;
  final String mesAnterior;

  @override
  Widget build(BuildContext context) {
    final cambio = (actual - anterior).toDouble() / anterior.toDouble();
    final pct = (cambio.abs() * 100).round();
    final String texto;
    final IconData icono;
    if (pct == 0) {
      texto = 'Igual que en $mesAnterior';
      icono = Icons.trending_flat_rounded;
    } else if (cambio < 0) {
      texto = '$pct% menos que en $mesAnterior';
      icono = Icons.south_east_rounded;
    } else {
      texto = '$pct% más que en $mesAnterior';
      icono = Icons.north_east_rounded;
    }
    return Container(
      key: const Key('chip_comparacion'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ¿En qué se fue? ────────────────────────────────────────────

/// Gasto del mes por categoría. Sale de `GET /v1/inteligencia/resumen`, no de la serie de muestra.
class _SeccionCategorias extends StatelessWidget {
  const _SeccionCategorias({required this.futuro, required this.onReintentar});

  final Future<ResumenDelMes> futuro;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '¿En qué se fue?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              key: const Key('ver_detalle_categorias'),
              // Lleva a "Movimientos con categoría", donde se ve y corrige cada gasto.
              onPressed: () => GoRouter.maybeOf(context)?.push('/inteligencia'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gradientStart,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Ver detalle',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tus gastos de este mes por categoría',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FutureBuilder<ResumenDelMes>(
          future: futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CargandoVera(
                  tamano: 60,
                  mensaje: 'Sumando tus gastos del mes',
                ),
              );
            }
            if (snap.hasError) {
              return EstadoVista.deError(
                snap.error!,
                mensaje: mensajeDeError(snap.error!),
                onReintentar: onReintentar,
              );
            }
            final resumen = snap.data!;
            if (resumen.categorias.every(
              (c) => c.totalCentavos == BigInt.zero,
            )) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no tienes gastos este mes.',
                  key: Key('sin_gastos_mes'),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              );
            }
            return BurbujasCategorias(resumen: resumen);
          },
        ),
      ],
    );
  }
}

// ── Balance ────────────────────────────────────────────────────

class _Balance extends StatelessWidget {
  const _Balance({required this.saldoCentavos, required this.error});

  final BigInt? saldoCentavos;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Widget valor;
    if (error) {
      valor = const Text(
        'Error al cargar',
        style: TextStyle(color: AppColors.textMuted, fontSize: 20),
      );
    } else if (saldoCentavos == null) {
      valor = const Align(
        alignment: Alignment.centerLeft,
        child: EsqueletoVera(ancho: 190, alto: 40, radio: 14),
      );
    } else {
      valor = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatPesos(saldoCentavos!),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Balance',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 17),
        ),
        const SizedBox(height: 4),
        valor,
      ],
    );
  }
}

// ── Lista de movimientos reales ────────────────────────────────

class _ListaMovimientos extends StatelessWidget {
  const _ListaMovimientos({
    required this.futuro,
    required this.offsetLocal,
    required this.onReintentar,
  });

  final Future<MovimientosPage> futuro;
  final Duration? offsetLocal;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovimientosPage>(
      future: futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: EsqueletoMovimientos(filas: 3),
          );
        }
        if (snap.hasError) {
          return TarjetaVidrio(
            radio: 24,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: EstadoVista.error(
              mensaje: mensajeDeError(snap.error!),
              onReintentar: onReintentar,
            ),
          );
        }
        final filas = construirFilas(
          snap.data?.items ?? const [],
          offset: offsetLocal,
        ).take(_maxFilas).toList();
        if (filas.isEmpty) {
          return const TarjetaVidrio(
            radio: 24,
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Sin movimientos aún',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          );
        }
        final ahora = ahoraLocal(offset: offsetLocal);
        return Column(
          children: [
            for (final f in filas)
              MovimientoFilaTile(
                fila: f.fila,
                subtitulo: formatFechaCorta(f.local, ahora),
              ),
          ],
        );
      },
    );
  }
}

// ── Período selector ───────────────────────────────────────────

class _PeriodoSelector extends StatelessWidget {
  const _PeriodoSelector({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _labels = ['Sem', 'Mes', 'Año'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.botonOscuro : Colors.transparent,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 17,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Stat chip ──────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.valorKey,
    required this.centavos,
    required this.color,
    required this.icon,
  });

  final String label;
  final Key valorKey;
  final int centavos;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      radio: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPesosInt(centavos),
                    key: valorKey,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Area chart ─────────────────────────────────────────────────

class _AreaChart extends StatelessWidget {
  const _AreaChart({
    required this.points,
    required this.labels,
    required this.progress,
    required this.burbujaIngresos,
    required this.burbujaGastos,
  });

  final List<double> points;
  final List<String> labels;
  final double progress;
  final String burbujaIngresos;
  final String burbujaGastos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final double paso = labels.length > 1
            ? (ancho - 40) / (labels.length - 1)
            : 0;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
              child: CustomPaint(
                size: const Size(double.infinity, 192),
                painter: _ChartPainter(points: points, progress: progress),
              ),
            ),
            for (var i = 0; i < labels.length; i++)
              Positioned(
                bottom: 0,
                left: 20 + i * paso - 16,
                width: 32,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            if (progress > 0.5)
              Positioned(
                top: 30,
                right: 32,
                child: Opacity(
                  opacity: ((progress - 0.5) * 2).clamp(0.0, 1.0),
                  child: _Bubble(
                    valueKey: const ValueKey('burbuja-ingresos'),
                    label: burbujaIngresos,
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            if (progress > 0.6)
              Positioned(
                top: 90,
                left: ancho * 0.35,
                child: Opacity(
                  opacity: ((progress - 0.6) * 2.5).clamp(0.0, 1.0),
                  child: _Bubble(
                    valueKey: const ValueKey('burbuja-gastos'),
                    label: burbujaGastos,
                    color: AppColors.accentPink,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.valueKey,
    required this.label,
    required this.color,
  });

  final Key valueKey;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.botonOscuro,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Text(
        label,
        key: valueKey,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.points, required this.progress});

  final List<double> points;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final n = points.length;
    final xStep = (size.width - 40) / (n - 1);
    final chartH = size.height - 16;

    final visibleCount = (progress * (n - 1)).clamp(0.0, n - 1.0);

    final curvePath = Path();
    final pts = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = 20 + i * xStep;
      final y = chartH - points[i] * chartH * 0.85 + 8;
      pts.add(Offset(x, y));
    }

    final lastIdx = visibleCount.floor();
    final frac = visibleCount - lastIdx;

    curvePath.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i <= lastIdx; i++) {
      final cp1 = Offset(pts[i - 1].dx + xStep * 0.5, pts[i - 1].dy);
      final cp2 = Offset(pts[i].dx - xStep * 0.5, pts[i].dy);
      curvePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }

    Offset currentTip = pts[lastIdx];
    if (lastIdx < n - 1 && frac > 0) {
      final a = pts[lastIdx];
      final b = pts[lastIdx + 1];
      final cp1 = Offset(a.dx + xStep * 0.5, a.dy);
      final cp2 = Offset(b.dx - xStep * 0.5, b.dy);
      final t = frac;
      final t2 = t * t;
      final t3 = t2 * t;
      final mt = 1 - t;
      final mt2 = mt * mt;
      final mt3 = mt2 * mt;
      currentTip = Offset(
        mt3 * a.dx + 3 * mt2 * t * cp1.dx + 3 * mt * t2 * cp2.dx + t3 * b.dx,
        mt3 * a.dy + 3 * mt2 * t * cp1.dy + 3 * mt * t2 * cp2.dy + t3 * b.dy,
      );
      curvePath.cubicTo(
        a.dx + xStep * 0.5 * frac,
        a.dy + (cp1.dy - a.dy) * frac,
        currentTip.dx - xStep * 0.1,
        currentTip.dy,
        currentTip.dx,
        currentTip.dy,
      );
    }

    final fillPath = Path.from(curvePath)
      ..lineTo(currentTip.dx, size.height)
      ..lineTo(pts[0].dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha(110),
          Colors.white.withAlpha(36),
          Colors.white.withAlpha(0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(curvePath, linePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(36)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = chartH - (i / 4) * chartH * 0.85 + 8;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }

    if (progress > 0.05) {
      final glowPaint = Paint()
        ..color = Colors.white.withAlpha(40)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 14, glowPaint);

      final outerPaint = Paint()
        ..color = Colors.white.withAlpha(70)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 8, outerPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 4.5, dotPaint);
    }

    if (progress > 0.1) {
      final dashPaint = Paint()
        ..color = Colors.white.withAlpha(70)
        ..strokeWidth = 1;

      double y = currentTip.dy + 10;
      while (y < size.height - 4) {
        canvas.drawLine(
          Offset(currentTip.dx, y),
          Offset(currentTip.dx, math.min(y + 5, size.height - 4)),
          dashPaint,
        );
        y += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.progress != progress || old.points != points;
}
