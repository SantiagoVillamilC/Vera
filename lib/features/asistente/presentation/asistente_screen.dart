import 'dart:async';

import 'dart:typed_data';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/asistente/data/asistente_mensajes.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/data/grabador_voz.dart';
import 'package:vera/features/asistente/data/lector_voz.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/asistente/presentation/accion_card.dart';
import 'package:vera/features/asistente/presentation/activacion_vera_view.dart';
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
    this.reintentable = false,
    this.anunciar = false,
    this.acciones = const [],
    this.accion,
  });

  final String id;
  final bool esUsuario;
  String texto;
  final bool esVoz;
  bool transcribiendo;
  final bool esError;

  /// Un error tras el cual conviene reintentar el mismo envío (misma clave de idempotencia).
  final bool reintentable;

  /// Una respuesta recién llegada: el lector de pantalla la anuncia. Las del historial no.
  final bool anunciar;

  /// Botones de una burbuja de error: por ejemplo Reintentar y Escribir tras un audio no entendido.
  final List<({String etiqueta, VoidCallback alTocar})> acciones;

  /// El envío de este mensaje del usuario falló y sigue sin llegar al servidor.
  bool noEnviado = false;
  AccionPendiente? accion;
}

/// Un mensaje o audio en camino. La [clave] y la [conversacionId] se fijan al crearlo: un reintento
/// debe llevar exactamente el cuerpo original, o el backend responde IdempotencyConflict.
class _Envio {
  _Envio({
    this.texto,
    this.bytes,
    required this.burbuja,
    required this.conversacionId,
  }) : clave = nuevaClaveEnvio();

  final String? texto;
  final Uint8List? bytes;
  final _Burbuja burbuja;
  final String? conversacionId;
  final String clave;
}

class AsistenteScreen extends StatefulWidget {
  /// [conversacionId] reabre una conversación del historial.
  const AsistenteScreen({
    super.key,
    this.conversacionId,
    this.repository,
    this.grabador,
    this.lector,
    this.preferenciaLectura,
    this.abrirAjustes,
  });
  final String? conversacionId;

  /// Solo para pruebas; por defecto el repositorio real.
  final AsistenteRepository? repository;

  /// Solo para pruebas; por defecto el micrófono real.
  final GrabadorDeVoz? grabador;

  /// Solo para pruebas; por defecto la voz del sistema.
  final LectorDeVoz? lector;

  /// Solo para pruebas; por defecto el almacenamiento seguro del dispositivo.
  final PreferenciaLectura? preferenciaLectura;

  /// Solo para pruebas; por defecto abre los ajustes de la app.
  final Future<void> Function()? abrirAjustes;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen>
    with WidgetsBindingObserver {
  late final AsistenteRepository _repo =
      widget.repository ?? AsistenteRepository();
  late final GrabadorDeVoz _grabador = widget.grabador ?? GrabadorVoz();
  late final LectorDeVoz _lector = widget.lector ?? LectorFlutterTts();
  late final PreferenciaLectura _preferencia =
      widget.preferenciaLectura ?? const PreferenciaLecturaSegura();
  final _foco = FocusNode();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _burbujas = <_Burbuja>[];

  String? _conversacionId;
  bool _cargandoHistorial = false;
  bool _enviando = false;
  bool _grabando = false;
  bool _leerEnVozAlta = false;
  bool _leyendo = false;
  Duration _tiempoGrabado = Duration.zero;
  ConsentimientoAsistente? _consent;
  bool _consultandoConsent = true;
  Object? _errorConsulta;
  bool _aceptando = false;
  String? _errorActivacion;
  _Envio? _pendiente;
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
    WidgetsBinding.instance.addObserver(this);
    _grabador.onTope = _detenerYEnviarVoz;
    _cargarPreferencia();
    _iniciar();
  }

  Future<void> _cargarPreferencia() async {
    try {
      final activada = await _preferencia.activada();
      if (mounted) setState(() => _leerEnVozAlta = activada);
    } catch (_) {
      // Sin preferencia legible la lectura queda apagada.
    }
  }

