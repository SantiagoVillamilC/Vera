import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/presentation/destino_de_aviso.dart';
import 'package:vera/features/inteligencia/presentation/detalle_aviso_screen.dart';

import '../../home/presentation/fake_inteligencia.dart';

/// El reloj del escenario de demo: noviembre de 2026.
final _ahora = DateTime.utc(2026, 11, 19, 17);

Aviso _aviso({
  String tipo = 'pago_no_alcanza',
  Object? accionCodigo = 'revisar_pagos',
  String accion = 'Ver los pagos que vencen',
  String id = '255c555d-1f84-422d-b55b-b30d6550f928',
  String monto = '970000',
  Object? referencia = '13990000',
  String periodo = '2026-11-20',
  int prioridad = 1,
  String titulo = 'Tus próximos pagos suman más que tu saldo',
  String texto =
      'Tu saldo es \$9.700 y los pagos recurrentes que vencen desde '
      '2026-11-20 suman \$139.900.',
  String porque = 'Los pagos recurrentes de la ventana suman más que tu saldo.',
  Object? transaccionId,
}) => Aviso.fromJson({
  'accion': accion,
  'accion_codigo': ?accionCodigo,
  'clave': 'pago-proximo',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': id,
  'monto_centavos': monto,
  'periodo': periodo,
  'porque': porque,
  'prioridad': prioridad,
  'referencia_centavos': ?referencia,
  'severidad_centavos': '13020000',
  'texto': texto,
  'tipo': tipo,
  'titulo': titulo,
  'transaccion_id': transaccionId,
});

