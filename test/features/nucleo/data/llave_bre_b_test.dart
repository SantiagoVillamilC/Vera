import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/nucleo/data/llave_bre_b.dart';

void main() {
  test('los códigos de tipo coinciden con el contrato', () {
    expect(
      TipoLlaveBreB.values.map((t) => t.codigo).toList(),
      ['documento', 'celular', 'correo', 'alfanumerico', 'comercio'],
    );
  });

  group('documento', () {
    test('acepta de 6 a 10 dígitos', () {
      expect(normalizarLlave(TipoLlaveBreB.documento, '123456'), '123456');
      expect(normalizarLlave(TipoLlaveBreB.documento, '1234567890'), '1234567890');
    });
    test('rechaza cortos, largos y con letras', () {
      expect(normalizarLlave(TipoLlaveBreB.documento, '12345'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.documento, '12345678901'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.documento, '12345a'), isNull);
    });
  });

  group('celular', () {
    test('acepta 10 dígitos que empiezan por 3', () {
      expect(normalizarLlave(TipoLlaveBreB.celular, '3001112233'), '3001112233');
    });
    test('no es E.164: rechaza +57 y el prefijo 57', () {
      expect(normalizarLlave(TipoLlaveBreB.celular, '+573001112233'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.celular, '573001112233'), isNull);
    });
    test('rechaza espacios internos, otro inicio y largo incorrecto', () {
      expect(normalizarLlave(TipoLlaveBreB.celular, '300 111 2233'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.celular, '2001112233'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.celular, '300111223'), isNull);
    });
  });

  group('correo', () {
    test('acepta un correo normal', () {
      expect(
        normalizarLlave(TipoLlaveBreB.correo, 'ana.perez+vera@mail.co'),
        'ana.perez+vera@mail.co',
      );
    });
    test('rechaza sin arroba, sin dominio o con TLD corto', () {
      expect(normalizarLlave(TipoLlaveBreB.correo, 'ana.mail.co'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.correo, 'ana@mail'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.correo, 'ana@mail.c'), isNull);
    });
  });

  group('alfanumerico', () {
    test('acepta @ seguido de 1 a 64 alfanuméricos', () {
      expect(normalizarLlave(TipoLlaveBreB.alfanumerico, '@ana1'), '@ana1');
      expect(
        normalizarLlave(TipoLlaveBreB.alfanumerico, '@${'a' * 64}'),
        '@${'a' * 64}',
      );
    });
    test('rechaza sin arroba, vacío tras la arroba o demasiado largo', () {
      expect(normalizarLlave(TipoLlaveBreB.alfanumerico, 'ana1'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.alfanumerico, '@'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.alfanumerico, '@${'a' * 65}'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.alfanumerico, '@ana_1'), isNull);
    });
  });

  group('comercio', () {
    test('acepta de 6 a 20 alfanuméricos', () {
      expect(normalizarLlave(TipoLlaveBreB.comercio, 'ABC123'), 'ABC123');
      expect(normalizarLlave(TipoLlaveBreB.comercio, 'a' * 20), 'a' * 20);
    });
    test('rechaza cortos, largos y con símbolos', () {
      expect(normalizarLlave(TipoLlaveBreB.comercio, 'ABC12'), isNull);
      expect(normalizarLlave(TipoLlaveBreB.comercio, 'a' * 21), isNull);
      expect(normalizarLlave(TipoLlaveBreB.comercio, 'ABC-123'), isNull);
    });
  });

  test('solo se hace trim del valor, sin otra transformación', () {
    expect(normalizarLlave(TipoLlaveBreB.celular, ' 3001112233 '), '3001112233');
    expect(normalizarLlave(TipoLlaveBreB.comercio, '  abcDEF '), 'abcDEF');
    expect(normalizarLlave(TipoLlaveBreB.correo, ' Ana@Mail.CO '), 'Ana@Mail.CO');
  });

  test('vacío o solo espacios es inválido en todos los tipos', () {
    for (final t in TipoLlaveBreB.values) {
      expect(normalizarLlave(t, ''), isNull);
      expect(normalizarLlave(t, '   '), isNull);
    }
  });
}
