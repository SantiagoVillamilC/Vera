import 'dart:async';
import 'dart:math' as math;

import 'dart:typed_data';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/marca_vera.dart';
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
    this.session,
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

  /// Solo para pruebas; por defecto la sesión real (el saludo usa el nombre guardado).
  final SessionStore? session;

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

  /// Con el teclado abierto se escribe; por defecto se habla.
  bool _modoTexto = false;
  String? _nombre;
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
    _cargarNombre();
    _iniciar();
  }

  /// Primer nombre de la persona (o de la empresa) para el saludo.
  Future<void> _cargarNombre() async {
    try {
      final perfil = await (widget.session ?? defaultSessionStore)
          .readProfile();
      final completo = (perfil.nombreCompleto ?? perfil.razonSocial)?.trim();
      if (completo == null || completo.isEmpty) return;
      if (mounted) {
        setState(() => _nombre = completo.split(RegExp(r'\s+')).first);
      }
    } catch (_) {
      // Sin perfil legible el saludo no lleva nombre.
    }
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
    if (texto.isEmpty || _enviando || !_chatDisponible) return;
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
            (etiqueta: 'Escribir', alTocar: _escribir),
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

  /// Abre el teclado y deja el cursor en el campo de texto.
  void _escribir() {
    setState(() => _modoTexto = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foco.requestFocus();
    });
  }

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
            (etiqueta: 'Escribir', alTocar: _escribir),
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
      body: Stack(
        children: [
          Positioned.fill(child: FondoAsistente(intenso: _grabando)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _cabecera(chat),
                Expanded(
                  child: chat || _errorConsulta != null
                      ? _chat()
                      : _antesDelChat(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _cerrar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Cerrar, el nombre del asistente y las opciones de la conversación.
  Widget _cabecera(bool chat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Cerrar',
            excludeSemantics: true,
            onTap: _cerrar,
            child: GestureDetector(
              key: const Key('cerrar_vera'),
              onTap: _cerrar,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              // En pantallas angostas el nombre se encoge antes que desbordar.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OrbeMini(),
                    SizedBox(width: 8),
                    Text(
                      'Vera',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    _InsigniaBeta(),
                  ],
                ),
              ),
            ),
          ),
          if (chat) ...[
            _AccionCabecera(
              tooltip: _leerEnVozAlta
                  ? 'Dejar de leer las respuestas en voz alta'
                  : 'Leer las respuestas en voz alta',
              icono: _leerEnVozAlta
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              alTocar: _alternarLectura,
            ),
            _AccionCabecera(
              tooltip: 'Nueva conversación',
              icono: Icons.add_comment_outlined,
              alTocar: _enviando ? null : _nuevaConversacion,
            ),
            _AccionCabecera(
              tooltip: 'Historial',
              icono: Icons.history_rounded,
              alTocar: _abrirHistorial,
            ),
          ] else
            const SizedBox(width: 46),
        ],
      ),
    );
  }

  Widget _chat() => Column(
    children: [
      _hero(),
      Expanded(child: _lista()),
      if (_leyendo) _chipLeyendo(),
      if (!_grabando && !_modoTexto) _sugerenciasFila(),
      _zonaInferior(),
    ],
  );

  /// El orbe de Vera con sus aros: grande al saludar y pequeño cuando ya hay conversación.
  Widget _hero() {
    final grande = _burbujas.isEmpty;
    // En pantallas bajas el orbe se encoge para dejar sitio al saludo y a los controles.
    final alto = grande
        ? (MediaQuery.of(context).size.height * 0.3).clamp(140.0, 250.0)
        : 120.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: alto,
      alignment: Alignment.center,
      child: OrbeGrande(tamano: alto * 0.84, activo: _grabando),
    );
  }

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
    if (_burbujas.isEmpty) return _saludo();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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

  Widget _saludo() {
    final nombre = _nombre;
    return Center(
      child: _Entrada(
        duracion: const Duration(milliseconds: 750),
        desplazamiento: 18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombre == null ? 'Hola.' : 'Hola, $nombre.',
                  key: const Key('saludo_vera'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const Text(
                  '¿En qué te ayudo hoy?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Háblame o escríbeme.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Preguntas de ejemplo en una fila que se desliza. Se envían como si se hubieran escrito.
  Widget _sugerenciasFila() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final texto = _sugerencias[i];
          // Cada sugerencia entra un poco después que la anterior.
          return _Entrada(
            duracion: Duration(milliseconds: 520 + i * 200),
            desplazamiento: 14,
            child: ActionChip(
              label: Text(texto),
              onPressed: _chatDisponible ? () => _enviarTexto(texto) : null,
              backgroundColor: Colors.white.withAlpha(28),
              labelStyle: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: AppColors.borderGlass),
              shape: const StadiumBorder(),
            ),
          );
        },
      ),
    );
  }

  /// Abajo: el micrófono grande (por defecto), la grabación en curso, el teclado o el aviso de
  /// que no se pudo verificar el consentimiento.
  Widget _zonaInferior() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final Widget contenido;
    if (_errorConsulta != null) {
      contenido = _avisoSinVerificar(_errorConsulta!);
    } else if (_grabando) {
      contenido = _barraGrabando();
    } else if (_modoTexto) {
      contenido = Row(
        children: [
          _AccionCabecera(
            key: const Key('usar_voz'),
            tooltip: 'Usar la voz',
            icono: Icons.graphic_eq_rounded,
            alTocar: () => setState(() => _modoTexto = false),
          ),
          const SizedBox(width: 4),
          Expanded(child: _barraTexto()),
        ],
      );
    } else {
      contenido = _controlVoz();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
      child: contenido,
    );
  }

  /// El micrófono grande con ondas a los lados y el botón del teclado.
  Widget _controlVoz() {
    return SizedBox(
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_Ondas(), SizedBox(width: 130), _Ondas(invertida: true)],
          ),
          Semantics(
            button: true,
            label: 'Grabar audio',
            excludeSemantics: true,
            onTap: _enviando ? null : _alternarGrabacion,
            child: GestureDetector(
              key: const Key('boton_microfono'),
              onTap: _enviando ? null : _alternarGrabacion,
              child: _LatidoMicrofono(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(34),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.botonOscuro,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 34,
                      color: _enviando
                          ? AppColors.textMuted
                          : AppColors.gradientStart,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Escribir',
              excludeSemantics: true,
              onTap: () => setState(() => _modoTexto = true),
              child: GestureDetector(
                key: const Key('abrir_teclado'),
                onTap: () => setState(() => _modoTexto = true),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                    border: Border.all(color: AppColors.borderGlass),
                  ),
                  child: const Icon(
                    Icons.keyboard_alt_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// No se pudo confirmar el consentimiento: el chat se ve, pero no se puede escribir ni grabar
  /// hasta que la consulta salga bien. Así no se envía nada sin autorización verificada.
  Widget _avisoSinVerificar(Object error) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mensajeDeError(error),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
        TextButton(
          onPressed: _reintentarConsulta,
          child: const Text('Reintentar'),
        ),
      ],
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
        ? Colors.white.withAlpha(48)
        : AppColors.surface;
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
                      : (b.esUsuario
                            ? Border.all(color: AppColors.borderGlass)
                            : null),
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
                          Flexible(child: _textoDeBurbuja(b)),
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

/// Texto de la burbuja. En las respuestas de Vera los montos en pesos van en negrita.
Widget _textoDeBurbuja(_Burbuja b) {
  final texto = b.texto.isEmpty
      ? (b.esVoz && b.esUsuario ? 'Audio sin enviar' : '(sin transcripción)')
      : b.texto;
  final estilo = TextStyle(
    color: b.esError ? AppColors.error : AppColors.textPrimary,
    fontSize: 16,
    height: 1.4,
  );
  if (b.esUsuario || b.esError || !texto.contains(r'$')) {
    return Text(texto, style: estilo);
  }
  final montos = RegExp(r'\$\s?\d[\d.,]*');
  final partes = <TextSpan>[];
  var desde = 0;
  for (final m in montos.allMatches(texto)) {
    if (m.start > desde) {
      partes.add(TextSpan(text: texto.substring(desde, m.start)));
    }
    partes.add(
      TextSpan(
        text: m.group(0),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    desde = m.end;
  }
  if (desde < texto.length) {
    partes.add(TextSpan(text: texto.substring(desde)));
  }
  return Text.rich(TextSpan(style: estilo, children: partes));
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

/// Esfera pequeña junto al nombre del asistente.
class _OrbeMini extends StatelessWidget {
  const _OrbeMini();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        gradient: AppGradients.orbe,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const MarcaVera(tamano: 18, chispa: false),
    );
  }
}

class _InsigniaBeta extends StatelessWidget {
  const _InsigniaBeta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Beta',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Botón redondo y pequeño de la cabecera.
class _AccionCabecera extends StatelessWidget {
  const _AccionCabecera({
    super.key,
    required this.tooltip,
    required this.icono,
    required this.alTocar,
  });

  final String tooltip;
  final IconData icono;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: alTocar,
      visualDensity: VisualDensity.compact,
      icon: Icon(icono, color: AppColors.textPrimary, size: 22),
    );
  }
}

/// Barras de sonido a los lados del micrófono. Suben y bajan como una señal de audio, cada una a
/// su ritmo. Con reducir movimiento quedan quietas.
class _Ondas extends StatefulWidget {
  const _Ondas({this.invertida = false});

  final bool invertida;

  @override
  State<_Ondas> createState() => _OndasState();
}

class _OndasState extends State<_Ondas> with SingleTickerProviderStateMixin {
  late final AnimationController _vuelta = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  static const _alturas = [10.0, 22.0, 34.0, 20.0];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _vuelta.stop();
    } else if (!_vuelta.isAnimating && _vuelta.value == 0) {
      _vuelta.repeat(count: 150);
    }
  }

  @override
  void dispose() {
    _vuelta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.invertida ? _alturas.reversed.toList() : _alturas;
    return AnimatedBuilder(
      animation: _vuelta,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < base.length; i++)
              Container(
                width: 4,
                height:
                    base[i] *
                    (0.55 +
                        0.45 *
                            math
                                .sin(
                                  2 * math.pi * _vuelta.value * (1 + i % 2) +
                                      i * 1.3 +
                                      (widget.invertida ? 2 : 0),
                                )
                                .abs()),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// El micrófono late: un aro se agranda y se desvanece una y otra vez a su alrededor.
class _LatidoMicrofono extends StatefulWidget {
  const _LatidoMicrofono({required this.child});

  final Widget child;

  @override
  State<_LatidoMicrofono> createState() => _LatidoMicrofonoState();
}

class _LatidoMicrofonoState extends State<_LatidoMicrofono>
    with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _latido.stop();
    } else if (!_latido.isAnimating && _latido.value == 0) {
      _latido.repeat(count: 80);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _latido,
      builder: (context, hijo) {
        final t = Curves.easeOut.transform(_latido.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112 + 46 * t,
              height: 112 + 46 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha((90 * (1 - t)).round()),
                  width: 2,
                ),
              ),
            ),
            hijo!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Hace que un elemento aparezca una sola vez: se desvanece hacia adentro y sube un poco.
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.duracion,
    required this.desplazamiento,
    required this.child,
  });

  final Duration duracion;
  final double desplazamiento;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duracion,
      curve: Curves.easeOutCubic,
      builder: (context, v, hijo) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, desplazamiento * (1 - v)),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}