/// Monta el detalle dentro de un router con destinos de prueba, para ver a
/// dónde lleva el botón principal.
Future<GoRouter> _pump(
  WidgetTester tester, {
  Aviso? aviso,
  String? avisoId,
  FakeInteligenciaRepository? repo,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => DetalleAvisoScreen(
          aviso: aviso,
          avisoId: avisoId ?? aviso?.id,
          repository: repo ?? FakeInteligenciaRepository(),
          ahora: _ahora,
        ),
      ),
      for (final ruta in ['/recargar', '/inteligencia', '/estadisticas'])
        GoRoute(
          path: ruta,
          builder: (_, _) => Scaffold(body: Text('destino $ruta')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

String _ubicacion(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('pago_no_alcanza muestra monto, fecha y porqué', (tester) async {
    await _pump(tester, aviso: _aviso());

    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(
      find.textContaining('los pagos recurrentes que vencen desde 2026-11-20'),
      findsOneWidget,
    );
    expect(
      find.text('Los pagos recurrentes de la ventana suman más que tu saldo.'),
      findsOneWidget,
    );
    // El monto es el saldo en este tipo, y así se rotula.
    expect(find.text('Tu saldo'), findsOneWidget);
    expect(find.text('\$9.700'), findsOneWidget);
    expect(find.text('Pagos que vencen'), findsOneWidget);
    expect(find.text('\$139.900'), findsOneWidget);
    expect(find.text('Fecha de pago'), findsOneWidget);
    expect(find.text('20 de noviembre de 2026'), findsOneWidget);
  });

  testWidgets('el botón de revisar_pagos abre /recargar', (tester) async {
    final router = await _pump(tester, aviso: _aviso());

    expect(find.text('Recargar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accion-principal')));
    await tester.pumpAndSettle();

    expect(_ubicacion(router), '/recargar');
  });

  testWidgets('el botón de revisar_categoria abre /inteligencia', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      aviso: _aviso(
        tipo: 'categoria_sobre_media',
        accionCodigo: 'revisar_categoria',
        accion: 'Ver los movimientos de esta categoría',
        titulo: 'Gastas más en Transporte',
        prioridad: 5,
        monto: '95000000',
        referencia: '40000000',
        periodo: '2026-11-01',
      ),
    );

    // Sin rótulo propio se usa el del contrato.
    expect(find.text('Ver los movimientos de esta categoría'), findsOneWidget);
    expect(find.text('Gasto de la categoría'), findsOneWidget);
    expect(find.text('Lo habitual'), findsOneWidget);
    // El periodo de este tipo es el mes, no un día.
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('noviembre de 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accion-principal')));
    await tester.pumpAndSettle();
    expect(_ubicacion(router), '/inteligencia');
  });

  testWidgets('el botón de revisar_presupuesto abre /estadisticas', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      aviso: _aviso(
        tipo: 'presupuesto_anticipado',
        accionCodigo: 'revisar_presupuesto',
        accion: 'Ver los gastos de este mes',
        periodo: '2026-11-01',
        prioridad: 4,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('accion-principal')));
    await tester.pumpAndSettle();
    expect(_ubicacion(router), '/estadisticas');
  });

  testWidgets('un accion_codigo desconocido deja el aviso sin botón', (
    tester,
  ) async {
    await _pump(tester, aviso: _aviso(accionCodigo: 'revisar_lo_que_sea'));

    expect(find.byKey(const ValueKey('accion-principal')), findsNothing);
    // El aviso se sigue leyendo completo y se puede descartar.
    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(find.byKey(const ValueKey('descartar-detalle')), findsOneWidget);
  });

  testWidgets('sin accion_codigo tampoco hay botón, ni la etiqueta suelta', (
    tester,
  ) async {
    await _pump(tester, aviso: _aviso(accionCodigo: null));

    expect(find.byKey(const ValueKey('accion-principal')), findsNothing);
    expect(find.text('Ver los pagos que vencen'), findsNothing);
  });

  testWidgets('cobro_nuevo sin referencia se ve completo y sin la fila', (
    tester,
  ) async {
    await _pump(
      tester,
      aviso: _aviso(
        tipo: 'cobro_nuevo',
        accionCodigo: 'revisar_cobro',
        accion: 'Ver el cobro y su próximo vencimiento',
        titulo: 'Apareció un cobro nuevo',
        texto:
            'Apareció un cobro de \$24.900 el 2026-10-28 y ya se repite o '
            'está declarado como recurrente.',
        porque: 'Apareció una llave recurrente que no estaba en tu historial.',
        monto: '2490000',
        referencia: null,
        periodo: '2026-11-28',
        prioridad: 3,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Apareció un cobro nuevo'), findsOneWidget);
    expect(find.text('Valor del cobro'), findsOneWidget);
    expect(find.text('\$24.900'), findsOneWidget);
    // Sin línea base no se dibuja la fila ni se inventa un cero.
    expect(find.text('Lo habitual'), findsNothing);
    expect(find.text('Pagos que vencen'), findsNothing);
    expect(find.text('\$0'), findsNothing);
  });

  testWidgets('un aviso con transaccion_id nulo no enlaza a ningún movimiento', (
    tester,
  ) async {
    await _pump(tester, aviso: _aviso());

    expect(find.textContaining('movimiento'), findsNothing);
    expect(find.text('Ver movimiento'), findsNothing);
  });

  testWidgets('un aviso de otro mes lo dice', (tester) async {
    await _pump(
      tester,
      aviso: _aviso(
        tipo: 'caida_ingreso',
        accionCodigo: 'revisar_ingreso',
        accion: 'Ver mis ingresos',
        titulo: 'Tu ingreso bajó',
        periodo: '2026-10-01',
        prioridad: 2,
      ),
    );

    expect(find.byKey(const ValueKey('aviso-de-otro-mes')), findsOneWidget);
    expect(find.text('Aviso de octubre de 2026'), findsOneWidget);
    expect(find.text('Ingreso del mes'), findsOneWidget);
  });

  testWidgets('un aviso del mes en curso no anuncia el mes', (tester) async {
    await _pump(tester, aviso: _aviso());

    expect(find.byKey(const ValueKey('aviso-de-otro-mes')), findsNothing);
  });

  testWidgets('descartar vuelve a la bandeja con el id del aviso', (
    tester,
  ) async {
    final aviso = _aviso();
    final repo = FakeInteligenciaRepository();
    Object? devuelto;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                devuelto = await context.push<Object?>('/detalle');
              },
              child: const Text('abrir detalle'),
            ),
          ),
        ),
        GoRoute(
          path: '/detalle',
          builder: (_, _) => DetalleAvisoScreen(
            aviso: aviso,
            repository: repo,
            ahora: _ahora,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir detalle'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('descartar-detalle')));
    await tester.pumpAndSettle();

    expect(repo.descartados, [aviso.id]);
    expect(devuelto, aviso.id);
    expect(find.text('abrir detalle'), findsOneWidget);
  });

  testWidgets('con 409 el detalle se queda y dice que todavía no se puede', (
    tester,
  ) async {
    final repo = FakeInteligenciaRepository()
      ..errorAlDescartar = ApiException(
        statusCode: 409,
        code: codigoDescarteAnteriorAlAlta,
        message: 'The notice cannot be dismissed before its creation time.',
      );
    await _pump(tester, aviso: _aviso(), repo: repo);

    await tester.tap(find.byKey(const ValueKey('descartar-detalle')));
    await tester.pumpAndSettle();

    expect(find.text(mensajeDescarteAnteriorAlAlta), findsOneWidget);
    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(repo.descartados, isEmpty);
    // Se puede volver a intentar.
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('descartar-detalle')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('entrando por id lo pide a la API, y un 404 ofrece reintentar', (
    tester,
  ) async {
    final repo = FakeInteligenciaRepository();
    await _pump(tester, avisoId: 'no-existe', repo: repo);

    expect(repo.idsPedidos, ['no-existe']);
    expect(find.byKey(const ValueKey('error-detalle-aviso')), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('entrando con el aviso no se llama a la API', (tester) async {
    final repo = FakeInteligenciaRepository();
    await _pump(tester, aviso: _aviso(), repo: repo);

    expect(repo.idsPedidos, isEmpty);
  });

  group('tabla de destinos', () {
    test('los cinco códigos tienen destino, y el comodín no', () {
      expect(destinosDeAviso[AccionAviso.revisarPagos]?.ruta, '/recargar');
      expect(destinosDeAviso[AccionAviso.revisarIngreso]?.ruta, '/inteligencia');
      expect(destinosDeAviso[AccionAviso.revisarCobro]?.ruta, '/inteligencia');
      expect(
        destinosDeAviso[AccionAviso.revisarPresupuesto]?.ruta,
        '/estadisticas',
      );
      expect(
        destinosDeAviso[AccionAviso.revisarCategoria]?.ruta,
        '/inteligencia',
      );
      // El comodín está en la tabla, con ruta vacía: es «sin botón», no un
      // olvido.
      expect(destinosDeAviso[AccionAviso.desconocida]?.ruta, isEmpty);
      // Los seis valores del enum están cubiertos.
      expect(destinosDeAviso.keys.toSet(), AccionAviso.values.toSet());
    });

    test('solo revisar_pagos cambia la etiqueta del contrato', () {
      expect(rotuloDeAccion(_aviso()), 'Recargar');
      expect(
        rotuloDeAccion(
          _aviso(
            accionCodigo: 'revisar_ingreso',
            accion: 'Ver mis ingresos',
          ),
        ),
        'Ver mis ingresos',
      );
      expect(rotuloDeAccion(_aviso(accionCodigo: null)), isNull);
      expect(rotuloDeAccion(_aviso(accionCodigo: 'otro')), isNull);
    });
  });
}
