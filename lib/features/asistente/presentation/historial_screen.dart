import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/fondo_vera.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/confirmar_borrado.dart';

/// Historial de conversaciones con Vera. Al tocar una, hace pop con su id.
class HistorialAsistenteScreen extends StatefulWidget {
  const HistorialAsistenteScreen({super.key, this.repository});

  /// Por defecto el repositorio real.
  final AsistenteRepository? repository;

  @override
  State<HistorialAsistenteScreen> createState() =>
      _HistorialAsistenteScreenState();
}

class _HistorialAsistenteScreenState extends State<HistorialAsistenteScreen> {
  late final AsistenteRepository _repo =
      widget.repository ?? AsistenteRepository();
  final _scroll = ScrollController();
  final _items = <ConversacionVera>[];
  String? _cursor;
  bool _hayMas = false;
  bool _cargando = true;
  Object? _error;

  /// Falló pedir una página siguiente: se muestra con Reintentar al pie de la lista.
  Object? _errorMas;

  static const _umbralScroll = 240.0;

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

  void _revisarFinal() {
    if (!_scroll.hasClients || _cargando || !_hayMas || _errorMas != null) {
      return;
    }
    if (_scroll.position.extentAfter < _umbralScroll) _cargar();
  }

  Future<void> _cargar({bool recargar = false}) async {
    if (recargar) {
      _items.clear();
      _cursor = null;
    }
    setState(() {
      _cargando = true;
      _error = null;
      _errorMas = null;
    });
    try {
      final p = await _repo.listarConversaciones(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _cursor = p.nextCursor;
        _hayMas = p.hasMore;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_items.isEmpty) {
            _error = e;
          } else {
            _errorMas = e;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
        // Una primera página corta no genera scroll que pida la siguiente.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revisarFinal();
        });
      }
    }
  }

  Future<void> _borrar(ConversacionVera c) async {
    final ok = await confirmarBorrado(
      context,
      titulo: '¿Borrar esta conversación?',
      detalle: 'También se cancelan sus acciones pendientes.',
    );
    if (ok != true) return;
    await _ejecutarBorrado(
      () => _repo.borrarConversacion(c.id),
      () => _items.remove(c),
    );
  }

  Future<void> _borrarTodas() async {
    final ok = await confirmarBorrado(
      context,
      titulo: '¿Borrar todo el historial?',
      detalle: 'No se puede deshacer.',
    );
    if (ok != true) return;
    await _ejecutarBorrado(_repo.borrarConversaciones, () {
      _items.clear();
      _hayMas = false;
      _cursor = null;
    });
  }

  /// Solo quita de la lista lo que el servidor confirmó borrado. Si falla, el aviso
  /// ofrece repetir la misma operación sin volver a pedir confirmación.
  Future<void> _ejecutarBorrado(
    Future<void> Function() operacion,
    VoidCallback alQuitar,
  ) async {
    try {
      await operacion();
      if (mounted) setState(alQuitar);
    } catch (e) {
      if (!mounted) return;
      avisarErrorDeBorrado(
        context,
        mensajeDeError(e),
        () => _ejecutarBorrado(operacion, alQuitar),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FondoVera(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            'Historial',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            if (_items.isNotEmpty)
              IconButton(
                tooltip: 'Borrar todo',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _borrarTodas,
              ),
          ],
        ),
        body: _cuerpo(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _items.isEmpty) return const EstadoVista.cargando();
    if (_error != null && _items.isEmpty) {
      return EstadoVista.deError(
        _error!,
        mensaje: mensajeDeError(_error!),
        onReintentar: () => _cargar(recargar: true),
      );
    }
    if (_items.isEmpty) {
      return const EstadoVista.vacio(mensaje: 'Aún no has hablado con Vera.');
    }
    return RefreshIndicator(
      onRefresh: () => _cargar(recargar: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hayMas || _errorMas != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == _items.length) return _pie();
          final c = _items[i];
          return Dismissible(
            key: ValueKey(c.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _borrar(c);
              return false; // _borrar ya quita el elemento de la lista si salió bien
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
            child: ListTile(
              onTap: () => context.pop(c.id),
              tileColor: Colors.white.withAlpha(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.borderGlass),
              ),
              title: Text(
                c.titulo.isEmpty ? 'Conversación' : c.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _fecha(c.ultimaActividad),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pie() {
    if (_errorMas != null) {
      return Column(
        children: [
          Text(
            mensajeDeError(_errorMas!),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year}  ${dos(l.hour)}:${dos(l.minute)}';
  }
}
