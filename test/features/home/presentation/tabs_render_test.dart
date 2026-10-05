import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/home/presentation/estadisticas_screen.dart';
import 'package:vera/features/home/presentation/perfil_tab.dart';
import 'package:vera/features/home/presentation/tarjetas_tab.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  testWidgets('estadísticas muestra Próximamente y ninguna cifra inventada',
      (tester) async {
    await _pump(tester, const EstadisticasScreen());
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsOneWidget);
    expect(find.textContaining('Nómina'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('tarjetas muestra Próximamente y ninguna tarjeta inventada',
      (tester) async {
    await _pump(tester, const TarjetasTab());
    expect(find.text('Mis Tarjetas'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsOneWidget);
    expect(find.textContaining('4417'), findsNothing);
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
