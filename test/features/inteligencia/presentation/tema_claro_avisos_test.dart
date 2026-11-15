import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/core/theme/app_theme.dart';
import 'package:vera/core/theme/paleta_vera.dart';
import 'package:vera/features/inteligencia/data/aviso.dart';
import 'package:vera/features/inteligencia/data/modelos.dart';
import 'package:vera/features/inteligencia/presentation/bandeja_avisos_screen.dart';
import 'package:vera/features/inteligencia/presentation/detalle_aviso_screen.dart';

import '../../home/presentation/cargar_roboto.dart';
import '../../home/presentation/fake_inteligencia.dart';

/// El reloj del escenario de demo: noviembre de 2026.
final _ahora = DateTime.utc(2026, 11, 19, 17);

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

Future<void> _montar(WidgetTester tester, Widget Function() pantalla) async {
  await cargarRoboto();
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => pantalla()),
      for (final ruta in ['/recargar', '/inteligencia', '/estadisticas'])
        GoRoute(
          path: ruta,
          builder: (_, _) => Scaffold(body: Text('destino $ruta')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light.copyWith(
        textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
      ),
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
    ),
  );
  await tester.pumpAndSettle();
}

/// Fondo del Scaffold de la pantalla montada.
Color _fondoDelScaffold(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;

void main() {
  testWidgets('la bandeja de avisos se arma en claro con fondo claro', (
    tester,
  ) async {
    final repo = FakeInteligenciaRepository(
      onResumen: (_) async => ResumenDelMes(
        mes: '2026-11',
        totalCentavos: BigInt.zero,
        categorias: const [],
        avisosEmitidos: 2,
        cupoAvisos: 3,
      ),
    );
    repo.onAvisos = (mes) async => mes == null ? [_pagoNoAlcanza()] : [];
    await _montar(
      tester,
      () => BandejaAvisosScreen(repository: repo, ahora: _ahora),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('Tus próximos pagos suman más que tu saldo'),
      findsOneWidget,
    );
    expect(_fondoDelScaffold(tester).computeLuminance(), greaterThan(0.5));

    final context = tester.element(find.byType(BandejaAvisosScreen));
    expect(context.paleta.esClara, isTrue);
    // El título se lee: texto oscuro sobre el fondo claro.
    final titulo = tester.widget<Text>(
      find.text('Tus próximos pagos suman más que tu saldo'),
    );
    expect(titulo.style!.color!.computeLuminance(), lessThan(0.2));
  });

  testWidgets('el detalle de un pago_no_alcanza se arma en claro', (
    tester,
  ) async {
    final aviso = _pagoNoAlcanza();
    await _montar(
      tester,
      () => DetalleAvisoScreen(
        aviso: aviso,
        avisoId: aviso.id,
        repository: FakeInteligenciaRepository(),
        ahora: _ahora,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('Tus próximos pagos suman más que tu saldo'),
      findsOneWidget,
    );
    expect(_fondoDelScaffold(tester).computeLuminance(), greaterThan(0.5));

    final boton = tester.widget<TextButton>(
      find.byKey(const ValueKey('accion-principal')),
    );
    final fondoBoton = boton.style!.backgroundColor!.resolve({})!;
    final tintaBoton = boton.style!.foregroundColor!.resolve({})!;
    // El botón principal conserva el azul de marca y su texto sigue legible.
    expect(fondoBoton.computeLuminance(), lessThan(0.2));
    expect(tintaBoton.computeLuminance(), greaterThan(0.8));
  });
}
