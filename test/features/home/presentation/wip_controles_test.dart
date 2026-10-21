import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/network/session_store.dart';
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

void main() {
  group('Home', () {
    testWidgets('las celdas sin destino ya no se muestran', (tester) async {
      await _pumpHome(tester);

      for (final etiqueta in [
        'Pagar\nservicios',
        'Pedir\ntarjeta',
        'Mis\nclaves',
        'Remune-\nración',
      ]) {
        expect(find.text(etiqueta), findsNothing, reason: etiqueta);
      }
      expect(find.textContaining('WIP'), findsNothing);
    });

    testWidgets('las celdas conectadas siguen visibles y en una sola fila',
        (tester) async {
      await _pumpHome(tester);

      final etiquetas = ['Enviar\ndinero', 'Enviar por llave', 'Recargar'];
      for (final etiqueta in etiquetas) {
        expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
      }
      final fila = etiquetas
          .map(
            (e) => tester
                .getCenter(
                  find
                      .ancestor(
                        of: find.text(e),
                        matching: find.byType(GestureDetector),
                      )
                      .first,
                )
                .dy,
          )
          .toSet();
      expect(fila, hasLength(1));
    });

    testWidgets('Mis CVUs ya no se muestra', (tester) async {
      await _pumpHome(tester);

      expect(find.text('Mis CVUs'), findsNothing);
    });

    testWidgets('el micrófono central ya no se muestra', (tester) async {
      await _pumpHome(tester);

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.textContaining('copilot'), findsNothing);

      await tester.tap(find.text('Perfil'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('lo conectado se mantiene sin marcas', (tester) async {
      final session = FakeSessionStore()..pendingDeposit = 'dep-1';
      await _pumpHome(tester, session: session);

      expect(find.text('Tienes una recarga pendiente'), findsOneWidget);
      expect(find.text('Sin movimientos aún'), findsOneWidget);
      expect(find.textContaining('WIP'), findsNothing);
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
    testWidgets('la campana ya no se muestra', (tester) async {
      await _pump(
        tester,
        () => EnviarScreen(repository: FakeNucleoRepository()),
      );

      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byTooltip('(WIP)'), findsNothing);
      expect(find.textContaining('WIP'), findsNothing);
    });

    for (final (ancho, alto) in [(360.0, 640.0), (411.0, 914.0)]) {
      testWidgets('a $ancho dp el título del AppBar no desborda',
          (tester) async {
        await _pump(
          tester,
          () => EnviarScreen(repository: FakeNucleoRepository()),
          size: Size(ancho, alto),
          fuenteReal: true,
        );

        expect(tester.takeException(), isNull);
        final titulo = tester.getRect(find.text('Enviar dinero'));
        expect(titulo.left, greaterThanOrEqualTo(0));
        expect(titulo.right, lessThanOrEqualTo(ancho));
      });
    }
  });

  group('Perfil', () {
    testWidgets('las filas sin acción ya no se muestran', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: PerfilTab(session: FakeSessionStore())),
      );

      for (final etiqueta in [
        'Seguridad y PIN',
        'Mis documentos',
        'Cuentas bancarias',
        'Centro de ayuda',
        'Chat con soporte',
        'Términos y condiciones',
        'Política de privacidad',
      ]) {
        expect(find.text(etiqueta), findsNothing, reason: etiqueta);
      }
      expect(find.textContaining('WIP'), findsNothing);
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

    testWidgets('nombre y Cerrar sesión siguen visibles', (tester) async {
      final session = FakeSessionStore(
        profile: const SessionProfile(nombreCompleto: 'Ana Prueba'),
      );
      await _pump(tester, () => Scaffold(body: PerfilTab(session: session)));

      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
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
    testWidgets('el chip Agregar ya no se muestra', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: TarjetasTab(session: FakeSessionStore())),
      );

      expect(find.text('Agregar'), findsNothing);
      expect(find.textContaining('WIP'), findsNothing);
      expect(find.text('Mis Tarjetas'), findsOneWidget);
    });

    testWidgets('Estadísticas conserva Ver todos y pierde more_horiz',
        (tester) async {
      await _pump(
        tester,
        () => EstadisticasScreen(repository: FakeNucleoRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('WIP'), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.text('Ver todos'), findsOneWidget);
    });
  });
}
