import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/api_client.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/inteligencia/presentation/bandeja_avisos_screen.dart';
import 'package:vera/features/inteligencia/presentation/detalle_aviso_screen.dart';

import '../../home/presentation/cargar_roboto.dart';
import '../../home/presentation/fake_inteligencia.dart';

/// El reloj del servidor en el escenario de demo: noviembre de 2026.
final _ahora = DateTime.utc(2026, 11, 19, 17);

/// Capturas de la sección 4 del contrato. A2 es la bandeja del mes en curso y
/// A4 la del mes anterior, que es el único camino a `caida_ingreso`.
Aviso _pagoNoAlcanza() => Aviso.fromJson({
  'accion': 'Ver los pagos que vencen',
  'accion_codigo': 'revisar_pagos',
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
});

Aviso _presupuesto() => Aviso.fromJson({
  'accion': 'Ver los gastos de este mes',
  'accion_codigo': 'revisar_presupuesto',
  'clave': 'gasto-total',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': '2c6242c9-f963-40e2-9f92-0a2050ca9f87',
  'monto_centavos': '19590000',
  'periodo': '2026-11-01',
  'porque': 'El gasto acumulado del mes supera lo habitual de tus meses completos.',
  'prioridad': 4,
  'referencia_centavos': '18990000',
  'severidad_centavos': '600000',
  'texto':
      'En noviembre de 2026 llevas \$195.900 en gastos. Lo habitual en tus '
      'meses completos es \$189.900.',
  'tipo': 'presupuesto_anticipado',
  'titulo': 'Tu gasto va por encima de lo habitual',
  'transaccion_id': null,
});

Aviso _caidaIngreso() => Aviso.fromJson({
  'accion': 'Ver mis ingresos',
  'accion_codigo': 'revisar_ingreso',
  'clave': 'ingreso-mensual',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': '409484e1-54be-4673-badf-a770df522fb1',
  'monto_centavos': '13800000',
  'periodo': '2026-10-01',
  'porque': 'El ingreso del último mes completo quedó por debajo de lo habitual.',
  'prioridad': 2,
  'referencia_centavos': '20000000',
  'severidad_centavos': '6200000',
  'texto':
      'El ingreso de octubre de 2026 fue \$138.000. Lo habitual en tus meses '
      'anteriores es \$200.000.',
  'tipo': 'caida_ingreso',
  'titulo': 'Tu ingreso bajó',
  'transaccion_id': null,
});

Aviso _cobroNuevo() => Aviso.fromJson({
  'accion': 'Ver el cobro y su próximo vencimiento',
  'accion_codigo': 'revisar_cobro',
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
});

/// Derivado del contrato: la semilla de la demo no produce este tipo.
Aviso _categoriaSobreMedia() => Aviso.fromJson({
  'accion': 'Ver los movimientos de esta categoría',
  'accion_codigo': 'revisar_categoria',
  'clave': 'transporte',
  'creado_en': '2026-11-19T12:00:00-05:00',
  'id': '8f1c0b7a-3333-4444-8555-666677778888',
  'monto_centavos': '95000000',
  'periodo': '2026-11-01',
  'porque': 'El acumulado de esta categoría supera lo habitual de tus meses completos.',
  'prioridad': 5,
  'referencia_centavos': '40000000',
  'severidad_centavos': '55000000',
  'texto':
      'En julio de 2026 llevas \$950.000 en Transporte. Lo habitual en esa '
      'categoría es \$400.000.',
  'tipo': 'categoria_sobre_media',
  'titulo': 'Gastas más en Transporte',
  'transaccion_id': null,
});

ResumenDelMes _resumen({int? emitidos, int? cupo}) => ResumenDelMes(
  mes: '2026-11',
  totalCentavos: BigInt.zero,
  categorias: const [],
  avisosEmitidos: emitidos,
  cupoAvisos: cupo,
);

FakeInteligenciaRepository _repo({
  List<Aviso> enCurso = const [],
  List<Aviso> anterior = const [],
  ResumenDelMes? resumen,
}) {
  final repo = FakeInteligenciaRepository(
    onResumen: (_) async => resumen ?? _resumen(emitidos: 2, cupo: 3),
  );
  repo.onAvisos = (mes) async => mes == null ? enCurso : anterior;
  return repo;
}

