import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

void main() {
  test('limites vacío (lo que responde el backend hoy) no trae tope', () {
    final kyc = KycEstado.fromJson({
      'producto': 'bajo_monto',
      'estado_kyc': 'basico',
      'limites': <String, dynamic>{},
    });

    expect(kyc.esBajoMonto, isTrue);
    expect(kyc.tieneLimites, isFalse);
  });

  test('tope y disponible llegan como string de centavos', () {
    final kyc = KycEstado.fromJson({
      'producto': 'bajo_monto',
      'estado_kyc': 'basico',
      'limites': {
        'tope_mensual': '100000000',
        'disponible_mes': '60000000',
      },
    });

    expect(kyc.topeMensual, BigInt.from(100000000));
    expect(kyc.disponibleMes, BigInt.from(60000000));
    expect(kyc.tieneLimites, isTrue);
  });

  test('un valor no numérico se ignora en vez de romper', () {
    final kyc = KycEstado.fromJson({
      'producto': 'bajo_monto',
      'estado_kyc': 'basico',
      'limites': {'tope_mensual': 'mucho', 'disponible_mes': 5},
    });

    expect(kyc.tieneLimites, isFalse);
  });

  test('sin limites el estado igual se lee', () {
    final kyc = KycEstado.fromJson({'producto': 'pleno', 'estado_kyc': 'ok'});

    expect(kyc.esBajoMonto, isFalse);
    expect(kyc.estadoKyc, 'ok');
  });
}
