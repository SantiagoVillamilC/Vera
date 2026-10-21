import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/features/auth/presentation/backup_codes_screen.dart';

Future<GoRouter> _pump(WidgetTester tester, Widget pantalla) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(path: '/inicio', builder: (_, _) => pantalla),
      GoRoute(path: '/login', builder: (_, _) => const Text('PANTALLA_LOGIN')),
      GoRoute(path: '/home', builder: (_, _) => const Text('PANTALLA_HOME')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  return router;
}

void main() {
  testWidgets('sin códigos muestra un error claro y ningún código de ejemplo', (
    tester,
  ) async {
    await _pump(tester, const BackupCodesScreen());
    expect(find.textContaining('VERA-'), findsNothing);
    expect(
      find.textContaining('No pudimos mostrar tus códigos'),
      findsOneWidget,
    );
    expect(find.text('Ir a iniciar sesión'), findsOneWidget);
    expect(find.text('Ir a mi cuenta'), findsNothing);
  });

  testWidgets('el botón del error va a /login con go', (tester) async {
    await _pump(tester, const BackupCodesScreen());
    await tester.tap(find.text('Ir a iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA_LOGIN'), findsOneWidget);
  });

  testWidgets('con códigos reales los muestra', (tester) async {
    await _pump(
      tester,
      const BackupCodesScreen(codes: ['AAAA-1111', 'BBBB-2222']),
    );
    expect(find.text('AAAA-1111'), findsOneWidget);
    expect(find.text('BBBB-2222'), findsOneWidget);
    expect(find.textContaining('No pudimos mostrar tus códigos'), findsNothing);
  });

  testWidgets('tras confirmar los códigos la app va a /login y no a /home', (
    tester,
  ) async {
    await _pump(
      tester,
      const BackupCodesScreen(codes: ['AAAA-1111', 'BBBB-2222']),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Ir a iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA_LOGIN'), findsOneWidget);
    expect(find.text('Ir a mi cuenta'), findsNothing);
  });
}
