import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/inteligencia/presentation/correccion_sheet.dart';

/// Vista enriquecida de los movimientos: categoría, contraparte legible y
/// corrección. Consume `GET /v1/inteligencia/movimientos` y el POST de
/// correcciones. Nunca dibuja identificadores de cuenta.
class MovimientosEnriquecidosScreen extends StatefulWidget {
  const MovimientosEnriquecidosScreen({
    super.key,
    this.repository,
    this.offsetLocal,
  });

  /// Por defecto el repositorio real.
  final InteligenciaRepository? repository;

  /// Solo para pruebas: zona horaria fija en lugar de la del equipo.
  final Duration? offsetLocal;

  @override
  State<MovimientosEnriquecidosScreen> createState() =>
      _MovimientosEnriquecidosScreenState();
}

class _MovimientosEnriquecidosScreenState
    extends State<MovimientosEnriquecidosScreen> {
  late final InteligenciaRepository _repo =
      widget.repository ?? InteligenciaRepository();

  bool _cargando = true;
  bool _aplicando = false;
  String? _error;
  List<MovimientoEnriquecido> _movimientos = const [];

  /// Descarta respuestas de una carga anterior cuando se reinicia la lista.
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final gen = ++_generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final movimientos = await _repo.listarMovimientos();
      if (!mounted || gen != _generacion) return;
      setState(() {
        _movimientos = movimientos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || gen != _generacion) return;
      setState(() {
        _error = mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  Future<void> _abrirCorreccion(MovimientoEnriquecido movimiento) async {
    if (_aplicando) return;
    final elegida = await mostrarHojaDeCorreccion(context, movimiento);
    if (!mounted || elegida == null || elegida.vacia) return;
    await _aplicar(movimiento.transaccionId, elegida);
  }

  Future<void> _aplicar(
    String transaccionId,
    CorreccionElegida elegida,
  ) async {
    setState(() => _aplicando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resultado = await _repo.corregir(
        transaccionId: transaccionId,
        categoria: elegida.categoria,
        nombreComercio: elegida.nombreComercio,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(_textoDeCambios(resultado.filasCambiadas))),
      );
      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      final conflicto =
          e.code == 'CorreccionEnCurso' || e.code == 'CopiaSinReconstruir';
      messenger.showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e)),
          action: conflicto
              ? SnackBarAction(
                  label: 'Reintentar',
                  onPressed: () {
                    if (mounted) _aplicar(transaccionId, elegida);
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(mensajeDeError(e))),
      );
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  static String _textoDeCambios(int filas) => switch (filas) {
        0 => 'Sin cambios',
        1 => 'Movimiento actualizado',
        _ => '$filas movimientos actualizados',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildResumen(),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movimientos con categoría',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Vera clasifica, tú corriges',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_aplicando)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: AppColors.gradientStart,
                strokeWidth: 2,
              ),
            )
          else
            IconButton(
              key: const ValueKey('recargar-inteligencia'),
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final sinCategoria = _movimientos.where((m) => m.sinCategoria).length;
    final texto = _cargando || _error != null
        ? 'Un momento'
        : sinCategoria == 0
            ? 'Todos los movimientos tienen categoría'
            : '$sinCategoria de ${_movimientos.length} sin categoría';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.accent,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const Text(
              'Toca una etiqueta',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const EstadoVista.cargando();
    if (_error != null) {
      return EstadoVista.error(mensaje: _error!, onReintentar: _cargar);
    }
    if (_movimientos.isEmpty) {
      return const EstadoVista.vacio(mensaje: 'Sin movimientos');
    }
    final ahora = ahoraLocal(offset: widget.offsetLocal);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: _movimientos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _TileEnriquecido(
        movimiento: _movimientos[i],
        ahora: ahora,
        offsetLocal: widget.offsetLocal,
        onCorregir: _aplicando ? null : _abrirCorreccion,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TileEnriquecido extends StatelessWidget {
  const _TileEnriquecido({
    required this.movimiento,
    required this.ahora,
    required this.onCorregir,
    this.offsetLocal,
  });

  final MovimientoEnriquecido movimiento;
  final DateTime ahora;
  final Duration? offsetLocal;
  final void Function(MovimientoEnriquecido)? onCorregir;

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    final local = m.enLocal(offset: offsetLocal);
    final origen = etiquetaDeOrigen(m.origenCategoria);
    final subtitulo = [
      encabezadoDeFecha(local, ahora),
      formatHora(local),
      if (origen.isNotEmpty) origen,
    ].join(' · ');

    return Container(
      key: ValueKey('enriquecido-${m.transaccionId}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: m.esIngreso
                  ? AppColors.accentGreen.withAlpha(20)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              m.esIngreso
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: m.esIngreso
                  ? AppColors.accentGreen
                  : AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                _EtiquetaDeCategoria(
                  movimiento: m,
                  onTap: onCorregir == null ? null : () => onCorregir!(m),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            montoConSigno(m.montoConSigno),
            style: TextStyle(
              color: m.esIngreso
                  ? AppColors.accentGreen
                  : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaDeCategoria extends StatelessWidget {
  const _EtiquetaDeCategoria({required this.movimiento, this.onTap});

  final MovimientoEnriquecido movimiento;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sin = movimiento.sinCategoria;
    return GestureDetector(
      key: ValueKey('categoria-${movimiento.transaccionId}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sin
              ? AppColors.gradientStart.withAlpha(46)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: sin ? AppColors.gradientMid : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sin ? Icons.add_rounded : Icons.sell_outlined,
              size: 12,
              color: sin ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              sin ? '+ Categoría' : movimiento.categoriaNombre,
              style: TextStyle(
                color: sin ? AppColors.accent : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
