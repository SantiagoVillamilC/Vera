import 'package:flutter/material.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/gradient_button.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';

/// Pantalla de activación de Vera: explica qué hace, qué comparte y pide la
/// autorización explícita antes de abrir el chat. El texto legal y su versión
/// llegan del servidor, así que un cambio de texto no exige publicar la app.
class ActivacionVeraView extends StatefulWidget {
  const ActivacionVeraView({
    super.key,
    required this.consentimiento,
    required this.activando,
    required this.error,
    required this.onActivar,
    required this.onAhoraNo,
  });

  final ConsentimientoAsistente consentimiento;
  final bool activando;

  /// Mensaje del último intento de activación fallido, si lo hubo.
  final String? error;
  final VoidCallback onActivar;
  final VoidCallback onAhoraNo;

  @override
  State<ActivacionVeraView> createState() => _ActivacionVeraViewState();
}

class _ActivacionVeraViewState extends State<ActivacionVeraView> {
  bool _verTexto = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.consentimiento;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activa a Vera',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Antes de empezar, esto es lo que debes saber.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Punto(
                    icono: Icons.chat_bubble_outline_rounded,
                    titulo: 'Qué hace Vera',
                    texto:
                        'Responde tus preguntas sobre tu saldo y tus movimientos y te ayuda a preparar operaciones.',
                  ),
                  const _Punto(
                    icono: Icons.verified_user_outlined,
                    titulo: 'Tu dinero solo se mueve con tu confirmación',
                    texto:
                        'Vera prepara la operación y tú decides si se confirma.',
                  ),
                  const _Punto(
                    icono: Icons.cloud_outlined,
                    titulo: 'Usa un proveedor externo de IA',
                    texto:
                        'Para responder, Vera envía fragmentos de tu saldo y tus movimientos a un proveedor externo de inteligencia artificial.',
                  ),
                  _Punto(
                    icono: Icons.schedule_rounded,
                    titulo: 'Datos y conservación',
                    texto:
                        'El detalle de los datos que se comparten y del tiempo que se conservan está en el texto completo, versión ${c.versionTexto}. Puedes borrar tus conversaciones cuando quieras.',
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    key: const Key('ver_texto_completo'),
                    onPressed: () => setState(() => _verTexto = !_verTexto),
                    icon: Icon(
                      _verTexto
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text('Texto completo (versión ${c.versionTexto})'),
                  ),
                  if (_verTexto)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        c.texto,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.error != null) ...[
                  Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GradientButton(
                  label: widget.error != null ? 'Reintentar' : 'Activar Vera',
                  loading: widget.activando,
                  onPressed: widget.activando ? null : widget.onActivar,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: widget.activando ? null : widget.onAhoraNo,
                  child: const Text(
                    'Ahora no',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.gradientStart, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
