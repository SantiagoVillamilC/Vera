import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/celular.dart';
import 'package:vera/core/format/nit.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/auth_background.dart';
import 'package:vera/core/widgets/auth_scroll_body.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/core/widgets/pin_pad.dart';
import 'package:vera/core/widgets/vera_logo.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

enum _AccountType { persona, empresa }

// Límites del contrato (openapi.yaml): contraseña de 8 a 64, nombres hasta 200.
const _minContrasena = 8;
const _maxContrasena = 64;
const _maxNombre = 200;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0; // 0: type, 1: personal, 2: identity, 3: password, 4: otp
  _AccountType _accountType = _AccountType.persona;
  final _formKey = GlobalKey<FormState>();

  // Campos comunes
  final _correoCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  // Persona
  final _nombreCtrl = TextEditingController();
  String _tipoDoc = 'CC';
  final _numDocCtrl = TextEditingController();
  final _nacidaEnCtrl = TextEditingController();

  // Empresa
  final _razonSocialCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _repNombreCtrl = TextEditingController();
  String _repTipoDoc = 'CC';
  final _repNumDocCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  // Los consentimientos nunca arrancan marcados: el usuario los acepta a mano.
  bool _aceptaTratamientoDatos = false;
  bool _aceptaWhatsappOptin = false;
  String _challengeId = '';
  String _celularParaOtp = '';
  late final AuthRepository _repo = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    for (final c in [
      _correoCtrl,
      _celularCtrl,
      _contrasenaCtrl,
      _confirmarCtrl,
      _nombreCtrl,
      _numDocCtrl,
      _nacidaEnCtrl,
      _razonSocialCtrl,
      _nitCtrl,
      _repNombreCtrl,
      _repNumDocCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _consentimientosCompletos =>
      _aceptaTratamientoDatos && _aceptaWhatsappOptin;

  Future<void> _next() async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    // Step 3 → POST /v1/auth/register
    if (!_consentimientosCompletos) return;
    setState(() => _loading = true);
    try {
      final RegisterResult result;
      if (_accountType == _AccountType.persona) {
        result = await _repo.registerPersona(
          correo: _correoCtrl.text.trim(),
          contrasena: _contrasenaCtrl.text,
          celular: _celularCtrl.text.trim(),
          nombreCompleto: _nombreCtrl.text.trim(),
          tipoDocumento: _tipoDoc,
          numeroDocumento: _numDocCtrl.text.trim(),
          aceptaTratamientoDatos: _aceptaTratamientoDatos,
          aceptaWhatsappOptin: _aceptaWhatsappOptin,
        );
      } else {
        result = await _repo.registerEmpresa(
          razonSocial: _razonSocialCtrl.text.trim(),
          nit: _nitCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          contrasena: _contrasenaCtrl.text,
          celular: _celularCtrl.text.trim(),
          repNombre: _repNombreCtrl.text.trim(),
          repTipoDoc: _repTipoDoc,
          repNumDoc: _repNumDocCtrl.text.trim(),
          aceptaTratamientoDatos: _aceptaTratamientoDatos,
          aceptaWhatsappOptin: _aceptaWhatsappOptin,
        );
      }
      setState(() {
        _loading = false;
        _challengeId = result.challengeId;
        _celularParaOtp = _celularCtrl.text.trim();
        _step = 4;
      });
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

  void _back() {
    if (_step == 0) {
      context.go('/login');
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 4) {
      return OtpRegisterScreen(
        correo: _correoCtrl.text,
        celular: _celularParaOtp,
        challengeId: _challengeId,
        repository: _repo,
      );
    }

    // El botón Atrás del sistema hace lo mismo que la flecha: retrocede un
    // paso y solo sale (al inicio de sesión) desde el primero. Mientras se crea
    // la cuenta se ignora para no dejar la petición a medias.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_loading) _back();
      },
      child: AuthBackground(
        child: Column(
          children: [
            // La barra superior se desplaza con el contenido: en pantallas bajas
            // con teclado el botón fijo se queda con el espacio mínimo. La clave
            // por paso evita heredar el desplazamiento del paso anterior.
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(_step),
                child: Column(
                  children: [
                    _TopBar(step: _step, totalSteps: 4, onBack: _back),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                      child: _step == 0
                          ? _TypeStep(
                              selected: _accountType,
                              onChanged: (t) =>
                                  setState(() => _accountType = t),
                            )
                          : Form(key: _formKey, child: _stepContent()),
                    ),
                  ],
                ),
              ),
            ),
            if (_step == 3 && !_consentimientosCompletos)
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Text(
                  'Marca las dos casillas para crear la cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
              child: GradientButton(
                label: _step < 3 ? 'Continuar' : 'Crear cuenta',
                loading: _loading,
                onPressed:
                    _loading || (_step == 3 && !_consentimientosCompletos)
                    ? null
                    : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 1:
        return _accountType == _AccountType.persona
            ? _PersonaStep(
                correoCtrl: _correoCtrl,
                celularCtrl: _celularCtrl,
                nombreCtrl: _nombreCtrl,
              )
            : _EmpresaStep(
                correoCtrl: _correoCtrl,
                celularCtrl: _celularCtrl,
                razonSocialCtrl: _razonSocialCtrl,
                nitCtrl: _nitCtrl,
              );
      case 2:
        return _accountType == _AccountType.persona
            ? _PersonaIdentityStep(
                tipoDoc: _tipoDoc,
                onTipoDocChanged: (v) => setState(() => _tipoDoc = v!),
                numDocCtrl: _numDocCtrl,
                nacidaEnCtrl: _nacidaEnCtrl,
              )
            : _EmpresaRepStep(
                repNombreCtrl: _repNombreCtrl,
                repTipoDoc: _repTipoDoc,
                onRepTipoDocChanged: (v) => setState(() => _repTipoDoc = v!),
                repNumDocCtrl: _repNumDocCtrl,
              );
      case 3:
        return _PasswordStep(
          contrasenaCtrl: _contrasenaCtrl,
          confirmarCtrl: _confirmarCtrl,
          obscurePass: _obscurePass,
          obscureConfirm: _obscureConfirm,
          onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
          onToggleConfirm: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          aceptaTratamientoDatos: _aceptaTratamientoDatos,
          aceptaWhatsappOptin: _aceptaWhatsappOptin,
          onTratamientoDatosChanged: (v) =>
              setState(() => _aceptaTratamientoDatos = v ?? false),
          onWhatsappOptinChanged: (v) =>
              setState(() => _aceptaWhatsappOptin = v ?? false),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ──────────────────────────────────────────────
// Top bar with step indicator
// ──────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  static const _titles = [
    'Crear cuenta',
    'Tus datos',
    'Tu identidad',
    'Crea tu contraseña',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
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
          if (step > 0) ...[
            const SizedBox(height: 8),
            _StepBar(current: step, total: totalSteps),
          ],
          const SizedBox(height: 28),
          Text(
            _titles[step],
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(step),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _subtitle(int s) {
    switch (s) {
      case 0:
        return '¿Eres persona natural o empresa?';
      case 1:
        return 'Información de contacto';
      case 2:
        return 'Verificamos quién eres';
      case 3:
        return 'Entre 8 y 64 caracteres';
      default:
        return '';
    }
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: active ? AppGradients.brand : null,
              color: active ? null : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────
// Step 0: Account type selector
// ──────────────────────────────────────────────
class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.selected, required this.onChanged});
  final _AccountType selected;
  final ValueChanged<_AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _TypeCard(
          type: _AccountType.persona,
          icon: Icons.person_outline_rounded,
          title: 'Persona natural',
          subtitle: 'Cuenta personal para ti',
          selected: selected == _AccountType.persona,
          onTap: () => onChanged(_AccountType.persona),
        ),
        const SizedBox(height: 16),
        _TypeCard(
          type: _AccountType.empresa,
          icon: Icons.business_outlined,
          title: 'Empresa',
          subtitle: 'Cuenta para tu negocio',
          selected: selected == _AccountType.empresa,
          onTap: () => onChanged(_AccountType.empresa),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final _AccountType type;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: selected ? AppGradients.brand : null,
        color: selected ? null : AppColors.surfaceVariant,
        border: Border.all(
          color: selected ? Colors.transparent : AppColors.border,
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.gradientMid.withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withAlpha(30)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.textSecondary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withAlpha(180)
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? Colors.white : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Step 1a: Persona contact info
// ──────────────────────────────────────────────
class _PersonaStep extends StatelessWidget {
  const _PersonaStep({
    required this.correoCtrl,
    required this.celularCtrl,
    required this.nombreCtrl,
  });

  final TextEditingController correoCtrl;
  final TextEditingController celularCtrl;
  final TextEditingController nombreCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Nombre completo'),
        const SizedBox(height: 8),
        _Field(
          controller: nombreCtrl,
          hint: 'Ej. María García López',
          icon: Icons.person_outline_rounded,
          capitalization: TextCapitalization.words,
          maxLength: _maxNombre,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
            if (v.trim().split(' ').length < 2)
              return 'Escribe nombre y apellido';
            if (v.trim().length > _maxNombre)
              return 'Máximo $_maxNombre caracteres';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('Correo electrónico'),
        const SizedBox(height: 8),
        _Field(
          controller: correoCtrl,
          hint: 'tu@correo.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa tu correo';
            if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v)) {
              return 'Correo inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('Número de celular'),
        const SizedBox(height: 8),
        _PhoneField(controller: celularCtrl),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Step 1b: Empresa contact info
// ──────────────────────────────────────────────
class _EmpresaStep extends StatelessWidget {
  const _EmpresaStep({
    required this.correoCtrl,
    required this.celularCtrl,
    required this.razonSocialCtrl,
    required this.nitCtrl,
  });

  final TextEditingController correoCtrl;
  final TextEditingController celularCtrl;
  final TextEditingController razonSocialCtrl;
  final TextEditingController nitCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Razón social'),
        const SizedBox(height: 8),
        _Field(
          controller: razonSocialCtrl,
          hint: 'Ej. Mi Empresa S.A.S.',
          icon: Icons.business_outlined,
          capitalization: TextCapitalization.words,
          maxLength: _maxNombre,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa la razón social';
            if (v.trim().length > _maxNombre)
              return 'Máximo $_maxNombre caracteres';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('NIT (con dígito de verificación)'),
        const SizedBox(height: 8),
        _Field(
          controller: nitCtrl,
          hint: 'Ej. 900123456-8',
          icon: Icons.numbers_rounded,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa el NIT';
            if (!esNitValido(v)) {
              return 'El NIT no es válido. Revisa el dígito de verificación.';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('Correo electrónico'),
        const SizedBox(height: 8),
        _Field(
          controller: correoCtrl,
          hint: 'empresa@correo.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa el correo';
            if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v)) {
              return 'Correo inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('Celular de contacto'),
        const SizedBox(height: 8),
        _PhoneField(controller: celularCtrl),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Step 2a: Persona identity
// ──────────────────────────────────────────────
class _PersonaIdentityStep extends StatelessWidget {
  const _PersonaIdentityStep({
    required this.tipoDoc,
    required this.onTipoDocChanged,
    required this.numDocCtrl,
    required this.nacidaEnCtrl,
  });

  final String tipoDoc;
  final ValueChanged<String?> onTipoDocChanged;
  final TextEditingController numDocCtrl;
  final TextEditingController nacidaEnCtrl;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      nacidaEnCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Tipo de documento'),
        const SizedBox(height: 8),
        _DocTypeDropdown(value: tipoDoc, onChanged: onTipoDocChanged),
        const SizedBox(height: 20),
        _Label('Número de documento'),
        const SizedBox(height: 8),
        _Field(
          controller: numDocCtrl,
          hint: 'Sin puntos ni guiones',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) =>
              v == null || v.length < 6 ? 'Número inválido' : null,
        ),
        const SizedBox(height: 20),
        _Label('Fecha de nacimiento'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickDate(context),
          child: AbsorbPointer(
            child: _Field(
              controller: nacidaEnCtrl,
              hint: 'YYYY-MM-DD',
              icon: Icons.calendar_today_outlined,
              validator: (v) => v == null || v.isEmpty
                  ? 'Selecciona tu fecha de nacimiento'
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _InfoBanner(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Step 2b: Empresa representative
// ──────────────────────────────────────────────
class _EmpresaRepStep extends StatelessWidget {
  const _EmpresaRepStep({
    required this.repNombreCtrl,
    required this.repTipoDoc,
    required this.onRepTipoDocChanged,
    required this.repNumDocCtrl,
  });

  final TextEditingController repNombreCtrl;
  final String repTipoDoc;
  final ValueChanged<String?> onRepTipoDocChanged;
  final TextEditingController repNumDocCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Nombre del representante legal'),
        const SizedBox(height: 8),
        _Field(
          controller: repNombreCtrl,
          hint: 'Nombre completo',
          icon: Icons.person_outline_rounded,
          capitalization: TextCapitalization.words,
          maxLength: _maxNombre,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa el nombre';
            if (v.trim().split(' ').length < 2) return 'Nombre y apellido';
            if (v.trim().length > _maxNombre)
              return 'Máximo $_maxNombre caracteres';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _Label('Tipo de documento'),
        const SizedBox(height: 8),
        _DocTypeDropdown(value: repTipoDoc, onChanged: onRepTipoDocChanged),
        const SizedBox(height: 20),
        _Label('Número de documento'),
        const SizedBox(height: 8),
        _Field(
          controller: repNumDocCtrl,
          hint: 'Sin puntos ni guiones',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) =>
              v == null || v.length < 6 ? 'Número inválido' : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Step 3: Password
// ──────────────────────────────────────────────
class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.contrasenaCtrl,
    required this.confirmarCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.aceptaTratamientoDatos,
    required this.aceptaWhatsappOptin,
    required this.onTratamientoDatosChanged,
    required this.onWhatsappOptinChanged,
  });

  final TextEditingController contrasenaCtrl;
  final TextEditingController confirmarCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final bool aceptaTratamientoDatos;
  final bool aceptaWhatsappOptin;
  final ValueChanged<bool?> onTratamientoDatosChanged;
  final ValueChanged<bool?> onWhatsappOptinChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Contraseña'),
        const SizedBox(height: 8),
        TextFormField(
          controller: contrasenaCtrl,
          obscureText: obscurePass,
          textInputAction: TextInputAction.next,
          maxLength: _maxContrasena,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Entre 8 y 64 caracteres',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: onTogglePass,
              icon: Icon(
                obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa una contraseña';
            if (v.length < _minContrasena)
              return 'Mínimo $_minContrasena caracteres';
            if (v.length > _maxContrasena)
              return 'Máximo $_maxContrasena caracteres';
            return null;
          },
        ),
        const SizedBox(height: 8),
        _StrengthBar(controller: contrasenaCtrl),
        const SizedBox(height: 20),
        _Label('Confirmar contraseña'),
        const SizedBox(height: 8),
        TextFormField(
          controller: confirmarCtrl,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          maxLength: _maxContrasena,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Repite tu contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: onToggleConfirm,
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Confirma tu contraseña';
            if (v != contrasenaCtrl.text) return 'Las contraseñas no coinciden';
            return null;
          },
        ),
        const SizedBox(height: 20),
        // Etiquetas cortas y neutras: los textos legales siguen pendientes.
        _ConsentTile(
          key: const Key('consentimiento_tratamiento_datos'),
          value: aceptaTratamientoDatos,
          onChanged: onTratamientoDatosChanged,
          label: 'Autorizo el tratamiento de mis datos personales',
        ),
        _ConsentTile(
          key: const Key('consentimiento_whatsapp_optin'),
          value: aceptaWhatsappOptin,
          onChanged: onWhatsappOptinChanged,
          label: 'Acepto recibir mensajes por WhatsApp',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// OTP verification after register
// ──────────────────────────────────────────────
/// Pública para poder montarla en pruebas de widget sin recorrer el registro.
class OtpRegisterScreen extends StatefulWidget {
  const OtpRegisterScreen({
    super.key,
    required this.correo,
    required this.celular,
    required this.challengeId,
    required this.repository,
  });
  final String correo;
  final String celular;
  final String challengeId;
  final AuthRepository repository;

  @override
  State<OtpRegisterScreen> createState() => _OtpRegisterScreenState();
}

class _OtpRegisterScreenState extends State<OtpRegisterScreen> {
  static const _otpLength = 6;
  String _otp = '';
  bool _loading = false;
  bool _resending = false;
  // N-6: sin reenvíos ni desafío vigente no hay forma de verificar desde aquí.
  bool _sinSalida = false;
  int _resendSeconds = 60;
  AuthRepository get _repo => widget.repository;

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
    if (_loading || _sinSalida || _otp.length >= _otpLength) return;
    setState(() => _otp += d);
    if (_otp.length == _otpLength) _verify();
  }

  void _onDelete() {
    if (_loading || _sinSalida || _otp.isEmpty) return;
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      final result = await _repo.verifyPhone(
        celular: widget.celular,
        codigo: _otp,
      );
      if (!mounted) return;
      context.go('/register/backup-codes', extra: result.codigosRespaldo);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otp = '';
        _sinSalida = _esCallejonSinSalida(e);
      });
      if (!_sinSalida) _avisar(mensajeDeError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otp = '';
      });
      _avisar('Error de conexión. Intenta de nuevo.');
    }
  }

  static bool _esCallejonSinSalida(ApiException e) =>
      e.code == 'OtpTooManyResends' || e.code == 'ChallengeInvalid';

  void _avisar(String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  /// El contador de 60 s solo reinicia cuando el backend respondió 200.
  Future<void> _resend() async {
    if (_resending || _sinSalida) return;
    setState(() => _resending = true);
    try {
      await _repo.resendOtp(challengeId: widget.challengeId);
      if (!mounted) return;
      setState(() {
        _resending = false;
        _resendSeconds = 60;
        _otp = '';
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _sinSalida = e is ApiException && _esCallejonSinSalida(e);
      });
      if (!_sinSalida) _avisar(mensajeDeError(e));
    }
  }

  String get _maskedCelular {
    if (widget.celular.length < 4) return widget.celular;
    return '+57 ••• ••• ${widget.celular.substring(widget.celular.length - 4)}';
  }

  Widget _callejonSinSalida() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 44,
          ),
          const SizedBox(height: 20),
          const Text(
            'Esta verificación ya no puede continuar',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Pediste demasiados códigos o el código ya no es válido. Inicia sesión o recupera tu cuenta para seguir.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Iniciar sesión',
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/login/recovery'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gradientStart,
            ),
            child: const Text(
              'Recuperar mi cuenta',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sinSalida) {
      return AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 0, 28, 40),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: VeraLogo(size: 22),
                  ),
                ),
                _callejonSinSalida(),
              ],
            ),
          ),
        ),
      );
    }
    return AuthBackground(
      child: AuthScrollBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
              child: Row(
                children: [
                  const SizedBox.shrink(),
                  const Spacer(),
                  const VeraLogo(size: 22),
                ],
              ),
            ),
            const EspacioFlexible(flex: 2, minimo: 16),
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
              'Verifica tu número',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enviamos un código por WhatsApp a\n$_maskedCelular',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            _loading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.gradientStart),
                  )
                : PinDots(length: _otpLength, filled: _otp.length),
            const EspacioFlexible(flex: 1, minimo: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NumPad(onDigit: _onDigit, onDelete: _onDelete),
            ),
            const SizedBox(height: 20),
            _resendSeconds > 0
                ? Text(
                    'Reenviar en ${_resendSeconds}s',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  )
                : TextButton(
                    onPressed: _resending ? null : _resend,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gradientStart,
                    ),
                    child: const Text(
                      'Reenviar código',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
            const EspacioFlexible(flex: 1, minimo: 12),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Shared small widgets
// ──────────────────────────────────────────────
class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.accentGreen,
      side: const BorderSide(color: AppColors.border, width: 1.5),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.formatters,
    this.validator,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: validator,
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: const [CelularColombianoFormatter()],
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: const InputDecoration(
        hintText: '300 000 0000',
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 16, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇨🇴', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '+57',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 18,
                child: VerticalDivider(color: AppColors.border, width: 1),
              ),
            ],
          ),
        ),
        prefixIconConstraints: BoxConstraints(),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Ingresa tu celular';
        if (v.length < 10) return 'Número inválido';
        return null;
      },
    );
  }
}

