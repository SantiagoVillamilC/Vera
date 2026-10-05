import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/core/widgets/vera_animated_logo.dart';
import 'package:vera/core/widgets/vera_logo.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

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
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.2,
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
  bool _loading = false;
  final _repo = AuthRepository();
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
    if (_loading || _pin.length >= _pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == _pinLength) _submit();
  }

  void _onDelete() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _repo.login(celular: widget.phone, contrasena: _pin);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pin = '';
      });
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pin = '';
      });
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    }
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
          _loading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
                )
              : AnimatedBuilder(
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
            onPressed: _loading ? null : () => context.push('/login/recovery'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('¿Olvidaste tu PIN?', style: TextStyle(fontSize: 14)),
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
