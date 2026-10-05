import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/nucleo/data/movimiento_filas.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

typedef _Seccion = ({String label, List<FilaLocal> filas});

List<_Seccion> _agruparPorDia(List<FilaLocal> filas, DateTime ahora) {
  final mapa = <String, List<FilaLocal>>{};
  for (final f in filas) {
    mapa.putIfAbsent(encabezadoDeFecha(f.local, ahora), () => []).add(f);
  }
  return [for (final e in mapa.entries) (label: e.key, filas: e.value)];
}

// ─────────────────────────────────────────────────────────────────────────────

class MovimientosTab extends StatefulWidget {
  const MovimientosTab({super.key, this.repository, this.offsetLocal});

  /// Por defecto el repositorio real.
  final NucleoRepository? repository;

  /// Solo para pruebas: zona horaria fija en lugar de la del equipo.
  final Duration? offsetLocal;

  @override
  State<MovimientosTab> createState() => _MovimientosTabState();
}

class _MovimientosTabState extends State<MovimientosTab> {
  static const _umbralScroll = 200.0;

  /// Páginas seguidas que se piden solas cuando la lista visible no llena la
  /// pantalla, antes de ofrecer el botón Cargar más.
  static const _maxEncadenadas = 5;

  late final NucleoRepository _repo = widget.repository ?? NucleoRepository();
  final _scroll = ScrollController();

  int _selectedFilter = 0; // 0=Todos, 1=Ingresos, 2=Gastos
  bool _loading = true;
  bool _cargandoMas = false;
  bool _errorMas = false;
  String? _error;
  List<Movimiento> _todos = [];
  bool _hasMore = false;
  int? _nextCursor;
  int _encadenadas = 0;

