import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';

ApiException _api(String code, {List<Map<String, dynamic>>? details}) =>
    ApiException(
      code: code,
      message: 'English server message for $code',
      details: details,
      statusCode: 400,
    );

void main() {
  const catalogo = <String>[
    'BadRequest',
    'ValidationError',
    'Unauthorized',
    'InvalidCredentials',
    'AccountSuspended',
    'AccountClosed',
    'OtpInvalid',
    'OtpExpired',
    'ChallengeInvalid',
    'OtpTooManyAttempts',
    'OtpResendCooldown',
    'RefreshInvalid',
    'RefreshReused',
    'SessionNotFound',
    'NoCompanyRole',
    'ContextInvalid',
    'ResetInvalid',
    'SecondFactorRequired',
    'KycRequired',
    'ConsentRequired',
    'DuplicateIdentifier',
    'PhoneUnverified',
    'OtpTooManyResends',
    'PhoneChangeCooldown',
    'TooManyRequests',
    'NotImplemented',
    'PayloadTooLarge',
    'RecipientNotFound',
    'SelfTransferNotAllowed',
    'MethodNotAllowed',
    'NotFound',
    'AuthUnavailable',
    'OtpDeliveryFailed',
    'Timeout',
    'WhatsappUnicoCanal',
    'InternalError',
    'InsufficientFunds',
    'OperationLimitExceeded',
    'MonthlyQuotaExceeded',
    'IdempotencyConflict',
    'TargetNotAllowed',
    'DirectoryUnavailable',
    'ConfirmationConflict',
    'LateConfirmation',
    'DepositNotFound',
    'NotReady',
  ];

  group('mensajeDeError por code', () {
    for (final code in catalogo) {
      test('$code tiene mensaje en español', () {
        final msg = mensajeDeError(_api(code));
        expect(msg, isNotEmpty);
        expect(msg, isNot(contains('English server message')));
        expect(msg, isNot(mensajeDeError(_api('CodigoQueNoExiste'))),
            reason: '$code no debe caer en el mensaje genérico');
      });
    }

    test('los mensajes del catálogo son distintos entre sí', () {
      final mensajes = {for (final c in catalogo) c: mensajeDeError(_api(c))};
      expect(mensajes.values.toSet().length, greaterThan(40));
    });

    test('nunca contiene rayas largas, cortas ni punto y coma', () {
      for (final code in catalogo) {
        final msg = mensajeDeError(_api(code));
        expect(msg, isNot(contains(String.fromCharCode(0x2014))));
        expect(msg, isNot(contains(String.fromCharCode(0x2013))));
        expect(msg, isNot(contains(';')));
      }
    });
  });

  group('código desconocido y red', () {
    test('código desconocido da mensaje genérico sin el message ingles', () {
      final msg = mensajeDeError(_api('AlgoNuevo'));
      expect(msg, isNotEmpty);
      expect(msg, isNot(contains('English')));
    });

    test('error de red', () {
      const esperado = 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      expect(mensajeDeError(http.ClientException('boom')), esperado);
      expect(mensajeDeError(TimeoutException('t')), esperado);
    });

    test('objeto no reconocido da mensaje genérico', () {
      final msg = mensajeDeError(StateError('English boom'));
      expect(msg, isNotEmpty);
      expect(msg, isNot(contains('English')));
    });
  });

  group('ValidationError con details', () {
    test('contraseña min 8', () {
      final e = _api('ValidationError', details: [
        {'field': 'nueva_contrasena', 'rule': 'min', 'param': '8'},
      ]);
      expect(detallesDeCampo(e),
          ['La contraseña debe tener al menos 8 caracteres']);
      expect(mensajeDeError(e),
          'La contraseña debe tener al menos 8 caracteres');
    });

    test('contraseña max 64', () {
      final e = _api('ValidationError', details: [
        {'field': 'contrasena', 'rule': 'max', 'param': '64'},
      ]);
      expect(detallesDeCampo(e),
          ['La contraseña debe tener como máximo 64 caracteres']);
    });

    test('celular e164', () {
      final e = _api('ValidationError', details: [
        {'field': 'celular', 'rule': 'e164'},
      ]);
      expect(detallesDeCampo(e), ['El número de celular no es válido']);
    });

    test('nuevo_celular e164', () {
      final e = _api('ValidationError', details: [
        {'field': 'nuevo_celular', 'rule': 'e164'},
      ]);
      expect(detallesDeCampo(e), ['El número de celular no es válido']);
    });

    test('nombre con dígitos (regla nombre)', () {
      final e = _api('ValidationError', details: [
        {'field': 'nombre_completo', 'rule': 'nombre'},
      ]);
      expect(detallesDeCampo(e), [
        'El nombre completo no es válido, usa solo letras sin números ni símbolos',
      ]);
    });

    test('nombre del representante legal (regla nombre)', () {
      final e = _api('ValidationError', details: [
        {'field': 'representante_legal.nombre_completo', 'rule': 'nombre'},
      ]);
      expect(detallesDeCampo(e), [
        'El nombre del representante legal no es válido, usa solo letras sin números ni símbolos',
      ]);
    });

    test('nombre completo max 200', () {
      final e = _api('ValidationError', details: [
        {'field': 'nombre_completo', 'rule': 'max', 'param': '200'},
      ]);
      expect(detallesDeCampo(e),
          ['El nombre completo debe tener como máximo 200 caracteres']);
    });

    test('correo email', () {
      final e = _api('ValidationError', details: [
        {'field': 'correo', 'rule': 'email'},
      ]);
      expect(detallesDeCampo(e), ['El correo no es válido']);
    });

    test('nit', () {
      final e = _api('ValidationError', details: [
        {'field': 'nit', 'rule': 'nit'},
      ]);
      expect(detallesDeCampo(e), ['El NIT no es válido']);
    });

    test('razon social max', () {
      final e = _api('ValidationError', details: [
        {'field': 'razon_social', 'rule': 'max', 'param': '200'},
      ]);
      expect(detallesDeCampo(e),
          ['La razón social debe tener como máximo 200 caracteres']);
    });

    test('required', () {
      final e = _api('ValidationError', details: [
        {'field': 'celular', 'rule': 'required'},
      ]);
      expect(detallesDeCampo(e), ['El celular es obligatorio']);
    });

    test('código len 6', () {
      final e = _api('ValidationError', details: [
        {'field': 'codigo', 'rule': 'len', 'param': '6'},
      ]);
      expect(detallesDeCampo(e), ['El código debe tener 6 dígitos']);
    });

    test('monto gt 0', () {
      final e = _api('ValidationError', details: [
        {'field': 'monto', 'rule': 'gt', 'param': '0'},
      ]);
      expect(detallesDeCampo(e), ['El monto debe ser mayor que cero']);
    });

    test('campo desconocido cae en mensaje general', () {
      final e = _api('ValidationError', details: [
        {'field': 'campo_raro', 'rule': 'regla_rara'},
      ]);
      final detalles = detallesDeCampo(e);
      expect(detalles, hasLength(1));
      expect(detalles.single, isNotEmpty);
      expect(detalles.single, isNot(contains('campo_raro')));
      expect(mensajeDeError(e), detalles.single);
    });

    test('varios details se unen y detalles vacíos caen en general', () {
      final e = _api('ValidationError', details: [
        {'field': 'celular', 'rule': 'e164'},
        {'field': 'correo', 'rule': 'email'},
      ]);
      expect(detallesDeCampo(e), hasLength(2));
      expect(mensajeDeError(e), contains('El número de celular no es válido'));
      expect(mensajeDeError(e), contains('El correo no es válido'));

      final sin = _api('ValidationError');
      expect(detallesDeCampo(sin), isEmpty);
      expect(mensajeDeError(sin), isNotEmpty);
      expect(mensajeDeError(sin), isNot(contains('English')));
    });
  });

  test('una FormatException da el mensaje genérico y no su texto', () {
    final msg = mensajeDeError(const FormatException('Campo "monto" ausente'));
    expect(msg, mensajeErrorGenerico);
    expect(msg, isNot(contains('FormatException')));
  });
}
