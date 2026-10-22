import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/widgets/estado_vista.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

const _textoSinRed = 'Sin conexión. Revisa tu internet e intenta de nuevo.';

void main() {
  group('esErrorDeRed', () {
    test('true para TimeoutException', () {
      expect(esErrorDeRed(TimeoutException('lento')), isTrue);
    });

    test('true para http.ClientException', () {
      expect(esErrorDeRed(http.ClientException('sin socket')), isTrue);
    });

    test('false para ApiException', () {
      const e = ApiException(code: 'X', message: 'fallo');
      expect(esErrorDeRed(e), isFalse);
    });

    test('false para StateError', () {
      expect(esErrorDeRed(StateError('mal')), isFalse);
    });
  });

  group('EstadoVista', () {
    testWidgets('cargando muestra el indicador', (tester) async {
      await tester.pumpWidget(_host(const EstadoVista.cargando()));
      expect(find.byKey(const Key('cargando_vera')), findsOneWidget);
    });

    testWidgets('vacio muestra el mensaje configurable', (tester) async {
      await tester.pumpWidget(
        _host(const EstadoVista.vacio(mensaje: 'Sin movimientos')),
      );
      expect(find.text('Sin movimientos'), findsOneWidget);
    });

    testWidgets('sin red muestra el texto y Reintentar invoca el callback', (
      tester,
    ) async {
      var llamadas = 0;
      await tester.pumpWidget(
        _host(EstadoVista.sinRed(onReintentar: () => llamadas++)),
      );
      expect(find.text(_textoSinRed), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(llamadas, 1);
    });

    testWidgets('error muestra el mensaje y Reintentar invoca el callback', (
      tester,
    ) async {
      var llamadas = 0;
      await tester.pumpWidget(
        _host(
          EstadoVista.error(
            mensaje: 'Algo falló',
            onReintentar: () => llamadas++,
          ),
        ),
      );
      expect(find.text('Algo falló'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(llamadas, 1);
    });

    testWidgets('deError con error de red muestra el texto de sin conexión', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EstadoVista.deError(TimeoutException('lento'), onReintentar: () {}),
        ),
      );
      expect(find.text(_textoSinRed), findsOneWidget);
    });

    testWidgets('deError con otro error muestra el mensaje recibido', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EstadoVista.deError(
            const ApiException(code: 'X', message: 'Saldo insuficiente'),
            mensaje: 'Saldo insuficiente',
            onReintentar: () {},
          ),
        ),
      );
      expect(find.text('Saldo insuficiente'), findsOneWidget);
      expect(find.text(_textoSinRed), findsNothing);
    });
  });
}
