import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/format/pesos.dart';
import 'package:vera/core/network/error_messages.dart';
import 'package:vera/features/home/presentation/home_screen.dart';
import 'package:vera/features/home/presentation/movimientos_tab.dart';
import 'package:vera/features/nucleo/data/nucleo_repository.dart';

import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

/// La fuente por defecto de las pruebas (Ahem) mide cada letra como un
/// cuadrado, lo que provoca desbordes que no existen en el dispositivo. Para
/// medir el layout real se carga Roboto desde el SDK de Flutter.
Future<void> _cargarRoboto() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  final dir = '$raiz/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final peso in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('$dir/Roboto-$peso.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _pump(
  WidgetTester tester,
  FakeNucleoRepository repo, {
  Size size = const Size(800, 1600),
  Duration? offset,
  bool fuenteReal = false,
}) async {
  if (fuenteReal) await _cargarRoboto();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: fuenteReal ? ThemeData(fontFamily: 'Roboto') : null,
      home: HomeScreen(repository: repo, offsetLocal: offset),
    ),
  );
  await tester.pump();
}

/// Monta el Home dentro de un router con destinos de prueba para verificar a
/// dónde navegan los accesos rápidos.
Future<GoRouter> _pumpConRouter(
  WidgetTester tester, {
  FakeSessionStore? session,
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeNucleoRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomeScreen(
          repository: repo,
          session: session ?? FakeSessionStore(),
        ),
      ),
      for (final ruta in [
        '/enviar',
        '/recargar',
        '/enviar-llave',
        '/inteligencia',
        '/estadisticas',
        '/asistente',
      ])
        GoRoute(
          path: ruta,
          builder: (_, _) => Scaffold(body: Text('destino $ruta')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump();
  return router;
}

String _ubicacion(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('Recargar navega a /recargar sin SnackBar de Próximamente', (
    tester,
  ) async {
    final router = await _pumpConRouter(tester);

    await tester.tap(find.text('Recargar'));
    await tester.pumpAndSettle();

    expect(_ubicacion(router), '/recargar');
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final (llave, ruta) in [
    ('acceso_categorias', '/inteligencia'),
    ('acceso_estadisticas', '/estadisticas'),
  ]) {
    testWidgets('el acceso $llave navega a $ruta', (tester) async {
      final router = await _pumpConRouter(tester);

      await tester.tap(find.byKey(Key(llave)));
      await tester.pumpAndSettle();

      expect(_ubicacion(router), ruta);
    });
  }

  testWidgets('Historial de Vera reabre la conversación elegida en el chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HomeScreen(
            repository: FakeNucleoRepository(),
            session: FakeSessionStore(),
          ),
        ),
        GoRoute(
          path: '/asistente/historial',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop('conv-7'),
              child: const Text('elegir conversación'),
            ),
          ),
        ),
        GoRoute(
          path: '/asistente',
          builder: (_, state) => Text('chat-con-${state.extra}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('acceso_historial_vera')));
    await tester.pumpAndSettle();
    expect(find.text('elegir conversación'), findsOneWidget);

    await tester.tap(find.text('elegir conversación'));
    await tester.pumpAndSettle();

    expect(find.text('chat-con-conv-7'), findsOneWidget);
  });

  testWidgets('Enviar por llave navega a /enviar-llave', (tester) async {
    final router = await _pumpConRouter(tester);

    await tester.tap(find.byTooltip('Enviar por llave'));
    await tester.pumpAndSettle();

    expect(_ubicacion(router), '/enviar-llave');
  });

  testWidgets('sin depósito pendiente no hay aviso de recarga pendiente', (
    tester,
  ) async {
    await _pumpConRouter(tester);

    expect(find.text('Tienes una recarga pendiente'), findsNothing);
  });

  testWidgets('con depósito pendiente el aviso lleva a /recargar', (
    tester,
  ) async {
    final session = FakeSessionStore()..pendingDeposit = 'dep-1';
    final router = await _pumpConRouter(tester, session: session);

    expect(find.text('Tienes una recarga pendiente'), findsOneWidget);
    await tester.tap(find.text('Tienes una recarga pendiente'));
    await tester.pumpAndSettle();

    expect(_ubicacion(router), '/recargar');
  });

  testWidgets('el aviso desaparece al volver si el depósito ya no está', (
    tester,
  ) async {
    final session = FakeSessionStore()..pendingDeposit = 'dep-1';
    final router = await _pumpConRouter(tester, session: session);

    await tester.tap(find.text('Tienes una recarga pendiente'));
    await tester.pumpAndSettle();
    session.pendingDeposit = null;
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Tienes una recarga pendiente'), findsNothing);
  });

  testWidgets('a 320x640 con aviso pendiente no hay desborde de RenderFlex', (
    tester,
  ) async {
    await _cargarRoboto();
    await _pumpConRouter(
      tester,
      session: FakeSessionStore()..pendingDeposit = 'dep-1',
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('monta con una sola petición de saldo y una de movimientos', (
    tester,
  ) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);

    expect(repo.saldoCalls, 1);
    expect(repo.movimientosCalls, hasLength(1));
    expect(repo.movimientosCalls.single.limit, 3);
  });

  testWidgets('un build repetido no relanza la petición de movimientos', (
    tester,
  ) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);

    // Alternar la visibilidad del saldo reconstruye todo el árbol.
    await tester.tap(find.byKey(const Key('alternar_saldo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('alternar_saldo')));
    await tester.pump();

    expect(repo.movimientosCalls, hasLength(1));
    expect(repo.saldoCalls, 1);
  });

  testWidgets('un error del preview muestra mensaje y Reintentar, no vacío', (
    tester,
  ) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => throw const FormatException('malo');
    await _pump(tester, repo);

    expect(find.text(mensajeErrorGenerico), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Sin movimientos aún'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);

    repo.onMovimientos = (_, _) async => pagina([
      mov(1, [(MotivoLinea.deposito, 500000)]),
    ]);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(repo.movimientosCalls, hasLength(2));
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('Depósito'), findsOneWidget);
  });

  testWidgets('una lista vacía muestra el vacío sin Reintentar', (
    tester,
  ) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);

    expect(find.text('Sin movimientos aún'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('RefreshIndicator actualiza saldo y preview', (tester) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(repo.saldoCalls, 2);
    expect(repo.movimientosCalls, hasLength(2));
  });

  group('bloque de depósito de bajo monto', () {
    testWidgets('muestra tope mensual y disponible del mes', (tester) async {
      final repo = FakeNucleoRepository()
        ..onKyc = () async => KycEstado(
          producto: 'bajo_monto',
          estadoKyc: 'basico',
          topeMensual: BigInt.from(100000000),
          disponibleMes: BigInt.from(60000000),
        );
      await _pump(tester, repo);
      await tester.pump();

      expect(find.text('Depósito de bajo monto'), findsOneWidget);
      expect(find.text('Disponible del mes'), findsOneWidget);
      expect(find.text('Tope mensual'), findsOneWidget);
      expect(find.text(formatPesos(BigInt.from(60000000))), findsOneWidget);
      expect(find.text(formatPesos(BigInt.from(100000000))), findsOneWidget);
    });

    testWidgets(
      'sin límites del backend avisa que el cupo no está disponible',
      (tester) async {
        await _pump(tester, FakeNucleoRepository());
        await tester.pump();

        expect(find.text('Depósito de bajo monto'), findsOneWidget);
        expect(
          find.text('Tu cupo mensual aún no está disponible.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('otro producto no muestra el bloque', (tester) async {
      final repo = FakeNucleoRepository()
        ..onKyc = () async =>
            const KycEstado(producto: 'pleno', estadoKyc: 'verificado');
      await _pump(tester, repo);
      await tester.pump();

      expect(find.byKey(const Key('bloque_bajo_monto')), findsNothing);
    });

    testWidgets('si kyc/estado falla el Home sigue y el bloque no aparece', (
      tester,
    ) async {
      final repo = FakeNucleoRepository()
        ..onKyc = () async => throw const SocketException('sin red');
      await _pump(tester, repo);
      await tester.pump();

      expect(find.byKey(const Key('bloque_bajo_monto')), findsNothing);
      expect(find.textContaining(r'$'), findsWidgets);
    });

    testWidgets('deslizar hacia abajo vuelve a consultar el estado', (
      tester,
    ) async {
      final repo = FakeNucleoRepository();
      await _pump(tester, repo);
      await tester.pump();

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(repo.kycCalls, 2);
    });
  });

  testWidgets('cuenta sin movimientos muestra \$0 sin error', (tester) async {
    final repo = FakeNucleoRepository()
      ..onSaldo = () async => MontoCalculado(
        montoCentavos: BigInt.zero,
        moneda: 'COP',
        calculadoEn: DateTime.utc(2026),
      );
    await _pump(tester, repo);
    await tester.pump();

    // Los centavos van aparte y en gris, así que el saldo es un texto con estilos.
    expect(find.text('\$0,00', findRichText: true), findsOneWidget);
    expect(find.text('Error al cargar'), findsNothing);
  });

  testWidgets(
    'el botón central del micrófono se anuncia como Hablar con Vera',
    (tester) async {
      final semantica = tester.ensureSemantics();
      await _pump(tester, FakeNucleoRepository());

      expect(find.bySemanticsLabel('Hablar con Vera'), findsOneWidget);
      semantica.dispose();
    },
  );

  testWidgets('al volver del chat de Vera se refresca el saldo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeNucleoRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              HomeScreen(repository: repo, session: FakeSessionStore()),
        ),
        GoRoute(
          path: '/asistente',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('volver'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();
    final antes = repo.saldoCalls;

    await tester.tap(find.byKey(const Key('boton_vera')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('volver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repo.saldoCalls, antes + 1);
  });

  testWidgets('el acceso Historial abre la pestaña de movimientos', (
    tester,
  ) async {
    await _pump(tester, FakeNucleoRepository());
    expect(find.byType(MovimientosTab), findsNothing);

    await tester.tap(find.byTooltip('Historial'));
    await tester.pump();

    expect(find.byType(MovimientosTab), findsOneWidget);
  });

  testWidgets('Ver todos navega a la pestaña de movimientos', (tester) async {
    final repo = FakeNucleoRepository();
    await _pump(tester, repo);
    expect(find.byType(MovimientosTab), findsNothing);

    await tester.tap(find.text('Ver todos'));
    await tester.pump();

    expect(find.byType(MovimientosTab), findsOneWidget);
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
    expect(find.text('Devolución del GMF'), findsOneWidget);
    expect(find.text('+\$40'), findsOneWidget);
    expect(find.textContaining('-\$0'), findsNothing);
  });

  testWidgets('la fecha del preview usa la hora local', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        mov(1, [
          (MotivoLinea.deposito, 100000),
        ], ocurridoEn: DateTime.utc(2025, 3, 10, 2, 30)),
      ]);
    await _pump(tester, repo, offset: const Duration(hours: -8));

    expect(find.text('9 mar'), findsOneWidget);
    expect(find.text('10 mar'), findsNothing);
  });

  testWidgets('a 320x640 no hay desborde de RenderFlex', (tester) async {
    final repo = FakeNucleoRepository()
      ..onMovimientos = (_, _) async => pagina([
        movCompensado(1),
        mov(2, [(MotivoLinea.transferenciaRecibida, 2500000)]),
      ]);
    await _pump(tester, repo, size: const Size(320, 640), fuenteReal: true);

    expect(tester.takeException(), isNull);
  });

  testWidgets('el preview no se bloquea si el saldo falla', (tester) async {
    final completer = Completer<MovimientosPage>();
    final repo = FakeNucleoRepository()
      ..onSaldo = (() async => throw const FormatException('x'))
      ..onMovimientos = (_, _) => completer.future;
    await _pump(tester, repo);

    expect(find.text('Error al cargar'), findsOneWidget);
    // Los movimientos aún no llegan: se ve el esqueleto, no un spinner.
    expect(find.byKey(const Key('esqueleto_movimientos')), findsOneWidget);
  });
}
