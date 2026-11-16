import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/asistente/data/troceador_texto.dart';

void main() {
  group('partirEnTrozos', () {
    test('un texto corto queda en un solo trozo', () {
      expect(partirEnTrozos('Tienes 50 mil pesos disponibles.'), [
        'Tienes 50 mil pesos disponibles.',
      ]);
    });

    test('un texto vacío o de solo espacios no produce trozos', () {
      expect(partirEnTrozos(''), isEmpty);
      expect(partirEnTrozos('  \n\t '), isEmpty);
    });

    test('junta frases enteras sin pasar del tope', () {
      const a = 'Primera frase corta.';
      const b = 'Segunda frase un poco más larga que la primera.';
      const c = 'Tercera.';
      final trozos = partirEnTrozos('$a $b $c', maxCaracteres: 70);

      expect(trozos, ['$a $b', c]);
      expect(trozos.every((t) => t.length <= 70), isTrue);
    });

    test('no parte un número decimal ni un monto con puntos de miles', () {
      const texto =
          'Gastaste 1.250.000 en total. El promedio fue de 3.5 al día. Sigue así.';
      final trozos = partirEnTrozos(texto, maxCaracteres: 30);

      expect(trozos.join(' '), texto);
      for (final t in trozos) {
        expect(t.endsWith('1.'), isFalse);
        expect(t.endsWith('3.'), isFalse);
        expect(t.endsWith('250.'), isFalse);
      }
      expect(trozos.any((t) => t.contains('1.250.000')), isTrue);
      expect(trozos.any((t) => t.contains('3.5')), isTrue);
    });

    test('una frase más larga que el tope se parte en límites de palabra', () {
      final frase = List.generate(40, (i) => 'palabra$i').join(' ');
      final trozos = partirEnTrozos(frase, maxCaracteres: 60);

      expect(trozos.length, greaterThan(1));
      expect(trozos.every((t) => t.length <= 60), isTrue);
      // Todas las palabras siguen enteras y en orden.
      expect(trozos.join(' '), frase);
    });

    test('las frases con signos de pregunta y exclamación son límites', () {
      final trozos = partirEnTrozos(
        '¿Cuánto tengo? Tienes 10 mil. ¡Listo!',
        maxCaracteres: 20,
      );

      expect(trozos, ['¿Cuánto tengo?', 'Tienes 10 mil.', '¡Listo!']);
    });

    test('los saltos de línea separan frases y no dejan trozos vacíos', () {
      final trozos = partirEnTrozos(
        '1. Arriendo\n\n2. Mercado\n3. Transporte',
        maxCaracteres: 15,
      );

      expect(trozos.every((t) => t.trim().isNotEmpty), isTrue);
      expect(trozos.every((t) => t.length <= 15), isTrue);
      expect(trozos.join(' '), contains('Mercado'));
    });

    test('cada trozo cabe en el tope del backend aunque haya tildes', () {
      final texto = List.filled(
        30,
        'Revisé tu información económica.',
      ).join(' ');
      final trozos = partirEnTrozos(texto);

      expect(trozos.length, greaterThan(1));
      expect(trozos.every((t) => t.length <= maxCaracteresPorTrozo), isTrue);
      expect(maxCaracteresPorTrozo, lessThan(400));
    });

    test('una palabra sin espacios más larga que el tope se corta al tope', () {
      final trozos = partirEnTrozos('a' * 25, maxCaracteres: 10);

      expect(trozos, ['a' * 10, 'a' * 10, 'a' * 5]);
    });
  });
}
