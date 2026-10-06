import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/utils/currency.dart';
import 'package:vera/features/home/presentation/movimientos_tab.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

// TODO: leer desde AuthRepository.getNombreCompleto() (flutter_secure_storage)
const _mockNombre = 'Elisa';

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _saldoVisible = true;

  final _nucleo = NucleoRepository();
  int? _saldoCentavos;
  bool _errorSaldo = false;
  KycEstado? _kyc;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await Future.wait([_cargarSaldo(), _cargarKyc()]);
  }

  Future<void> _cargarSaldo() async {
    try {
      final s = await _nucleo.getSaldo();
      if (mounted) setState(() { _saldoCentavos = s.montoCentavos; _errorSaldo = false; });
    } catch (_) {
      if (mounted) setState(() => _errorSaldo = true);
    }
  }

  Future<void> _cargarKyc() async {
    try {
      final k = await _nucleo.getKycEstado();
      if (mounted) setState(() => _kyc = k);
    } catch (_) {}
  }

  void _onNavTap(int i) {
    if (i == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vera copilot próximamente')),
      );
      return;
    }
    setState(() => _tab = i);
  }

  Widget get _body => switch (_tab) {
        1 => const MovimientosTab(),
        3 => const TarjetasTab(),
        4 => const PerfilTab(),
        _ => _InicioTab(
            saldoVisible: _saldoVisible,
            saldoCentavos: _saldoCentavos,
            errorSaldo: _errorSaldo,
            kyc: _kyc,
            onToggleSaldo: () => setState(() => _saldoVisible = !_saldoVisible),
            onRefresh: _cargar,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _body,
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: _onNavTap,
        bottomPadding: bottom,
      ),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.bottomPadding,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final double bottomPadding;

  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.bar_chart_rounded, 'Movim.'),
    (Icons.mic_rounded, ''),
    (Icons.credit_card_rounded, 'Tarjetas'),
    (Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64 + bottomPadding + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 64 + bottomPadding,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: Row(
                  children: List.generate(5, (i) {
                    if (i == 2) return const Expanded(child: SizedBox());
                    final active = currentIndex == i;
                    final (icon, label) = _items[i];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 22,
                                color: active
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted),
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: active
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                )),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding + 20,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gradientMid.withAlpha(120),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inicio ─────────────────────────────────────────────────────

class _InicioTab extends StatelessWidget {
  const _InicioTab({
    required this.saldoVisible,
    required this.onToggleSaldo,
    required this.saldoCentavos,
    required this.errorSaldo,
    required this.kyc,
    required this.onRefresh,
  });

  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final int? saldoCentavos;
  final bool errorSaldo;
  final KycEstado? kyc;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          saldoVisible: saldoVisible,
          onToggleSaldo: onToggleSaldo,
          saldoCentavos: saldoCentavos,
          errorSaldo: errorSaldo,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.gradientStart,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ActionsCard(),
                  if (kyc != null) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _KycBlock(kyc: kyc!),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _MovimientosSection(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header (purple top) ────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.saldoVisible,
    required this.onToggleSaldo,
    required this.saldoCentavos,
    required this.errorSaldo,
  });

  final bool saldoVisible;
  final VoidCallback onToggleSaldo;
  final int? saldoCentavos;
  final bool errorSaldo;

  Widget _buildSaldoWidget() {
    if (errorSaldo) {
      return const Text(
        'Error al cargar',
        style: TextStyle(color: Colors.white54, fontSize: 20),
      );
    }
    if (saldoCentavos == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white54,
        ),
      );
    }
    return Text(
      saldoVisible ? formatPesosConCentavos(saldoCentavos!) : '\$ ••••••',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 42,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'En tu cuenta',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    // TODO: reemplazar con AuthRepository.getNombreCompleto()
                    _mockNombre,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Text(
                  'Mis CVUs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildSaldoWidget()),
              GestureDetector(
                onTap: onToggleSaldo,
                child: Icon(
                  saldoVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Actions card ───────────────────────────────────────────────

class _ActionsCard extends StatelessWidget {
  const _ActionsCard();

  static const _actions = [
    (Icons.send_rounded, 'Enviar\ndinero', '/enviar'),
    (Icons.swap_horiz_rounded, 'Enviar\npor llave', '/enviar-por-llave'),
    (Icons.add_circle_outline_rounded, 'Recargar', '/recargar'),
    (Icons.receipt_long_rounded, 'Pagar\nservicios', ''),
    (Icons.credit_card_rounded, 'Pedir\ntarjeta', ''),
    (Icons.key_rounded, 'Mis\nclaves', ''),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.05,
              children: _actions.map((a) {
                final (icon, label, route) = a;
                return _ActionCell(
                  icon: icon,
                  label: label,
                  onTap: route.isNotEmpty
                      ? () => context.push(route)
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Próximamente')),
                          ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _CardRow(),
        ],
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.gradientStart, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('VERA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    )),
                Text('VISA',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Vera Débito',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
              SizedBox(height: 3),
              Text('•••• •••• •••• 4417',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

// ── Bloque KYC (depósito de bajo monto) ───────────────────────

class _KycBlock extends StatelessWidget {
  const _KycBlock({required this.kyc});
  final KycEstado kyc;

  @override
  Widget build(BuildContext context) {
    final tope = kyc.topeMensualCentavos;
    final disponible = kyc.disponibleMesCentavos;
    final usado = (tope != null && disponible != null) ? tope - disponible : null;
    final progreso = (tope != null && usado != null && tope > 0)
        ? (usado / tope).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  kyc.productoLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (tope != null)
                Text(
                  'Tope ${formatPesos(tope)}/mes',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          if (disponible != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Disponible este mes', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text(
                  formatPesos(disponible),
                  style: const TextStyle(color: AppColors.accentGreen, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
          if (progreso != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 5,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progreso > 0.85 ? Colors.orange : AppColors.gradientStart,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Movimientos recientes en home (preview, últimos 3) ─────────
// Usa NucleoRepository directamente con FutureBuilder para
// mostrar un preview sin estado complejo en HomeScreen.

class _MovimientosSection extends StatelessWidget {
  const _MovimientosSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Últimos Movimientos',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
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
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<MovimientosPage>(
          future: NucleoRepository().getMovimientos(limit: 3),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: AppColors.gradientStart,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            final items = snap.data?.items ?? [];
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text('Sin movimientos aún',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14)),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: List.generate(items.length, (i) {
                  final m = items[i];
                  final linea = m.lineaPrincipal;
                  final esIngreso = linea.motivo.esIngreso;
                  final isLast = i == items.length - 1;
                  return Column(
                    children: [
                      _MovItem(
                        label: linea.motivo.label,
                        fecha: _formatFecha(m.ocurridoEn),
                        centavos: m.montoNeto.abs(),
                        esIngreso: esIngreso,
                        icon: _iconForMotivo(linea.motivo),
                      ),
                      if (!isLast)
                        const Divider(
                            color: AppColors.border,
                            height: 1,
                            indent: 72),
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _formatFecha(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(dt.year, dt.month, dt.day);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  if (day == today) return 'Hoy $h:$m';
  if (day == yesterday) return 'Ayer';
  final months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  return '${dt.day} ${months[dt.month - 1]}';
}

IconData _iconForMotivo(MotivoLinea motivo) => switch (motivo) {
      MotivoLinea.deposito => Icons.arrow_downward_rounded,
      MotivoLinea.transferenciaRecibida => Icons.arrow_downward_rounded,
      MotivoLinea.envio => Icons.arrow_upward_rounded,
      MotivoLinea.gravamen => Icons.account_balance_rounded,
      MotivoLinea.devolucion => Icons.refresh_rounded,
      MotivoLinea.devolucionGravamen => Icons.refresh_rounded,
      MotivoLinea.desconocido => Icons.swap_horiz_rounded,
    };

class _MovItem extends StatelessWidget {
  const _MovItem({
    required this.label,
    required this.fecha,
    required this.centavos,
    required this.esIngreso,
    required this.icon,
  });

  final String label;
  final String fecha;
  final int centavos;
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
              color: esIngreso ? AppColors.accentGreen : AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 3),
                Text(fecha,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${esIngreso ? '+' : '-'}${formatPesos(centavos)}',
            style: TextStyle(
              color: esIngreso ? AppColors.accentGreen : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
