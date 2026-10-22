import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/features/asistente/data/asistente_repository.dart';
import 'package:vera/features/asistente/presentation/accion_card.dart';

AccionPendiente _accion(
  EstadoAccion estado, {
  Duration vence = const Duration(minutes: 5),
}) => AccionPendiente(
  id: 'a1',
  estado: estado,
  tipo: TipoAccion.transferenciaInterna,
  destinatario: const DestinatarioAccion(
    nombre: 'Laura R.',
    celularParcial: '******4321',
  ),
  montoCentavos: BigInt.from(15000000),
  moneda: 'COP',
  requiereCodigo: true,
  expiraEn: DateTime.now().add(vence),
);

Future<void> _pump(WidgetTester t, AccionPendiente a) => t.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: AccionCard(
        accion: a,
        repo: AsistenteRepository(),
        onActualizada: (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('pendiente muestra monto, destinatario y botones', (t) async {
    await _pump(t, _accion(EstadoAccion.pendiente));
    expect(find.text('\$150.000'), findsOneWidget);
    expect(find.textContaining('Laura R.'), findsOneWidget);
    expect(find.text('Confirmar con código'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('confirmada no ofrece botones', (t) async {
    await _pump(t, _accion(EstadoAccion.confirmada));
    expect(find.text('Enviada'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('pendiente ya vencida no ofrece botones', (t) async {
    await _pump(
      t,
      _accion(EstadoAccion.pendiente, vence: const Duration(seconds: -1)),
    );
    expect(find.text('Cancelar'), findsNothing);
  });
}
