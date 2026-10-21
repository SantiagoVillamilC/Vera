import 'package:local_auth/local_auth.dart';

enum ResultadoVerificacion {
  /// La persona se identificó con huella, rostro o el PIN del teléfono.
  exitosa,

  /// Canceló o la verificación falló.
  rechazada,

  /// El teléfono no tiene biometría ni bloqueo de pantalla con los que verificar.
  noDisponible,
}

/// Verificación local de que quien tiene el teléfono es su dueño. No viaja nada al servidor:
/// solo decide si la app puede confirmar sin pedir el código de WhatsApp.
abstract interface class VerificadorLocal {
  Future<ResultadoVerificacion> verificar(String motivo);
}

class VerificadorLocalAuth implements VerificadorLocal {
  VerificadorLocalAuth([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<ResultadoVerificacion> verificar(String motivo) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return ResultadoVerificacion.noDisponible;
      }
      final ok = await _auth.authenticate(
        localizedReason: motivo,
        persistAcrossBackgrounding: true,
      );
      return ok
          ? ResultadoVerificacion.exitosa
          : ResultadoVerificacion.rechazada;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware =>
          ResultadoVerificacion.noDisponible,
        _ => ResultadoVerificacion.rechazada,
      };
    } on Object {
      return ResultadoVerificacion.rechazada;
    }
  }
}
