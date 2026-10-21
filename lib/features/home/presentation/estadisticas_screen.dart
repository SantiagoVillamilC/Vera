import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
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
  const EstadisticasScreen({super.key, this.repository, this.offsetLocal});

  /// Por defecto el repositorio real.
  final NucleoRepository? repository;

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

  late final NucleoRepository _nucleo =
      widget.repository ?? NucleoRepository();
  BigInt? _saldoCentavos;
  Object? _errorSaldo;
  late Future<MovimientosPage> _movimientos;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Estadísticas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Balance(
                          saldoCentavos: _saldoCentavos,
                          error: _errorSaldo != null,
                        ),
                        _PeriodoSelector(
                          selected: _periodo,
                          onSelect: _setPeriodo,
                        ),
                      ],
                    ),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver todos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
      valor = const SizedBox(
        width: 40,
        height: 40,
        child: EstadoVista.cargando(),
      );
    } else {
      valor = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatPesos(saldoCentavos!),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Balance',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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

  BoxDecoration get _tarjeta => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovimientosPage>(
      future: futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: EstadoVista.cargando(),
          );
        }
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: _tarjeta,
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
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: _tarjeta,
            child: const Center(
              child: Text(
                'Sin movimientos aún',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          );
        }
        final ahora = ahoraLocal(offset: offsetLocal);
        return Container(
          decoration: _tarjeta,
          child: Column(
            children: [
              for (var i = 0; i < filas.length; i++) ...[
                MovimientoFilaTile(
                  fila: filas[i].fila,
                  subtitulo: formatFechaCorta(filas[i].local, ahora),
                ),
                if (i < filas.length - 1)
                  const Divider(color: AppColors.border, height: 1, indent: 72),
              ],
            ],
          ),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: active ? AppGradients.brand : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
                      fontSize: 13,
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
        final double paso =
            labels.length > 1 ? (ancho - 40) / (labels.length - 1) : 0;
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
          AppColors.gradientStart.withAlpha(180),
          AppColors.gradientEnd.withAlpha(60),
          AppColors.background.withAlpha(0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(curvePath, linePaint);

    final gridPaint = Paint()
      ..color = AppColors.border.withAlpha(80)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = chartH - (i / 4) * chartH * 0.85 + 8;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }

    if (progress > 0.05) {
      final glowPaint = Paint()
        ..color = AppColors.gradientStart.withAlpha(40)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 14, glowPaint);

      final outerPaint = Paint()
        ..color = AppColors.gradientStart.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 8, outerPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentTip, 4.5, dotPaint);
    }

    if (progress > 0.1) {
      final dashPaint = Paint()
        ..color = AppColors.gradientStart.withAlpha(60)
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
