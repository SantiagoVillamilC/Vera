import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

class _FakeSession implements SessionStore {
  _FakeSession({this.access, this.refresh});

  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

// 2^53 + 1: el primer entero que un double no puede representar.
const _grande = '9007199254740993';
// Mucho mayor que 2^63.
const _enorme = '123456789012345678901234567890';

void main() {
  group('MontoCalculado.fromJson', () {
    test('conserva precision por encima de 2^53', () {
      final m = MontoCalculado.fromJson({
        'monto': _grande,
        'moneda': 'COP',
        'calculado_en': '2026-10-05T10:00:00Z',
      });
      expect(m.montoCentavos, BigInt.parse(_grande));
      expect(m.montoCentavos.toString(), _grande);
    });

    test('lanza FormatException si falta monto', () {
      expect(
        () => MontoCalculado.fromJson({
          'moneda': 'COP',
          'calculado_en': '2026-10-05T10:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('lanza FormatException si el monto no es numerico', () {
      for (final malo in ['abc', '12.5', '', '0x10', '1e3']) {
        expect(
          () => MontoCalculado.fromJson({
            'monto': malo,
            'moneda': 'COP',
            'calculado_en': '2026-10-05T10:00:00Z',
          }),
          throwsFormatException,
          reason: 'monto "$malo"',
        );
      }
    });

    test('lanza FormatException si el monto no es string', () {
      expect(
        () => MontoCalculado.fromJson({
          'monto': 1500,
          'moneda': 'COP',
          'calculado_en': '2026-10-05T10:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('lanza FormatException si falta calculado_en', () {
      expect(
        () => MontoCalculado.fromJson({'monto': '100', 'moneda': 'COP'}),
        throwsFormatException,
      );
    });
  });

  group('LineaMovimiento y Movimiento', () {
    test('linea con monto negativo mayor que 2^53 conserva precision', () {
      final l = LineaMovimiento.fromJson({
        'monto': '-$_grande',
        'motivo': 'envio',
      });
      expect(l.montoCentavos, -BigInt.parse(_grande));
      expect(l.motivo, MotivoLinea.envio);
    });

    test('linea sin monto lanza FormatException', () {
      expect(
        () => LineaMovimiento.fromJson({'motivo': 'envio'}),
        throwsFormatException,
      );
    });

    test('montoNeto suma BigInt sin perder precision', () {
      final mov = Movimiento.fromJson({
        'entry_id': 7,
        'ocurrido_en': '2026-10-05T10:00:00Z',
        'moneda': 'COP',
        'lineas': [
          {'monto': '-$_grande', 'motivo': 'envio'},
          {'monto': '-1', 'motivo': 'gravamen'},
        ],
      });
      expect(mov.montoNeto, BigInt.parse('-9007199254740994'));
    });

    test('montoNeto de cifras enormes es exacto', () {
      final mov = Movimiento.fromJson({
        'entry_id': 1,
        'ocurrido_en': '2026-10-05T10:00:00Z',
        'moneda': 'COP',
        'lineas': [
          {'monto': _enorme, 'motivo': 'deposito'},
          {'monto': '1', 'motivo': 'deposito'},
        ],
      });
      expect(mov.montoNeto, BigInt.parse(_enorme) + BigInt.one);
    });

    test('movimiento sin ocurrido_en lanza FormatException', () {
      expect(
        () => Movimiento.fromJson({
          'entry_id': 1,
          'moneda': 'COP',
          'lineas': [
            {'monto': '1', 'motivo': 'deposito'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('movimiento con una linea sin monto lanza FormatException', () {
      expect(
        () => Movimiento.fromJson({
          'entry_id': 1,
          'ocurrido_en': '2026-10-05T10:00:00Z',
          'moneda': 'COP',
          'lineas': [
            {'motivo': 'deposito'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('Deposito, Transferencia y EnvioPorLlave', () {
    test('Deposito parsea monto grande y falla sin monto', () {
      final base = {
        'id': 'd1',
        'referencia': 'ref',
        'moneda': 'COP',
        'estado': 'pendiente',
        'creada_en': '2026-10-05T10:00:00Z',
      };
      final d = Deposito.fromJson({...base, 'monto': _grande});
      expect(d.montoCentavos, BigInt.parse(_grande));
      expect(() => Deposito.fromJson(base), throwsFormatException);
      expect(
        () => Deposito.fromJson({...base, 'monto': _grande}..remove('creada_en')),
        throwsFormatException,
      );
    });

    test('Transferencia parsea monto grande y falla sin fechas', () {
      final base = {
        'id': 't1',
        'destino': '+573001112233',
        'monto': _grande,
        'moneda': 'COP',
        'estado': 'creada',
        'creada_en': '2026-10-05T10:00:00Z',
        'actualizada_en': '2026-10-05T10:00:01Z',
      };
      expect(
        Transferencia.fromJson(base).montoCentavos,
        BigInt.parse(_grande),
      );
      expect(
        () => Transferencia.fromJson({...base}..remove('actualizada_en')),
        throwsFormatException,
      );
      expect(
        () => Transferencia.fromJson({...base}..remove('monto')),
        throwsFormatException,
      );
    });

    test('EnvioPorLlave parsea monto grande y falla sin monto', () {
      final base = {
        'id': 'e1',
        'tipo_llave': 'celular',
        'llave': '3001112233',
        'monto': _enorme,
        'moneda': 'COP',
        'estado': 'creada',
        'creada_en': '2026-10-05T10:00:00Z',
        'actualizada_en': '2026-10-05T10:00:01Z',
      };
      expect(
        EnvioPorLlave.fromJson(base).montoCentavos,
        BigInt.parse(_enorme),
      );
      expect(
        () => EnvioPorLlave.fromJson({...base}..remove('monto')),
        throwsFormatException,
      );
    });
  });

  group('NucleoRepository', () {
    NucleoRepository build(
      _FakeSession session,
      Future<http.Response> Function(http.Request) handler,
    ) {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        session: session,
        clientFactory: () => MockClient(handler),
      );
      return NucleoRepository(client: client, session: session);
    }

    test('getSaldo usa el Bearer del ApiClient y conserva precision', () async {
      final session = _FakeSession(access: 'tok', refresh: 'ref');
      String? auth;
      final repo = build(session, (req) async {
        auth = req.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'monto': _grande,
              'moneda': 'COP',
              'calculado_en': '2026-10-05T10:00:00Z',
            },
          }),
          200,
        );
      });
      final saldo = await repo.getSaldo();
      expect(auth, 'Bearer tok');
      expect(saldo.montoCentavos, BigInt.parse(_grande));
    });

    test('getSaldo propaga FormatException si el servidor omite monto',
        () async {
      final session = _FakeSession(access: 'tok', refresh: 'ref');
      final repo = build(session, (req) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'moneda': 'COP', 'calculado_en': '2026-10-05T10:00:00Z'},
          }),
          200,
        );
      });
      expect(repo.getSaldo(), throwsFormatException);
    });

    test('getMovimientos parsea paginas con montos grandes', () async {
      final session = _FakeSession(access: 'tok', refresh: 'ref');
      final repo = build(session, (req) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'entry_id': 3,
                'ocurrido_en': '2026-10-05T10:00:00Z',
                'moneda': 'COP',
                'lineas': [
                  {'monto': _grande, 'motivo': 'deposito'},
                ],
              },
            ],
            'meta': {'next_cursor': 3, 'has_more': true},
          }),
          200,
        );
      });
      final page = await repo.getMovimientos();
      expect(page.items.single.montoNeto, BigInt.parse(_grande));
      expect(page.hasMore, isTrue);
    });
  });
}
