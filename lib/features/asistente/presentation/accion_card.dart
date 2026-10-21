import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/security/verificador_local.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/codigo_otp.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/asistente/data/asistente_mensajes.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

/// Tarjeta de confirmación de una transferencia preparada por Vera.
///
/// Muestra los datos estructurados de la acción (nunca el texto del modelo), una cuenta
/// regresiva hasta `expira_en` y los botones de confirmar o cancelar. Confirmar exige que el
/// teléfono verifique a su dueño (huella, rostro o PIN); sin esa posibilidad, o si la acción lo
/// pide, se confirma con el código de WhatsApp. Escribir «sí» en el chat nunca confirma.
class AccionCard extends StatefulWidget {
  const AccionCard({
    super.key,
    required this.accion,
    required this.repo,
    required this.onActualizada,
    this.verificador,
  });

  final AccionPendiente accion;
  final AsistenteRepository repo;

  /// Recibe la acción con su estado nuevo (confirmada, cancelada, vencida...).
  final ValueChanged<AccionPendiente> onActualizada;

  /// Solo para pruebas; por defecto la verificación local del teléfono.
  final VerificadorLocal? verificador;

  @override
  State<AccionCard> createState() => _AccionCardState();
}

/// Qué pasó con un código escrito en la hoja.
class _ResultadoCodigo {
  const _ResultadoCodigo.listo() : mensaje = null, cerrar = true;
  const _ResultadoCodigo.reintentar(String this.mensaje) : cerrar = false;
  const _ResultadoCodigo.definitivo() : mensaje = null, cerrar = true;

  final String? mensaje;
  final bool cerrar;
}

class _AccionCardState extends State<AccionCard> {
  Timer? _reloj;
  VerificadorLocal? _verificadorPropio;
  bool _ocupada = false;
  String? _error;
  String? _motivoFallo;
  Transferencia? _transferencia;
  DesafioAccion? _desafio;

  /// La misma confirmación, para reenviarla tal cual si la red o el servidor fallaron sin
  /// saber si llegó. El backend devuelve el resultado original en vez de duplicar.
  Future<AccionResuelta> Function()? _reintento;

  VerificadorLocal get _verificador =>
      widget.verificador ?? (_verificadorPropio ??= VerificadorLocalAuth());

