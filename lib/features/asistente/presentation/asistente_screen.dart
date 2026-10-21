import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/data/grabador_voz.dart';
import 'package:vera/features/asistente/presentation/accion_card.dart';
import 'package:vera/features/asistente/presentation/fondo_asistente.dart';

/// Burbuja del chat. [texto] de una burbuja de voz arranca vacío y se llena con la transcripción.
class _Burbuja {
  _Burbuja({
    required this.id,
    required this.esUsuario,
    required this.texto,
    this.esVoz = false,
    this.transcribiendo = false,
    this.esError = false,
    this.accion,
  });

  final String id;
  final bool esUsuario;
  String texto;
  final bool esVoz;
  bool transcribiendo;
  final bool esError;
  AccionPendiente? accion;
}

class AsistenteScreen extends StatefulWidget {
  /// [conversacionId] reabre una conversación del historial.
  const AsistenteScreen({super.key, this.conversacionId});
  final String? conversacionId;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _repo = AsistenteRepository();
  final _grabador = GrabadorVoz();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _burbujas = <_Burbuja>[];

  String? _conversacionId;
  bool _cargandoHistorial = false;
  bool _enviando = false;
  bool _grabando = false;
  Duration _tiempoGrabado = Duration.zero;
  Timer? _cronometro;
  int _seq = 0;

  static const _sugerencias = [
    '¿Cuánto tengo disponible?',
    '¿En qué gasté más este mes?',
    'Mándale 50 mil a Laura',
  ];

  @override
  void initState() {
    super.initState();
    _conversacionId = widget.conversacionId;
    _grabador.onTope = _detenerYEnviarVoz;
    if (_conversacionId != null) _cargarMensajes();
  }

