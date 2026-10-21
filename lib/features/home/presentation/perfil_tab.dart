import 'package:flutter/material.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/wip_badge.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/confirmar_borrado.dart';
import 'package:vera/core/network/error_messages.dart';
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
    this.session,
    this.authRepository,
    this.asistente,
  });

  final SessionStore? session;

  /// Por defecto el repositorio de autenticación real.
  final AuthRepository? authRepository;

  /// Por defecto el repositorio real del asistente (borrar el historial de Vera).
  final AsistenteRepository? asistente;

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  late final AuthRepository _repository =
      widget.authRepository ?? AuthRepository();
  late final AsistenteRepository _asistente =
      widget.asistente ?? AsistenteRepository();
  String? _nombre;
  bool _cerrando = false;
  bool _borrandoHistorial = false;
  ConsentimientoAsistente? _consentVera;
  bool _revocandoVera = false;
  bool _biometriaDisponible = false;
  bool _biometriaActiva = false;
  bool _cambiandoBiometria = false;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    _cargarBiometria();
    _cargarConsentimientoVera();
  }

  Future<void> _cargarConsentimientoVera() async {
    try {
      final c = await _asistente.consultarConsentimiento();
      if (mounted) setState(() => _consentVera = c);
    } catch (_) {
      // Sin el dato no se ofrece desactivar a Vera.
    }
  }

  /// Revoca el consentimiento de IA: el chat queda bloqueado hasta una nueva activación.
  /// Después ofrece borrar también el historial.
  Future<void> _desactivarVera() async {
    final c = _consentVera;
    if (c == null || _revocandoVera) return;
    final ok = await confirmarBorrado(
      context,
      titulo: '¿Desactivar a Vera?',
      detalle:
          'Vera dejará de usar tus datos y no podrás conversar con ella hasta que la actives de nuevo.',
      etiquetaConfirmar: 'Desactivar',
    );
    if (ok != true || !mounted) return;
    await _revocarVera(c);
  }

  Future<void> _revocarVera(ConsentimientoAsistente c) async {
    setState(() => _revocandoVera = true);
    try {
      await _asistente.revocarConsentimiento(c.versionTexto);
      if (!mounted) return;
      setState(() => _consentVera = null);
      final borrar = await confirmarBorrado(
        context,
        titulo: '¿Borrar también tu historial?',
        detalle:
            'Se borran tus conversaciones con Vera y se cancelan sus acciones pendientes.',
        etiquetaConfirmar: 'Borrar historial',
        etiquetaCancelar: 'Conservar',
      );
      if (borrar == true && mounted) await _ejecutarBorradoHistorial();
    } catch (e) {
      if (mounted) {
        avisarErrorDeBorrado(context, mensajeDeError(e), () => _revocarVera(c));
      }
    }
    if (mounted) setState(() => _revocandoVera = false);
  }

  Future<void> _cargarBiometria() async {
    try {
      final disponible = await _repository.biometriaDisponible();
      final activa = disponible && await _repository.biometriaHabilitada();
      if (mounted) {
        setState(() {
          _biometriaDisponible = disponible;
          _biometriaActiva = activa;
        });
      }
    } catch (_) {
      // Sin poder consultar la biometría la opción no se ofrece.
    }
  }

  Future<void> _cambiarBiometria(bool activar) async {
    if (_cambiandoBiometria) return;
    setState(() => _cambiandoBiometria = true);
    try {
      if (activar) {
        final ok = await _repository.habilitarBiometria();
        if (mounted) setState(() => _biometriaActiva = ok);
      } else if (await _confirmarDesactivar() == true) {
        // Desactivar borra el enrolamiento local y la sesión: sigue el login completo.
        await _repository.logout();
      }
    } catch (_) {
      // El interruptor queda como estaba si el sistema rechaza la operación.
    }
    if (mounted) setState(() => _cambiandoBiometria = false);
  }

  Future<void> _borrarHistorialDeVera() async {
    if (_borrandoHistorial) return;
    final ok = await confirmarBorrado(
      context,
      titulo: '¿Borrar el historial de Vera?',
      detalle:
          'Se borran todas tus conversaciones y se cancelan sus acciones pendientes. No se puede deshacer.',
    );
    if (ok == true && mounted) await _ejecutarBorradoHistorial();
  }

  Future<void> _ejecutarBorradoHistorial() async {
    setState(() => _borrandoHistorial = true);
    try {
      await _asistente.borrarConversaciones();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial de Vera borrado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        avisarErrorDeBorrado(
          context,
          mensajeDeError(e),
          _ejecutarBorradoHistorial,
        );
      }
    }
    if (mounted) setState(() => _borrandoHistorial = false);
  }

  Future<bool?> _confirmarDesactivar() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Desactivar desbloqueo biométrico'),
      content: const Text(
        'Cerraremos tu sesión y tendrás que iniciar sesión completa la próxima vez.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Desactivar'),
        ),
      ],
    ),
  );

  Future<void> _cargarNombre() async {
    try {
      final perfil = await (widget.session ?? defaultSessionStore)
          .readProfile();
      if (mounted) setState(() => _nombre = nombreDePerfil(perfil));
    } catch (_) {
      // Sin perfil legible se queda "Mi cuenta".
    }
  }

  Future<void> _cerrarSesion() async {
    if (_cerrando) return;
    setState(() => _cerrando = true);
    try {
      await _repository.logout();
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
                children: [
                  if (_biometriaDisponible) ...[
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        key: const Key('biometria_switch'),
                        value: _biometriaActiva,
                        onChanged: _cambiandoBiometria
                            ? null
                            : _cambiarBiometria,
                        secondary: const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.textSecondary,
                        ),
                        title: const Text(
                          'Desbloqueo con huella o rostro',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      color: AppColors.border,
                      height: 1,
                      indent: 60,
                    ),
                  ],
                  if (_consentVera?.autorizado ?? false) ...[
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        key: const Key('desactivar_vera'),
                        enabled: !_revocandoVera,
                        onTap: _desactivarVera,
                        leading: const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.textSecondary,
                        ),
                        title: const Text(
                          'Desactivar a Vera',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Divider(
                      color: AppColors.border,
                      height: 1,
                      indent: 60,
                    ),
                  ],
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      key: const Key('borrar_historial_vera'),
                      enabled: !_borrandoHistorial,
                      onTap: _borrarHistorialDeVera,
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.textSecondary,
                      ),
                      title: const Text(
                        'Borrar historial de Vera',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1, indent: 60),
                  const _MenuItem(
                    icon: Icons.security_rounded,
                    label: 'Seguridad y PIN',
                  ),
                  const Divider(color: AppColors.border, height: 1, indent: 60),
                  const _MenuItem(
                    icon: Icons.badge_rounded,
                    label: 'Mis documentos',
                  ),
                  const Divider(color: AppColors.border, height: 1, indent: 60),
                  const _MenuItem(
                    icon: Icons.account_balance_rounded,
                    label: 'Cuentas bancarias',
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
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const WipBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
