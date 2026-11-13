import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Texto único de la marca, para que la vista y sus pruebas no se separen.
const rotuloDatosDeMuestra = 'Datos de muestra';

/// Insignia que marca un dato que todavía no viene del backend.
///
/// El contrato no tiene endpoint de tarjetas ni de estadísticas, así que esas
/// cifras son fijas. Mientras lo sigan siendo deben verse como tales: la
/// insignia va pegada al dato que marca, no al encabezado de la pantalla.
class InsigniaMuestra extends StatelessWidget {
  const InsigniaMuestra({super.key, this.compacta = false});

  /// Deja solo la palabra «Muestra», para pegarla a un dato angosto.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    // La marca es contenido: crece con la letra del sistema como el dato que
    // acompaña. Solo se limita el tope para que no se coma la fila entera.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.6,
      child: Semantics(
        label: rotuloDatosDeMuestra,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            compacta ? 'Muestra' : rotuloDatosDeMuestra,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea de aviso para un bloque entero cuyos datos son de muestra.
class AvisoMuestra extends StatelessWidget {
  const AvisoMuestra({super.key, required this.detalle});

  /// Qué es lo que no viene del backend, en palabras del usuario.
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rotuloDatosDeMuestra. $detalle',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textMuted,
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$rotuloDatosDeMuestra: $detalle',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
