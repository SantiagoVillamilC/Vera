import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/widgets/estado_vista.dart';

const mensajeErrorGenerico =
    'Algo salió mal. Intenta de nuevo en unos minutos.';

const mensajeValidacionGeneral =
    'Revisa los datos ingresados e intenta de nuevo.';

/// Mensaje en español para cualquier error. Se mapea por `code`, nunca por
/// `message`, porque el texto del servidor viene en ingles.
String mensajeDeError(Object error) {
  if (esErrorDeRed(error)) return mensajeSinRed;
  if (error is ApiException) {
    if (error.code == 'ValidationError') {
      final detalles = detallesDeCampo(error);
      if (detalles.isEmpty) return mensajeValidacionGeneral;
      return detalles.join('\n');
    }
    return _porCodigo[error.code] ?? mensajeErrorGenerico;
  }
  return mensajeErrorGenerico;
}

/// Un mensaje en español por cada elemento de `details` del ValidationError.
List<String> detallesDeCampo(ApiException e) {
  final details = e.details;
  if (details == null) return const [];
  return [
    for (final d in details)
      _mensajeDeCampo(
        d['field']?.toString() ?? '',
        d['rule']?.toString() ?? '',
        d['param']?.toString(),
      ),
  ];
}

const _porCodigo = <String, String>{
  'BadRequest': 'No pudimos entender la solicitud. Intenta de nuevo.',
  'ValidationError': mensajeValidacionGeneral,
  'Unauthorized': 'Tu sesión ya no es válida. Inicia sesión de nuevo.',
  'InvalidCredentials': 'El celular o la contraseña no son correctos.',
  'AccountSuspended':
      'Tu cuenta está suspendida. Comunícate con soporte para reactivarla.',
  'AccountClosed': 'Tu cuenta está cerrada y ya no se puede usar.',
  'OtpInvalid': 'El código no es correcto. Revísalo e intenta de nuevo.',
  'OtpExpired': 'El código venció. Solicita uno nuevo.',
  'ChallengeInvalid':
      'La verificación ya no es válida. Vuelve a empezar el proceso.',
  'OtpTooManyAttempts':
      'Superaste el límite de intentos del código. Solicita uno nuevo.',
  'OtpResendCooldown':
      'Espera cerca de un minuto antes de pedir otro código.',
  'RefreshInvalid': 'Tu sesión venció. Inicia sesión de nuevo.',
  'RefreshReused':
      'Detectamos un uso inusual de tu sesión. Inicia sesión de nuevo por seguridad.',
  'SessionNotFound': 'No encontramos tu sesión. Inicia sesión de nuevo.',
  'NoCompanyRole': 'No tienes un rol asignado en esta empresa.',
  'ContextInvalid': 'El perfil seleccionado no es válido. Elige otro.',
  'ResetInvalid':
      'El enlace para restablecer la contraseña no es válido o ya venció.',
  'SecondFactorRequired':
      'Necesitas completar la verificación adicional para continuar.',
  'KycRequired':
      'Debes verificar tu identidad para realizar esta operación.',
  'ConsentRequired':
      'Debes aceptar los términos requeridos para continuar.',
  'DuplicateIdentifier':
      'Ya existe una cuenta con ese celular, correo o documento.',
  'PhoneUnverified': 'Primero debes verificar tu número de celular.',
  'OtpTooManyResends':
      'Pediste demasiados códigos. Intenta de nuevo más tarde.',
  'PhoneChangeCooldown':
      'Cambiaste tu celular hace poco. Espera antes de hacerlo otra vez.',
  'TooManyRequests':
      'Hiciste demasiadas solicitudes. Intenta de nuevo más tarde.',
  'NotImplemented': 'Esta función aún no está disponible.',
  'PayloadTooLarge': 'Los datos enviados son demasiado grandes.',
  'RecipientNotFound': 'No encontramos al destinatario. Revisa los datos.',
  'SelfTransferNotAllowed': 'No puedes enviarte dinero a ti mismo.',
  'MethodNotAllowed': 'Esta acción no está permitida.',
  'NotFound': 'No encontramos lo que buscas.',
  'AuthUnavailable':
      'El servicio de autenticación no está disponible. Intenta de nuevo en unos minutos.',
  'OtpDeliveryFailed':
      'No pudimos enviarte el código. Intenta de nuevo en unos minutos.',
  'Timeout': 'El servidor tardó demasiado en responder. Intenta de nuevo.',
  'WhatsappUnicoCanal':
      'No puedes desactivar WhatsApp mientras sea tu único canal para recibir códigos.',
  'InternalError': 'Tuvimos un problema de nuestro lado. Intenta más tarde.',
  'InsufficientFunds': 'No tienes saldo suficiente para esta operación.',
  'OperationLimitExceeded':
      'El monto supera el límite permitido por operación.',
  'MonthlyQuotaExceeded': 'Superaste tu límite mensual de operaciones.',
  'IdempotencyConflict':
      'Esta operación ya se envió con datos diferentes. Inicia una nueva.',
  'TargetNotAllowed': 'No puedes enviar dinero a este destino.',
  'DirectoryUnavailable':
      'El directorio de destinatarios no está disponible. Intenta más tarde.',
  'ConfirmationConflict': 'Este depósito ya fue confirmado antes.',
  'LateConfirmation':
      'La confirmación llegó fuera de tiempo y no se pudo aplicar.',
  'DepositNotFound': 'No encontramos el depósito indicado.',
  'NotReady':
      'El servicio no está listo en este momento. Intenta de nuevo en unos minutos.',
  'CorreccionEnCurso':
      'Hay otra actualización en curso. Intenta de nuevo en unos segundos.',
  'CopiaSinReconstruir':
      'Los movimientos aún se están procesando. Intenta de nuevo en un momento.',
};