  static const _erroresDeNegocio = {
    'InsufficientFunds',
    'OperationLimitExceeded',
    'MonthlyQuotaExceeded',
    'RecipientNotFound',
    'SelfTransferNotAllowed',
  };

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.accion.estado == EstadoAccion.pendiente &&
          !DateTime.now().isBefore(widget.accion.expiraEn)) {
        widget.onActualizada(_conEstado(EstadoAccion.vencida));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  AccionPendiente _conEstado(EstadoAccion e) => AccionPendiente(
    id: widget.accion.id,
    estado: e,
    tipo: widget.accion.tipo,
    destinatario: widget.accion.destinatario,
    llave: widget.accion.llave,
    tipoLlave: widget.accion.tipoLlave,
    montoCentavos: widget.accion.montoCentavos,
    moneda: widget.accion.moneda,
    requiereCodigo: widget.accion.requiereCodigo,
    expiraEn: widget.accion.expiraEn,
  );

  void _aplicar(AccionResuelta r) {
    _transferencia = r.transferencia;
    _reintento = null;
    widget.onActualizada(r.accion);
  }

  /// Estados finales que el servidor decide con un error. Devuelve si cambió la tarjeta.
  bool _aplicarErrorDeNegocio(ApiException e) {
    switch (e.code) {
      case 'ActionExpired':
        widget.onActualizada(_conEstado(EstadoAccion.vencida));
      case 'ActionNotPending' || 'ConsentRequired':
        // El backend ya la resolvió o la canceló: se muestra como cancelada.
        widget.onActualizada(_conEstado(EstadoAccion.cancelada));
      case final c when _erroresDeNegocio.contains(c):
        setState(() => _motivoFallo = mensajeDeError(e));
        widget.onActualizada(_conEstado(EstadoAccion.fallida));
      default:
        return false;
    }
    _reintento = null;
    return true;
  }

  String _mensajeDeFalla(Object e) => esErrorDeRed(e)
      ? 'Sin conexión. Toca Reintentar confirmación: es la misma confirmación y no se duplica.'
      : mensajeDeError(e);

  Future<void> _cancelar() => _ejecutar(
    () => widget.repo.cancelarAccion(widget.accion.id),
    esConfirmacion: false,
  );

  Future<void> _ejecutar(
    Future<AccionResuelta> Function() op, {
    bool esConfirmacion = true,
    Future<void> Function()? siPideCodigo,
  }) async {
    setState(() {
      _ocupada = true;
      _error = null;
    });
    try {
      final r = await op();
      if (mounted) _aplicar(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'SecondFactorRequired' && siPideCodigo != null) {
        setState(() => _ocupada = false);
        await siPideCodigo();
        return;
      }
      if (_aplicarErrorDeNegocio(e)) return;
      // Con un 5xx o un timeout no se sabe si llegó: se reenvía la misma confirmación.
      if (esConfirmacion && esErrorReintentable(e)) _reintento = op;
      setState(() => _error = _mensajeDeFalla(e));
    } on Object catch (e) {
      if (!mounted) return;
      if (esConfirmacion) _reintento = op;
      setState(() => _error = _mensajeDeFalla(e));
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _confirmar() async {
    if (_ocupada) return;
    final reintento = _reintento;
    if (reintento != null) return _ejecutar(reintento);
    final a = widget.accion;
    if (a.requiereCodigo) {
      return _confirmarConCodigo(sinVerificacionLocal: false);
    }

    setState(() {
      _ocupada = true;
      _error = null;
    });
    final verificacion = await _verificador.verificar(
      'Confirma la transferencia de ${formatPesos(a.montoCentavos)}',
    );
    if (!mounted) return;
    setState(() => _ocupada = false);
    switch (verificacion) {
      case ResultadoVerificacion.exitosa:
        await _ejecutar(
          () => widget.repo.confirmarAccion(a.id),
          siPideCodigo: () => _confirmarConCodigo(sinVerificacionLocal: false),
        );
      case ResultadoVerificacion.noDisponible:
        // Sin biometría ni bloqueo en el teléfono, el código de WhatsApp reemplaza la verificación.
        await _confirmarConCodigo(sinVerificacionLocal: true);
      case ResultadoVerificacion.rechazada:
        setState(
          () => _error =
              'No pudimos verificar que eres tú. La transferencia sigue pendiente.',
        );
    }
  }

  Future<void> _confirmarConCodigo({required bool sinVerificacionLocal}) async {
    setState(() {
      _ocupada = true;
      _error = null;
    });
    try {
      _desafio = await widget.repo.solicitarCodigo(widget.accion.id);
    } on ApiException catch (e) {
      if (mounted) {
        if (!_aplicarErrorDeNegocio(e)) {
          setState(() => _error = mensajeDeError(e));
        }
      }
      if (mounted) setState(() => _ocupada = false);
      return;
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _ocupada = false;
          _error = mensajeDeError(e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _ocupada = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _CodigoSheet(
        expiraEnSegundos: _desafio!.expiraEnSegundos,
        alCompletar: (codigo) => _verificarCodigo(codigo, sinVerificacionLocal),
        alReenviar: _reenviarCodigo,
      ),
    );
  }

  Future<_ResultadoCodigo> _verificarCodigo(
    String codigo,
    bool sinVerificacionLocal,
  ) async {
    try {
      final r = await widget.repo.confirmarAccion(
        widget.accion.id,
        desafioId: _desafio!.challengeId,
        codigo: codigo,
        sinVerificacionLocal: sinVerificacionLocal,
      );
      if (mounted) _aplicar(r);
      return const _ResultadoCodigo.listo();
    } on ApiException catch (e) {
      if (!mounted) return const _ResultadoCodigo.definitivo();
      switch (e.code) {
        case 'OtpInvalid' || 'OtpExpired':
          return _ResultadoCodigo.reintentar(mensajeDeError(e));
        case 'OtpTooManyAttempts' || 'ChallengeInvalid':
          // Ya no se puede reintentar con este código: la acción sigue sin confirmar.
          setState(() => _error = mensajeDeError(e));
          return const _ResultadoCodigo.definitivo();
        default:
          if (_aplicarErrorDeNegocio(e)) {
            return const _ResultadoCodigo.definitivo();
          }
          return _ResultadoCodigo.reintentar(_mensajeDeFalla(e));
      }
    } on Object catch (e) {
      return _ResultadoCodigo.reintentar(
        esErrorDeRed(e)
            ? 'Sin conexión. Vuelve a escribir el código para reintentar.'
            : mensajeDeError(e),
      );
    }
  }

  Future<bool> _reenviarCodigo() async {
    try {
      _desafio = await widget.repo.solicitarCodigo(widget.accion.id);
      return true;
    } on Object {
      return false;
    }
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
  }

  /// Mensaje del estado final de la tarjeta, con los datos del resultado cuando existen.
  Widget? _resultado(AccionPendiente a) {
    final (texto, color) = switch (a.estado) {
      EstadoAccion.confirmada => (
        'Transferencia enviada.',
        AppColors.accentGreen,
      ),
      EstadoAccion.fallida => (
        _motivoFallo ?? 'La transferencia no se pudo completar.',
        AppColors.error,
      ),
      EstadoAccion.vencida => (
        'Esta transferencia venció. Pídele a Vera que la prepare de nuevo.',
        AppColors.warning,
      ),
      EstadoAccion.cancelada => (
        'Cancelaste esta transferencia.',
        AppColors.textSecondary,
      ),
      _ => (null, AppColors.textSecondary),
    };
    if (texto == null) return null;
    final t = _transferencia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(texto, style: TextStyle(color: color, fontSize: 13)),
        if (a.estado == EstadoAccion.confirmada && t != null) ...[
          const SizedBox(height: 4),
          Text(
            'Identificador: ${t.id}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Text(
            _fecha(t.creadaEn),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.accion;
    final restante = a.expiraEn.difference(DateTime.now());
    final accionable = a.esAccionable;
    final resultado = _resultado(a);
    final destino = switch (a.tipo) {
      TipoAccion.transferenciaLlave => a.llave ?? a.destinatario?.nombre ?? '',
      _ => a.destinatario?.nombre ?? '',
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text(
                'Transferencia preparada',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              _EstadoChip(estado: a.estado),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPesos(a.montoCentavos),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                a.moneda,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Para $destino',
              if (a.destinatario?.celularParcial != null)
                a.destinatario!.celularParcial!,
            ].join('  ·  '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (accionable) ...[
            const SizedBox(height: 6),
            Text(
              'Vence en ${_mmss(restante)}',
              style: TextStyle(
                color: restante.inSeconds < 60
                    ? AppColors.warning
                    : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (resultado != null) ...[const SizedBox(height: 10), resultado],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          if (accionable) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _ocupada ? null : _cancelar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _ocupada ? null : _confirmar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gradientMid,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _ocupada
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _reintento != null
                                ? 'Reintentar confirmación'
                                : a.requiereCodigo
                                ? 'Confirmar con código'
                                : 'Confirmar',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _mmss(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _CodigoSheet extends StatefulWidget {
  const _CodigoSheet({
    required this.expiraEnSegundos,
    required this.alCompletar,
    required this.alReenviar,
  });
  final int expiraEnSegundos;
  final Future<_ResultadoCodigo> Function(String codigo) alCompletar;
  final Future<bool> Function() alReenviar;

  @override
  State<_CodigoSheet> createState() => _CodigoSheetState();
}

class _CodigoSheetState extends State<_CodigoSheet> {
  final _otp = GlobalKey<CodigoOtpState>();
  bool _verificando = false;
  String? _error;

  Future<void> _completar(String codigo) async {
    setState(() {
      _verificando = true;
      _error = null;
    });
    final r = await widget.alCompletar(codigo);
    if (!mounted) return;
    if (r.cerrar) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _verificando = false;
      _error = r.mensaje;
    });
    _otp.currentState?.limpiar();
  }

  Future<bool> _reenviar() async {
    final ok = await widget.alReenviar();
    if (mounted) {
      setState(
        () => _error = ok
            ? null
            : 'No pudimos reenviar el código. Intenta de nuevo.',
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Código de confirmación',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Te lo enviamos por WhatsApp. Vale por ${widget.expiraEnSegundos ~/ 60} minutos.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: CodigoOtp(
                key: _otp,
                alCompletar: _completar,
                alReenviar: _reenviar,
                ocupado: _verificando,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});
  final EstadoAccion estado;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (estado) {
      EstadoAccion.pendiente => ('Pendiente', AppColors.accent),
      EstadoAccion.confirmada => ('Enviada', AppColors.accentGreen),
      EstadoAccion.cancelada => ('Cancelada', AppColors.textSecondary),
      EstadoAccion.vencida => ('Vencida', AppColors.warning),
      EstadoAccion.fallida => ('Fallida', AppColors.error),
      EstadoAccion.desconocido => ('—', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
