import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import 'cargar_roboto.dart';
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
}) async {
  if (fuenteReal) await cargarRoboto();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
        ),
        child: child!,
      ),
      home: EstadisticasScreen(repository: repo),
    ),
  );
  await tester.pump();
  await tester.pump();
  if (asentar) await tester.pumpAndSettle();
}

String _texto(WidgetTester tester, String clave) =>
    tester.widget<Text>(find.byKey(ValueKey(clave))).data!;

void main() {
  testWidgets('el balance sale del saldo del repositorio y no es fijo',
      (tester) async {
    final repo = FakeNucleoRepository()
      ..onSaldo = () async => _saldo(7654321);
    await _pump(tester, repo);

    expect(repo.saldoCalls, 1);
    expect(find.text('\$76.543,21'), findsOneWidget);
    expect(find.textContaining('145.123,56'), findsNothing);
  });

  testWidgets('mientras carga el saldo muestra progreso y no una cifra',
      (tester) async {
    final completer = Completer<MontoCalculado>();
    final repo = FakeNucleoRepository()..onSaldo = () => completer.future;
    await _pump(tester, repo, asentar: false);

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.textContaining('145.123,56'), findsNothing);
  });

  testWidgets('un error del saldo muestra mensaje y Reintentar', (tester) async {
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

  testWidgets('la lista usa los movimientos reales del repositorio',
      (tester) async {
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

  testWidgets('un error de movimientos muestra Reintentar y se recupera',
      (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => throw const FormatException('malo');
    await _pump(tester, repo);

    expect(find.text(mensajeErrorGenerico), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Sin movimientos aún'), findsNothing);

    repo.onMovimientos =
        (_, _) async => pagina([mov(1, [(MotivoLinea.deposito, 500000)])]);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(repo.movimientosCalls, hasLength(2));
    expect(find.text('Depósito'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('los totales y las burbujas coinciden en cada período',
      (tester) async {
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

  testWidgets('las cifras del período Mes no son las incoherentes de antes',
      (tester) async {
    await _pump(tester, FakeNucleoRepository());

    expect(find.text('+\$3.518'), findsNothing);
    expect(find.text('-\$897,29'), findsNothing);
    expect(find.text('\$351.800'), findsNothing);
    expect(find.text('\$89.772,90'), findsNothing);
  });

  testWidgets('no muestra marcas de trabajo en curso', (tester) async {
    await _pump(tester, FakeNucleoRepository());

    expect(find.textContaining('WIP'), findsNothing);
    expect(find.text('Ver todos'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);
  });

  testWidgets('a 320x640 no hay desborde de RenderFlex', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
            movCompensado(1),
            mov(2, [(MotivoLinea.transferenciaRecibida, 2500000)]),
          ]);
    await _pump(
      tester,
      repo,
      size: const Size(320, 640),
      fuenteReal: true,
    );
    expect(tester.takeException(), isNull);

    for (final periodo in ['Sem', 'Año']) {
      await tester.tap(find.text(periodo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a 320x640 con textScaleFactor 1.3 no hay desborde',
      (tester) async {
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
}
