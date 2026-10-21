import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/format/nit.dart';

// Vectores de Backend_Vera: TestValidarNIT (internal/platform/api/binding_test.go)
// y el generador cuerpoDeNITDeEmpresa de las pruebas de integración, que
// aplica el mismo módulo 11 de la DIAN.
void main() {
  group('esNitValido', () {
    const validos = {
      '9001234568': 'vector del backend',
      '900123456-8': 'vector del backend con guion',
      '900.123.456-8': 'con puntos y guion',
      ' 900123456 8 ': 'con espacios',
      '8001972684': 'generado con el algoritmo del backend',
      '8600343137': 'generado con el algoritmo del backend',
      '9010000009': 'generado con el algoritmo del backend',
      '9000000090': 'resto 0, el dígito es 0',
      '9000000171': 'resto 1, el dígito es 1',
    };
    validos.forEach((nit, motivo) {
      test('acepta $nit ($motivo)', () => expect(esNitValido(nit), isTrue));
    });

    const invalidos = {
      '9001234569': 'dígito de verificación incorrecto',
      '9001234560': 'dígito de verificación incorrecto',
      'abc': 'no numérico',
      '': 'vacío',
      '9': 'una sola cifra',
      '90012345a8': 'letra en el cuerpo',
      '900123456x': 'dígito de verificación no numérico',
      '1234567890123456': 'más de 15 cifras',
    };
    invalidos.forEach((nit, motivo) {
      test('rechaza "$nit" ($motivo)', () => expect(esNitValido(nit), isFalse));
    });
  });
}
