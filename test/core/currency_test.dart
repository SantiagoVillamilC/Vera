import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/utils/currency.dart';

void main() {
  group('formatPesos', () {
    test('caso del spec F0: 1234500 → \$12.345', () {
      expect(formatPesos(1234500), '\$12.345');
    });

    test('cero', () {
      expect(formatPesos(0), '\$0');
    });

    test('menos de 100 centavos (sin pesos completos)', () {
      expect(formatPesos(50), '\$0');
    });

    test('exactamente 100 centavos = 1 peso', () {
      expect(formatPesos(100), '\$1');
    });

    test('1000 pesos = 100000 centavos', () {
      expect(formatPesos(100000), '\$1.000');
    });

    test('saldo típico: 14512356 centavos', () {
      expect(formatPesos(14512356), '\$145.123');
    });

    test('millón de pesos', () {
      expect(formatPesos(100000000), '\$1.000.000');
    });
  });

  group('formatPesosConCentavos', () {
    test('1234567 → "\$ 12.345,67"', () {
      expect(formatPesosConCentavos(1234567), '\$ 12.345,67');
    });

    test('cero', () {
      expect(formatPesosConCentavos(0), '\$ 0,00');
    });

    test('centavos con padding: 5 centavos → ,05', () {
      expect(formatPesosConCentavos(105), '\$ 1,05');
    });
  });

  group('parseCentavos', () {
    test('texto limpio "12345" → 1234500', () {
      expect(parseCentavos('12345'), 1234500);
    });

    test('vacío → 0', () {
      expect(parseCentavos(''), 0);
    });

    test('texto con caracteres extra → solo dígitos', () {
      // $1.000 = 1000 pesos (el punto es separador de miles) = 100000 centavos
      expect(parseCentavos('\$1.000'), 100000);
    });

    test('cero string', () {
      expect(parseCentavos('0'), 0);
    });
  });
}
