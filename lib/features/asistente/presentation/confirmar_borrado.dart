import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

/// Diálogo de confirmación de un borrado del historial de Vera. Las etiquetas se pueden
/// cambiar para reusarlo en otras decisiones de sí o no sobre los datos del asistente.
Future<bool?> confirmarBorrado(
  BuildContext context, {
  required String titulo,
  required String detalle,
  String etiquetaConfirmar = 'Borrar',
  String etiquetaCancelar = 'Cancelar',
}) => showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(titulo, style: const TextStyle(color: AppColors.textPrimary)),
    content: Text(
      detalle,
      style: const TextStyle(color: AppColors.textSecondary),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: Text(etiquetaCancelar),
      ),
      TextButton(
        onPressed: () => Navigator.pop(ctx, true),
        child: Text(
          etiquetaConfirmar,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    ],
  ),
);

/// Aviso de un borrado fallido, con la misma operación a un toque.
void avisarErrorDeBorrado(
  BuildContext context,
  String mensaje,
  VoidCallback reintentar,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      action: SnackBarAction(label: 'Reintentar', onPressed: reintentar),
    ),
  );
}
