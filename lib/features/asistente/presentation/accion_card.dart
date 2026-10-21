import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

/// Tarjeta de confirmación de una transferencia preparada por Vera.
///
/// Muestra los datos de la acción (no el texto del modelo), una cuenta regresiva hasta
/// `expira_en` y los botones de confirmar o cancelar. Si la acción exige código, lo pide primero.
class AccionCard extends StatefulWidget {
  const AccionCard({
    super.key,
    required this.accion,
    required this.repo,
    required this.onActualizada,
  });

  final AccionPendiente accion;
  final AsistenteRepository repo;

  /// Recibe la acción con su estado nuevo (confirmada, cancelada, vencida...).
  final ValueChanged<AccionPendiente> onActualizada;

  @override
  State<AccionCard> createState() => _AccionCardState();
}

class _AccionCardState extends State<AccionCard> {
  Timer? _reloj;
  bool _ocupada = false;
  String? _error;

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

  Future<void> _ejecutar(Future<AccionResuelta> Function() op) async {
    setState(() {
      _ocupada = true;
      _error = null;
    });
    try {
      final r = await op();
      if (mounted) widget.onActualizada(r.accion);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'ActionExpired':
          widget.onActualizada(_conEstado(EstadoAccion.vencida));
        case 'ActionNotPending' || 'ConsentRequired':
          // El backend ya la resolvió o la canceló: se muestra como cancelada.
          widget.onActualizada(_conEstado(EstadoAccion.cancelada));
        default:
          setState(() => _error = mensajeDeError(e));
      }
    } on Object catch (e) {
      // Tras un timeout la acción pudo ejecutarse: no se reintenta sola.
      if (mounted) {
        setState(
          () => _error = esErrorDeRed(e)
              ? 'Sin conexión. Revisa tus movimientos antes de reintentar.'
              : mensajeDeError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupada = false);
    }
  }

  Future<void> _confirmar() async {
    if (!widget.accion.requiereCodigo) {
      return _ejecutar(() => widget.repo.confirmarAccion(widget.accion.id));
    }
    setState(() {
      _ocupada = true;
      _error = null;
    });
    DesafioAccion desafio;
    try {
      desafio = await widget.repo.solicitarCodigo(widget.accion.id);
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
    final codigo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _CodigoSheet(expiraEnSegundos: desafio.expiraEnSegundos),
    );
    if (codigo == null || !mounted) return;
    await _ejecutar(
      () => widget.repo.confirmarAccion(
        widget.accion.id,
        desafioId: desafio.challengeId,
        codigo: codigo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.accion;
    final restante = a.expiraEn.difference(DateTime.now());
    final accionable = a.esAccionable;
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
          Text(
            formatPesos(a.montoCentavos),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
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
                    onPressed: _ocupada
                        ? null
                        : () =>
                              _ejecutar(() => widget.repo.cancelarAccion(a.id)),
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
                            a.requiereCodigo
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

class _CodigoSheet extends StatefulWidget {
  const _CodigoSheet({required this.expiraEnSegundos});
  final int expiraEnSegundos;

  @override
  State<_CodigoSheet> createState() => _CodigoSheetState();
}

class _CodigoSheetState extends State<_CodigoSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
            'Te lo enviamos. Vale por ${widget.expiraEnSegundos ~/ 60} minutos.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.textPrimary,
              letterSpacing: 4,
              fontSize: 20,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '------',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _ctrl.text.trim().length != 6
                  ? null
                  : () => Navigator.pop(context, _ctrl.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gradientMid,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Confirmar transferencia'),
            ),
          ),
        ],
      ),
    );
  }
}
