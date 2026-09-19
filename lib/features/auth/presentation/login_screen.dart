import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/core/widgets/vera_animated_logo.dart';
import 'package:vera/core/widgets/vera_logo.dart';

// Step 1: phone number entry
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    context.push('/login/pin', extra: _phoneController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Center(child: VeraAnimatedLogo()),
              const SizedBox(height: 36),
              const Text(
                'Bienvenido\nde nuevo.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa con tu número de celular',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              _GlassCard(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continue(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: '300 000 0000',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 20, right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇨🇴', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text(
                            '+57',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 10),
                          SizedBox(
                            height: 22,
                            child: VerticalDivider(color: AppColors.border, width: 1),
                          ),
                        ],
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '  Ingresa tu número';
                    if (v.length < 10) return '  Número inválido';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 32),
              ValueListenableBuilder(
                valueListenable: _phoneController,
                builder: (context, value, child) => GradientButton(
                  label: 'Continuar',
                  onPressed: value.text.length >= 10 ? _continue : null,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: const Text.rich(
                    TextSpan(
                      text: '¿No tienes cuenta? ',
                      style: TextStyle(fontSize: 15),
                      children: [
                        TextSpan(
                          text: 'Regístrate',
                          style: TextStyle(
                            color: AppColors.gradientStart,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Step 2: PIN entry
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.phone});
  final String phone;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 6;
  String _pin = '';
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
    if (_pin.length == _pinLength) _submit();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    // TODO: validate PIN then call POST /auth/login
    // On success, navigate to OTP screen with challengeId
    context.push('/login/otp', extra: {
      'phone': widget.phone,
      'challengeId': 'mock-challenge-id',
    });
  }

  String get _maskedPhone {
    if (widget.phone.length < 4) return widget.phone;
    return '••• ••• ${widget.phone.substring(widget.phone.length - 4)}';
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
          const Text(
            'Ingresa tu PIN',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _maskedPhone,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnimation.value * (_shakeController.value < 0.5 ? 1 : -1), 0),
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
              onBiometric: () {},
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('¿Olvidaste tu PIN?', style: TextStyle(fontSize: 14)),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// Step 3: OTP verification
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key, required this.phone, required this.challengeId});
  final String phone;
  final String challengeId;

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  static const _otpLength = 6;
  String _otp = '';
  bool _loading = false;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() async {
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
    // TODO: POST /auth/login/verify-otp {challengeId, codigo}
    // On success: save tokens with flutter_secure_storage, navigate to home
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _loading = false);
        context.go('/home');
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
            'Código de verificación',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
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
                    setState(() => _resendSeconds = 60);
                    _startResendTimer();
                    // TODO: resend OTP
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGlass, width: 1),
      ),
      child: child,
    );
  }
}
