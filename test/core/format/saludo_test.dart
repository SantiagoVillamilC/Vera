import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/saludo.dart';

void main() {
  group('saludoDeLaHora', () {
    test('de madrugada y por la mañana saluda con buenos días', () {
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 0)), 'Buenos días,');
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 11, 59)), 'Buenos días,');
    });

    test('desde el mediodía hasta las 6:59 pm saluda con buenas tardes', () {
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 12)), 'Buenas tardes,');
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 18, 59)), 'Buenas tardes,');
    });

    test('desde las 7 pm saluda con buenas noches', () {
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 19)), 'Buenas noches,');
      expect(saludoDeLaHora(DateTime(2026, 10, 21, 23, 59)), 'Buenas noches,');
    });
  });

  group('inicialesDe', () {
    test('toma la primera letra de las dos primeras palabras', () {
      expect(inicialesDe('Valentina Ríos'), 'VR');
      expect(inicialesDe('maría de los ángeles'), 'MD');
    });

    test('un solo nombre da una inicial', () {
      expect(inicialesDe('Ana'), 'A');
    });

    test('ignora espacios de más', () {
      expect(inicialesDe('  ana   prueba  '), 'AP');
    });

    test('sin nombre usa la V de Vera', () {
      expect(inicialesDe(null), 'V');
      expect(inicialesDe('   '), 'V');
    });
  });
}