  @override
  void dispose() {
    _cronometro?.cancel();
    _grabador.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _idLocal() => 'local-${_seq++}';

  Future<void> _cargarMensajes() async {
    setState(() => _cargandoHistorial = true);
    try {
      final p = await _repo.listarMensajes(_conversacionId!, limit: 100);
      // La API devuelve del más nuevo al más viejo.
      final ordenados = p.items.reversed.map(
        (m) => _Burbuja(
          id: m.id,
          esUsuario: m.rol == RolMensaje.usuario,
          texto: m.texto,
          esVoz: m.canal == CanalMensaje.voz,
          accion: m.accionPendiente,
        ),
      );
      if (mounted) setState(() => _burbujas.addAll(ordenados));
      _irAlFinal();
    } catch (e) {
      _agregarError(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _agregarError(String msg) {
    if (!mounted) return;
    setState(
      () => _burbujas.add(
        _Burbuja(id: _idLocal(), esUsuario: false, texto: msg, esError: true),
      ),
    );
    _irAlFinal();
  }

  void _nuevaConversacion() {
    setState(() {
      _burbujas.clear();
      _conversacionId = null;
    });
  }

  // ── Envío de texto ──────────────────────────────────────────

  Future<void> _enviarTexto([String? predefinido]) async {
    final texto = (predefinido ?? _ctrl.text).trim();
    if (texto.isEmpty || _enviando) return;
    _ctrl.clear();
    setState(() {
      _enviando = true;
      _burbujas.add(_Burbuja(id: _idLocal(), esUsuario: true, texto: texto));
    });
    _irAlFinal();
    try {
      final r = await _repo.enviarTexto(
        texto: texto,
        conversacionId: _conversacionId,
      );
      _agregarRespuesta(r);
    } catch (e) {
      _agregarError(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _agregarRespuesta(RespuestaAsistente r) {
    if (!mounted) return;
    setState(() {
      _conversacionId = r.conversacionId;
      _burbujas.add(
        _Burbuja(
          id: r.mensajeId,
          esUsuario: false,
          texto: r.texto,
          accion: r.accionPendiente,
        ),
      );
    });
    _irAlFinal();
  }

  // ── Voz ─────────────────────────────────────────────────────

  Future<void> _alternarGrabacion() async {
    if (_enviando) return;
    if (_grabando) return _detenerYEnviarVoz();
    if (!await _grabador.tienePermiso()) {
      _agregarError('Activa el permiso del micrófono para hablarle a Vera.');
      return;
    }
    await _grabador.iniciar();
    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tiempoGrabado += const Duration(seconds: 1));
    });
    setState(() {
      _grabando = true;
      _tiempoGrabado = Duration.zero;
    });
  }

  Future<void> _cancelarGrabacion() async {
    _cronometro?.cancel();
    await _grabador.cancelar();
    if (mounted) setState(() => _grabando = false);
  }

  Future<void> _detenerYEnviarVoz() async {
    if (!_grabando) return;
    _cronometro?.cancel();
    final bytes = await _grabador.detener();
    if (!mounted) return;
    setState(() => _grabando = false);
    if (bytes == null) return;

    final burbuja = _Burbuja(
      id: _idLocal(),
      esUsuario: true,
      texto: '',
      esVoz: true,
      transcribiendo: true,
    );
    setState(() {
      _enviando = true;
      _burbujas.add(burbuja);
    });
    _irAlFinal();
    try {
      final r = await _repo.enviarVoz(
        audioM4a: bytes,
        conversacionId: _conversacionId,
      );
      if (mounted) {
        setState(() {
          burbuja
            ..texto = r.transcripcion ?? ''
            ..transcribiendo = false;
        });
      }
      _agregarRespuesta(r);
    } on AudioFueraDeLimiteException {
      _quitar(burbuja);
      _agregarError('El audio es demasiado largo. Máximo 60 segundos.');
    } catch (e) {
      _quitar(burbuja);
      _agregarError(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _quitar(_Burbuja b) {
    if (mounted) setState(() => _burbujas.remove(b));
  }

  // ── UI ──────────────────────────────────────────────────────

  Future<void> _abrirHistorial() async {
    final id = await context.push<String>('/asistente/historial');
    if (id != null && mounted) {
      context.pushReplacement('/asistente', extra: id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Vera',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _enviando ? null : _nuevaConversacion,
          ),
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history_rounded),
            onPressed: _abrirHistorial,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: FondoAsistente(intenso: _grabando)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(child: _lista()),
                _barraEntrada(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_cargandoHistorial) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gradientStart,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_burbujas.isEmpty) return _vacio();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount:
          _burbujas.length +
          (_enviando && !_burbujas.last.transcribiendo ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _burbujas.length) return const _Escribiendo();
        final b = _burbujas[i];
        return _BurbujaView(
          burbuja: b,
          repo: _repo,
          onAccion: (a) => setState(() => b.accion = a),
        );
      },
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: AppGradients.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿En qué te ayudo?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Escríbeme o háblame.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _sugerencias)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => _enviarTexto(s),
                    backgroundColor: AppColors.surfaceVariant,
                    labelStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    side: const BorderSide(color: AppColors.border),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraEntrada() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(200),
        border: const Border(top: BorderSide(color: AppColors.borderGlass)),
      ),
      child: _grabando ? _barraGrabando() : _barraTexto(),
    );
  }

  Widget _barraTexto() {
    final hayTexto = _ctrl.text.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            enabled: !_enviando,
            maxLength: 1000,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Escribe a Vera',
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _enviarTexto(),
          ),
        ),
        const SizedBox(width: 8),
        _BotonRedondo(
          icono: hayTexto ? Icons.arrow_upward_rounded : Icons.mic_rounded,
          onTap: _enviando
              ? null
              : (hayTexto ? _enviarTexto : _alternarGrabacion),
          semantica: hayTexto ? 'Enviar' : 'Grabar audio',
        ),
      ],
    );
  }

  Widget _barraGrabando() {
    final restante = LimitesAudio.maxDuracion - _tiempoGrabado;
    String mmss(Duration d) =>
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(
          tooltip: 'Descartar',
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.textSecondary,
          ),
          onPressed: _cancelarGrabacion,
        ),
        const Icon(Icons.fiber_manual_record, color: AppColors.error, size: 14),
        const SizedBox(width: 8),
        Text(
          mmss(_tiempoGrabado),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            restante.inSeconds <= 10
                ? 'Termina en ${restante.inSeconds}s'
                : 'Grabando…',
            style: TextStyle(
              color: restante.inSeconds <= 10
                  ? AppColors.warning
                  : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        _BotonRedondo(
          icono: Icons.stop_rounded,
          onTap: _detenerYEnviarVoz,
          semantica: 'Enviar audio',
        ),
      ],
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.onTap,
    required this.semantica,
  });
  final IconData icono;
  final VoidCallback? onTap;
  final String semantica;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantica,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: onTap == null ? null : AppGradients.brand,
            color: onTap == null ? AppColors.surfaceVariant : null,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _BurbujaView extends StatelessWidget {
  const _BurbujaView({
    required this.burbuja,
    required this.repo,
    required this.onAccion,
  });
  final _Burbuja burbuja;
  final AsistenteRepository repo;
  final ValueChanged<AccionPendiente> onAccion;

  @override
  Widget build(BuildContext context) {
    final b = burbuja;
    final color = b.esError
        ? AppColors.error.withAlpha(30)
        : b.esUsuario
        ? AppColors.gradientMid
        : AppColors.surfaceVariant.withAlpha(235);
    final ancho = MediaQuery.of(context).size.width * 0.82;
    return Align(
      alignment: b.esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        constraints: BoxConstraints(maxWidth: ancho),
        child: Column(
          crossAxisAlignment: b.esUsuario
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(b.esUsuario ? 18 : 4),
                  bottomRight: Radius.circular(b.esUsuario ? 4 : 18),
                ),
                border: b.esError
                    ? Border.all(color: AppColors.error.withAlpha(90))
                    : null,
              ),
              child: b.transcribiendo
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transcribiendo…',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.esVoz) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.mic_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            b.texto.isEmpty ? '(sin transcripción)' : b.texto,
                            style: TextStyle(
                              color: b.esError
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (b.accion != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ancho),
                child: AccionCard(
                  key: ValueKey(b.accion!.id),
                  accion: b.accion!,
                  repo: repo,
                  onActualizada: onAccion,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 12),
        child: SizedBox(
          width: 28,
          height: 14,
          child: LinearProgressIndicator(
            color: AppColors.gradientStart,
            backgroundColor: AppColors.border,
          ),
        ),
      ),
    );
  }
}