Future<void> _pump(
  WidgetTester tester,
  FakeInteligenciaRepository repo, {
  Size tamano = const Size(900, 1800),
  double escala = 1,
  bool fuenteReal = false,
  bool mostrarCupo = false,
}) async {
  if (fuenteReal) await cargarRoboto();
  tester.view.physicalSize = tamano;
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
      home: BandejaAvisosScreen(
        repository: repo,
        ahora: _ahora,
        mostrarCupo: mostrarCupo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('une los dos meses y los ordena como el servidor', (
    tester,
  ) async {
    final repo = _repo(
      enCurso: [_presupuesto(), _pagoNoAlcanza()],
      anterior: [_caidaIngreso(), _cobroNuevo()],
    );
    await _pump(tester, repo);

    // Dos llamadas: la bandeja del mes en curso y ?mes= del anterior.
    expect(repo.mesesDeAvisos, [null, '2026-10']);

    // Se mira la posición en pantalla, que es lo que ve el usuario.
    double altura(Aviso a) =>
        tester.getTopLeft(find.byKey(ValueKey('aviso-${a.id}'))).dy;

    // El mes en curso va primero y el anterior después, como en el wireframe:
    // un aviso de octubre mezclado entre los de noviembre sin decir de qué mes
    // es engaña, aunque su prioridad sea menor.
    expect(altura(_presupuesto()), lessThan(altura(_caidaIngreso())));

    // Dentro de cada mes manda el orden del servidor: prioridad ascendente y,
    // a igual prioridad, severidad descendente.
    expect(altura(_pagoNoAlcanza()), lessThan(altura(_presupuesto())));
    expect(altura(_caidaIngreso()), lessThan(altura(_cobroNuevo())));
  });

  testWidgets('cada aviso muestra su título, su texto y su acción', (
    tester,
  ) async {
    await _pump(tester, _repo(enCurso: [_pagoNoAlcanza()]));

    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(
      find.textContaining('los pagos recurrentes que vencen desde 2026-11-20'),
      findsOneWidget,
    );
    // revisar_pagos lleva a /recargar, así que el botón dice lo que hace.
    // La etiqueta del contrato describiría un destino que la app no tiene.
    expect(find.text('Recargar'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
  });

  testWidgets('agrupa por mes en curso y mes anterior', (tester) async {
    await _pump(
      tester,
      _repo(enCurso: [_presupuesto()], anterior: [_caidaIngreso()]),
    );

    expect(find.text('Noviembre · mes en curso'), findsOneWidget);
    expect(find.text('Octubre · mes anterior'), findsOneWidget);
  });

  testWidgets('el tipo derivado categoria_sobre_media se pinta igual', (
    tester,
  ) async {
    await _pump(tester, _repo(enCurso: [_categoriaSobreMedia()]));

    expect(find.text('Gastas más en Transporte'), findsOneWidget);
    expect(find.text('Ver los movimientos de esta categoría'), findsOneWidget);
  });

  testWidgets('un accion_codigo desconocido o ausente deja la tarjeta sin '
      'botón de acción, pero con su texto', (tester) async {
    final desconocido = Aviso.fromJson({
      'accion': 'Ver los pagos que vencen',
      'accion_codigo': 'revisar_lo_que_sea',
      'clave': 'pago-proximo',
      'creado_en': '2026-11-19T12:00:00-05:00',
      'id': 'aaaa1111-2222-4333-8444-555566667777',
      'monto_centavos': '970000',
      'periodo': '2026-11-20',
      'porque': 'x',
      'prioridad': 1,
      'severidad_centavos': '1',
      'texto': 'Texto del aviso con código nuevo.',
      'tipo': 'pago_no_alcanza',
      'titulo': 'Aviso con código nuevo',
    });
    final sinCodigo = Aviso.fromJson({
      'accion': 'Ver mis ingresos',
      'clave': 'ingreso-mensual',
      'creado_en': '2026-11-19T12:00:00-05:00',
      'id': 'bbbb1111-2222-4333-8444-555566667777',
      'monto_centavos': '1',
      'periodo': '2026-11-02',
      'porque': 'x',
      'prioridad': 2,
      'severidad_centavos': '1',
      'texto': 'Texto del aviso sin código.',
      'tipo': 'caida_ingreso',
      'titulo': 'Aviso sin código',
    });
    await _pump(tester, _repo(enCurso: [desconocido, sinCodigo]));

    expect(tester.takeException(), isNull);
    expect(find.text('Aviso con código nuevo'), findsOneWidget);
    expect(find.text('Aviso sin código'), findsOneWidget);
    expect(find.text('Ver los pagos que vencen'), findsNothing);
    expect(find.text('Ver mis ingresos'), findsNothing);
    // Se pueden descartar igual.
    expect(find.text('Descartar'), findsNWidgets(2));
  });

  testWidgets('sin avisos muestra el vacío, no una lista en blanco', (
    tester,
  ) async {
    await _pump(tester, _repo());

    expect(find.byKey(const ValueKey('avisos-vacio')), findsOneWidget);
    expect(find.text('Sin avisos este mes.'), findsOneWidget);
  });

  testWidgets('sin red muestra Reintentar y al reintentar carga la lista', (
    tester,
  ) async {
    var primeraVez = true;
    final repo = FakeInteligenciaRepository(
      onResumen: (_) async => _resumen(emitidos: 1, cupo: 3),
    );
    repo.onAvisos = (mes) async {
      if (primeraVez) throw const SocketLikeError();
      return mes == null ? [_pagoNoAlcanza()] : const <Aviso>[];
    };
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('error-avisos')), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byKey(const ValueKey('avisos-vacio')), findsNothing);

    primeraVez = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(find.byKey(const ValueKey('error-avisos')), findsNothing);
  });

  testWidgets('descartar quita el aviso al instante y llama al POST', (
    tester,
  ) async {
    final aviso = _pagoNoAlcanza();
    final repo = _repo(enCurso: [aviso, _presupuesto()]);
    await _pump(tester, repo);

    await tester.tap(find.byKey(ValueKey('descartar-${aviso.id}')));
    await tester.pump();

    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsNothing);
    expect(find.text('Tu gasto va por encima de lo habitual'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(repo.descartados, [aviso.id]);
  });

  testWidgets('si el descarte falla el aviso vuelve y se avisa', (tester) async {
    final aviso = _pagoNoAlcanza();
    final repo = _repo(enCurso: [aviso]);
    repo.errorAlDescartar = ApiException(
      statusCode: 500,
      code: 'InternalError',
      message: 'Something went wrong.',
    );
    await _pump(tester, repo);

    // El quite instantáneo se comprueba en la prueba del descarte con éxito:
    // aquí el fallo llega en el mismo microtask y la reversión se ve ya en el
    // primer cuadro.
    await tester.tap(find.byKey(ValueKey('descartar-${aviso.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(repo.descartados, isEmpty);
  });

  testWidgets('con 409 el aviso vuelve y dice que todavía no se puede', (
    tester,
  ) async {
    final aviso = _presupuesto();
    final repo = _repo(enCurso: [aviso]);
    repo.errorAlDescartar = ApiException(
      statusCode: 409,
      code: codigoDescarteAnteriorAlAlta,
      message: 'The notice cannot be dismissed before its creation time.',
    );
    await _pump(tester, repo);

    await tester.tap(find.byKey(ValueKey('descartar-${aviso.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsOneWidget);
    expect(find.text(mensajeDescarteAnteriorAlAlta), findsOneWidget);
  });

  testWidgets('el indicador de cupo usa los valores del servidor', (
    tester,
  ) async {
    await _pump(
      tester,
      _repo(
        enCurso: [_presupuesto()],
        resumen: _resumen(emitidos: 5, cupo: 5),
      ),
      mostrarCupo: true,
    );

    expect(find.byKey(const ValueKey('indicador-cupo')), findsOneWidget);
    // El cupo de la demo es 5 y el de producto 3: la app no fija el número.
    expect(find.text('5 de 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('cupo-lleno')), findsOneWidget);
  });

  testWidgets('sin llegar al tope no se avisa del cupo', (tester) async {
    await _pump(
      tester,
      _repo(
        enCurso: [_presupuesto()],
        resumen: _resumen(emitidos: 2, cupo: 5),
      ),
      mostrarCupo: true,
    );

    expect(find.text('2 de 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('cupo-lleno')), findsNothing);
  });

  testWidgets('si el resumen no trae el cupo no se dibuja el indicador', (
    tester,
  ) async {
    await _pump(
      tester,
      _repo(enCurso: [_presupuesto()], resumen: _resumen()),
      mostrarCupo: true,
    );

    expect(find.byKey(const ValueKey('indicador-cupo')), findsNothing);
    expect(find.byKey(const ValueKey('cupo-lleno')), findsNothing);
  });

  testWidgets('por defecto no se dibuja el cupo aunque el servidor lo llene', (
    tester,
  ) async {
    final aviso = _presupuesto();
    final repo = _repo(
      enCurso: [aviso],
      resumen: _resumen(emitidos: 5, cupo: 5),
    );
    await _pump(tester, repo);

    expect(find.byKey(const ValueKey('indicador-cupo')), findsNothing);
    expect(find.byKey(const ValueKey('cupo-lleno')), findsNothing);
    expect(find.text('5 de 5'), findsNothing);
    // El cupo se sigue leyendo: solo deja de mostrarse.
    expect(repo.resumenCalls, greaterThan(0));
    // La lista de avisos no cambia.
    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsOneWidget);
  });

  testWidgets('el parámetro apagado gana aunque el cupo esté lleno', (
    tester,
  ) async {
    await _pump(
      tester,
      _repo(
        enCurso: [_pagoNoAlcanza()],
        resumen: _resumen(emitidos: 3, cupo: 3),
      ),
      mostrarCupo: false,
    );

    expect(find.byKey(const ValueKey('indicador-cupo')), findsNothing);
    expect(find.byKey(const ValueKey('cupo-lleno')), findsNothing);
  });

  testWidgets('contarAvisosVigentes suma los dos meses', (tester) async {
    final repo = _repo(
      enCurso: [_pagoNoAlcanza(), _presupuesto()],
      anterior: [_caidaIngreso()],
    );

    expect(await contarAvisosVigentes(repo, ahora: _ahora), 3);
    expect(repo.mesesDeAvisos, [null, '2026-10']);
  });

  testWidgets('si el mes anterior falla, el mes en curso se muestra igual', (
    tester,
  ) async {
    final repo = FakeInteligenciaRepository(
      onResumen: (_) async => _resumen(emitidos: 1, cupo: 3),
    );
    repo.onAvisos = (mes) async {
      if (mes != null) throw const SocketLikeError();
      return [_pagoNoAlcanza()];
    };
    await _pump(tester, repo);

    expect(find.text('Tus próximos pagos suman más que tu saldo'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const ValueKey('error-avisos')), findsNothing);
  });
  // ── Paso al detalle ───────────────────────────────────────────────────────

  /// La bandeja dentro de un router, para poder abrir el detalle.
  Future<GoRouter> pumpConRouter(
    WidgetTester tester,
    FakeInteligenciaRepository repo,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/avisos',
      routes: [
        GoRoute(
          path: '/avisos',
          builder: (_, _) =>
              BandejaAvisosScreen(repository: repo, ahora: _ahora),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => DetalleAvisoScreen(
                aviso: state.extra is Aviso ? state.extra! as Aviso : null,
                avisoId: state.pathParameters['id'],
                repository: repo,
                ahora: _ahora,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/recargar',
          builder: (_, _) => const Scaffold(body: Text('destino /recargar')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('tocar un aviso abre su detalle con el objeto que ya se tiene', (
    tester,
  ) async {
    final aviso = _pagoNoAlcanza();
    final repo = _repo(enCurso: [aviso]);
    await pumpConRouter(tester, repo);

    await tester.tap(find.byKey(ValueKey('abrir-${aviso.id}')));
    await tester.pumpAndSettle();

    // El porqué solo está en el detalle.
    expect(find.byKey(const ValueKey('porque-aviso')), findsOneWidget);
    // Y no hizo falta pedirlo: la bandeja pasó el aviso.
    expect(repo.idsPedidos, isEmpty);
  });

  testWidgets('descartar desde el detalle deja el aviso fuera de la bandeja', (
    tester,
  ) async {
    final aviso = _pagoNoAlcanza();
    final repo = _repo(enCurso: [aviso, _presupuesto()]);
    await pumpConRouter(tester, repo);
    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('abrir-${aviso.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('descartar-detalle')));
    await tester.pumpAndSettle();

    // De vuelta en la bandeja, sin el aviso y sin recargar la lista.
    expect(repo.descartados, [aviso.id]);
    expect(find.byKey(ValueKey('aviso-${aviso.id}')), findsNothing);
    expect(find.text('Tu gasto va por encima de lo habitual'), findsOneWidget);
  });

  testWidgets('el botón de la tarjeta lleva al destino de su accion_codigo', (
    tester,
  ) async {
    final aviso = _pagoNoAlcanza();
    final router = await pumpConRouter(tester, _repo(enCurso: [aviso]));

    await tester.tap(find.byKey(ValueKey('accion-${aviso.id}')));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/recargar',
    );
  });

  // La tarjeta de accesibilidad pide que la bandeja aguante el tamaño de letra
  // del sistema al máximo y que sus botones se anuncien.
  group('accesibilidad', () {
    for (final ancho in [320.0, 360.0]) {
      testWidgets('a ${ancho.toInt()}x640 con letra 2.0 no hay desborde', (
        tester,
      ) async {
        await _pump(
          tester,
          _repo(
            enCurso: [_pagoNoAlcanza(), _presupuesto(), _categoriaSobreMedia()],
            anterior: [_caidaIngreso()],
          ),
          tamano: Size(ancho, 640),
          escala: 2,
          fuenteReal: true,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'a ${ancho.toInt()}x640 con letra 2.0 el cupo lleno no desborda',
        (tester) async {
          await _pump(
            tester,
            _repo(
              enCurso: [_pagoNoAlcanza()],
              resumen: _resumen(emitidos: 3, cupo: 3),
            ),
            tamano: Size(ancho, 640),
            escala: 2,
            fuenteReal: true,
            mostrarCupo: true,
          );

          expect(find.byKey(const Key('cupo-lleno')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('cada aviso y su descarte se anuncian por separado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final pago = _pagoNoAlcanza();
      final presupuesto = _presupuesto();
      await _pump(tester, _repo(enCurso: [pago, presupuesto]));

      // Abrir lleva el título: quien no ve la tarjeta sabe cuál abre.
      expect(
        find.bySemanticsLabel('${pago.titulo}. Ver el detalle'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('${presupuesto.titulo}. Ver el detalle'),
        findsOneWidget,
      );

      // Y descartar también: con dos avisos en pantalla, «Descartar» a secas
      // se oiría dos veces igual.
      expect(
        find.bySemanticsLabel('Descartar: ${pago.titulo}'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Descartar: ${presupuesto.titulo}'),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('descartar desde la etiqueta semántica quita el aviso', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final pago = _pagoNoAlcanza();
      final repo = _repo(enCurso: [pago]);
      await _pump(tester, repo);

      // Se toca por la etiqueta, que es por donde lo haría un lector de
      // pantalla, no por la llave del botón.
      await tester.tap(find.bySemanticsLabel('Descartar: ${pago.titulo}'));
      await tester.pumpAndSettle();

      expect(repo.descartados, [pago.id]);
      expect(find.byKey(ValueKey('aviso-${pago.id}')), findsNothing);
      semantica.dispose();
    });
  });
}

/// Error de red sin depender de dart:io, para que la prueba corra en web.
class SocketLikeError implements Exception {
  const SocketLikeError();
  @override
  String toString() => 'sin red';
}
