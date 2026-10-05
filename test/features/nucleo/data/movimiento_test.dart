import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/nucleo/data/movimiento_filas.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

// Fixture tomada de Backend_Vera/internal/nucleo/historial.go (armarMovimientos
// y derivarLineas): una transferencia compensada con GMF. Las líneas salen en
// el orden de los asientos: retención (envío, gravamen) y luego compensación
// (devolución, devolución del gravamen). Los signos son los del backend.
Map<String, dynamic> _json({
  Object? lineas,
  bool sinEntryId = false,
  bool sinMoneda = false,
  bool sinRegistrado = false,
  bool sinOcurrido = false,
  bool sinLineas = false,
}) =>
    {
      if (!sinEntryId) 'entry_id': 9,
      if (!sinOcurrido) 'ocurrido_en': '2026-10-04T15:12:23Z',
      if (!sinRegistrado) 'registrado_en': '2026-10-04T15:12:24Z',
      if (!sinMoneda) 'moneda': 'COP',
      if (!sinLineas) 'lineas': lineas ?? _lineasCompensadas,
    };

const _lineasCompensadas = [
  {'monto': '-50000000', 'motivo': 'envio'},
  {'monto': '-200000', 'motivo': 'gravamen'},
  {'monto': '50000000', 'motivo': 'devolucion'},
  {'monto': '200000', 'motivo': 'devolucion_gravamen'},
];

Movimiento _mov([Map<String, dynamic>? json]) =>
    Movimiento.fromJson(json ?? _json());