const _etiquetas = <String, ({String nombre, bool masculino})>{
  'contrasena': (nombre: 'contraseña', masculino: false),
  'nueva_contrasena': (nombre: 'contraseña', masculino: false),
  'contrasena_actual': (nombre: 'contraseña actual', masculino: false),
  'celular': (nombre: 'celular', masculino: true),
  'nuevo_celular': (nombre: 'celular', masculino: true),
  'correo': (nombre: 'correo', masculino: true),
  'nit': (nombre: 'NIT', masculino: true),
  'razon_social': (nombre: 'razón social', masculino: false),
  'nombre_completo': (nombre: 'nombre completo', masculino: true),
  'representante_legal.nombre_completo': (
    nombre: 'nombre del representante legal',
    masculino: true,
  ),
  'codigo': (nombre: 'código', masculino: true),
  'monto': (nombre: 'monto', masculino: true),
  'llave': (nombre: 'llave', masculino: false),
  'destino': (nombre: 'destino', masculino: true),
  'tipo_llave': (nombre: 'tipo de llave', masculino: true),
  'version_texto': (nombre: 'versión del texto', masculino: false),
  'categoria': (nombre: 'categoría', masculino: false),
  'nombre_comercio': (nombre: 'nombre del comercio', masculino: true),
};

String _mensajeDeCampo(String campo, String regla, String? param) {
  final et = _etiquetas[campo];
  if (et == null) return mensajeValidacionGeneral;
  final articulo = et.masculino ? 'El' : 'La';
  final nombre = et.nombre;
  switch (regla) {
    case 'required':
      return '$articulo $nombre es obligatori${et.masculino ? 'o' : 'a'}';
    case 'min':
      if (param == null) return mensajeValidacionGeneral;
      return '$articulo $nombre debe tener al menos $param caracteres';
    case 'max':
      if (param == null) return mensajeValidacionGeneral;
      return '$articulo $nombre debe tener como máximo $param caracteres';
    case 'len':
      if (param == null) return mensajeValidacionGeneral;
      final unidad = campo == 'codigo' ? 'dígitos' : 'caracteres';
      return '$articulo $nombre debe tener $param $unidad';
    case 'e164':
      return 'El número de celular no es válido';
    case 'email':
      return 'El correo no es válido';
    case 'nit':
      return 'El NIT no es válido';
    case 'nombre':
      return '$articulo $nombre no es válido, usa solo letras sin números ni símbolos';
    case 'number':
      return '$articulo $nombre debe contener solo números';
    case 'gt':
      return param == '0'
          ? '$articulo $nombre debe ser mayor que cero'
          : mensajeValidacionGeneral;
    case 'oneof':
      return '$articulo $nombre no es una opción válida';
    case 'categoria_visible':
      return 'Esa categoría no aplica a este movimiento';
    case 'solo_comercio':
      return 'Solo puedes cambiar el nombre de un pago a un comercio';
    default:
      return mensajeValidacionGeneral;
  }
}
