import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/widgets/estado_vista.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

const mensajeErrorConexionEnvio = 'Error de conexión. Intenta de nuevo.';

const mensajeReintentoEnvio =
    'No pudimos confirmar el envío. Vuelve a intentarlo, no se duplicará.';

/// Resultado de un envío para mostrar al usuario. Solo `confirmada` es éxito.
class ResultadoEnvio {
  const ResultadoEnvio({required this.mensaje, required this.exito});
  final String mensaje;
  final bool exito;
}

ResultadoEnvio resultadoDeEstado(EstadoTransferencia estado) => switch (estado) {
      EstadoTransferencia.confirmada => const ResultadoEnvio(
          mensaje: 'Envío confirmado. El dinero ya llegó al destinatario.',
          exito: true,
        ),
      EstadoTransferencia.creada => const ResultadoEnvio(
          mensaje:
              'Recibimos tu envío y lo estamos procesando. Revisa el historial para ver el resultado.',
          exito: false,
        ),
      EstadoTransferencia.reservada => const ResultadoEnvio(
          mensaje:
              'Reservamos el dinero y el envío está en proceso. Revisa el historial para ver el resultado.',
          exito: false,
        ),
      EstadoTransferencia.despachada => const ResultadoEnvio(
          mensaje:
              'Tu envío salió y estamos esperando la confirmación. Revisa el historial para ver el resultado.',
          exito: false,
        ),
      EstadoTransferencia.indeterminada => const ResultadoEnvio(
          mensaje:
              'No pudimos confirmar si el envío se completó. Revisa el historial antes de hacer otro envío.',
          exito: false,
        ),
      EstadoTransferencia.fallida => const ResultadoEnvio(
          mensaje: 'El envío no se pudo completar. Puedes intentarlo de nuevo.',
          exito: false,
        ),
      EstadoTransferencia.compensada => const ResultadoEnvio(
          mensaje:
              'El envío no se completó y el dinero volvió a tu saldo. Revisa el historial para ver el detalle.',
          exito: false,
        ),
      EstadoTransferencia.desconocido => const ResultadoEnvio(
          mensaje:
              'No reconocemos el estado de este envío. Revisa el historial antes de hacer otro envío.',
          exito: false,
        ),
    };

/// Mensaje para un error al enviar. Los 5xx y los fallos de conexión son
/// resultados desconocidos: se reintenta con la misma operación.
String mensajeDeErrorEnvio(Object error) {
  if (esErrorDeRed(error)) return mensajeErrorConexionEnvio;
  if (error is ApiException) {
    final s = error.statusCode;
    if (error.code == 'InternalError' || (s != null && s >= 500)) {
      return mensajeReintentoEnvio;
    }
  }
  return mensajeDeError(error);
}
