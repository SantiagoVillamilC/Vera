import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/widgets/gradient_button.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

Future<({Color indicador, Color fondo})> _montarCargando(
  WidgetTester tester,
  ThemeData tema,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: const Scaffold(
        body: GradientButton(label: 'Entrar', onPressed: null, loading: true),
      ),
    ),
  );
  final indicador = tester.widget<CircularProgressIndicator>(
    find.byType(CircularProgressIndicator),
  );
  final caja = tester.widget<Container>(
    find.descendant(
      of: find.byType(GradientButton),
      matching: find.byType(Container),
    ),
  );
  final decoracion = caja.decoration! as BoxDecoration;
  return (indicador: indicador.color!, fondo: decoracion.color!);
}

void main() {
  testWidgets('en claro el indicador de carga se distingue del fondo', (
    tester,
  ) async {
    final r = await _montarCargando(tester, AppTheme.light);
    expect(_contraste(r.indicador, r.fondo), greaterThanOrEqualTo(3.0));
  });

  testWidgets('en oscuro el indicador de carga sigue blanco', (tester) async {
    final r = await _montarCargando(tester, AppTheme.dark);
    expect(r.indicador, Colors.white);
    expect(r.fondo, AppColors.surfaceVariant);
    expect(_contraste(r.indicador, r.fondo), greaterThanOrEqualTo(3.0));
  });
}
