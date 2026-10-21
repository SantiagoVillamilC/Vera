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
  OrigenCategoria? origen,
}) =>
    MovimientoEnriquecido(
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
      origenCategoria: origen ??
          (categoria == codigoSinCategoria
              ? OrigenCategoria.sinCategoria
              : OrigenCategoria.catalogo),
    );

class _FakeInteligencia implements InteligenciaRepository {
  _FakeInteligencia(this.movimientos);

  List<MovimientoEnriquecido> movimientos;
  final llamadas = <({
    String transaccionId,
    String? categoria,
    String? nombreComercio,
  })>[];
  int lecturas = 0;
  int filasCambiadas = 2;
  ApiException? errorDeCorreccion;
  bool fallaLaRecarga = false;

  @override
  Future<List<MovimientoEnriquecido>> listarMovimientos({
    int limit = 50,
  }) async {
    lecturas++;
    if (fallaLaRecarga && lecturas > 1) {
      throw Exception('sin red');
    }
    return List.of(movimientos);
  }

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
            categoriaNombre: categoria == m.categoria
                ? m.categoriaNombre
                : 'Transporte',
            contraparte: m.contraparte,
            monto: m.montoCentavos,
            origen: OrigenCategoria.memoria,
          )
        else
          m,
    ];
    return CorreccionAplicada(
      filasCambiadas: filasCambiadas,
      movimiento: movimientos.firstWhere(
        (m) => m.transaccionId == transaccionId,
      ),
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
  testWidgets('muestra + Categoría solo donde falta y nunca el id crudo',
      (tester) async {
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

  testWidgets('la hoja ofrece las diez de gasto y aplica la corrección',
      (tester) async {
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

  testWidgets('en una entrada la hoja ofrece solo las cuatro de ingreso',
      (tester) async {
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

  testWidgets('un 409 explica el conflicto y ofrece reintentar', (tester) async {
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

  testWidgets('una categoría sugerida se marca y se confirma sin cambiarla',
      (tester) async {
    final repo = _FakeInteligencia([
      _movimiento(
        id: _idTransporte,
        categoria: 'transporte',
        categoriaNombre: 'Transporte',
        contraparte: 'Uber',
        origen: OrigenCategoria.tfidf,
      ),
    ]);
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('marca-sugerida')), findsOneWidget);
    expect(
      find.text('1 sugerida por Vera, toca para confirmar'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('categoria-$_idTransporte')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Vera la sugiere. Confírmala o elige otra.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar categoría'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();

    expect(repo.llamadas, hasLength(1));
    expect(repo.llamadas.single.categoria, 'transporte');
    expect(repo.llamadas.single.nombreComercio, isNull);
    // El backend la guarda en memoria y deja de ser sugerencia.
    expect(find.byKey(const ValueKey('marca-sugerida')), findsNothing);
  });

  testWidgets('si la recarga falla, la lista se queda y avisa', (tester) async {
    final repo = _FakeInteligencia([
      _movimiento(
        id: _idTransporte,
        categoria: 'transporte',
        categoriaNombre: 'Transporte',
        contraparte: 'Uber',
        origen: OrigenCategoria.tfidf,
      ),
    ])
      ..fallaLaRecarga = true;
    await _pump(tester, repo);

    await tester.tap(
      find.byKey(const ValueKey('categoria-$_idTransporte')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo actualizar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('enriquecido-$_idTransporte')),
      findsOneWidget,
    );
    expect(find.text('Uber'), findsOneWidget);
    // La fila se actualizó en memoria aunque la recarga fallara.
    expect(find.byKey(const ValueKey('marca-sugerida')), findsNothing);
  });

  testWidgets('una sugerencia de gasto en una entrada no se confirma sola',
      (tester) async {
    final repo = _FakeInteligencia([
      _movimiento(
        id: _idTransporte,
        categoria: 'comisiones_costos_financieros',
        categoriaNombre: 'Comisiones y costos financieros',
        direccion: DireccionMovimiento.entrada,
        contraparte: 'Banco custodio',
        origen: OrigenCategoria.lexico,
      ),
    ]);
    await _pump(tester, repo);

    await tester.tap(
      find.byKey(const ValueKey('categoria-$_idTransporte')),
    );
    await tester.pumpAndSettle();

    // La categoría sugerida no es de ingreso: no se ofrece confirmarla.
    expect(find.textContaining('Vera la sugiere'), findsNothing);
    expect(find.text('Confirmar categoría'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('boton-aplicar-correccion')));
    await tester.pumpAndSettle();
    expect(repo.llamadas, isEmpty);

    await tester.tap(find.byKey(const ValueKey('opcion-categoria-salario')));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);
  });

  testWidgets('una categoría ya confirmada no se marca como sugerida',
      (tester) async {
    final repo = _FakeInteligencia([
      _movimiento(
        id: _idTransporte,
        categoria: 'transporte',
        categoriaNombre: 'Transporte',
        contraparte: 'Uber',
        origen: OrigenCategoria.memoria,
      ),
    ]);
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('marca-sugerida')), findsNothing);
    expect(find.textContaining('sugeridas por Vera'), findsNothing);
  });

  testWidgets('la sección del tab de movimientos navega a /inteligencia',
      (tester) async {
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
