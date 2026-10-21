import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/pin_pad.dart';

/// Captura de un código numérico (por defecto 6 dígitos) con teclado propio y reenvío
/// habilitado tras [segundosReenvio]. Llama a [alCompletar] al llegar al último dígito.
class CodigoOtp extends StatefulWidget {
  const CodigoOtp({
    super.key,
    required this.alCompletar,
    required this.alReenviar,
    this.longitud = 6,
    this.segundosReenvio = 60,
    this.ocupado = false,
  });

  final void Function(String codigo) alCompletar;

  /// Pide un código nuevo y devuelve si se envió. El contador de reenvío solo reinicia si sí.
  final Future<bool> Function() alReenviar;
  final int longitud;
  final int segundosReenvio;

  /// Con una verificación en curso no se aceptan más dígitos.
  final bool ocupado;

  @override
  State<CodigoOtp> createState() => CodigoOtpState();
}

class CodigoOtpState extends State<CodigoOtp> {
  String _codigo = '';
  late int _restantes = widget.segundosReenvio;
  bool _reenviando = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _iniciarCuenta();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _iniciarCuenta() {
    _reloj?.cancel();
    _restantes = widget.segundosReenvio;
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _restantes--);
      if (_restantes <= 0) t.cancel();
    });
  }

  /// Borra lo escrito, por ejemplo tras un código incorrecto.
  void limpiar() => setState(() => _codigo = '');

  void _digito(String d) {
    if (widget.ocupado || _codigo.length >= widget.longitud) return;
    setState(() => _codigo += d);
    if (_codigo.length == widget.longitud) widget.alCompletar(_codigo);
  }

  void _borrar() {
    if (widget.ocupado || _codigo.isEmpty) return;
    setState(() => _codigo = _codigo.substring(0, _codigo.length - 1));
  }

  Future<void> _reenviar() async {
    if (_reenviando) return;
    setState(() => _reenviando = true);
    try {
      final enviado = await widget.alReenviar();
      if (mounted && enviado) {
        _codigo = '';
        _iniciarCuenta();
      }
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(length: widget.longitud, filled: _codigo.length),
        const SizedBox(height: 20),
        NumPad(onDigit: _digito, onDelete: _borrar),
        const SizedBox(height: 12),
        if (_restantes > 0)
          Text(
            'Reenviar código en ${_restantes}s',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          )
        else
          TextButton(
            key: const Key('reenviar_codigo'),
            onPressed: _reenviando ? null : _reenviar,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gradientStart,
            ),
            child: const Text(
              'Reenviar código',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
