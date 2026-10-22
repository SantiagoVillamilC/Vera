import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/features/home/presentation/movimientos_tab.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import 'fake_nucleo_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeNucleoRepository repo, {
  Duration? offset,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MovimientosTab(repository: repo, offsetLocal: offset),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<Movimiento> _depositos(int desde, int cantidad) => [
  for (var i = desde; i < desde + cantidad; i++)
    mov(i, [(MotivoLinea.deposito, 100000 + i)]),
];

/// Los chips de filtro comparten texto con los títulos del resumen.
Finder _chip(String label) => find.descendant(
  of: find.byType(AnimatedContainer),
  matching: find.text(label),
);

Future<void> _alFinal(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -5000));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('monta con una sola petición', (tester) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);

    expect(repo.movimientosCalls, hasLength(1));
    expect(repo.movimientosCalls.single.limit, 50);
  });

  testWidgets('el scroll al final carga más una sola vez y se detiene', (
    tester,
  ) async {
    final segunda = Completer<MovimientosPage>();
    final repo = FakeNucleoRepository()
      ..onMovimientos = (limit, cursor) {
        if (cursor == null) {
          return Future.value(
            pagina(_depositos(1, 20), nextCursor: 20, hasMore: true),
          );
        }
        return segunda.future;
      };
    await _pump(tester, repo);
    expect(repo.movimientosCalls, hasLength(1));

    await _alFinal(tester);
    await _alFinal(tester);
    await _alFinal(tester);
    expect(repo.movimientosCalls, hasLength(2));
    expect(repo.movimientosCalls.last.cursor, 20);

    segunda.complete(pagina(_depositos(21, 5)));
    await tester.pump();
    await tester.pump();
    await _alFinal(tester);
    await _alFinal(tester);

    expect(repo.movimientosCalls, hasLength(2));
    expect(find.byKey(const ValueKey('boton-cargar-mas')), findsNothing);
    expect(find.text('Cargar más'), findsNothing);
  });

  testWidgets('con filtro activo carga más hasta encontrar filas del tipo', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (limit, cursor) async {
        if (cursor == null) {
          return pagina(_depositos(1, 3), nextCursor: 3, hasMore: true);
        }
        return pagina([
          mov(99, [(MotivoLinea.envio, -250000)]),
        ]);
      };
    await _pump(tester, repo);

    await tester.tap(_chip('Gastos'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repo.movimientosCalls, hasLength(2));
    expect(find.text('-\$2.500'), findsOneWidget);
    expect(find.text('Depósito'), findsNothing);
  });

  testWidgets(
    'filtro Ingresos con página 1 de solo envíos carga la página 2 sin '
    'scroll y nunca muestra el estado vacío',
    (tester) async {
      final repo = FakeNucleoRepository()
        ..onMovimientos = (limit, cursor) async {
          if (cursor == null) {
            return pagina(
              [
                for (var i = 1; i <= 50; i++)
                  mov(i, [(MotivoLinea.envio, -100000 - i)]),
              ],
              nextCursor: 50,
              hasMore: true,
            );
          }
          return pagina([
            mov(99, [(MotivoLinea.deposito, 500000)]),
          ]);
        };
      await _pump(tester, repo);

      await tester.tap(_chip('Ingresos'));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
        expect(find.text('Sin movimientos'), findsNothing);
      }

      expect(repo.movimientosCalls, hasLength(2));
      expect(repo.movimientosCalls.last.cursor, 50);
      expect(find.text('Depósito'), findsOneWidget);
      expect(find.text('Sin movimientos'), findsNothing);
    },
  );

  testWidgets('sin filtro y con lista corta en superficie alta carga la '
      'página 2 sin scroll', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (limit, cursor) async {
        if (cursor == null) {
          return pagina(_depositos(1, 2), nextCursor: 2, hasMore: true);
        }
        return pagina(_depositos(3, 2));
      };
    await _pump(tester, repo);
    await tester.pump();
    await tester.pump();

    expect(repo.movimientosCalls, hasLength(2));
    expect(repo.movimientosCalls.last.cursor, 2);
    expect(find.text('Depósito'), findsNWidgets(4));
  });

  testWidgets('sin has_more un filtro sin resultados muestra el estado vacío '
      'y no pide más páginas', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina(_depositos(1, 3));
    await _pump(tester, repo);

    await tester.tap(_chip('Gastos'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(repo.movimientosCalls, hasLength(1));
    expect(find.text('Sin movimientos'), findsOneWidget);
  });

  testWidgets('las cargas encadenadas son de una en una y topan en 5, luego '
      'queda el botón Cargar más', (tester) async {
    var enVuelo = 0;
    var maxEnVuelo = 0;
    final repo = FakeNucleoRepository()
      ..onMovimientos = (limit, cursor) async {
        enVuelo++;
        if (enVuelo > maxEnVuelo) maxEnVuelo = enVuelo;
        await Future<void>.delayed(Duration.zero);
        enVuelo--;
        final base = (cursor ?? 0) + 1;
        return pagina(
          [
            mov(base, [(MotivoLinea.envio, -100000 - base)]),
          ],
          nextCursor: base,
          hasMore: true,
        );
      };
    await _pump(tester, repo);

    await tester.tap(_chip('Ingresos'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Sin movimientos'), findsNothing);
    }

    expect(maxEnVuelo, 1);
    expect(repo.movimientosCalls, hasLength(6));
    final boton = find.byKey(const ValueKey('boton-cargar-mas'));
    expect(boton, findsOneWidget);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(boton);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(maxEnVuelo, 1);
    expect(repo.movimientosCalls, hasLength(12));
    expect(find.byKey(const ValueKey('boton-cargar-mas')), findsOneWidget);
  });

  testWidgets('el filtro Ingresos solo muestra líneas positivas', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        movCompensado(1),
        mov(2, [(MotivoLinea.envio, -300000)]),
      ]);
    await _pump(tester, repo);

    await tester.tap(_chip('Ingresos'));
    await tester.pump();

    expect(find.text('Devolución'), findsOneWidget);
    expect(find.text('Envío'), findsNothing);
    expect(find.text('GMF'), findsNothing);
  });

  testWidgets('un error muestra mensaje genérico y Reintentar', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => throw const FormatException('malo');
    await _pump(tester, repo);

    expect(find.text(mensajeErrorGenerico), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);

    repo.onMovimientos = (_, _) async => pagina(_depositos(1, 1));
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Depósito'), findsOneWidget);
  });

  testWidgets('los totales no cuentan la transferencia compensada', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        mov(1, [(MotivoLinea.deposito, 50000000)]),
        mov(2, [(MotivoLinea.envio, -2000000)]),
        mov(3, [
          (MotivoLinea.envio, -10000000),
          (MotivoLinea.devolucion, 10000000),
        ]),
      ]);
    await _pump(tester, repo);

    // Una vez en el resumen y otra en la fila del depósito.
    expect(find.text('+\$500.000'), findsNWidgets(2));
    expect(find.text('\$20.000'), findsOneWidget);
    expect(find.text('+\$600.000'), findsNothing);
    expect(find.text('\$120.000'), findsNothing);
  });

  testWidgets('cada fila dice si es Ingreso o Gasto', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        mov(1, [(MotivoLinea.deposito, 5000000)]),
        mov(2, [(MotivoLinea.envio, -2000000)]),
      ]);
    await _pump(tester, repo);

    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Gasto'), findsOneWidget);
  });

  testWidgets('la compensación muestra filas con signo y ningún -\$0', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([movCompensado(1)]);
    await _pump(tester, repo);

    expect(find.text('Envío'), findsOneWidget);
    expect(find.text('-\$10.000'), findsOneWidget);
    expect(find.text('Devolución'), findsOneWidget);
    expect(find.text('+\$10.000'), findsOneWidget);
    expect(find.text('GMF'), findsOneWidget);
    expect(find.text('-\$40'), findsOneWidget);
    expect(find.textContaining('-\$0'), findsNothing);
  });

  testWidgets('la hora y el día de agrupación usan la hora local', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        mov(1, [
          (MotivoLinea.deposito, 100000),
        ], ocurridoEn: DateTime.utc(2025, 3, 10, 2, 30)),
      ]);
    await _pump(tester, repo, offset: const Duration(hours: -8));

    expect(find.text('6:30 pm'), findsOneWidget);
    expect(find.text('Dom 9 mar'), findsOneWidget);
  });

  testWidgets('ya no hay un botón de filtros sin acción', (tester) async {
    await _pump(tester, FakeNucleoRepository());

    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });
}
