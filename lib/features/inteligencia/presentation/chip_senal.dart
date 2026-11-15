import 'package:flutter/material.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Chip que nombra la señal de la cascada que decidió la categoría.
///
/// Es informativo, no una alerta: la abstención del clasificador se pinta con
/// el mismo estilo neutro que el resto, porque es parte del diseño de la
/// cascada. Al tocarlo se abre la explicación de esa señal.
class ChipSenal extends StatelessWidget {
  const ChipSenal({super.key, required this.senal, this.interactivo = true});

  final SenalDeCategoria senal;

  /// Falso para pintarlo sin abrir la explicación, donde ya hay otra acción.
  final bool interactivo;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.paleta.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.paleta.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 12,
            color: context.paleta.textSecondary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              senal.chip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.paleta.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!interactivo) {
      return Semantics(
        label: 'Señal: ${senal.chip}',
        excludeSemantics: true,
        child: KeyedSubtree(key: ValueKey('senal-${senal.chip}'), child: chip),
      );
    }
    return Semantics(
      button: true,
      label: 'Señal: ${senal.chip}. Toca para saber por qué',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('senal-${senal.chip}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => mostrarExplicacionDeSenal(context, senal),
        child: chip,
      ),
    );
  }
}

/// Abre la explicación de una señal. Solo informa: no cambia nada.
Future<void> mostrarExplicacionDeSenal(
  BuildContext context,
  SenalDeCategoria senal,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.paleta.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          22 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senal.chip,
              key: const ValueKey('explicacion-titulo'),
              style: TextStyle(
                color: context.paleta.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              senal.explicacion,
              key: const ValueKey('explicacion-texto'),
              style: TextStyle(
                color: context.paleta.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
