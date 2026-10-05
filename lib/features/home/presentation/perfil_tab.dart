import 'package:flutter/material.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/auth/data/auth_repository.dart';

/// Nombre de la persona o, si no hay, la razón social. Un texto vacío cuenta
/// como no guardado.
String? nombreDePerfil(SessionProfile perfil) {
  for (final v in [perfil.nombreCompleto, perfil.razonSocial]) {
    final limpio = v?.trim();
    if (limpio != null && limpio.isNotEmpty) return limpio;
  }
  return null;
}

class PerfilTab extends StatefulWidget {
  const PerfilTab({
    super.key,
    this.session = defaultSessionStore,
    this.authRepository,
  });

  final SessionStore session;

  /// Por defecto el repositorio de autenticación real.
  final AuthRepository? authRepository;

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  String? _nombre;
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  Future<void> _cargarNombre() async {
    try {
      final perfil = await widget.session.readProfile();
      if (mounted) setState(() => _nombre = nombreDePerfil(perfil));
    } catch (_) {
      // Sin perfil legible se queda "Mi cuenta".
    }
  }

  Future<void> _cerrarSesion() async {
    if (_cerrando) return;
    setState(() => _cerrando = true);
    try {
      await (widget.authRepository ?? AuthRepository()).logout();
    } catch (_) {
      // logout() borra la sesión local antes de propagar cualquier error,
      // así que el router ya llevó a /login.
    }
    if (mounted) setState(() => _cerrando = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perfil',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombre ?? 'Mi cuenta',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _SectionLabel('CUENTA'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: const [
                  _MenuItem(
                    icon: Icons.security_rounded,
                    label: 'Seguridad y PIN',
                    subtitle: 'Cambiar PIN, biométrico',
                  ),
                  Divider(color: AppColors.border, height: 1, indent: 60),
                  _MenuItem(
                    icon: Icons.badge_rounded,
                    label: 'Mis documentos',
                    subtitle: 'CC, fotos verificadas',
                  ),
                  Divider(color: AppColors.border, height: 1, indent: 60),
                  _MenuItem(
                    icon: Icons.account_balance_rounded,
                    label: 'Cuentas bancarias',
                    subtitle: 'Bancos vinculados',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionLabel('SOPORTE'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: const [
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Centro de ayuda',
                  ),
                  Divider(color: AppColors.border, height: 1, indent: 60),
                  _MenuItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat con soporte',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SectionLabel('LEGAL'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: const [
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: 'Términos y condiciones',
                  ),
                  Divider(color: AppColors.border, height: 1, indent: 60),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Política de privacidad',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _cerrando ? null : _cerrarSesion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.subtitle});

  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
