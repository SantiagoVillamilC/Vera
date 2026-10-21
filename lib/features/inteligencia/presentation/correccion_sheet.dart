import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/inteligencia/data/categorias.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Abre la hoja de corrección y devuelve lo elegido, o null si se cerró.
Future<CorreccionElegida?> mostrarHojaDeCorreccion(
  BuildContext context,
  MovimientoEnriquecido movimiento,
) =>
    showModalBottomSheet<CorreccionElegida>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaDeCorreccion(movimiento: movimiento),
    );

/// Hoja con las categorías visibles para la dirección del movimiento y un
/// nombre de comercio opcional. `sin_categoria` no se ofrece.
class HojaDeCorreccion extends StatefulWidget {
  const HojaDeCorreccion({super.key, required this.movimiento});

  final MovimientoEnriquecido movimiento;

  @override
  State<HojaDeCorreccion> createState() => _HojaDeCorreccionState();
}

class _HojaDeCorreccionState extends State<HojaDeCorreccion> {
  late String? _categoria = widget.movimiento.sinCategoria
      ? null
      : widget.movimiento.categoria;
  final _nombre = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _cambiaCategoria =>
      _categoria != null && _categoria != widget.movimiento.categoria;

  bool get _cambiaNombre => _nombre.text.trim().isNotEmpty;

  /// La sugerencia solo se puede confirmar si es una categoría que esta hoja
  /// ofrece para la dirección del movimiento. Un depósito con categoría de
  /// gasto no se confirma en silencio: el usuario elige una de ingreso.
  bool get _sugerenciaAplicable {
    if (!widget.movimiento.categoriaSugerida) return false;
    return categoriasPara(widget.movimiento.direccion)
        .any((c) => c.codigo == widget.movimiento.categoria);
  }

  /// Confirmar una sugerencia envía la misma categoría. El backend la guarda en
  /// memoria y la fila pasa de origen sugerido a `memoria`.
  bool get _confirmaSugerencia =>
      _sugerenciaAplicable &&
      _categoria != null &&
      _categoria == widget.movimiento.categoria;

  bool get _puedeAplicar =>
      _cambiaCategoria || _cambiaNombre || _confirmaSugerencia;

  void _aplicar() {
    if (!_puedeAplicar) return;
    Navigator.of(context).pop(
      CorreccionElegida(
        categoria: _cambiaCategoria || _confirmaSugerencia ? _categoria : null,
        nombreComercio: _cambiaNombre ? _nombre.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorias = categoriasPara(widget.movimiento.direccion);
    final sugiere = _sugerenciaAplicable;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        key: const ValueKey('hoja-correccion'),
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movimiento.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sugiere
                          ? 'Vera la sugiere. Confírmala o elige otra.'
                          : 'Elige la categoría correcta',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (sugiere) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.accent.withAlpha(90),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 11,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Sugerencia: ${widget.movimiento.categoriaNombre}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  itemCount: categorias.length,
                  itemBuilder: (context, i) {
                    final c = categorias[i];
                    return _OpcionDeCategoria(
                      categoria: c,
                      activa: _categoria == c.codigo,
                      onTap: () => setState(() => _categoria = c.codigo),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: TextField(
                  key: const ValueKey('campo-nombre-comercio'),
                  controller: _nombre,
                  maxLength: 80,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    counterStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                    labelText: 'Nombre del comercio (opcional)',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    hintText: 'Nombre que verás en este pago',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.borderFocus),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GestureDetector(
                  key: const ValueKey('boton-aplicar-correccion'),
                  onTap: _puedeAplicar ? _aplicar : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _puedeAplicar ? AppGradients.brand : null,
                      color: _puedeAplicar ? null : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _confirmaSugerencia ? 'Confirmar categoría' : 'Aplicar',
                      style: TextStyle(
                        color: _puedeAplicar
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionDeCategoria extends StatelessWidget {
  const _OpcionDeCategoria({
    required this.categoria,
    required this.activa,
    required this.onTap,
  });

  final CategoriaVisible categoria;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        key: ValueKey('opcion-categoria-${categoria.codigo}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: activa ? AppColors.gradientStart.withAlpha(46) : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activa ? AppColors.gradientMid : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  categoria.nombre,
                  style: TextStyle(
                    color: activa
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                activa
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: activa ? AppColors.gradientMid : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
