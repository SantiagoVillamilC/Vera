import 'package:flutter/material.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/format/tarjeta_muestra.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/tintes.dart';
import 'package:vera/core/widgets/adornos_vera.dart';
import 'package:vera/core/widgets/marca_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
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
      final perfil = await (widget.session ?? defaultSessionStore)
          .readProfile();
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mis tarjetas',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TarjetaVisual(
              nombre: (_nombre ?? nombreTarjetaGenerico).toUpperCase(),
            ),
            const SizedBox(height: 14),
            const _PuntosPaginacion(),
            const SizedBox(height: 22),
            const SizedBox(height: 22),
            TarjetaVidrio(
              radio: 24,
              opaca: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  const _DetailRow(
                    label: 'Tarjeta',
                    value: tarjetaMuestraRotulo,
                  ),
                  const _Separador(),
                  const _DetailRow(
                    label: 'Número',
                    value: tarjetaMuestraNumero,
                  ),
                  const _Separador(),
                  const _DetailRow(
                    label: 'Vencimiento',
                    value: tarjetaMuestraVencimiento,
                  ),
                  const _Separador(),
                  const _DetailRow(label: 'Tipo', value: tarjetaMuestraTipo),
                  const _Separador(),
                  const _DetailRowEstado(label: 'Estado'),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Movimientos con tarjeta',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in movimientosTarjetaMuestra) _TxItem(datos: m),
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
    // Una tarjeta física no crece con la letra del sistema: se queda en su tamaño.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: 1,
      child: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        gradient: AppGradients.tarjetaSaldo,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: ConAdorno(
        tipo: AdornoTarjeta.curvas,
        radio: 32,
        expandir: true,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MarcaVera(tamano: 34, chispa: false),
                const SizedBox(width: 8),
                const Text(
                  'vera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontFamilyFallback: ['Georgia', 'serif'],
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderGlass),
                  ),
                  child: const Text(
                    tarjetaMuestraEstado,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEFF5F8), Color(0xFFB9CBD6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
              ],
            ),
            const Spacer(),
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                tarjetaMuestraNumero,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TITULAR',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VENCE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const Text(
                      tarjetaMuestraVencimiento,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                const Text(
                  'VISA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
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
          width: 28,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.gradientMid,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.textMuted,
            shape: BoxShape.circle,
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
    return Divider(
      color: Colors.white.withAlpha(22),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
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
                  fontSize: 15,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
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
                  fontSize: 15,
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

TinteVera _tinteDeConcepto(String concepto) => switch (concepto) {
  'Restaurante' => TinteVera.naranja,
  'Combustible' => TinteVera.ambar,
  _ => TinteVera.morado,
};

class _TxItem extends StatelessWidget {
  const _TxItem({required this.datos});

  final MovimientoTarjetaMuestra datos;

  @override
  Widget build(BuildContext context) {
    final tinte = _tinteDeConcepto(datos.concepto);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: tinte.fondo,
              shape: BoxShape.circle,
            ),
            child: Icon(datos.icono, color: tinte.tinta, size: 22),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  datos.fecha,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
