import 'package:flutter/material.dart';
import 'package:vera/core/format/saludo.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/marca_vera.dart';
import 'package:vera/core/widgets/tarjeta_vidrio.dart';
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
  String? _tipoCuenta;
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
      if (mounted) {
        setState(() {
          _nombre = nombreDePerfil(perfil);
          _tipoCuenta = perfil.tipoCuenta;
        });
      }
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cabecera(nombre: _nombre, tipoCuenta: _tipoCuenta),
            const SizedBox(height: 22),
            const _EtiquetaSeccion('CUENTA'),
            _GrupoPerfil(
              children: [
                if (_biometriaDisponible)
                  _FilaPerfil(
                    icono: Icons.fingerprint_rounded,
                    etiqueta: 'Desbloqueo con huella o rostro',
                    alTocar: _cambiandoBiometria
                        ? null
                        : () => _cambiarBiometria(!_biometriaActiva),
                    derecha: Switch(
                      key: const Key('biometria_switch'),
                      value: _biometriaActiva,
                      onChanged: _cambiandoBiometria ? null : _cambiarBiometria,
                      activeThumbColor: AppColors.tintaBotonClaro,
                      activeTrackColor: AppColors.accentGreen,
                    ),
                  ),
                if (_consentVera?.autorizado ?? false)
                  _FilaPerfil(
                    key: const Key('desactivar_vera'),
                    icono: Icons.auto_awesome_outlined,
                    etiqueta: 'Desactivar a Vera',
                    alTocar: _revocandoVera ? null : _desactivarVera,
                  ),
                _FilaPerfil(
                  key: const Key('borrar_historial_vera'),
                  icono: Icons.delete_sweep_outlined,
                  etiqueta: 'Borrar historial de Vera',
                  alTocar: _borrandoHistorial ? null : _borrarHistorialDeVera,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: TextButton.icon(
                onPressed: _cerrando ? null : _cerrarSesion,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gradientStart,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 22),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.nombre, required this.tipoCuenta});

  final String? nombre;
  final String? tipoCuenta;

  @override
  Widget build(BuildContext context) {
    final etiquetaCuenta = tipoCuenta == 'empresa'
        ? 'Cuenta empresa'
        : 'Cuenta personal';
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          AvatarVera(iniciales: inicialesDe(nombre), tamano: 104),
          const SizedBox(height: 14),
          Text(
            nombre ?? 'Mi cuenta',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Text(
              etiquetaCuenta,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetaSeccion extends StatelessWidget {
  const _EtiquetaSeccion(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Grupo de filas en una tarjeta de vidrio, con separadores entre ellas.
class _GrupoPerfil extends StatelessWidget {
  const _GrupoPerfil({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TarjetaVidrio(
      radio: 26,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(color: Colors.white.withAlpha(22), height: 1, indent: 44),
          ],
        ],
      ),
    );
  }
}

/// Fila de ajustes con una función.
class _FilaPerfil extends StatelessWidget {
  const _FilaPerfil({
    super.key,
    required this.icono,
    required this.etiqueta,
    this.alTocar,
    this.derecha,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alTocar;

  /// Reemplaza la flecha del final, por ejemplo con un interruptor o una insignia.
  final Widget? derecha;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icono, color: AppColors.gradientStart, size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (derecha != null)
              derecha!
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