class _DocTypeDropdown extends StatelessWidget {
  const _DocTypeDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      dropdownColor: AppColors.surfaceVariant,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'CC', child: Text('Cédula de ciudadanía')),
        DropdownMenuItem(value: 'CE', child: Text('Cédula de extranjería')),
        DropdownMenuItem(value: 'PA', child: Text('Pasaporte')),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gradientMid.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gradientMid.withAlpha(50)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.gradientStart, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu información está protegida con encriptación de 256 bits.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthBar extends StatefulWidget {
  const _StrengthBar({required this.controller});
  final TextEditingController controller;

  @override
  State<_StrengthBar> createState() => _StrengthBarState();
}

class _StrengthBarState extends State<_StrengthBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  int get _score {
    final p = widget.controller.text;
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(p)) s++;
    return s;
  }

  static const _colors = [
    AppColors.border,
    Color(0xFFFF5B79),
    Color(0xFFFFB347),
    Color(0xFF00D4FF),
    Color(0xFF00E5A0),
  ];
  static const _labels = ['', 'Débil', 'Regular', 'Buena', 'Fuerte'];

  @override
  Widget build(BuildContext context) {
    final s = _score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i < s ? _colors[s] : AppColors.border,
                ),
              ),
            );
          }),
        ),
        if (s > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Contraseña ${_labels[s]}',
              style: TextStyle(
                color: _colors[s],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
