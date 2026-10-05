import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';

const contrasenaMinima = 8;
const contrasenaMaxima = 64;

/// Valida la contraseña con el rango del contrato (8 a 64 caracteres).
String? validarContrasena(String? valor) {
  final v = valor ?? '';
  if (v.isEmpty) return 'Ingresa tu contraseña';
  if (v.length < contrasenaMinima) {
    return 'La contraseña debe tener al menos $contrasenaMinima caracteres';
  }
  if (v.length > contrasenaMaxima) {
    return 'La contraseña debe tener como máximo $contrasenaMaxima caracteres';
  }
  return null;
}

/// Campo de contraseña oculto con botón para mostrar u ocultar. Acepta
/// cualquier carácter y no corrige ni sugiere texto.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText = 'Contraseña',
    this.autofocus = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.validator = validarContrasena,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String> validator;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: !_visible,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.password],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      validator: widget.validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
          onPressed: () => setState(() => _visible = !_visible),
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
      ),
    );
  }
}
