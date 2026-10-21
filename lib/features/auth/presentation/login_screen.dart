import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/celular.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/password_field.dart';
import 'package:vera/core/widgets/vera_animated_logo.dart';
import 'package:vera/core/widgets/vera_logo.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

// Step 1: phone number entry
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.repository,
    this.showcase = const bool.fromEnvironment('SHOWCASE'),
    this.showcaseCelular = const String.fromEnvironment('SHOWCASE_CELULAR'),
    this.showcaseContrasena = const String.fromEnvironment(
      'SHOWCASE_CONTRASENA',
    ),
  });

  final AuthRepository? repository;
  final bool showcase;
  final String showcaseCelular;
  final String showcaseContrasena;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showcaseLoading = false;
  String? _showcaseError;

  @override
  void initState() {
    super.initState();
    if (widget.showcase && widget.showcaseCelular.isNotEmpty) {
      _phoneController.text = widget.showcaseCelular;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    context.push('/login/pin', extra: _phoneController.text.trim());
  }

  Future<void> _showcaseLogin() async {
    if (_showcaseLoading) return;
    setState(() {
      _showcaseLoading = true;
      _showcaseError = null;
    });
    try {
      final repo = widget.repository ?? AuthRepository();
      await repo.login(
        celular: widget.showcaseCelular,
        contrasena: widget.showcaseContrasena,
      );
      if (mounted) context.go('/home');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _showcaseLoading = false;
        _showcaseError = mensajeDeError(e);
      });
    }
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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 28),
              _GlassCard(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continue(),
                  inputFormatters: const [CelularColombianoFormatter()],
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
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
                            child: VerticalDivider(
                              color: AppColors.border,
                              width: 1,
                            ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
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
              if (widget.showcase) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: _showcaseLoading ? null : _showcaseLogin,
                    icon: _showcaseLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Entrar a la demo'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gradientStart,
                    ),
                  ),
                ),
                if (_showcaseError != null)
                  Center(
                    child: Text(
                      _showcaseError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Step 2: password entry
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.phone, this.repository});
  final String phone;
  final AuthRepository? repository;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late final AuthRepository _repo = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.login(celular: widget.phone, contrasena: _passwordCtrl.text);
      if (mounted) context.go('/home');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeDeError(e);
      });
    }
  }

  String get _maskedPhone {
    if (widget.phone.length < 4) return widget.phone;
    return '••• ••• ${widget.phone.substring(widget.phone.length - 4)}';
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
              const SizedBox(height: 24),
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
              const Text(
                'Ingresa tu contraseña',
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
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              PasswordField(
                controller: _passwordCtrl,
                autofocus: true,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
              const SizedBox(height: 32),
              GradientButton(
                label: 'Iniciar sesión',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => context.push('/login/recovery'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 14),
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
