import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/auth_scroll_body.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/password_field.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/core/widgets/vera_logo.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

// Step 1: email input → POST /v1/auth/recovery/request
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _correoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  late final AuthRepository _repo = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final challengeId = await _repo.recoveryRequest(
        correo: _correoCtrl.text.trim(),
      );
      if (!mounted) return;
      context.push(
        '/login/recovery/otp',
        extra: {'correo': _correoCtrl.text.trim(), 'challengeId': challengeId},
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Form(
          key: _formKey,
          child: AuthScrollBody(
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
                    border: Border.all(
                      color: AppColors.gradientMid.withAlpha(80),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.gradientStart,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recuperar contraseña',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ingresa el correo electrónico de tu cuenta. Enviaremos un código de verificación por WhatsApp.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOtp(),
                  autofocus: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'tu@correo.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu correo';
                    if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v)) {
                      return 'Correo inválido';
                    }
                    return null;
                  },
                ),
                const EspacioFlexible(minimo: 24),
                GradientButton(
                  label: 'Enviar código',
                  loading: _loading,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Step 2: OTP + backup code → POST /v1/auth/recovery/verify
class RecoveryOtpScreen extends StatefulWidget {
  const RecoveryOtpScreen({
    super.key,
    required this.correo,
    required this.challengeId,
    this.repository,
  });
  final String correo;
  final String challengeId;
  final AuthRepository? repository;

  @override
  State<RecoveryOtpScreen> createState() => _RecoveryOtpScreenState();
}

class _RecoveryOtpScreenState extends State<RecoveryOtpScreen> {
  static const _otpLength = 6;
  String _otp = '';
  bool _loading = false;
  int _resendSeconds = 60;
  bool _resending = false;
  bool _resendClosed = false;
  final _codigoRespaldoCtrl = TextEditingController();
  late final AuthRepository _repo = widget.repository ?? AuthRepository();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _codigoRespaldoCtrl.dispose();
    super.dispose();
  }

  void _startTimer() async {
    while (mounted && _resendSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendSeconds--);
    }
  }

  void _onDigit(String d) {
    if (_loading || _otp.length >= _otpLength) return;
    setState(() => _otp += d);
    if (_otp.length == _otpLength) _verify();
  }

  void _onDelete() {
    if (_loading || _otp.isEmpty) return;
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  Future<void> _verify() async {
    final codigoRespaldo = _codigoRespaldoCtrl.text.trim();
    if (codigoRespaldo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu código de respaldo')),
      );
      setState(() => _otp = '');
      return;
    }
    setState(() => _loading = true);
    try {
      final resetToken = await _repo.recoveryVerify(
        challengeId: widget.challengeId,
        codigo: _otp,
        codigoRespaldo: codigoRespaldo,
      );
      if (!mounted) return;
      context.push('/login/recovery/new-pin', extra: resetToken);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otp = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otp = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    }
  }

  /// Reenvía sobre el challenge_id vigente. El contador de 60 s solo reinicia
  /// tras un 200. Con OtpTooManyResends o ChallengeInvalid ya no hay reenvío
  /// posible y se ofrecen las salidas.
  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await _repo.resendOtp(
        challengeId: widget.challengeId,
        proposito: 'recuperacion',
      );
      if (!mounted) return;
      setState(() {
        _otp = '';
        _resending = false;
        _resendSeconds = 60;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        if (e is ApiException &&
            (e.code == 'OtpTooManyResends' || e.code == 'ChallengeInvalid')) {
          _resendClosed = true;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  Widget _resendArea() {
    if (_resendClosed) {
      return Column(
        children: [
          TextButton(
            onPressed: () => context.go('/login/recovery'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gradientStart,
            ),
            child: const Text(
              'Volver a empezar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Iniciar sesión'),
          ),
        ],
      );
    }
    if (_resendSeconds > 0) {
      return Text(
        'Reenviar código en ${_resendSeconds}s',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      );
    }
    return TextButton(
      onPressed: _resending ? null : _resend,
      style: TextButton.styleFrom(foregroundColor: AppColors.gradientStart),
      child: const Text(
        'Reenviar código',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 8,
                  ),
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
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
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
                  'Enviamos un código por WhatsApp al celular\nregistrado en ${widget.correo}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                _loading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.gradientStart,
                        ),
                      )
                    : PinDots(length: _otpLength, filled: _otp.length),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Código de respaldo',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codigoRespaldoCtrl,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ej. ABCD-1234-EFGH',
                          prefixIcon: Icon(Icons.key_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Uno de los 8 códigos de respaldo que recibiste al registrarte.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: NumPad(onDigit: _onDigit, onDelete: _onDelete),
                ),
                const SizedBox(height: 20),
                _resendArea(),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Step 3: new password → POST /v1/auth/recovery/reset
class NewPinScreen extends StatefulWidget {
  const NewPinScreen({super.key, required this.resetToken, this.repository});
  final String resetToken;
  final AuthRepository? repository;

  @override
  State<NewPinScreen> createState() => _NewPinScreenState();
}

class _NewPinScreenState extends State<NewPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late final AuthRepository _repo = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateConfirm(String? v) {
    final base = validarContrasena(v);
    if (base != null) return base;
    if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.recoveryReset(
        resetToken: widget.resetToken,
        nuevaContrasena: _passwordCtrl.text,
      );
      if (!mounted) return;
      context.go('/login');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = mensajeDeError(e);
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
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => context.pop(),
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
                'Crea tu nueva contraseña',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa entre 8 y 64 caracteres. Puedes incluir letras, números y símbolos.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              PasswordField(
                controller: _passwordCtrl,
                hintText: 'Nueva contraseña',
                autofocus: true,
                enabled: !_loading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmCtrl,
                hintText: 'Confirma tu nueva contraseña',
                enabled: !_loading,
                validator: _validateConfirm,
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
                label: 'Guardar contraseña',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
