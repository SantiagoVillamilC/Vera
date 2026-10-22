import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vera/app/app.dart';
import 'package:vera/core/network/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appSession.load(
    defaultSessionStore,
    locked: await defaultSessionStore.requiresUnlock(),
  );
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
