import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

/// Historial de conversaciones con Vera. Al tocar una, hace pop con su id.
class HistorialAsistenteScreen extends StatefulWidget {
  const HistorialAsistenteScreen({super.key});

  @override
  State<HistorialAsistenteScreen> createState() =>
      _HistorialAsistenteScreenState();
}

class _HistorialAsistenteScreenState extends State<HistorialAsistenteScreen> {
  final _repo = AsistenteRepository();
  final _items = <ConversacionVera>[];
  int? _cursor;
  bool _hayMas = false;
  bool _cargando = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool recargar = false}) async {
    if (recargar) {
      _items.clear();
      _cursor = null;
    }
    setState(() {
      _cargando = true;
      _error = null;
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
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _borrar(ConversacionVera c) async {
    final ok = await _confirmar(
      '¿Borrar esta conversación?',
      'También se cancelan sus acciones pendientes.',
    );
    if (ok != true) return;
    try {
      await _repo.borrarConversacion(c.id);
      if (mounted) setState(() => _items.remove(c));
    } catch (e) {
      _aviso(mensajeDeError(e));
    }
  }

  Future<void> _borrarTodas() async {
    final ok = await _confirmar(
      '¿Borrar todo el historial?',
      'No se puede deshacer.',
    );
    if (ok != true) return;
    try {
      await _repo.borrarConversaciones();
      if (mounted) setState(_items.clear);
    } catch (e) {
      _aviso(mensajeDeError(e));
    }
  }

  void _aviso(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<bool?> _confirmar(String titulo, String detalle) => showDialog<bool>(
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
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Borrar', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hayMas ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return TextButton(
              onPressed: _cargando ? null : _cargar,
              child: const Text('Ver más'),
            );
          }
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
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
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

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year}  ${dos(l.hour)}:${dos(l.minute)}';
  }
}
