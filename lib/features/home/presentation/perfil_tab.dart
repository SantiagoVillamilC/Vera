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
