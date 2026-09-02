import 'package:flutter/material.dart';

class AuthConfirmWidget extends StatelessWidget {
  const AuthConfirmWidget({super.key, required this.onConfirm});
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onConfirm,
        child: const Text('Confirmar con huella o PIN'),
      );
}
