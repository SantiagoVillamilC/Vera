import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/tintes.dart';

void main() {
  group('tinteDeCategoria', () {
    test('cada categoría conocida tiene su color', () {
      expect(tinteDeCategoria('Restaurantes y domicilios'), TinteVera.naranja);
      expect(tinteDeCategoria('Transporte'), TinteVera.azul);
      expect(tinteDeCategoria('Salario'), TinteVera.verde);
      expect(tinteDeCategoria('Alimentos y mercado'), TinteVera.teal);
      expect(tinteDeCategoria('Salud'), TinteVera.rosa);
      expect(tinteDeCategoria('Entretenimiento'), TinteVera.morado);
      expect(
        tinteDeCategoria('Comisiones y costos financieros'),
        TinteVera.ambar,
      );
    });

    test('no distingue mayúsculas ni tildes', () {
      expect(tinteDeCategoria('EDUCACIÓN'), TinteVera.morado);
      expect(tinteDeCategoria('educacion'), TinteVera.morado);
    });

    test('una categoría desconocida queda en gris', () {
      expect(tinteDeCategoria('Algo nuevo'), TinteVera.gris);
    });
  });

  group('iconoDeCategoria', () {
    test(
      'devuelve un icono propio por categoría y uno genérico si no la conoce',
      () {
        expect(iconoDeCategoria('Transporte'), Icons.directions_bus_outlined);
        expect(iconoDeCategoria('Salud'), Icons.favorite_border_rounded);
        expect(iconoDeCategoria('Algo nuevo'), Icons.sell_outlined);
      },
    );
  });
}
