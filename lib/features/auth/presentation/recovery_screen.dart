import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/core/widgets/vera_logo.dart';

// Step 1: confirm identity via OTP sent to registered phone
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.phone});
  final String phone;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _loading = false;

  void _sendOtp() {
    setState(() => _loading = true);
    // TODO: POST /auth/login with proposito=restablecimiento to trigger OTP
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _loading = false);
        context.push('/login/recovery/otp', extra: {
          'phone': widget.phone,
          'challengeId': 'mock-recovery-challenge',
        });
      }
    });
  }

  String get _maskedPhone {
    if (widget.phone.length < 4) return widget.phone;
    return '+57 ••• ••• ${widget.phone.substring(widget.phone.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                const VeraLogo(size: 22),
              ],
            ),
            const SizedBox(height: 48),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.gradientMid.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gradientMid.withAlpha(80)),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.gradientStart, size: 28),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recuperar PIN',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enviaremos un código de verificación por WhatsApp a $_maskedPhone para confirmar tu identidad.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.55),
            ),
            const Spacer(),
            GradientButton(
              label: 'Enviar código',
              loading: _loading,
              onPressed: _sendOtp,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// Step 2: OTP verification for recovery (proposito = restablecimiento)
class RecoveryOtpScreen extends StatefulWidget {
  const RecoveryOtpScreen({super.key, required this.phone, required this.challengeId});
  final String phone;
  final String challengeId;

  @override
  State<RecoveryOtpScreen> createState() => _RecoveryOtpScreenState();
}

class _RecoveryOtpScreenState extends State<RecoveryOtpScreen> {
  static const _otpLength = 6;
  String _otp = '';
  bool _loading = false;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    while (mounted && _resendSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendSeconds--);
    }
  }

  void _onDigit(String d) {
    if (_otp.length >= _otpLength) return;
    setState(() => _otp += d);
    if (_otp.length == _otpLength) _verify();
  }

  void _onDelete() {
    if (_otp.isEmpty) return;
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  void _verify() {
    setState(() => _loading = true);
    // TODO: POST /auth/login/verify-otp {challengeId, codigo, proposito: 'restablecimiento'}
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _loading = false);
        context.push('/login/recovery/new-pin', extra: {
          'phone': widget.phone,
          'challengeId': widget.challengeId,
        });
      }
    });
  }

  String get _maskedPhone {
    if (widget.phone.length < 4) return widget.phone;
    return '+57 ••• ••• ${widget.phone.substring(widget.phone.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                const VeraLogo(size: 22),
              ],
            ),
          ),
          const Spacer(flex: 2),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientMid.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          const Text(
            'Código de restablecimiento',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enviamos un código por WhatsApp a\n$_maskedPhone',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 48),
          _loading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
                )
              : PinDots(length: _otpLength, filled: _otp.length),
          const Spacer(flex: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: NumPad(
              onDigit: _onDigit,
              onDelete: _onDelete,
            ),
          ),
          const SizedBox(height: 20),
          _resendSeconds > 0
              ? Text(
                  'Reenviar código en ${_resendSeconds}s',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                )
              : TextButton(
                  onPressed: () {
                    setState(() {
                      _otp = '';
                      _resendSeconds = 60;
                    });
                    _startTimer();
                    // TODO: resend recovery OTP
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.gradientStart),
                  child: const Text('Reenviar código', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// Step 3: set new PIN after identity confirmed
class NewPinScreen extends StatefulWidget {
  const NewPinScreen({super.key, required this.phone, required this.challengeId});
  final String phone;
  final String challengeId;

  @override
  State<NewPinScreen> createState() => _NewPinScreenState();
}

class _NewPinScreenState extends State<NewPinScreen> with SingleTickerProviderStateMixin {
  static const _pinLength = 6;
  bool _confirming = false;
  String _pin = '';
  String _firstPin = '';
  bool _loading = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == _pinLength) {
      if (!_confirming) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _confirming = true;
        });
      } else {
        _submit();
      }
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin != _firstPin) {
      _shakeController.forward(from: 0);
      setState(() {
        _pin = '';
        _confirming = false;
        _firstPin = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los PINs no coinciden, inténtalo de nuevo')),
      );
      return;
    }
    setState(() => _loading = true);
    // TODO: PATCH /auth/credentials or dedicated reset-pin endpoint
    // Body: {challengeId, nuevo_pin: _pin}
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _loading = false);
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                const SizedBox(height: 24),
                IconButton(
                  onPressed: _confirming
                      ? () => setState(() {
                            _pin = '';
                            _confirming = false;
                            _firstPin = '';
                          })
                      : () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                const VeraLogo(size: 22),
              ],
            ),
          ),
          const Spacer(flex: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _confirming ? 'Confirma tu nuevo PIN' : 'Crea tu nuevo PIN',
              key: ValueKey(_confirming),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _confirming
                ? 'Ingresa el PIN nuevamente para confirmarlo'
                : 'Elige 6 dígitos que recuerdes fácilmente',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 48),
          _loading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
                )
              : AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      _shakeAnimation.value * (_shakeController.value < 0.5 ? 1 : -1),
                      0,
                    ),
                    child: child,
                  ),
                  child: PinDots(length: _pinLength, filled: _pin.length),
                ),
          const Spacer(flex: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: NumPad(
              onDigit: _onDigit,
              onDelete: _onDelete,
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}
