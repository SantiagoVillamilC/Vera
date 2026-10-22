import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart'
    show montoConSigno;
import 'package:vera/features/inteligencia/data/categorias.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

/// Abre la hoja de corrección y devuelve lo elegido, o null si se cerró.
Future<CorreccionElegida?> mostrarHojaDeCorreccion(
  BuildContext context,
  MovimientoEnriquecido movimiento,
) => showModalBottomSheet<CorreccionElegida>(
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
    return categoriasPara(
      widget.movimiento.direccion,
    ).any((c) => c.codigo == widget.movimiento.categoria);
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const ValueKey('hoja-correccion'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF15202F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Elige la categoría correcta',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (sugiere) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Vera la sugiere. Confírmala o elige otra.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withAlpha(24),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.accentGreen.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Sugerencia: ${widget.movimiento.categoriaNombre}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.botonOscuro,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.movimiento.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        montoConSigno(widget.movimiento.montoConSigno),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in categorias)
                      _OpcionDeCategoria(
                        categoria: c,
                        activa: _categoria == c.codigo,
                        onTap: () => setState(() => _categoria = c.codigo),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Nombre que verás en este pago',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('campo-nombre-comercio'),
                  controller: _nombre,
                  maxLength: 80,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Nombre del comercio (opcional)',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.borderFocus,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  key: const ValueKey('boton-aplicar-correccion'),
                  onTap: _puedeAplicar ? _aplicar : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _puedeAplicar
                          ? AppColors.botonClaro
                          : Colors.white.withAlpha(18),
                      borderRadius: BorderRadius.circular(31),
                    ),
                    child: Text(
                      _confirmaSugerencia ? 'Confirmar categoría' : 'Aplicar',
                      style: TextStyle(
                        color: _puedeAplicar
                            ? AppColors.tintaBotonClaro
                            : AppColors.textMuted,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción de categoría: píldora con borde; la elegida se rellena de azul con una marca.
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
    return GestureDetector(
      key: ValueKey('opcion-categoria-${categoria.codigo}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: activa ? 20 : 22,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: activa ? const Color(0xFF2F7BD0) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: activa ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activa) ...[
              const Icon(Icons.check_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              categoria.nombre,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
