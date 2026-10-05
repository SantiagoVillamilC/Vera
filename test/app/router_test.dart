import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vera/app/router.dart';
import 'package:vera/core/network/session_store.dart';

Iterable<String> _rutas(List<RouteBase> rutas, [String base = '']) sync* {
  for (final r in rutas.whereType<GoRoute>()) {
    final completa = r.path.startsWith('/')
        ? r.path
        : (base.endsWith('/') ? '$base${r.path}' : '$base/${r.path}');
    yield completa;
    yield* _rutas(r.routes, completa);
  }
}

void main() {
  test('el router no declara /login/otp', () {
    final router = buildRouter(SessionNotifier());
    addTearDown(router.dispose);
    final rutas = _rutas(router.configuration.routes).toList();
    expect(rutas, isNot(contains('/login/otp')));
  });

  test('el router conserva las rutas vigentes de login y recuperación', () {
    final router = buildRouter(SessionNotifier());
    addTearDown(router.dispose);
    final rutas = _rutas(router.configuration.routes).toList();
    expect(
      rutas,
      containsAll([
        '/login',
        '/login/pin',
        '/login/recovery',
        '/login/recovery/otp',
        '/login/recovery/new-pin',
        '/register',
        '/register/backup-codes',
        '/home',
        '/enviar',
        '/estadisticas',
      ]),
    );
  });
}
