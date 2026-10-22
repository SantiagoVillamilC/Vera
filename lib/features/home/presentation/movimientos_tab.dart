import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/cargando_vera.dart';
import 'package:vera/core/widgets/marca_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
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
      final sinRelleno =
          vacia ||
          (_scroll.hasClients && _scroll.position.extentAfter < _umbralScroll);
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
          _buildAccesoCategorias(context),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Movimientos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (!_loading)
            _BotonCircular(
              key: const Key('recargar_movimientos'),
              etiqueta: 'Actualizar movimientos',
              icono: Icons.refresh_rounded,
              alTocar: _cargar,
            ),
          const SizedBox(width: 10),
          _BotonCircular(
            key: const Key('abrir_estadisticas'),
            etiqueta: 'Estadísticas',
            icono: Icons.bar_chart_rounded,
            claro: true,
            alTocar: () => context.push('/estadisticas'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final entro = totalIngresos(_todos);
    final salio = totalGastos(_todos);
    final suma = entro + salio;
    final pesoEntro = suma == BigInt.zero ? 1 : entro.toInt().clamp(1, 1 << 30);
    final pesoSalio = suma == BigInt.zero ? 1 : salio.toInt().clamp(1, 1 << 30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TarjetaVidrio(
        radio: 26,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 17),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Total(
                    titulo: 'Entró',
                    centavos: entro,
                    cargando: _loading,
                    color: AppColors.accentGreen,
                    conSigno: true,
                  ),
                ),
                Expanded(
                  child: _Total(
                    titulo: 'Salió',
                    centavos: salio,
                    cargando: _loading,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: pesoEntro,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: pesoSalio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B4C66),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const labels = ['Todos', 'Ingresos', 'Gastos'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Row(
          children: List.generate(3, (i) {
            final activo = _selectedFilter == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _elegirFiltro(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activo ? AppColors.botonOscuro : Colors.transparent,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: activo
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 17,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Acceso a la vista enriquecida. Es una sección y no una pestaña nueva
  /// para no tocar el orden del menú inferior.
  Widget _buildAccesoCategorias(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        key: const ValueKey('acceso-categorias'),
        onTap: () => context.push('/inteligencia'),
        behavior: HitTestBehavior.opaque,
        child: TarjetaVidrio(
          radio: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: AppGradients.orbe,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const MarcaVera(tamano: 28),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Vera clasifica, tú corriges',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: EsqueletoMovimientos(filas: 6),
      );
    }
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      itemCount: secciones.length + (hayPie ? 1 : 0),
      itemBuilder: (context, si) {
        if (si == secciones.length) return _buildPie();
        final seccion = secciones[si];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (si > 0) const SizedBox(height: 14),
            Text(
              seccion.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final f in seccion.filas)
              MovimientoFilaTile(
                fila: f.fila,
                subtitulo: formatHora(f.local),
                mostrarTipo: true,
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
                child: Text(
                  _errorMas ? 'Reintentar' : 'Cargar más',
                  style: const TextStyle(color: AppColors.gradientStart),
                ),
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
    this.conSigno = false,
  });

  final String titulo;
  final BigInt centavos;
  final bool cargando;
  final Color color;
  final bool conSigno;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 2),
        cargando
            ? SizedBox(
                width: 70,
                height: 16,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceVariant,
                  color: color,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  conSigno && centavos > BigInt.zero
                      ? '+${formatPesos(centavos)}'
                      : formatPesos(centavos),
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
      ],
    );
  }
}

/// Botón redondo del encabezado: oscuro sobre vidrio o claro cuando es la acción principal.
class _BotonCircular extends StatelessWidget {
  const _BotonCircular({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.alTocar,
    this.claro = false,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback alTocar;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        onTap: alTocar,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: claro ? AppColors.botonClaro : AppColors.botonOscuro,
            shape: BoxShape.circle,
            border: claro ? null : Border.all(color: AppColors.borderGlass),
          ),
          child: Icon(
            icono,
            size: 22,
            color: claro ? AppColors.tintaBotonClaro : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
