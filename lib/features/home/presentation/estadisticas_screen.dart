import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';

// TODO: GET /v1/nucleo/estadisticas?periodo=mes
// Datos mock — reemplazar con respuesta real del backend
const _saldoActualCentavos = 14512356;
const _ingresosCentavos = 35180000;
const _gastosCentavos = 8977290;

// Puntos del gráfico normalizados (0.0–1.0) por período
// TODO: derivar de movimientos reales agrupados por fecha
const _puntosSemana = [0.42, 0.38, 0.55, 0.48, 0.61, 0.70, 0.78];
const _puntosMes = [0.30, 0.25, 0.40, 0.35, 0.50, 0.45, 0.60, 0.55, 0.68, 0.72, 0.65, 0.78];
const _puntosAnio = [0.20, 0.30, 0.25, 0.45, 0.40, 0.55, 0.50, 0.60, 0.58, 0.70, 0.75, 0.85];

const _labelsSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _labelsMes = ['1', '5', '10', '15', '20', '25', '30', '', '', '', '', ''];
const _labelsAnio = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

final _movsMock = [
  _MovStat('Nómina', 'Hoy, 8:02', 18000000, true, Icons.arrow_downward_rounded),
  _MovStat('Mercado D1', 'Hoy, 12:40', 863000, false, Icons.store_rounded),
  _MovStat('Netflix', 'Ayer', 4990000, false, Icons.play_circle_outline_rounded),
  _MovStat('Transferencia', 'Lun 29', 17180000, true, Icons.swap_horiz_rounded),
  _MovStat('Gasolina BP', 'Lun 29', 8500000, false, Icons.local_gas_station_rounded),
];

String _pesos(int centavos) {
  final s = (centavos ~/ 100).toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  final cents = (centavos % 100).toString().padLeft(2, '0');
  return '\$ ${b.toString()},$cents';
}

class _MovStat {
  const _MovStat(this.name, this.fecha, this.centavos, this.esIngreso, this.icon);
  final String name;
  final String fecha;
  final int centavos;
  final bool esIngreso;
  final IconData icon;
}

// ─────────────────────────────────────────────────────────────────────────────

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen>
    with SingleTickerProviderStateMixin {
  int _periodo = 1; // 0=Sem, 1=Mes, 2=Año
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  List<double> get _puntos => switch (_periodo) {
        0 => _puntosSemana,
        2 => _puntosAnio,
        _ => _puntosMes,
      };

  List<String> get _labels => switch (_periodo) {
        0 => _labelsSemana,
        2 => _labelsAnio,
        _ => _labelsMes,
      };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _setPeriodo(int p) {
    setState(() => _periodo = p);
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ─────────────────────────────────────────
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
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textSecondary, size: 18),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Balance header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        _pesos(_saldoActualCentavos),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Período selector
                  _PeriodoSelector(
                    selected: _periodo,
                    onSelect: _setPeriodo,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Stat chips ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Ingresos',
                    centavos: _ingresosCentavos,
                    color: AppColors.accentGreen,
                    icon: Icons.arrow_upward_rounded,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'Gastos',
                    centavos: _gastosCentavos,
                    color: AppColors.accentPink,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Chart ──────────────────────────────────────────
            SizedBox(
              height: 220,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) => _AreaChart(
                  points: _puntos,
                  labels: _labels,
                  progress: _anim.value,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Movimientos ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Todos los movimientos',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gradientStart,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Ver todos',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: List.generate(_movsMock.length, (i) {
                    final m = _movsMock[i];
                    final isLast = i == _movsMock.length - 1;
                    return Column(
                      children: [
                        _MovRow(data: m),
                        if (!isLast)
                          const Divider(
                              color: AppColors.border,
                              height: 1,
                              indent: 72),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
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
    required this.centavos,
    required this.color,
    required this.icon,
  });
  final String label;
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
        mainAxisSize: MainAxisSize.min,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                _pesos(centavos),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
  });

  final List<double> points;
  final List<String> labels;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chart painter
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          child: CustomPaint(
            size: const Size(double.infinity, 192),
            painter: _ChartPainter(points: points, progress: progress),
          ),
        ),
        // X-axis labels
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((l) => SizedBox(
              width: 24,
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            )).toList(),
          ),
        ),
        // Annotation bubbles
        if (progress > 0.5)
          Positioned(
            top: 30,
            right: 32,
            child: Opacity(
              opacity: ((progress - 0.5) * 2).clamp(0.0, 1.0),
              child: _Bubble(
                label: '+\$3.518,00',
                color: AppColors.accentGreen,
              ),
            ),
          ),
        if (progress > 0.6)
          Positioned(
            top: 90,
            left: MediaQuery.of(context).size.width * 0.35,
            child: Opacity(
              opacity: ((progress - 0.6) * 2.5).clamp(0.0, 1.0),
              child: _Bubble(
                label: '-\$897,29',
                color: AppColors.accentPink,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.label, required this.color});
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
    if (points.isEmpty) return;

    final n = points.length;
    final xStep = (size.width - 40) / (n - 1);
    final chartH = size.height - 16;

    // Compute visible points up to progress
    final visibleCount = (progress * (n - 1)).clamp(0.0, n - 1.0);

    // Build the curve path
    final curvePath = Path();
    final pts = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = 20 + i * xStep;
      final y = chartH - points[i] * chartH * 0.85 + 8;
      pts.add(Offset(x, y));
    }

    // Draw only up to visibleCount
    final lastIdx = visibleCount.floor();
    final frac = visibleCount - lastIdx;

    curvePath.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i <= lastIdx; i++) {
      final cp1 = Offset(
        pts[i - 1].dx + xStep * 0.5,
        pts[i - 1].dy,
      );
      final cp2 = Offset(
        pts[i].dx - xStep * 0.5,
        pts[i].dy,
      );
      curvePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }

    // Partial last segment
    Offset currentTip = pts[lastIdx];
    if (lastIdx < n - 1 && frac > 0) {
      final a = pts[lastIdx];
      final b = pts[lastIdx + 1];
      final cp1 = Offset(a.dx + xStep * 0.5, a.dy);
      final cp2 = Offset(b.dx - xStep * 0.5, b.dy);
      // Interpolate along cubic
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

    // Fill path (area under curve)
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

    // Stroke the line
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

    // Horizontal grid lines (subtle)
    final gridPaint = Paint()
      ..color = AppColors.border.withAlpha(80)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = chartH - (i / 4) * chartH * 0.85 + 8;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }

    // Glowing dot at tip
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

    // Vertical dashed line at tip
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

// ── Movimiento row ─────────────────────────────────────────────

class _MovRow extends StatelessWidget {
  const _MovRow({required this.data});
  final _MovStat data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.esIngreso
                  ? AppColors.accentGreen.withAlpha(20)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: data.esIngreso
                    ? AppColors.accentGreen.withAlpha(50)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              data.icon,
              color: data.esIngreso ? AppColors.accentGreen : AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 3),
                Text(data.fecha,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${data.esIngreso ? '+' : '-'}${_pesos(data.centavos)}',
            style: TextStyle(
              color: data.esIngreso
                  ? AppColors.accentGreen
                  : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
