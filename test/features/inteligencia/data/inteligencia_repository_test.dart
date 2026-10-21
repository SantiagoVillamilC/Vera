import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/inteligencia/data/categorias.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

class _FakeSession implements SessionStore {
  @override
  Future<String?> readAccess() async => 'tok';

  @override
  Future<String?> readRefresh() async => 'ref';

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<SessionProfile> readProfile() async => const SessionProfile();

  @override
  Future<void> saveProfile(SessionProfile profile) async {}

  @override
  Future<String?> readDepositoPendiente() async => null;

  @override
  Future<void> saveDepositoPendiente(String id) async {}

  @override
  Future<void> clearDepositoPendiente() async {}

  @override
  Future<void> clear() async {}
}

InteligenciaRepository _build(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = ApiClient(
    baseUrl: 'https://api.test',
    session: _FakeSession(),
    clientFactory: () => MockClient(handler),
  );
  return InteligenciaRepository(client: client);
}

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status);

http.Response _error(int status, String code) => _json(status, {
      'success': false,
      'data': null,
      'error': {'code': code, 'message': 'm'},
      'meta': null,
    });

const _id = 'b3f1a2c4-1111-4222-8333-444455556666';

Map<String, dynamic> _fila({
  String categoria = 'sin_categoria',
  String categoriaNombre = 'Sin categoría',
  String origen = 'sin_categoria',
  String direccion = 'salida',
  String contraparte = 'Tienda D1',
  String monto = '12500000',
}) =>
    {
      'transaccion_id': _id,
      'ocurrido_en': '2026-10-12T14:30:00Z',
      'moneda': 'COP',
      'direccion': direccion,
      'monto_centavos': monto,
      'contraparte': contraparte,
      'contraparte_resuelta': true,
      'descripcion': 'COMPRA POS',
      'categoria': categoria,
      'categoria_nombre': categoriaNombre,
      'origen_categoria': origen,
    };

void main() {
  group('listarMovimientos', () {
    test('pide la página con Bearer y parsea todos los campos', () async {
      late http.Request visto;
      final repo = _build((req) async {
        visto = req;
        return _json(200, {
          'success': true,
          'data': [
            _fila(),
            _fila(
              categoria: 'transporte',
              categoriaNombre: 'Transporte',
              origen: 'memoria',
              direccion: 'entrada',
              contraparte: 'Uber',
              monto: '9007199254740993',
            ),
          ],
          'meta': null,
        });
      });

      final lista = await repo.listarMovimientos();

      expect(visto.method, 'GET');
      expect(visto.url.path, '/v1/inteligencia/movimientos');
      expect(visto.url.queryParameters['limit'], '50');
      expect(visto.headers['Authorization'], 'Bearer tok');

      expect(lista, hasLength(2));
      final primera = lista.first;
      expect(primera.transaccionId, _id);
      expect(primera.categoria, 'sin_categoria');
      expect(primera.sinCategoria, isTrue);
      expect(primera.origenCategoria, OrigenCategoria.sinCategoria);
      expect(primera.esIngreso, isFalse);
      expect(primera.montoCentavos, BigInt.from(12500000));
      expect(primera.montoConSigno, BigInt.from(-12500000));
      expect(primera.ocurridoEn.isUtc, isTrue);
      expect(primera.descripcion, 'COMPRA POS');

      final segunda = lista.last;
      expect(segunda.esIngreso, isTrue);
      expect(segunda.origenCategoria, OrigenCategoria.memoria);
      // Más allá de 2^53: se conserva la precisión.
      expect(segunda.montoCentavos.toString(), '9007199254740993');
      expect(segunda.montoConSigno, segunda.montoCentavos);
    });

    test('un origen desconocido no rompe el parseo', () async {
      final repo = _build((req) async => _json(200, {
            'success': true,
            'data': [
              _fila(origen: 'escalon_nuevo'),
            ],
          }));

      final lista = await repo.listarMovimientos();
      expect(lista.single.origenCategoria, OrigenCategoria.desconocido);
      expect(etiquetaDeOrigen(OrigenCategoria.desconocido), isEmpty);
    });
  });

  group('corregir', () {
    test('manda categoría y nombre recortado, y lee filas_cambiadas', () async {
      late http.Request visto;
      final repo = _build((req) async {
        visto = req;
        return _json(200, {
          'success': true,
          'data': {
            'filas_cambiadas': 3,
            'movimiento': _fila(
              categoria: 'transporte',
              categoriaNombre: 'Transporte',
              origen: 'memoria',
            ),
          },
        });
      });

      final resultado = await repo.corregir(
        transaccionId: _id,
        categoria: 'transporte',
        nombreComercio: '  Tienda D1  ',
      );

      expect(visto.method, 'POST');
      expect(
        visto.url.path,
        '/v1/inteligencia/movimientos/$_id/correcciones',
      );
      expect(visto.headers['Authorization'], 'Bearer tok');
      final cuerpo = jsonDecode(visto.body) as Map<String, dynamic>;
      expect(cuerpo['categoria'], 'transporte');
      expect(cuerpo['nombre_comercio'], 'Tienda D1');

      expect(resultado.filasCambiadas, 3);
      expect(resultado.movimiento.categoria, 'transporte');
    });

    test('sin nombre no manda la llave', () async {
      late http.Request visto;
      final repo = _build((req) async {
        visto = req;
        return _json(200, {
          'success': true,
          'data': {'filas_cambiadas': 1, 'movimiento': _fila()},
        });
      });

      await repo.corregir(transaccionId: _id, categoria: 'compras');

      final cuerpo = jsonDecode(visto.body) as Map<String, dynamic>;
      expect(cuerpo.keys, ['categoria']);
    });

    test('409 CorreccionEnCurso llega como ApiException con mensaje propio',
        () async {
      final repo = _build(
        (req) async => _error(409, 'CorreccionEnCurso'),
      );

      await expectLater(
        repo.corregir(transaccionId: _id, categoria: 'compras'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'CorreccionEnCurso')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
      expect(
        mensajeDeError(const ApiException(
          code: 'CorreccionEnCurso',
          message: 'm',
        )),
        contains('otra actualización en curso'),
      );
    });
  });

  group('catálogo visible', () {
    test('las salidas ofrecen diez y las entradas cuatro', () {
      expect(categoriasPara(DireccionMovimiento.salida), hasLength(10));
      expect(categoriasPara(DireccionMovimiento.entrada), hasLength(4));
    });

    test('sin_categoria no se ofrece en ninguna dirección', () {
      for (final direccion in DireccionMovimiento.values) {
        expect(
          categoriasPara(direccion).map((c) => c.codigo),
          isNot(contains(codigoSinCategoria)),
        );
      }
    });
  });
}