  /// Segundo plano o una llamada entrante: la grabación se cancela y la lectura se detiene.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_grabando) _cancelarGrabacion();
    _detenerLectura();
  }

  /// El historial solo se pide con consentimiento vigente.
  Future<void> _iniciar() async {
    await _consultarConsentimiento();
    if (mounted && _chatDisponible && _conversacionId != null) {
      _cargarMensajes();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cronometro?.cancel();
    _grabador.dispose();
    _lector.dispose();
    _foco.dispose();
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
      _agregarError(mensajeDeErrorAsistente(e));
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

  void _agregarError(
    String msg, {
    bool reintentable = false,
    List<({String etiqueta, VoidCallback alTocar})> acciones = const [],
  }) {
    if (!mounted) return;
    setState(
      () => _burbujas.add(
        _Burbuja(
          id: _idLocal(),
          esUsuario: false,
          texto: msg,
          esError: true,
          reintentable: reintentable,
          anunciar: true,
          acciones: acciones,
        ),
      ),
    );
    _irAlFinal();
  }

  void _nuevaConversacion() {
    _detenerLectura();
    setState(() {
      _burbujas.clear();
      _conversacionId = null;
    });
  }

  // ── Consentimiento de IA ────────────────────────────────────

  /// Sin consentimiento vigente no se abre el chat. Si la consulta falla tampoco: se ofrece
  /// reintentar. Devuelve si el servidor dice que falta autorización.
  Future<bool> _consultarConsentimiento() async {
    try {
      final c = await _repo.consultarConsentimiento();
      if (mounted) setState(() => _consent = c);
      return !c.autorizado;
    } catch (e) {
      if (mounted) setState(() => _errorConsulta = e);
      return false;
    } finally {
      if (mounted) setState(() => _consultandoConsent = false);
    }
  }

  Future<void> _reintentarConsulta() async {
    setState(() {
      _consultandoConsent = true;
      _errorConsulta = null;
    });
    await _iniciar();
  }

  bool get _chatDisponible =>
      !_consultandoConsent &&
      _errorConsulta == null &&
      _consent?.autorizado == true;

  Future<void> _activar() async {
    final c = _consent;
    if (c == null || _aceptando) return;
    setState(() {
      _aceptando = true;
      _errorActivacion = null;
    });
    try {
      await _repo.otorgarConsentimiento(c.versionTexto);
      if (mounted) setState(() => _consent = c.autorizadoAhora());
      if (mounted && _conversacionId != null && _burbujas.isEmpty) {
        _cargarMensajes();
      }
    } catch (e) {
      if (mounted) setState(() => _errorActivacion = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _aceptando = false);
    }
  }

  void _ahoraNo() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ── Envío ───────────────────────────────────────────────────

  Future<void> _enviarTexto([String? predefinido]) async {
    final texto = (predefinido ?? _ctrl.text).trim();
    if (texto.isEmpty || _enviando) return;
    _ctrl.clear();
    final burbuja = _Burbuja(id: _idLocal(), esUsuario: true, texto: texto);
    setState(() => _burbujas.add(burbuja));
    _irAlFinal();
    await _ejecutar(
      _Envio(texto: texto, burbuja: burbuja, conversacionId: _conversacionId),
    );
  }

  /// Reintenta el último envío con su misma clave: si el servidor ya lo guardó, devuelve la misma
  /// respuesta en vez de duplicar el turno.
  Future<void> _reintentar() async {
    final envio = _pendiente;
    if (envio == null || _enviando) return;
    setState(() {
      if (_burbujas.isNotEmpty && _burbujas.last.esError) {
        _burbujas.removeLast();
      }
    });
    await _ejecutar(envio);
  }

  Future<void> _ejecutar(_Envio envio) async {
    final burbuja = envio.burbuja;
    _detenerLectura();
    setState(() {
      _enviando = true;
      burbuja.noEnviado = false;
      if (envio.bytes != null) burbuja.transcribiendo = true;
    });
    try {
      final r = envio.bytes != null
          ? await _repo.enviarVoz(
              audioM4a: envio.bytes!,
              idempotencyKey: envio.clave,
              conversacionId: envio.conversacionId,
            )
          : await _repo.enviarTexto(
              texto: envio.texto!,
              idempotencyKey: envio.clave,
              conversacionId: envio.conversacionId,
            );
      _pendiente = null;
      if (mounted && envio.bytes != null) {
        setState(() {
          burbuja
            ..texto = r.transcripcion ?? ''
            ..transcribiendo = false;
        });
      }
      _agregarRespuesta(r);
    } on AudioFueraDeLimiteException {
      _pendiente = null;
      _quitar(burbuja);
      _agregarError('El audio es demasiado largo. Máximo 60 segundos.');
    } catch (e) {
      if (e is ApiException && e.code == 'ConsentRequired') {
        await _pedirActivacion(envio, e);
        return;
      }
      if (envio.bytes != null &&
          e is ApiException &&
          e.code == 'AudioNotUnderstood') {
        _pendiente = null;
        _quitar(burbuja);
        _agregarError(
          mensajeDeErrorAsistente(e),
          acciones: [
            (etiqueta: 'Reintentar', alTocar: _alternarGrabacion),
            (etiqueta: 'Escribir', alTocar: _foco.requestFocus),
          ],
        );
        return;
      }
      final reintentable = esErrorReenviable(e);
      _pendiente = reintentable ? envio : null;
      if (mounted) {
        setState(() {
          burbuja.transcribiendo = false;
          burbuja.noEnviado = true;
        });
      }
      if (envio.bytes != null && !reintentable) _quitar(burbuja);
      _agregarError(mensajeDeErrorAsistente(e), reintentable: reintentable);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// El servidor dice que falta la autorización: el mensaje no se envió, así que se quita de la
  /// conversación, el texto vuelve al campo y se presenta la activación en vez de un error.
  Future<void> _pedirActivacion(_Envio envio, ApiException e) async {
    _pendiente = null;
    if (mounted) {
      setState(() {
        _burbujas.remove(envio.burbuja);
        _enviando = false;
        if (envio.texto != null) _ctrl.text = envio.texto!;
      });
    }
    final falta = await _consultarConsentimiento();
    if (!falta && _errorConsulta == null) {
      _agregarError(mensajeDeErrorAsistente(e));
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
          anunciar: true,
          accion: r.accionPendiente,
        ),
      );
    });
    _irAlFinal();
    if (_leerEnVozAlta) _leerRespuesta(r.texto);
  }

  // ── Lectura en voz alta ─────────────────────────────────────

  void _leerRespuesta(String texto) {
    if (texto.trim().isEmpty) return;
    setState(() => _leyendo = true);
    _lector.leer(
      texto,
      alTerminar: () {
        if (mounted) setState(() => _leyendo = false);
      },
    );
  }

  Future<void> _detenerLectura() async {
    if (!_leyendo) return;
    await _lector.detener();
    if (mounted) setState(() => _leyendo = false);
  }

  Future<void> _alternarLectura() async {
    final nueva = !_leerEnVozAlta;
    setState(() => _leerEnVozAlta = nueva);
    if (!nueva) await _detenerLectura();
    try {
      await _preferencia.guardar(nueva);
    } catch (_) {
      // Si no se puede guardar, la preferencia vale solo en esta sesión.
    }
  }

  // ── Voz ─────────────────────────────────────────────────────

  Future<void> _alternarGrabacion() async {
    if (_enviando) return;
    if (_grabando) return _detenerYEnviarVoz();
    await _detenerLectura();
    if (!await _grabador.tienePermiso(pedir: false)) {
      final seguir = await _explicarMicrofono();
      if (seguir != true || !mounted) return;
      if (!await _grabador.tienePermiso()) {
        _agregarError(
          'No tenemos permiso para usar el micrófono. Puedes escribir tu pregunta o habilitarlo en los ajustes.',
          acciones: [
            (
              etiqueta: 'Abrir ajustes',
              alTocar: () =>
                  (widget.abrirAjustes ?? AppSettings.openAppSettings)(),
            ),
            (etiqueta: 'Escribir', alTocar: _foco.requestFocus),
          ],
        );
        return;
      }
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

  /// Antes del diálogo del sistema, explica para qué se usa el micrófono.
  Future<bool?> _explicarMicrofono() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Vera necesita el micrófono',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: const Text(
        'Lo usa solo mientras grabas, para escuchar tu pregunta. El audio no queda guardado en tu teléfono.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );

  Future<void> _cancelarGrabacion() async {
    _cronometro?.cancel();
    await _grabador.cancelar();
    if (mounted) setState(() => _grabando = false);
  }

  Future<void> _detenerYEnviarVoz() async {
    if (!_grabando) return;
    _cronometro?.cancel();
    final duracion = _tiempoGrabado;
    final bytes = await _grabador.detener();
    if (!mounted) return;
    setState(() => _grabando = false);
    // Un toque sin hablar: menos de un segundo se descarta sin enviar.
    if (bytes == null || duracion < const Duration(seconds: 1)) return;

    final burbuja = _Burbuja(
      id: _idLocal(),
      esUsuario: true,
      texto: '',
      esVoz: true,
      transcribiendo: true,
    );
    setState(() => _burbujas.add(burbuja));
    _irAlFinal();
    await _ejecutar(
      _Envio(bytes: bytes, burbuja: burbuja, conversacionId: _conversacionId),
    );
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
    final chat = _chatDisponible;
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Vera',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (chat) ...[
            IconButton(
              tooltip: _leerEnVozAlta
                  ? 'Dejar de leer las respuestas en voz alta'
                  : 'Leer las respuestas en voz alta',
              icon: Icon(
                _leerEnVozAlta
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
              onPressed: _alternarLectura,
            ),
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
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: FondoAsistente(intenso: _grabando)),
          chat ? _chat() : _antesDelChat(),
        ],
      ),
    );
  }

  Widget _chat() => SafeArea(
    bottom: false,
    child: Column(
      children: [
        Expanded(child: _lista()),
        if (_leyendo) _chipLeyendo(),
        _barraEntrada(),
      ],
    ),
  );

  /// Un toque detiene la lectura en voz alta.
  Widget _chipLeyendo() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      button: true,
      label: 'Detener la lectura',
      excludeSemantics: true,
      onTap: _detenerLectura,
      child: ActionChip(
        key: const Key('detener_lectura'),
        avatar: const Icon(Icons.stop_rounded, size: 18),
        label: const Text('Leyendo… Toca para detener'),
        onPressed: _detenerLectura,
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );

  /// Lo que se ve mientras no hay consentimiento vigente: nada del chat ni de sus envíos.
  Widget _antesDelChat() {
    if (_consultandoConsent) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.gradientStart,
          strokeWidth: 2.5,
        ),
      );
    }
    final error = _errorConsulta;
    if (error != null) {
      return SafeArea(
        child: EstadoVista.deError(
          error,
          mensaje: mensajeDeError(error),
          onReintentar: _reintentarConsulta,
        ),
      );
    }
    return ActivacionVeraView(
      consentimiento: _consent!,
      activando: _aceptando,
      error: _errorActivacion,
      onActivar: _activar,
      onAhoraNo: _ahoraNo,
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
          onReintentar: _reintentar,
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
            focusNode: _foco,
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
    required this.onReintentar,
  });
  final _Burbuja burbuja;
  final VoidCallback onReintentar;
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
            Semantics(
              liveRegion: b.anunciar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
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
                              b.texto.isEmpty
                                  ? (b.esVoz && b.esUsuario
                                        ? 'Audio sin enviar'
                                        : '(sin transcripción)')
                                  : b.texto,
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
            ),
            if (b.noEnviado)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'No enviado',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (b.acciones.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [
                  for (final a in b.acciones)
                    TextButton(
                      onPressed: a.alTocar,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentPink,
                      ),
                      child: Text(a.etiqueta),
                    ),
                ],
              ),
            if (b.reintentable)
              TextButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPink,
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
