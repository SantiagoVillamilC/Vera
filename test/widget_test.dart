import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/app/app.dart';
import 'package:vera/core/network/session_store.dart';
import 'package:vera/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('App con sesion renders home screen', (WidgetTester tester) async {
    appSession.setAuthenticated(true);
    addTearDown(() => appSession.setAuthenticated(false));
    await tester.pumpWidget(
      const ProviderScope(child: App()),
    );
    // El home muestra un indicador de carga animado mientras consulta el
    // saldo, por lo que pumpAndSettle nunca termina. Se avanza un tiempo fijo.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
