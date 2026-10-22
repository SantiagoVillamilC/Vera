import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vera/core/theme/app_theme.dart';

const mensajeSinRed = 'Sin conexión. Revisa tu internet e intenta de nuevo.';

/// Sin dart:io para que compile en web: en web los fallos de red llegan como
/// http.ClientException.
bool esErrorDeRed(Object e) =>
    e is TimeoutException || e is http.ClientException;

enum _Tipo { cargando, vacio, sinRed, error }

class EstadoVista extends StatelessWidget {
  const EstadoVista.cargando({super.key})
    : _tipo = _Tipo.cargando,
      mensaje = null,
      onReintentar = null;

  const EstadoVista.vacio({super.key, this.mensaje = 'Sin datos'})
    : _tipo = _Tipo.vacio,
      onReintentar = null;

  const EstadoVista.sinRed({super.key, required this.onReintentar})
    : _tipo = _Tipo.sinRed,
      mensaje = mensajeSinRed;

  const EstadoVista.error({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  }) : _tipo = _Tipo.error;

  /// Elige entre sin red y error según [esErrorDeRed]. [mensaje] es el texto
  /// a mostrar cuando no es un error de red (por defecto, el del propio error).
  factory EstadoVista.deError(
    Object e, {
    Key? key,
    String? mensaje,
    required VoidCallback onReintentar,
  }) {
    if (esErrorDeRed(e)) {
      return EstadoVista.sinRed(key: key, onReintentar: onReintentar);
    }
    return EstadoVista.error(
      key: key,
      mensaje: mensaje ?? e.toString(),
      onReintentar: onReintentar,
    );
  }

  final _Tipo _tipo;
  final String? mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    switch (_tipo) {
      case _Tipo.cargando:
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.gradientStart,
            strokeWidth: 2,
          ),
        );
      case _Tipo.vacio:
        return Center(
          child: Text(
            mensaje!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
        );
      case _Tipo.sinRed:
      case _Tipo.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _tipo == _Tipo.sinRed
                      ? Icons.cloud_off_rounded
                      : Icons.error_outline_rounded,
                  color: AppColors.textMuted,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onReintentar,
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(color: AppColors.gradientStart),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
