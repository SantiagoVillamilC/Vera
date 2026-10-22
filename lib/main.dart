import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vera/app/app.dart';
import 'package:vera/app/splash_vera.dart';
import 'package:vera/core/network/session_store.dart';

Future<void> _cargarSesion() async {
  await appSession.load(
    defaultSessionStore,
    locked: await defaultSessionStore.requiresUnlock(),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // La sesión se carga detrás del splash; la app (y su router) se crea cuando ya está lista.
  runApp(
    ProviderScope(
      child: Arranque(preparar: _cargarSesion, app: () => const App()),
    ),
  );
}
