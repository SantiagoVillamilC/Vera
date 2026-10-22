import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/fechas.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/marca_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Texto y color con que se rotula el estado de un envío.
(String, Color) etiquetaDeEstado(EstadoTransferencia estado) => switch (estado) {
  EstadoTransferencia.confirmada => ('Exitoso', AppColors.accentGreen),
  EstadoTransferencia.creada => ('Creado', AppColors.warning),
  EstadoTransferencia.reservada => ('Reservado', AppColors.warning),
  EstadoTransferencia.despachada => ('En camino', AppColors.warning),
  EstadoTransferencia.fallida => ('Fallido', AppColors.error),
  EstadoTransferencia.compensada => ('Compensado', AppColors.warning),
  EstadoTransferencia.indeterminada ||
  EstadoTransferencia.desconocido => ('Por confirmar', AppColors.warning),
};

/// «+57 310 ••• 4821» a partir de un celular E.164. Nunca muestra el número completo.
String celularEnmascarado(String e164) {
  final d = e164.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('57') && d.length == 12) {
    return '+57 ${d.substring(2, 5)} ••• ${d.substring(8)}';
  }
  if (d.length < 4) return '•••';
  return '••• ${d.substring(d.length - 4)}';
}

typedef FilaDetalle = ({String etiqueta, String valor});

/// Pantalla final de un envío: dice qué pasó, el monto y el detalle del comprobante.
/// El mensaje y el estado vienen del servidor; aquí solo se presentan.
class ResultadoEnvioScreen extends StatelessWidget {
  const ResultadoEnvioScreen({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.exito,
    required this.montoCentavos,
    required this.estado,
    required this.filas,
    this.alVolver,
  });

  final String titulo;
  final String mensaje;

  /// El envío salió bien: marca azul. Si no, un aviso de que hay que revisar el historial.
  final bool exito;
  final BigInt montoCentavos;
  final EstadoTransferencia estado;

  /// Filas del detalle antes de la fecha de envío, el estado y la referencia.
  final List<FilaDetalle> filas;

  /// Por defecto vuelve al Home.
  final VoidCallback? alVolver;

  void _volver(BuildContext context) {
    final accion = alVolver;
    if (accion != null) return accion();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/home');
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (textoEstado, colorEstado) = etiquetaDeEstado(estado);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FondoVera(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    children: [
                      _Cabecera(exito: exito, estado: estado),
                      const SizedBox(height: 22),
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mensaje,
                        key: const Key('resultado_mensaje'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        formatPesos(montoCentavos),
                        key: const Key('resultado_monto'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TarjetaVidrio(
                        opaca: true,
                        radio: 26,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            for (final f in filas) _Fila(f.etiqueta, f.valor),
                            _Fila(
                              'Estado',
                              textoEstado,
                              colorValor: colorEstado,
                              conPunto: true,
                              llave: const Key('resultado_estado'),
                              ultima: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        key: const Key('volver_inicio'),
                        onTap: () => _volver(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.botonClaro,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Text(
                            'Volver al inicio',
                            style: TextStyle(
                              color: AppColors.tintaBotonClaro,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculos concéntricos con la marca del resultado y unos destellos alrededor.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.exito, required this.estado});

  final bool exito;
  final EstadoTransferencia estado;

  @override
  Widget build(BuildContext context) {
    final fallo = estado == EstadoTransferencia.fallida;
    final color = exito
        ? AppColors.gradientStart
        : (fallo ? AppColors.error : AppColors.warning);
    final icono = exito
        ? Icons.check_rounded
        : (fallo ? Icons.close_rounded : Icons.schedule_rounded);
    return SizedBox(
      width: 260,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(36),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(120),
            ),
          ),
          Container(
            key: exito ? const Key('icono_exito') : const Key('icono_aviso'),
            width: 70,
            height: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icono, color: Colors.white, size: 40),
          ),
          const Positioned(
            left: 22,
            top: 22,
            child: ChispaVera(tamano: 22, color: AppColors.accentGreen),
          ),
          const Positioned(
            right: 24,
            top: 56,
            child: ChispaVera(tamano: 22, color: AppColors.gradientStart),
          ),
          Positioned(
            right: 34,
            top: 6,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gradientStart,
              ),
            ),
          ),
          Positioned(
            left: 48,
            bottom: 24,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(
    this.etiqueta,
    this.valor, {
    this.colorValor = AppColors.textPrimary,
    this.conPunto = false,
    this.llave,
    this.ultima = false,
  });

  final String etiqueta;
  final String valor;
  final Color colorValor;
  final bool conPunto;
  final Key? llave;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (conPunto) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorValor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          valor,
                          key: llave,
                          style: TextStyle(
                            color: colorValor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!ultima) Divider(color: Colors.white.withAlpha(22), height: 1),
      ],
    );
  }
}

/// Fecha y hora local de un instante, como se rotula en el comprobante.
String fechaDeComprobante(DateTime instante, {Duration? offset}) =>
    formatFechaLarga(aLocal(instante.toUtc(), offset: offset));
