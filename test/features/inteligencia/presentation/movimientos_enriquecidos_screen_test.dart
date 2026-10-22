import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/home/presentation/movimientos_tab.dart';
import 'package:vera/features/inteligencia/data/inteligencia_repository.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/inteligencia/presentation/movimientos_enriquecidos_screen.dart';

import '../../home/presentation/fake_nucleo_repository.dart';

const _idSinCategoria = 'b3f1a2c4-1111-4222-8333-444455556666';
const _idTransporte = 'c9d8e7f6-2222-4333-8444-555566667777';

MovimientoEnriquecido _movimiento({
  String id = _idSinCategoria,
  String categoria = codigoSinCategoria,
  String categoriaNombre = 'Sin categoría',
  DireccionMovimiento direccion = DireccionMovimiento.salida,
  String contraparte = 'Tienda D1',
  BigInt? monto,
}) => MovimientoEnriquecido(
  transaccionId: id,
  ocurridoEn: DateTime.utc(2026, 10, 12, 19, 30),
  moneda: 'COP',
  direccion: direccion,
  montoCentavos: monto ?? BigInt.from(1250000),
  contraparte: contraparte,
  contraparteResuelta: true,
  descripcion: 'COMPRA POS',
  categoria: categoria,
  categoriaNombre: categoriaNombre,
  origenCategoria: categoria == codigoSinCategoria
      ? OrigenCategoria.sinCategoria
      : OrigenCategoria.catalogo,
);

class _FakeInteligencia implements InteligenciaRepository {
  _FakeInteligencia(this.movimientos);

  List<MovimientoEnriquecido> movimientos;
  final llamadas =
      <({String transaccionId, String? categoria, String? nombreComercio})>[];
  int lecturas = 0;
  int filasCambiadas = 2;
  ApiException? errorDeCorreccion;

  @override
  Future<List<MovimientoEnriquecido>> listarMovimientos({
    int limit = 50,
  }) async {
    lecturas++;
    return List.of(movimientos);
  }

  @override
  Future<ResumenDelMes> resumen({String? mes}) async => ResumenDelMes(
    mes: '2026-10',
    totalCentavos: BigInt.zero,
    categorias: const [],
  );

  @override
  Future<CorreccionAplicada> corregir({
    required String transaccionId,
    String? categoria,
    String? nombreComercio,
  }) async {
    llamadas.add((
      transaccionId: transaccionId,
      categoria: categoria,
      nombreComercio: nombreComercio,
    ));
    final error = errorDeCorreccion;
    if (error != null) throw error;
    movimientos = [
      for (final m in movimientos)
        if (m.transaccionId == transaccionId && categoria != null)
          _movimiento(
            id: m.transaccionId,
            categoria: categoria,
            categoriaNombre: 'Transporte',
            contraparte: m.contraparte,
            monto: m.montoCentavos,
          )
        else
          m,
    ];
    return CorreccionAplicada(
      filasCambiadas: filasCambiadas,
      movimiento: movimientos.first,
    );
  }
}

