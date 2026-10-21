import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

Map<String, dynamic> _base({String estado = 'pendiente'}) => {
      'id': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      'referencia': 'DEP-123',
      'monto': '5000000000000000000000',
      'moneda': 'COP',
      'estado': estado,
      'creada_en': '2026-10-05T10:00:00Z',
    };

void main() {
  group('DepositoConPago (respuesta del POST)', () {
    test('parsea con url_pago y conserva el monto como BigInt', () {
      final d = DepositoConPago.fromJson({
        ..._base(),
        'url_pago': 'https://pse.test/pagar?ref=DEP-123',
      });
      expect(d.urlPago, 'https://pse.test/pagar?ref=DEP-123');
      expect(d.montoCentavos, BigInt.parse('5000000000000000000000'));
      expect(d.estado, EstadoDeposito.pendiente);
      expect(d.referencia, 'DEP-123');
    });

    test('sin url_pago lanza FormatException', () {
      expect(
        () => DepositoConPago.fromJson(_base()),
        throwsA(isA<FormatException>()),
      );
    });

    test('url_pago vacío o no string lanza FormatException', () {
      expect(
        () => DepositoConPago.fromJson({..._base(), 'url_pago': ''}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DepositoConPago.fromJson({..._base(), 'url_pago': 3}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Deposito (respuesta del GET)', () {
    test('parsea sin url_pago', () {
      final d = Deposito.fromJson(_base(estado: 'confirmada'));
      expect(d.estado, EstadoDeposito.confirmada);
      expect(d.id, '7c9e6679-7425-40de-944b-e07fc1f90ae7');
    });

    test('los cuatro estados del contrato se mapean', () {
      expect(
        {
          for (final e in ['pendiente', 'confirmada', 'rechazada', 'expirada'])
            e: Deposito.fromJson(_base(estado: e)).estado,
        },
        {
          'pendiente': EstadoDeposito.pendiente,
          'confirmada': EstadoDeposito.confirmada,
          'rechazada': EstadoDeposito.rechazada,
          'expirada': EstadoDeposito.expirada,
        },
      );
    });

    test('un estado desconocido no lanza y cae en desconocido', () {
      expect(
        Deposito.fromJson(_base(estado: 'reversada')).estado,
        EstadoDeposito.desconocido,
      );
      final sinEstado = _base()..remove('estado');
      expect(Deposito.fromJson(sinEstado).estado, EstadoDeposito.desconocido);
      expect(
        Deposito.fromJson({..._base(), 'estado': 7}).estado,
        EstadoDeposito.desconocido,
      );
    });

    test('esTerminal solo para confirmada, rechazada y expirada', () {
      expect(EstadoDeposito.pendiente.esTerminal, isFalse);
      expect(EstadoDeposito.desconocido.esTerminal, isFalse);
      expect(EstadoDeposito.confirmada.esTerminal, isTrue);
      expect(EstadoDeposito.rechazada.esTerminal, isTrue);
      expect(EstadoDeposito.expirada.esTerminal, isTrue);
    });

    test('un monto no numérico lanza', () {
      expect(
        () => Deposito.fromJson({..._base(), 'monto': '12.5'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
