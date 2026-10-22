import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/home/presentation/enviar_screen.dart';
import 'package:vera/features/home/presentation/home_screen.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';

import 'cargar_roboto.dart';
import 'fake_inteligencia.dart';
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
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
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
}) => _pump(
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
    testWidgets(
      'Enviar, Recargar, llave e Historial están en la tarjeta de saldo',
      (tester) async {
        await _pumpHome(tester);

        expect(find.text('Enviar'), findsOneWidget);
        expect(find.text('Recargar'), findsOneWidget);
        expect(find.byTooltip('Enviar por llave'), findsOneWidget);
        expect(find.byTooltip('Historial'), findsOneWidget);
      },
    );

    testWidgets('los accesos del Home son solo funciones que existen', (
      tester,
    ) async {
      await _pumpHome(tester);

      for (final etiqueta in ['Categorías', 'Estadísticas', 'Mis charlas']) {
        expect(find.text(etiqueta), findsOneWidget, reason: etiqueta);
      }
      // Hablar con Vera ya está abajo, en el orbe de la barra.
      expect(find.byKey(const Key('acceso_vera')), findsNothing);
      expect(find.text('Preguntar\na Vera'), findsNothing);
      for (final inexistente in [
        'Pagar\nservicios',
        'Pedir\ntarjeta',
        'Mis\nclaves',
        'Remune-\nración',
        'Mis CVUs',
      ]) {
        expect(find.text(inexistente), findsNothing, reason: inexistente);
      }
    });

    testWidgets('el orbe de Vera abre el asistente', (tester) async {
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
            path: '/asistente',
            builder: (_, _) => const Text('chat-asistente'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('boton_vera')));
      await tester.pumpAndSettle();

      expect(find.text('chat-asistente'), findsOneWidget);
    });

    testWidgets('el orbe se anuncia como Hablar con Vera', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(tester);

      expect(find.bySemanticsLabel('Hablar con Vera'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('con un depósito pendiente avisa y lo demás sigue igual', (
      tester,
    ) async {
      final session = FakeSessionStore()..pendingDeposit = 'dep-1';
      await _pumpHome(tester, session: session);

      expect(find.text('Tienes una recarga pendiente'), findsOneWidget);
      expect(find.text('Ver estado'), findsOneWidget);
      expect(find.text('Sin movimientos aún'), findsOneWidget);
    });

    for (final tam in [const Size(320, 640), const Size(360, 640)]) {
      for (final escala in [1.0, 1.3]) {
        testWidgets('sin overflow a ${tam.width.toInt()}x${tam.height.toInt()} '
            'con escala $escala y nombre largo', (tester) async {
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
        });
      }
    }
  });

  group('Enviar', () {
    testWidgets('ya no tiene una campana sin función', (tester) async {
      await _pump(
        tester,
        () => EnviarScreen(repository: FakeNucleoRepository()),
      );

      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.text('Enviar dinero'), findsOneWidget);
    });
  });

  group('Perfil', () {
    testWidgets('solo tiene filas con función', (tester) async {
      await _pump(
        tester,
        () => Scaffold(body: PerfilTab(session: FakeSessionStore())),
      );

      expect(find.byKey(const Key('borrar_historial_vera')), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      for (final inexistente in [
        'Seguridad y PIN',
        'Mis documentos',
        'Cuentas bancarias',
        'Centro de ayuda',
        'Chat con soporte',
        'Términos y condiciones',
        'Política de privacidad',
      ]) {
        expect(find.text(inexistente), findsNothing, reason: inexistente);
      }
    });

    testWidgets('muestra el nombre y las iniciales', (tester) async {
      final session = FakeSessionStore(
        profile: const SessionProfile(nombreCompleto: 'Ana Prueba'),
      );
      await _pump(tester, () => Scaffold(body: PerfilTab(session: session)));

      expect(find.text('Ana Prueba'), findsOneWidget);
      expect(find.text('AP'), findsOneWidget);
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
    testWidgets('Tarjetas ya no tiene el botón Agregar sin función', (
      tester,
    ) async {
      await _pump(
        tester,
        () => Scaffold(body: TarjetasTab(session: FakeSessionStore())),
      );

      expect(find.text('Agregar'), findsNothing);
      expect(find.textContaining('(WIP)'), findsNothing);
    });

    testWidgets('Estadísticas ya no tiene el botón de más opciones', (
      tester,
    ) async {
      await _pump(
        tester,
        () => EstadisticasScreen(
          repository: FakeNucleoRepository(),
          inteligencia: FakeInteligenciaRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.textContaining('(WIP)'), findsNothing);
    });
  });
}
