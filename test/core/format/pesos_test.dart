import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/pesos.dart';

void main() {
  group('formatPesos', () {
    test('monto entero en pesos sin decimales', () {
      expect(formatPesos(BigInt.from(1234500)), r'$12.345');
    });

    test('cero', () {
      expect(formatPesos(BigInt.zero), r'$0');
    });

    test('menos de un peso muestra coma y dos digitos', () {
      expect(formatPesos(BigInt.from(99)), r'$0,99');
      expect(formatPesos(BigInt.from(5)), r'$0,05');
    });

    test('centavos fraccionarios con coma', () {
      expect(formatPesos(BigInt.from(1234550)), r'$12.345,50');
      expect(formatPesos(BigInt.from(1234501)), r'$12.345,01');
    });

    test('negativos con signo', () {
      expect(formatPesos(BigInt.from(-1234500)), r'-$12.345');
      expect(formatPesos(BigInt.from(-1234550)), r'-$12.345,50');
      expect(formatPesos(BigInt.from(-99)), r'-$0,99');
    });

    test('2^60 centavos sin perdida de precision', () {
      final v = BigInt.one << 60;
      expect(v.toString(), '1152921504606846976');
      expect(formatPesos(v), r'$11.529.215.046.068.469,76');
      expect(formatPesos(-v), r'-$11.529.215.046.068.469,76');
    });

    test('separador de miles en limites', () {
      expect(formatPesos(BigInt.from(99900)), r'$999');
      expect(formatPesos(BigInt.from(100000)), r'$1.000');
    });
  });

  group('formatPesosInt', () {
    test('delega en formatPesos', () {
      expect(formatPesosInt(1234500), r'$12.345');
      expect(formatPesosInt(99), r'$0,99');
    });
  });
}
