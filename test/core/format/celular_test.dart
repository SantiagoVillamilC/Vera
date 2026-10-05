import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/celular.dart';

TextEditingValue _aplicar(String texto, {String anterior = ''}) =>
    CelularColombianoFormatter().formatEditUpdate(
      TextEditingValue(text: anterior),
      TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      ),
    );

void main() {
  group('CelularColombianoFormatter', () {
    test('deja pasar hasta 10 dígitos', () {
      expect(_aplicar('3001234567').text, '3001234567');
      expect(_aplicar('300').text, '300');
    });

    test('descarta lo que no es dígito', () {
      expect(_aplicar('300 123-4567').text, '3001234567');
      expect(_aplicar('3a0b0').text, '300');
    });

    test('el dígito 11 no entra', () {
      final v = _aplicar('30012345678', anterior: '3001234567');
      expect(v.text, '3001234567');
      expect(v.selection, const TextSelection.collapsed(offset: 10));
    });

    test('un 11 dígitos pegado se corta a los primeros 10', () {
      expect(_aplicar('63105550404').text, '6310555040');
    });

    test('un celular pegado con el indicativo 57 queda en 10 dígitos', () {
      expect(_aplicar('573105550404').text, '3105550404');
      expect(_aplicar('+57 310 555 0404').text, '3105550404');
    });

    test('un 12 dígitos que no empieza por 57 se corta a 10', () {
      expect(_aplicar('631055504041').text, '6310555040');
    });

    test('el cursor queda al final del texto corregido', () {
      expect(
        _aplicar('+57 310 555 0404').selection,
        const TextSelection.collapsed(offset: 10),
      );
    });
  });
}
