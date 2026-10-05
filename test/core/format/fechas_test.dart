import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/fechas.dart';

void main() {
  const colombia = Duration(hours: -5);

  group('aLocal', () {
    test('2026-10-04T15:12:23Z con offset -5 h es las 10:12', () {
      final local = aLocal(DateTime.utc(2026, 10, 4, 15, 12, 23), offset: colombia);
      expect(local.hour, 10);
      expect(local.minute, 12);
      expect(local.day, 4);
    });

    test('2026-10-05T02:00:00Z con offset -5 h agrupa en el 4 de octubre', () {
      final local = aLocal(DateTime.utc(2026, 10, 5, 2), offset: colombia);
      expect(local.year, 2026);
      expect(local.month, 10);
      expect(local.day, 4);
      expect(local.hour, 21);
    });

    test('un offset positivo puede adelantar el día', () {
      final local = aLocal(
        DateTime.utc(2026, 10, 4, 22),
        offset: const Duration(hours: 3),
      );
      expect(local.day, 5);
      expect(local.hour, 1);
    });

    test('acepta una fecha que no viene en UTC', () {
      final local = aLocal(
        DateTime.parse('2026-10-04T10:12:23-05:00'),
        offset: colombia,
      );
      expect(local.hour, 10);
    });

    test('sin offset usa la zona del equipo', () {
      final utc = DateTime.utc(2026, 10, 4, 15, 12, 23);
      final local = aLocal(utc);
      expect(local.hour, utc.toLocal().hour);
      expect(local.day, utc.toLocal().day);
    });
  });
}
