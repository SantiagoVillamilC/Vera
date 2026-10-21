import 'package:flutter/material.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/vera_logo.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

/// Cerradura de la sesión guardada: pide huella o rostro y, si pasa, renueva
/// en silencio. El router saca de aquí cuando la sesión queda desbloqueada o
/// descartada.
class DesbloqueoScreen extends StatefulWidget {
  const DesbloqueoScreen({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<DesbloqueoScreen> createState() => _DesbloqueoScreenState();
}

class _DesbloqueoScreenState extends State<DesbloqueoScreen> {
  late final AuthRepository _repository = widget.repository ?? AuthRepository();
  bool _cargando = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _desbloquear());
  }

  Future<void> _desbloquear() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _mensaje = null;
    });
    final DesbloqueoBiometrico resultado;
    try {
      resultado = await _repository.desbloquearConBiometria();
    } on Object {
      if (mounted) {
        setState(() {
          _cargando = false;
          _mensaje = mensajeErrorGenerico;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _mensaje = switch (resultado) {
        DesbloqueoBiometrico.desbloqueado ||
        DesbloqueoBiometrico.sesionVencida => null,
        DesbloqueoBiometrico.cancelado =>
          'No pudimos verificar tu huella o rostro.',
        DesbloqueoBiometrico.sinRed => mensajeSinRed,
        DesbloqueoBiometrico.error => mensajeErrorGenerico,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Center(child: VeraLogo(size: 44)),
            const SizedBox(height: 28),
            const Text(
              'Desbloquea tu billetera',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa tu huella o tu rostro para entrar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            if (_mensaje != null) ...[
              const SizedBox(height: 20),
              Text(
                _mensaje!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ],
            const Spacer(),
            GradientButton(
              label: 'Desbloquear',
              icon: Icons.fingerprint_rounded,
              loading: _cargando,
              onPressed: _desbloquear,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _cargando
                  ? null
                  : _repository.abandonarSesionBloqueada,
              child: const Text(
                'Iniciar sesión con contraseña',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
