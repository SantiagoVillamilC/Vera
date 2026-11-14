import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';

/// Capturas reales de la sección 4 del contrato de avisos, tal cual.
const _pagoNoAlcanza = {
  'accion': 'Ver los pagos que vencen',
  'clave': 'pago-proximo',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': '255c555d-1f84-422d-b55b-b30d6550f928',
  'monto_centavos': '970000',
  'periodo': '2026-11-20',
  'porque': 'Los pagos recurrentes de la ventana suman más que tu saldo.',
  'prioridad': 1,
  'referencia_centavos': '13990000',
  'severidad_centavos': '13020000',
  'texto':
      'Tu saldo es \$9.700 y los pagos recurrentes que vencen desde 2026-11-20 '
      'suman \$139.900.',
  'tipo': 'pago_no_alcanza',
  'titulo': 'Tus próximos pagos suman más que tu saldo',
  'transaccion_id': null,
  'accion_codigo': 'revisar_pagos',
};

/// `cobro_nuevo` no trae `referencia_centavos`: la clave no aparece en el JSON.
const _cobroNuevo = {
  'accion': 'Ver el cobro y su próximo vencimiento',
  'clave': 'cobro-nuevo',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': '527d4bd4-aa65-4305-879e-762e17ead8b0',
  'monto_centavos': '2490000',
  'periodo': '2026-10-28',
  'porque': 'Apareció una llave recurrente que no estaba en tu historial.',
  'prioridad': 3,
  'severidad_centavos': '2490000',
  'texto':
      'Apareció un cobro de \$24.900 el 2026-10-28 y ya se repite o está '
      'declarado como recurrente.',
  'tipo': 'cobro_nuevo',
  'titulo': 'Apareció un cobro nuevo',
  'transaccion_id': null,
  'accion_codigo': 'revisar_cobro',
};

void main() {
  group('Aviso.fromJson', () {
    test('lee la captura de pago_no_alcanza completa', () {
      final a = Aviso.fromJson(Map<String, dynamic>.from(_pagoNoAlcanza));

      expect(a.id, '255c555d-1f84-422d-b55b-b30d6550f928');
      expect(a.tipo, TipoAviso.pagoNoAlcanza);
      expect(a.clave, 'pago-proximo');
      expect(a.periodo, '2026-11-20');
      expect(a.mes, '2026-11');
      expect(a.prioridad, 1);
      // En este tipo el monto es el saldo del usuario, no una proyección.
      expect(a.montoCentavos, BigInt.from(970000));
      expect(a.referenciaCentavos, BigInt.from(13990000));
      expect(a.severidadCentavos, BigInt.from(13020000));
      expect(a.accion, 'Ver los pagos que vencen');
      expect(a.accionCodigo, AccionAviso.revisarPagos);
      expect(a.tieneAccion, isTrue);
      expect(a.transaccionId, isNull);
      expect(a.creadoEn.isUtc, isTrue);
      expect(a.creadoEn, DateTime.utc(2026, 11, 19, 17));
    });

    test('cobro_nuevo llega sin referencia y no se inventa un cero', () {
      final a = Aviso.fromJson(Map<String, dynamic>.from(_cobroNuevo));

      expect(a.referenciaCentavos, isNull);
      expect(a.montoCentavos, BigInt.from(2490000));
      expect(a.mes, '2026-10');
    });

    test('un tipo nuevo no rompe el parseo', () {
      final a = Aviso.fromJson({
        ..._pagoNoAlcanza,
        'tipo': 'algo_que_no_existe',
      });

      expect(a.tipo, TipoAviso.desconocido);
      // El título y el texto vienen del servidor, así que se siguen pintando.
      expect(a.titulo, 'Tus próximos pagos suman más que tu saldo');
    });

    test('un accion_codigo nuevo o ausente deja el aviso sin acción', () {
      final nuevo = Aviso.fromJson({
        ..._pagoNoAlcanza,
        'accion_codigo': 'revisar_otra_cosa',
      });
      expect(nuevo.accionCodigo, AccionAviso.desconocida);
      expect(nuevo.tieneAccion, isFalse);

      final sinCodigo = Map<String, dynamic>.from(_pagoNoAlcanza)
        ..remove('accion_codigo');
      final viejo = Aviso.fromJson(sinCodigo);
      expect(viejo.accionCodigo, isNull);
      expect(viejo.tieneAccion, isFalse);
      // La etiqueta sigue llegando: lo que falta es el destino.
      expect(viejo.accion, 'Ver los pagos que vencen');
    });

    test('un monto mayor que 2^53 conserva la precisión', () {
      final a = Aviso.fromJson({
        ..._pagoNoAlcanza,
        'monto_centavos': '9007199254740993',
      });

      expect(a.montoCentavos.toString(), '9007199254740993');
    });
  });

  group('orden', () {
    Aviso conOrden(int prioridad, int severidad, {String id = 'a'}) =>
        Aviso.fromJson({
          ..._pagoNoAlcanza,
          'id': id,
          'prioridad': prioridad,
          'severidad_centavos': '$severidad',
        });

    test('prioridad ascendente y, dentro de ella, severidad descendente', () {
      final lista = [
        conOrden(4, 600000, id: 'presupuesto'),
        conOrden(1, 100, id: 'pago-poco-grave'),
        conOrden(1, 13020000, id: 'pago-grave'),
        conOrden(2, 6200000, id: 'ingreso'),
      ]..sort(Aviso.comparar);

      expect(lista.map((a) => a.id).toList(), [
        'pago-grave',
        'pago-poco-grave',
        'ingreso',
        'presupuesto',
      ]);
    });
  });

  group('AvisoDescartado.fromJson', () {
    test('lee el id y el instante del descarte', () {
      final d = AvisoDescartado.fromJson(const {
        'id': '2c6242c9-f963-40e2-9f92-0a2050ca9f87',
        'descartado_en': '2026-11-19T12:30:00-05:00',
      });

      expect(d.id, '2c6242c9-f963-40e2-9f92-0a2050ca9f87');
      expect(d.descartadoEn, DateTime.utc(2026, 11, 19, 17, 30));
    });
  });
}