void main() {
  group('Movimiento.fromJson', () {
    test('parsea la fixture de cuatro líneas en orden', () {
      final m = _mov();
      expect(m.entryId, 9);
      expect(m.ocurridoEn, DateTime.utc(2026, 10, 4, 15, 12, 23));
      expect(m.registradoEn, DateTime.utc(2026, 10, 4, 15, 12, 24));
      expect(m.lineas.map((l) => l.motivo), [
        MotivoLinea.envio,
        MotivoLinea.gravamen,
        MotivoLinea.devolucion,
        MotivoLinea.devolucionGravamen,
      ]);
    });

    test('un campo requerido ausente lanza FormatException', () {
      expect(() => _mov(_json(sinEntryId: true)), throwsFormatException);
      expect(() => _mov(_json(sinMoneda: true)), throwsFormatException);
      expect(() => _mov(_json(sinRegistrado: true)), throwsFormatException);
      expect(() => _mov(_json(sinOcurrido: true)), throwsFormatException);
      expect(() => _mov(_json(sinLineas: true)), throwsFormatException);
    });

    test('una línea sin motivo lanza FormatException', () {
      expect(
        () => _mov(_json(lineas: [
          {'monto': '1'},
        ])),
        throwsFormatException,
      );
    });

    test('un motivo desconocido no lanza y cae en otro', () {
      final m = _mov(_json(lineas: [
        {'monto': '-100', 'motivo': 'motivo_nuevo_del_backend'},
      ]));
      expect(m.lineas.single.motivo, MotivoLinea.desconocido);
      expect(m.lineas.single.motivo.label, 'Movimiento');
    });

    test('lineas vacías no lanza y lineaPrincipal es segura', () {
      final m = _mov(_json(lineas: <Object>[]));
      expect(m.lineas, isEmpty);
      expect(m.lineaPrincipal.motivo, MotivoLinea.desconocido);
      expect(m.lineaPrincipal.montoCentavos, BigInt.zero);
      expect(m.montoNeto, BigInt.zero);
      expect(filasDe(m), isEmpty);
    });

    test('lineaPrincipal omite gravamen y devolución de gravamen', () {
      expect(_mov().lineaPrincipal.motivo, MotivoLinea.envio);
    });
  });

  group('filasDe', () {
    test('la fixture produce 4 filas separadas con signo y etiqueta', () {
      final filas = filasDe(_mov());
      expect(filas.map((f) => f.etiqueta),
          ['Envío', 'GMF', 'Devolución', 'Devolución del GMF']);
      expect(filas.map((f) => f.montoCentavos), [
        BigInt.from(-50000000),
        BigInt.from(-200000),
        BigInt.from(50000000),
        BigInt.from(200000),
      ]);
      expect(filas.map((f) => f.esIngreso), [false, false, true, true]);
    });

    test('ninguna fila es cero y la transferencia compensada no se netea', () {
      final filas = filasDe(_mov());
      expect(filas.every((f) => f.montoCentavos != BigInt.zero), isTrue);
      expect(filas.length, 4);
    });

    test('el signo sale del monto y no del motivo', () {
      final filas = filasDe(_mov(_json(lineas: [
        {'monto': '300', 'motivo': 'envio'},
        {'monto': '-300', 'motivo': 'deposito'},
      ])));
      expect(filas[0].esIngreso, isTrue);
      expect(filas[1].esIngreso, isFalse);
    });
  });

  group('totales', () {
    // Montos en centavos. Escenario del informe de revisión visual: recarga de
    // 500.000, envío de 20.000 y una interbancaria de 100.000 rechazada.
    Movimiento recarga() => _mov(_json(lineas: [
          {'monto': '50000000', 'motivo': 'deposito'},
        ]));
    Movimiento envio20mil() => _mov(_json(lineas: [
          {'monto': '-2000000', 'motivo': 'envio'},
        ]));
    Movimiento interbancariaRechazada() => _mov(_json(lineas: [
          {'monto': '-10000000', 'motivo': 'envio'},
          {'monto': '10000000', 'motivo': 'devolucion'},
        ]));
    Movimiento interbancariaAceptada() => _mov(_json(lineas: [
          {'monto': '-10000000', 'motivo': 'envio'},
        ]));

    test('el envío rechazado y su devolución no cuentan como gasto ni ingreso',
        () {
      final movs = [recarga(), envio20mil(), interbancariaRechazada()];
      expect(totalIngresos(movs), BigInt.from(50000000));
      expect(totalGastos(movs), BigInt.from(2000000));
    });

    test('con una interbancaria aceptada además solo suma esa al gasto', () {
      final movs = [
        recarga(),
        envio20mil(),
        interbancariaRechazada(),
        interbancariaAceptada(),
      ];
      expect(totalIngresos(movs), BigInt.from(50000000));
      expect(totalGastos(movs), BigInt.from(12000000));
    });

    test('una transferencia compensada con GMF se anula por completo', () {
      expect(totalIngresos([_mov()]), BigInt.zero);
      expect(totalGastos([_mov()]), BigInt.zero);
    });

    test('si el GMF no se devuelve, queda como gasto', () {
      final m = _mov(_json(lineas: [
        {'monto': '-10000000', 'motivo': 'envio'},
        {'monto': '-40000', 'motivo': 'gravamen'},
        {'monto': '10000000', 'motivo': 'devolucion'},
      ]));
      expect(totalIngresos([m]), BigInt.zero);
      expect(totalGastos([m]), BigInt.from(40000));
    });

    test('el GMF de un envío normal cuenta como gasto junto con el envío', () {
      final m = _mov(_json(lineas: [
        {'monto': '-10000000', 'motivo': 'envio'},
        {'monto': '-40000', 'motivo': 'gravamen'},
      ]));
      expect(totalGastos([m]), BigInt.from(10040000));
    });

    test('el resto de líneas se clasifica por el signo del monto', () {
      final movs = [
        _mov(_json(lineas: [
          {'monto': '1000000', 'motivo': 'transferencia_recibida'},
        ])),
        _mov(_json(lineas: [
          {'monto': '-300', 'motivo': 'motivo_nuevo_del_backend'},
        ])),
      ];
      expect(totalIngresos(movs), BigInt.from(1000000));
      expect(totalGastos(movs), BigInt.from(300));
    });

    test('sin movimientos los totales son cero', () {
      expect(totalIngresos(const []), BigInt.zero);
      expect(totalGastos(const []), BigInt.zero);
    });

    test('el gasto se devuelve en positivo', () {
      expect(totalGastos([envio20mil()]), BigInt.from(2000000));
    });
  });
}