  /// Descarta respuestas de una carga anterior cuando se reinicia la lista.
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_revisarFinal);
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final gen = ++_generacion;
    _encadenadas = 0;
    setState(() {
      _loading = true;
      _cargandoMas = false;
      _errorMas = false;
      _error = null;
    });
    try {
      final page = await _repo.getMovimientos(limit: 50);
      if (!mounted || gen != _generacion) return;
      setState(() {
        _todos = page.items;
        _hasMore = page.hasMore && page.nextCursor != null;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
      _programarRevision();
    } catch (e) {
      if (!mounted || gen != _generacion) return;
      setState(() {
        _error = mensajeDeError(e);
        _loading = false;
      });
    }
  }

  /// Una sola petición a la vez: mientras haya una en vuelo no se lanza otra.
  Future<void> _cargarMas({bool automatica = false}) async {
    if (_loading || _cargandoMas || !_hasMore) return;
    final gen = _generacion;
    _encadenadas = automatica ? _encadenadas + 1 : 0;
    setState(() {
      _cargandoMas = true;
      _errorMas = false;
    });
    try {
      final page = await _repo.getMovimientos(limit: 50, cursor: _nextCursor);
      if (!mounted || gen != _generacion) return;
      setState(() {
        _todos = [..._todos, ...page.items];
        _hasMore = page.hasMore && page.nextCursor != null;
        _nextCursor = page.nextCursor;
        _cargandoMas = false;
      });
      _programarRevision();
    } catch (_) {
      if (!mounted || gen != _generacion) return;
      setState(() {
        _cargandoMas = false;
        _errorMas = true;
      });
    }
  }

  /// El scroll del usuario siempre cuenta como acción manual.
  void _revisarFinal() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _umbralScroll && !_errorMas) {
      _cargarMas();
    }
  }

  bool get _mostrarBoton =>
      _hasMore &&
      !_loading &&
      !_cargandoMas &&
      !_errorMas &&
      _encadenadas >= _maxEncadenadas;

  /// Con un filtro la lista visible puede no llenar la pantalla y entonces no
  /// hay scroll que dispare la siguiente página. Se encadenan pedidos hasta el
  /// tope y después queda el botón Cargar más como respaldo.
  void _programarRevision() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _errorMas || _loading || _cargandoMas || !_hasMore) {
        return;
      }
      final vacia = _filas.isEmpty;
      final sinRelleno = vacia ||
          (_scroll.hasClients &&
              _scroll.position.extentAfter < _umbralScroll);
      if (!sinRelleno) return;
      if (_encadenadas >= _maxEncadenadas) {
        setState(() {});
        return;
      }
      _cargarMas(automatica: true);
    });
  }

  void _elegirFiltro(int i) {
    setState(() => _selectedFilter = i);
    _encadenadas = 0;
    _programarRevision();
  }

  List<FilaLocal> get _filas => construirFilas(
        _todos,
        offset: widget.offsetLocal,
        ingreso: switch (_selectedFilter) {
          1 => true,
          2 => false,
          _ => null,
        },
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildSummaryCard(),
          _buildFilterChips(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          const Text(
            'Movimientos',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (!_loading)
            IconButton(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          GestureDetector(
            onTap: () => context.push('/estadisticas'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Stats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Total(
                titulo: 'Ingresos',
                centavos: totalIngresos(_todos),
                cargando: _loading,
                color: AppColors.accentGreen,
                icono: Icons.arrow_upward_rounded,
                fondoIcono: AppColors.accentGreen.withAlpha(20),
                colorIcono: AppColors.accentGreen,
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: _Total(
                  titulo: 'Gastos',
                  centavos: totalGastos(_todos),
                  cargando: _loading,
                  color: AppColors.textPrimary,
                  icono: Icons.arrow_downward_rounded,
                  fondoIcono: AppColors.surfaceVariant,
                  colorIcono: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(3, (i) {
          const labels = ['Todos', 'Ingresos', 'Gastos'];
          final active = _selectedFilter == i;
          return Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: GestureDetector(
              onTap: () => _elegirFiltro(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? AppGradients.brand : null,
                  color: active ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: active ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const EstadoVista.cargando();
    if (_error != null) {
      return EstadoVista.error(mensaje: _error!, onReintentar: _cargar);
    }

    final ahora = ahoraLocal(offset: widget.offsetLocal);
    final secciones = _agruparPorDia(_filas, ahora);

    if (secciones.isEmpty) {
      if (!_hasMore) return const EstadoVista.vacio(mensaje: 'Sin movimientos');
      if (_errorMas || _mostrarBoton) return Center(child: _buildPie());
      return const EstadoVista.cargando();
    }

    final hayPie = _cargandoMas || _errorMas || _mostrarBoton;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: secciones.length + (hayPie ? 1 : 0),
      itemBuilder: (context, si) {
        if (si == secciones.length) return _buildPie();
        final seccion = secciones[si];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (si > 0) const SizedBox(height: 24),
            Text(
              seccion.label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < seccion.filas.length; i++) ...[
                    MovimientoFilaTile(
                      fila: seccion.filas[i].fila,
                      subtitulo: formatHora(seccion.filas[i].local),
                      mostrarTipo: true,
                    ),
                    if (i < seccion.filas.length - 1)
                      const Divider(
                        color: AppColors.border,
                        height: 1,
                        indent: 72,
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPie() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _errorMas || _mostrarBoton
            ? TextButton(
                key: _errorMas ? null : const ValueKey('boton-cargar-mas'),
                onPressed: _cargarMas,
                child: Text(_errorMas ? 'Reintentar' : 'Cargar más',
                    style: const TextStyle(color: AppColors.gradientStart)),
              )
            : const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.gradientStart,
                  strokeWidth: 2,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.centavos,
    required this.cargando,
    required this.color,
    required this.icono,
    required this.fondoIcono,
    required this.colorIcono,
  });

  final String titulo;
  final BigInt centavos;
  final bool cargando;
  final Color color;
  final IconData icono;
  final Color fondoIcono;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: fondoIcono, shape: BoxShape.circle),
          child: Icon(icono, color: colorIcono, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              cargando
                  ? SizedBox(
                      width: 60,
                      height: 14,
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.surfaceVariant,
                        color: color,
                      ),
                    )
                  : Text(
                      formatPesos(centavos),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
