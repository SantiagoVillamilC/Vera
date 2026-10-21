import 'package:flutter/material.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/format/tarjeta_muestra.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/wip_badge.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';

/// Sin endpoint de tarjetas en el contrato: número, vencimiento, tipo, estado
/// y movimientos son de muestra. Solo el nombre impreso sale del perfil.
class TarjetasTab extends StatefulWidget {
  const TarjetasTab({super.key, this.session});

  /// Por defecto la sesión real.
  final SessionStore? session;

  @override
  State<TarjetasTab> createState() => _TarjetasTabState();
}

class _TarjetasTabState extends State<TarjetasTab> {
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  Future<void> _cargarNombre() async {
    try {
      final perfil =
          await (widget.session ?? defaultSessionStore).readProfile();
      if (mounted) setState(() => _nombre = nombreDePerfil(perfil));
    } catch (_) {
      // Sin perfil legible se queda el nombre genérico.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Mis Tarjetas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded,
                          color: AppColors.textSecondary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Agregar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 6),
                      WipBadge(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const WipAviso(),
            const SizedBox(height: 16),
            _TarjetaVisual(nombre: (_nombre ?? nombreTarjetaGenerico).toUpperCase()),
            const SizedBox(height: 12),
            const _PuntosPaginacion(),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  _DetailRow(label: 'Tarjeta', value: tarjetaMuestraRotulo),
                  _Separador(),
                  _DetailRow(label: 'Número', value: tarjetaMuestraNumero),
                  _Separador(),
                  _DetailRow(
                    label: 'Vencimiento',
                    value: tarjetaMuestraVencimiento,
                  ),
                  _Separador(),
                  _DetailRow(label: 'Tipo', value: tarjetaMuestraTipo),
                  _Separador(),
                  _DetailRowEstado(label: 'Estado'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Últimos movimientos con tarjeta',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < movimientosTarjetaMuestra.length; i++) ...[
                    _TxItem(datos: movimientosTarjetaMuestra[i]),
                    if (i < movimientosTarjetaMuestra.length - 1)
                      const Divider(
                        color: AppColors.border,
                        height: 1,
                        indent: 72,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVisual extends StatelessWidget {
  const _TarjetaVisual({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientStart.withAlpha(80),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VERA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Débito',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              tarjetaMuestraNumero,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'VISA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PuntosPaginacion extends StatelessWidget {
  const _PuntosPaginacion();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 6,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.textMuted,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AppColors.border,
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRowEstado extends StatelessWidget {
  const _DetailRowEstado({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                tarjetaMuestraEstado,
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  const _TxItem({required this.datos});

  final MovimientoTarjetaMuestra datos;

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
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(datos.icono, color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  datos.concepto,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  datos.fecha,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-${formatPesosInt(datos.centavos)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
