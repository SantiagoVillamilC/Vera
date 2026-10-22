import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import 'cargar_roboto.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';

import 'package:vera/core/widgets/cargando_vera.dart';

import 'fake_inteligencia.dart';
import 'fake_nucleo_repository.dart';

MontoCalculado _saldo(int centavos) => MontoCalculado(
  montoCentavos: BigInt.from(centavos),
  moneda: 'COP',
  calculadoEn: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester,
  FakeNucleoRepository repo, {
  Size size = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
  bool asentar = true,
  FakeInteligenciaRepository? inteligencia,
}) async {
  if (fuenteReal) await cargarRoboto();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: EstadisticasScreen(
        repository: repo,
        inteligencia: inteligencia ?? FakeInteligenciaRepository(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (asentar) await tester.pumpAndSettle();
}

String _texto(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

void main() {
  testWidgets('el balance sale del saldo del repositorio y no es fijo', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()..onSaldo = () async => _saldo(7654321);
    await _pump(tester, repo);

    expect(repo.saldoCalls, 1);
    expect(find.text('\$76.543,21'), findsOneWidget);
    expect(find.textContaining('145.123,56'), findsNothing);
  });

  testWidgets('mientras carga el saldo muestra progreso y no una cifra', (
    tester,
  ) async {
    final completer = Completer<MontoCalculado>();
    final repo = FakeNucleoRepository()..onSaldo = () => completer.future;
    await _pump(tester, repo, asentar: false);

    expect(find.byType(EsqueletoVera), findsWidgets);
    expect(find.textContaining('145.123,56'), findsNothing);
  });

  testWidgets('un error del saldo muestra mensaje y Reintentar', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onSaldo = () async => throw const FormatException('malo');
    await _pump(tester, repo);

    expect(find.text(mensajeErrorGenerico), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.textContaining('145.123,56'), findsNothing);

    repo.onSaldo = () async => _saldo(250000);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(repo.saldoCalls, 2);
    expect(find.text('\$2.500'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('la lista usa los movimientos reales del repositorio', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        mov(1, [(MotivoLinea.deposito, 500000)]),
        mov(2, [(MotivoLinea.envio, -120000)]),
      ]);
    await _pump(tester, repo);

    expect(repo.movimientosCalls, hasLength(1));
    expect(find.text('Depósito'), findsOneWidget);
    expect(find.text('+\$5.000'), findsOneWidget);
    expect(find.text('Envío'), findsOneWidget);
    expect(find.text('-\$1.200'), findsOneWidget);
    for (final inventado in [
      'Nómina',
      'Mercado D1',
      'Netflix',
      'Gasolina BP',
      'Transferencia',
    ]) {
      expect(find.textContaining(inventado), findsNothing);
    }
  });

  testWidgets('sin movimientos muestra el vacío', (tester) async {
    await _pump(tester, FakeNucleoRepository());

    expect(find.text('Sin movimientos aún'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('un error de movimientos muestra Reintentar y se recupera', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => throw const FormatException('malo');
    await _pump(tester, repo);

    expect(find.text(mensajeErrorGenerico), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Sin movimientos aún'), findsNothing);

    repo.onMovimientos = (_, _) async => pagina([
      mov(1, [(MotivoLinea.deposito, 500000)]),
    ]);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(repo.movimientosCalls, hasLength(2));
    expect(find.text('Depósito'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('los totales y las burbujas coinciden en cada período', (
    tester,
  ) async {
    await _pump(tester, FakeNucleoRepository());

    final vistos = <String>{};
    for (final periodo in ['Sem', 'Mes', 'Año']) {
      await tester.tap(find.text(periodo));
      await tester.pumpAndSettle();

      final ingresos = _texto(tester, 'total-ingresos');
      final gastos = _texto(tester, 'total-gastos');
      expect(ingresos, startsWith('\$'));
      expect(gastos, startsWith('\$'));
      expect(_texto(tester, 'burbuja-ingresos'), '+$ingresos');
      expect(_texto(tester, 'burbuja-gastos'), '-$gastos');
      vistos.add('$ingresos|$gastos');
    }
    expect(vistos, hasLength(3));
  });

  testWidgets('las cifras del período Mes no son las incoherentes de antes', (
    tester,
  ) async {
    await _pump(tester, FakeNucleoRepository());

    expect(find.text('+\$3.518'), findsNothing);
    expect(find.text('-\$897,29'), findsNothing);
    expect(find.text('\$351.800'), findsNothing);
    expect(find.text('\$89.772,90'), findsNothing);
  });

  testWidgets('a 320x640 no hay desborde de RenderFlex', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        movCompensado(1),
        mov(2, [(MotivoLinea.transferenciaRecibida, 2500000)]),
      ]);
    await _pump(tester, repo, size: const Size(320, 640), fuenteReal: true);
    expect(tester.takeException(), isNull);

    for (final periodo in ['Sem', 'Año']) {
      await tester.tap(find.text(periodo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a 320x640 con textScaleFactor 1.3 no hay desborde', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onSaldo = (() async => _saldo(123456789012))
      ..onMovimientos = (_, _) async => pagina([
        movCompensado(1),
        mov(2, [(MotivoLinea.transferenciaRecibida, 2500000)]),
      ]);
    await _pump(
      tester,
      repo,
      size: const Size(320, 640),
      escala: 1.3,
      fuenteReal: true,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320x640 con errores tampoco hay desborde', (tester) async {
    final repo = FakeNucleoRepository()
      ..onSaldo = (() async => throw const FormatException('x'))
      ..onMovimientos = (_, _) async => throw const FormatException('x');
    await _pump(
      tester,
      repo,
      size: const Size(320, 640),
      escala: 1.3,
      fuenteReal: true,
    );

    expect(tester.takeException(), isNull);
  });

  group('¿En qué se fue?', () {
    ResumenDelMes resumen(List<GastoDeCategoria> c) => ResumenDelMes(
      mes: '2026-10',
      totalCentavos: BigInt.zero,
      categorias: c,
    );

    testWidgets('dibuja una burbuja por categoría con su porcentaje real', (
      tester,
    ) async {
      final inteligencia = FakeInteligenciaRepository(
        onResumen: (_) async => resumen([
          gasto('Mercado', 186),
          gasto('Vivienda y servicios', 412),
          gasto('Domicilios', 148),
          gasto('Transporte', 93),
          gasto('Salud', 54),
          gasto('Compras', 107),
        ]),
      );
      await _pump(
        tester,
        FakeNucleoRepository(),
        inteligencia: inteligencia,
        fuenteReal: true,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('burbujas_categorias')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Una lectura del mes en curso y otra del anterior, solo para comparar.
      expect(inteligencia.meses.first, isNull);
      expect(inteligencia.meses.length, 2);
      expect(find.text('¿En qué se fue?'), findsOneWidget);
      // Suma 1000: el reparto sale de los montos y no es un texto fijo.
      expect(find.text('41,2%'), findsOneWidget);
      expect(find.text('18,6%'), findsOneWidget);
      expect(find.text('5,4%'), findsOneWidget);
      expect(find.text('Vivienda y servicios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin gastos avisa en vez de dibujar burbujas vacías', (
      tester,
    ) async {
      await _pump(tester, FakeNucleoRepository());
      await tester.scrollUntilVisible(
        find.byKey(const Key('sin_gastos_mes')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('burbujas_categorias')), findsNothing);
    });

    testWidgets('si falla el resumen ofrece reintentar y se recupera', (
      tester,
    ) async {
      var intento = 0;
      final inteligencia = FakeInteligenciaRepository(
        onResumen: (_) async {
          intento++;
          if (intento == 1) throw StateError('caído');
          return resumen([gasto('Mercado', 100)]);
        },
      );
      await _pump(tester, FakeNucleoRepository(), inteligencia: inteligencia);
      await tester.scrollUntilVisible(
        find.text('Reintentar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('burbujas_categorias')), findsOneWidget);
      expect(find.text('100,0%'), findsOneWidget);
    });

    testWidgets('con letra 1.3 en 320 de ancho no se desborda', (tester) async {
      final inteligencia = FakeInteligenciaRepository(
        onResumen: (_) async => resumen([
          gasto('Vivienda y servicios', 412),
          gasto('Mercado', 186),
          gasto('Domicilios', 148),
          gasto('Transporte', 93),
          gasto('Salud', 54),
          gasto('Compras', 107),
        ]),
      );
      await _pump(
        tester,
        FakeNucleoRepository(),
        inteligencia: inteligencia,
        size: const Size(320, 640),
        escala: 1.3,
        fuenteReal: true,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('burbujas_categorias')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra lo gastado en el mes y lo compara con el anterior', (
      tester,
    ) async {
      final inteligencia = FakeInteligenciaRepository(
        onResumen: (mes) async => ResumenDelMes(
          mes: mes ?? '',
          totalCentavos: BigInt.from(mes == null ? 184256000 : 200000000),
          categorias: [gasto('Mercado', 100)],
        ),
      );
      await _pump(tester, FakeNucleoRepository(), inteligencia: inteligencia);

      expect(find.byKey(const Key('pildora_mes')), findsOneWidget);
      expect(find.textContaining('Gastaste en'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('gasto_del_mes')))
            .textSpan!
            .toPlainText(),
        '\$1.842.560,00',
      );
      // 1.842.560 frente a 2.000.000: casi 8% menos.
      expect(find.textContaining('8% menos que en'), findsOneWidget);
      // El segundo pedido es del mes anterior al actual.
      expect(inteligencia.meses.last, isNotNull);
    });

    testWidgets('sin datos del mes anterior no inventa comparación', (
      tester,
    ) async {
      final inteligencia = FakeInteligenciaRepository(
        onResumen: (mes) async {
          if (mes != null) throw StateError('sin mes anterior');
          return resumen([gasto('Mercado', 100)]);
        },
      );
      await _pump(tester, FakeNucleoRepository(), inteligencia: inteligencia);
      expect(find.byKey(const Key('chip_comparacion')), findsNothing);
    });
  });
}
