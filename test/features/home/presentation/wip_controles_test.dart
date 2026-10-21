import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/core/widgets/wip_badge.dart';
import 'package:vera/features/home/presentation/enviar_screen.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/home_screen.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';

import 'cargar_roboto.dart';
import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

const _nombreLargo =
    'Maria de los Angeles Fernandez Rodriguez de la Torre Montoya';

Future<void> _pump(
  WidgetTester tester,
  Widget Function() home, {
  Size size = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
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
      home: home(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpHome(
  WidgetTester tester, {
  FakeSessionStore? session,
  Size size = const Size(800, 1600),
  double escala = 1,
  bool fuenteReal = false,
}) =>
    _pump(
      tester,
      () => HomeScreen(
        repository: FakeNucleoRepository(),
        session: session ?? FakeSessionStore(),
      ),
      size: size,
      escala: escala,
      fuenteReal: fuenteReal,
    );

/// Insignias dentro de la celda que contiene [etiqueta].
Finder _insigniaDeCelda(String etiqueta) => find.descendant(
      of: find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(GestureDetector),
      ).first,
      matching: find.byType(WipBadge),
    );

void main() {
  group('Home', () {
    testWidgets('las 4 celdas sin destino llevan (WIP)', (tester) async {
      await _pumpHome(tester);

      for (final etiqueta in [
        'Pagar\nservicios',
        'Pedir\ntarjeta',
        'Mis\nclaves',
        'Remune-\nración',
      ]) {
        expect(_insigniaDeCelda(etiqueta), findsOneWidget, reason: etiqueta);
      }
    });

    testWidgets('las celdas conectadas no llevan (WIP)', (tester) async {
      await _pumpHome(tester);

      for (final etiqueta in [
        'Enviar\ndinero',
        'Enviar por llave',
        'Recargar',
      ]) {
        expect(_insigniaDeCelda(etiqueta), findsNothing, reason: etiqueta);
      }
    });

    testWidgets('la celda en desarrollo tiene etiqueta semántica',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(tester);

      expect(
        find.bySemanticsLabel('Pagar servicios, en desarrollo'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('tocar una celda en desarrollo no muestra Próximamente',
        (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.text('Pagar\nservicios'));
      await tester.pump();

      expect(find.text('Próximamente'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Mis CVUs lleva (WIP)', (tester) async {
      await _pumpHome(tester);

      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Mis CVUs'),
            matching: find.byType(Row),
          ).first,
          matching: find.byType(WipBadge),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el micrófono abre el asistente', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HomeScreen(
            repository: FakeNucleoRepository(),
            session: FakeSessionStore(),
          ),
        ),
        GoRoute(path: '/asistente', builder: (_, _) => const Text('chat-asistente')),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.mic_rounded).last);
      await tester.pumpAndSettle();

      expect(find.text('chat-asistente'), findsOneWidget);
    });

    testWidgets('lo conectado no lleva (WIP)', (tester) async {
      final session = FakeSessionStore()..pendingDeposit = 'dep-1';
      await _pumpHome(tester, session: session);

      expect(find.text('Tienes una recarga pendiente'), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Tienes una recarga pendiente'),
            matching: find.byType(InkWell),
          ).first,
          matching: find.byType(WipBadge),
        ),
        findsNothing,
      );
      expect(find.text('Sin movimientos aún'), findsOneWidget);
      // 4 celdas + Mis CVUs, nada más en el Inicio.
      expect(find.byType(WipBadge), findsNWidgets(5));
    });

    for (final tam in [const Size(320, 640), const Size(360, 640)]) {
      for (final escala in [1.0, 1.3]) {
        testWidgets(
          'cuadrícula sin overflow a ${tam.width.toInt()}x${tam.height.toInt()} '
          'con escala $escala y nombre largo',
          (tester) async {
            await _pumpHome(
              tester,
              session: FakeSessionStore(
                profile: const SessionProfile(nombreCompleto: _nombreLargo),
              ),
              size: tam,
              escala: escala,
              fuenteReal: true,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Enviar', () {
    testWidgets('la campana lleva (WIP) con tooltip', (tester) async {
      await _pump(
        tester,
        () => EnviarScreen(repository: FakeNucleoRepository()),
      );

      expect(find.byType(WipBadge), findsOneWidget);
      expect(find.byTooltip('(WIP)'), findsOneWidget);
    });

    for (final (ancho, alto) in [(360.0, 640.0), (411.0, 914.0)]) {
      testWidgets(
        'a $ancho dp la insignia no se recorta ni tapa la campana ni el título',
        (tester) async {
          await _pump(
            tester,
            () => EnviarScreen(repository: FakeNucleoRepository()),
            size: Size(ancho, alto),
            fuenteReal: true,
          );

          final insignia = tester.getRect(find.byType(WipBadge));
          final campana = tester.getRect(
            find.byIcon(Icons.notifications_outlined),
          );
          final titulo = tester.getRect(find.text('Enviar dinero'));

          expect(tester.takeException(), isNull);
          expect(insignia.left, greaterThanOrEqualTo(0));
          expect(insignia.top, greaterThanOrEqualTo(0));
          expect(insignia.right, lessThanOrEqualTo(ancho));
          expect(insignia.bottom, lessThanOrEqualTo(alto));
          expect(insignia.overlaps(campana), isFalse);
          expect(insignia.overlaps(titulo), isFalse);
        },
      );
    }
  });

  group('Perfil', () {
    testWidgets('las 7 filas sin acción llevan (WIP)', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: PerfilTab(session: FakeSessionStore())),
      );

      expect(find.byType(WipBadge), findsNWidgets(7));
    });

    testWidgets('los subtítulos no prometen funciones inexistentes',
        (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: PerfilTab(session: FakeSessionStore())),
      );

      expect(find.text('Cambiar PIN, biométrico'), findsNothing);
      expect(find.text('CC, fotos verificadas'), findsNothing);
      expect(find.text('Bancos vinculados'), findsNothing);
    });

    testWidgets('nombre y Cerrar sesión no llevan (WIP)', (tester) async {
      final session = FakeSessionStore(
        profile: const SessionProfile(nombreCompleto: 'Ana Prueba'),
      );
      await _pump(tester, () => Scaffold(body: PerfilTab(session: session)));

      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(WipBadge),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Ana Prueba'),
            matching: find.byType(Container),
          ).first,
          matching: find.byType(WipBadge),
        ),
        findsNothing,
      );
    });

    testWidgets('a 320x640 con escala 1.3 no hay overflow', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: PerfilTab(session: FakeSessionStore())),
        size: const Size(320, 640),
        escala: 1.3,
        fuenteReal: true,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Tarjetas y Estadísticas', () {
    testWidgets('el chip Agregar lleva (WIP)', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: TarjetasTab(session: FakeSessionStore())),
      );

      expect(find.text('Agregar'), findsOneWidget);
      expect(find.byType(WipBadge), findsOneWidget);
    });

    testWidgets('Ver todos y more_horiz llevan (WIP)', (tester) async {
      await _pump(
        tester,
        () => EstadisticasScreen(repository: FakeNucleoRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WipBadge), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Ver todos'),
            matching: find.byType(Row),
          ).first,
          matching: find.byType(WipBadge),
        ),
        findsOneWidget,
      );
    });
  });
}