Future<void> _pump(WidgetTester tester, _FakeInteligencia repo) async {
  tester.view.physicalSize = const Size(900, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MovimientosEnriquecidosScreen(
        repository: repo,
        offsetLocal: const Duration(hours: -5),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra + Categoría solo donde falta y nunca el id crudo', (
    tester,
  ) async {
    final repo = _FakeInteligencia([
      _movimiento(),
      _movimiento(
        id: _idTransporte,
        categoria: 'transporte',
        categoriaNombre: 'Transporte',
        contraparte: 'Uber',
      ),
    ]);
    await _pump(tester, repo);

    expect(find.text('+ Categoría'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Tienda D1'), findsOneWidget);
    expect(find.text('Uber'), findsOneWidget);
    expect(find.text('1 de 2 sin categoría'), findsOneWidget);
    expect(find.textContaining(_idSinCategoria), findsNothing);
    expect(find.textContaining(_idTransporte), findsNothing);
  });

  testWidgets(
    'cada fila muestra la fecha, el origen de la categoría y la hora',
    (tester) async {
      final repo = _FakeInteligencia([
        _movimiento(
          id: _idTransporte,
          categoria: 'transporte',
          categoriaNombre: 'Transporte',
          contraparte: 'Uber',
        ),
      ]);
      await _pump(tester, repo);

      // 19:30 UTC con el desfase de -5 h son las 2:30 pm.
      expect(find.text('2:30 pm'), findsOneWidget);
      expect(find.textContaining('Catálogo'), findsOneWidget);
    },
  );

  testWidgets('la hoja ofrece las diez de gasto y aplica la corrección', (
    tester,
  ) async {
    final repo = _FakeInteligencia([_movimiento()]);
    await _pump(tester, repo);

    await tester.tap(find.text('+ Categoría'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hoja-correccion')), findsOneWidget);
    expect(find.text('Alimentos y mercado'), findsOneWidget);
    expect(find.text('Restaurantes y domicilios'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    // Las de ingreso no se ofrecen y sin_categoria tampoco.
    expect(find.text('Salario'), findsNothing);
    expect(find.text('Sin categoría'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('opcion-categoria-transporte')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();

    expect(repo.llamadas, hasLength(1));
    expect(repo.llamadas.single.transaccionId, _idSinCategoria);
    expect(repo.llamadas.single.categoria, 'transporte');
    expect(repo.llamadas.single.nombreComercio, isNull);
    // Refresca la lista después de corregir.
    expect(repo.lecturas, 2);
    expect(find.text('2 movimientos actualizados'), findsOneWidget);
    expect(find.text('+ Categoría'), findsNothing);
  });

  testWidgets('en una entrada la hoja ofrece solo las cuatro de ingreso', (
    tester,
  ) async {
    final repo = _FakeInteligencia([
      _movimiento(
        direccion: DireccionMovimiento.entrada,
        contraparte: 'Nómina',
      ),
    ]);
    await _pump(tester, repo);

    await tester.tap(find.text('+ Categoría'));
    await tester.pumpAndSettle();

    expect(find.text('Salario'), findsOneWidget);
    expect(find.text('Reembolso'), findsOneWidget);
    expect(find.text('Alimentos y mercado'), findsNothing);
  });

  testWidgets('el nombre del comercio viaja cuando se escribe', (tester) async {
    final repo = _FakeInteligencia([_movimiento()]);
    await _pump(tester, repo);

    await tester.tap(find.text('+ Categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('campo-nombre-comercio')),
      'Tienda del barrio',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();

    expect(repo.llamadas.single.nombreComercio, 'Tienda del barrio');
    expect(repo.llamadas.single.categoria, isNull);
  });

  testWidgets('un 409 explica el conflicto y ofrece reintentar', (
    tester,
  ) async {
    final repo = _FakeInteligencia([_movimiento()])
      ..errorDeCorreccion = const ApiException(
        code: 'CorreccionEnCurso',
        message: 'busy',
        statusCode: 409,
      );
    await _pump(tester, repo);

    await tester.tap(find.text('+ Categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('opcion-categoria-transporte')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();

    expect(find.textContaining('otra actualización en curso'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(repo.lecturas, 1);
  });

  testWidgets('una lista vacía muestra el estado vacío', (tester) async {
    final repo = _FakeInteligencia(const []);
    await _pump(tester, repo);
    expect(find.text('Sin movimientos'), findsOneWidget);
    expect(find.text('+ Categoría'), findsNothing);
  });

  testWidgets('la sección del tab de movimientos navega a /inteligencia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: MovimientosTab(repository: FakeNucleoRepository()),
          ),
        ),
        GoRoute(
          path: '/inteligencia',
          builder: (_, _) => const Scaffold(body: Text('destino')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();

    expect(find.text('Movimientos con categoría'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('acceso-categorias')));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/inteligencia',
    );
    expect(find.text('destino'), findsOneWidget);
  });
}
