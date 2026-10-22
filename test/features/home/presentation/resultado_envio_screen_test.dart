import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/features/home/presentation/movimiento_vista.dart';
import 'package:vera/features/home/presentation/resultado_envio_screen.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  EstadoTransferencia estado = EstadoTransferencia.confirmada,
  bool exito = true,
  VoidCallback? alVolver,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ResultadoEnvioScreen(
        titulo: '¡Listo!',
        mensaje: 'Verás el resultado en tu historial.',
        exito: exito,
        montoCentavos: BigInt.from(15000000),
        estado: estado,
        alVolver: alVolver,
        filas: const [
          (etiqueta: 'Para', valor: 'Camilo H.'),
          (etiqueta: 'Celular', valor: '+57 310 ••• 4821'),
        ],
      ),
    ),
  );
}

void main() {
  group('celularEnmascarado', () {
    test('deja el indicativo, los tres primeros y los cuatro últimos', () {
      expect(celularEnmascarado('+573101234821'), '+57 310 ••• 4821');
    });

    test(
      'un número sin indicativo conocido solo muestra los cuatro últimos',
      () {
        expect(celularEnmascarado('3101234821'), '••• 4821');
      },
    );

    test('un valor demasiado corto no se revela', () {
      expect(celularEnmascarado('12'), '•••');
    });
  });

  group('etiquetaDeEstado', () {
    test('solo confirmada va en verde y se llama Exitoso', () {
      expect(etiquetaDeEstado(EstadoTransferencia.confirmada), (
        'Exitoso',
        AppColors.accentGreen,
      ));
      for (final e in EstadoTransferencia.values) {
        if (e == EstadoTransferencia.confirmada) continue;
        expect(
          etiquetaDeEstado(e).$2,
          isNot(AppColors.accentGreen),
          reason: '$e',
        );
      }
    });

    test('fallida va en rojo', () {
      expect(etiquetaDeEstado(EstadoTransferencia.fallida).$2, AppColors.error);
    });
  });

  test('formatFechaLarga junta el día, el mes, el año y la hora', () {
    expect(
      formatFechaLarga(DateTime(2026, 10, 21, 15, 42)),
      '21 oct 2026 · 3:42 pm',
    );
  });

  testWidgets('muestra el título, el mensaje, el monto y el detalle', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('Verás el resultado en tu historial.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('resultado_monto'))).data,
      '\$150.000',
    );
    expect(find.text('Para'), findsOneWidget);
    expect(find.text('Camilo H.'), findsOneWidget);
    expect(find.text('+57 310 ••• 4821'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Exitoso'), findsOneWidget);
  });

  testWidgets('con éxito marca azul y sin éxito un aviso', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('icono_exito')), findsOneWidget);

    await _pump(tester, exito: false, estado: EstadoTransferencia.fallida);
    expect(find.byKey(const Key('icono_exito')), findsNothing);
    expect(find.byKey(const Key('icono_aviso')), findsOneWidget);
    expect(find.text('Fallido'), findsOneWidget);
  });

  testWidgets('Volver al inicio llama a la acción', (tester) async {
    var volvio = 0;
    await _pump(tester, alVolver: () => volvio++);

    await tester.tap(find.byKey(const Key('volver_inicio')));

    expect(volvio, 1);
  });
}
