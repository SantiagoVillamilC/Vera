import 'package:flutter/material.dart';
import 'package:vera/core/theme/paleta_vera.dart';

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
    backgroundColor: context.paleta.surface,
    title: Text(titulo, style: TextStyle(color: context.paleta.textPrimary)),
    content: Text(
      detalle,
      style: TextStyle(color: context.paleta.textSecondary),
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
          style: TextStyle(color: context.paleta.error),
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
