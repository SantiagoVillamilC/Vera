import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

IconData _iconForMotivo(MotivoLinea motivo) => switch (motivo) {
      MotivoLinea.deposito => Icons.arrow_downward_rounded,
      MotivoLinea.transferenciaRecibida => Icons.arrow_downward_rounded,
      MotivoLinea.envio => Icons.arrow_upward_rounded,
      MotivoLinea.gravamen => Icons.account_balance_rounded,
      MotivoLinea.devolucion => Icons.refresh_rounded,
      MotivoLinea.devolucionGravamen => Icons.refresh_rounded,
      MotivoLinea.desconocido => Icons.swap_horiz_rounded,
    };

String _formatDateHeader(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'Hoy';
  if (day == yesterday) return 'Ayer';
  final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  return '${weekdays[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}';
}

String _formatHour(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = h < 12 ? 'am' : 'pm';
  final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$displayH:$m $period';
}

// Groups a flat Movimiento list into date-keyed sections
List<({String label, List<Movimiento> items})> _groupByDate(
    List<Movimiento> items) {
  final Map<String, List<Movimiento>> map = {};
  for (final m in items) {
    final key = _formatDateHeader(m.ocurridoEn);
    map.putIfAbsent(key, () => []).add(m);
  }
  return map.entries.map((e) => (label: e.key, items: e.value)).toList();
}

// ─────────────────────────────────────────────────────────────────────────────

class MovimientosTab extends StatefulWidget {
  const MovimientosTab({super.key});

  @override
  State<MovimientosTab> createState() => _MovimientosTabState();
}

class _MovimientosTabState extends State<MovimientosTab> {
  final _repo = NucleoRepository();

  int _selectedFilter = 0; // 0=Todos, 1=Ingresos, 2=Gastos
  bool _loading = true;
  String? _error;
  List<Movimiento> _todos = [];
  bool _hasMore = false;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool reset = true}) async {
    if (reset) setState(() { _loading = true; _error = null; });
    try {
      final page = await _repo.getMovimientos(
        limit: 50,
        cursor: reset ? null : _nextCursor,
      );
      setState(() {
        if (reset) {
          _todos = page.items;
        } else {
          _todos = [..._todos, ...page.items];
        }
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? mensajeDeError(e) : 'Error al cargar movimientos';
        _loading = false;
      });
    }
  }

  List<Movimiento> get _filtered {
    if (_selectedFilter == 0) return _todos;
    final wantIngreso = _selectedFilter == 1;
    return _todos.where((m) => m.lineaPrincipal.motivo.esIngreso == wantIngreso).toList();
  }

  BigInt get _ingresosCentavos => _todos
      .where((m) => m.lineaPrincipal.motivo.esIngreso)
      .fold(BigInt.zero, (acc, m) => acc + m.montoNeto.abs());

  BigInt get _gastosCentavos => _todos
      .where((m) => !m.lineaPrincipal.motivo.esIngreso)
      .fold(BigInt.zero, (acc, m) => acc + m.montoNeto.abs());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildSummaryCard(),
          _buildFilterChips(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          const Text(
            'Movimientos',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (!_loading)
            IconButton(
              onPressed: () => _cargar(),
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          GestureDetector(
            onTap: () => context.push('/estadisticas'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: AppColors.accentGreen, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ingresos',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      _loading
                          ? const SizedBox(
                              width: 60,
                              height: 14,
                              child: LinearProgressIndicator(
                                  backgroundColor: AppColors.surfaceVariant,
                                  color: AppColors.accentGreen),
                            )
                          : Text(
                              formatPesos(_ingresosCentavos),
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded,
                          color: AppColors.textSecondary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gastos',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                        _loading
                            ? const SizedBox(
                                width: 60,
                                height: 14,
                                child: LinearProgressIndicator(
                                    backgroundColor: AppColors.surfaceVariant,
                                    color: AppColors.gradientMid),
                              )
                            : Text(
                                formatPesos(_gastosCentavos),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(3, (i) {
          const labels = ['Todos', 'Ingresos', 'Gastos'];
          final active = _selectedFilter == i;
          return Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppGradients.brand : null,
                  color: active ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: active ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gradientStart,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _cargar(),
              child: const Text('Reintentar',
                  style: TextStyle(color: AppColors.gradientStart)),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final sections = _groupByDate(filtered);

    if (sections.isEmpty) {
      return const Center(
        child: Text('Sin movimientos',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: sections.length + (_hasMore && _selectedFilter == 0 ? 1 : 0),
      itemBuilder: (context, si) {
        if (si == sections.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton(
                onPressed: () => _cargar(reset: false),
                child: const Text('Cargar más',
                    style: TextStyle(color: AppColors.gradientStart)),
              ),
            ),
          );
        }

        final section = sections[si];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (si > 0) const SizedBox(height: 24),
            Text(
              section.label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: List.generate(section.items.length, (ii) {
                  final m = section.items[ii];
                  final linea = m.lineaPrincipal;
                  final esIngreso = linea.motivo.esIngreso;
                  final isLast = ii == section.items.length - 1;
                  return Column(
                    children: [
                      _MovRow(
                        label: linea.motivo.label,
                        hora: _formatHour(m.ocurridoEn),
                        centavos: m.montoNeto.abs(),
                        esIngreso: esIngreso,
                        icon: _iconForMotivo(linea.motivo),
                      ),
                      if (!isLast)
                        const Divider(
                          color: AppColors.border,
                          height: 1,
                          indent: 72,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MovRow extends StatelessWidget {
  const _MovRow({
    required this.label,
    required this.hora,
    required this.centavos,
    required this.esIngreso,
    required this.icon,
  });

  final String label;
  final String hora;
  final BigInt centavos;
  final bool esIngreso;
  final IconData icon;

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
              icon,
              color: esIngreso ? AppColors.accentGreen : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hora,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${esIngreso ? '+' : '-'}${formatPesos(centavos)}',
                style: TextStyle(
                  color: esIngreso
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                esIngreso ? 'Ingreso' : 'Gasto',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
