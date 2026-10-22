import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/tintes.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
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

  Future<void> _aplicar(String transaccionId, CorreccionElegida elegida) async {
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
      messenger.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
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
      body: FondoVera(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildResumen(),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Volver',
            excludeSemantics: true,
            onTap: () => context.canPop() ? context.pop() : null,
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.botonOscuro,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Movimientos con categoría',
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Text(
                  'Vera clasifica, tú corriges',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (_aplicando)
            const SizedBox(
              width: 20,
              height: 20,
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
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final total = _movimientos.length;
    final sinCategoria = _movimientos.where((m) => m.sinCategoria).length;
    final listo = !_cargando && _error == null;
    final titulo = !listo
        ? 'Un momento'
        : sinCategoria == 0
        ? 'Todos los movimientos tienen categoría'
        : '$sinCategoria de $total sin categoría';
    final avance = listo && total > 0 ? (total - sinCategoria) / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TarjetaVidrio(
        radio: 26,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: avance,
                      strokeWidth: 6,
                      color: AppColors.gradientStart,
                      backgroundColor: Colors.white.withAlpha(30),
                    ),
                  ),
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.gradientStart,
                    size: 26,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca una etiqueta para ajustarla. Vera aprende de tus cambios.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      itemCount: _movimientos.length,
      separatorBuilder: (_, _) =>
          Divider(color: Colors.white.withAlpha(24), height: 1),
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
    final fecha = [
      encabezadoDeFecha(local, ahora),
      if (origen.isNotEmpty) origen,
    ].join(' · ');

    return Padding(
      key: ValueKey('enriquecido-${m.transaccionId}'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                _EtiquetaDeCategoria(
                  movimiento: m,
                  onTap: onCorregir == null ? null : () => onCorregir!(m),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                montoConSigno(m.montoConSigno),
                style: TextStyle(
                  color: m.esIngreso
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fecha,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              Text(
                formatHora(local),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de categoría con su color; sin categoría es un botón punteado «+ Categoría».
class _EtiquetaDeCategoria extends StatelessWidget {
  const _EtiquetaDeCategoria({required this.movimiento, this.onTap});

  final MovimientoEnriquecido movimiento;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sin = movimiento.sinCategoria;
    final tinte = sin
        ? const TinteVera(Color(0x1A6CB6F2), AppColors.accent)
        : tinteDeCategoria(movimiento.categoriaNombre);
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!sin) ...[
          Icon(
            iconoDeCategoria(movimiento.categoriaNombre),
            size: 18,
            color: tinte.tinta,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            sin ? '+ Categoría' : movimiento.categoriaNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tinte.tinta,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    return GestureDetector(
      key: ValueKey('categoria-${movimiento.transaccionId}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: sin
          ? CustomPaint(
              painter: _BordePunteado(color: tinte.tinta.withAlpha(170)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tinte.fondo,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: contenido,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: tinte.fondo,
                borderRadius: BorderRadius.circular(999),
              ),
              child: contenido,
            ),
    );
  }
}

class _BordePunteado extends CustomPainter {
  const _BordePunteado({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final borde = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(borde);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), trazo);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteado old) => old.color != color;
}
