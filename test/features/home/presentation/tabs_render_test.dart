import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';

import 'fake_nucleo_repository.dart';
import 'fake_session_store.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  testWidgets('estadísticas se dibuja con datos de muestra y sin Próximamente',
      (tester) async {
    await _pump(
      tester,
      EstadisticasScreen(repository: FakeNucleoRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Datos de muestra (WIP)'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);
    expect(find.textContaining('Nómina'), findsNothing);
  });

  testWidgets('tarjetas se dibuja con datos de muestra y sin Próximamente',
      (tester) async {
    await _pump(tester, TarjetasTab(session: FakeSessionStore()));
    expect(find.text('Mis Tarjetas'), findsOneWidget);
    expect(find.text('Datos de muestra (WIP)'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);
    expect(find.textContaining('4417'), findsWidgets);
    expect(find.textContaining('Rappi'), findsNothing);
  });

  testWidgets('perfil no muestra nombres ni datos de ejemplo', (tester) async {
    await _pump(tester, const PerfilTab());
    expect(find.textContaining('Elisa'), findsNothing);
    expect(find.textContaining('310 234'), findsNothing);
    expect(find.textContaining('Desde 2024'), findsNothing);
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}
