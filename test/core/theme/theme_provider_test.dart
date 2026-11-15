import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vera/core/theme/theme_provider.dart';

void main() {
  group('modoDeTema', () {
    test('claro, oscuro y sistema se reconocen', () {
      expect(modoDeTema('claro'), ThemeMode.light);
      expect(modoDeTema('oscuro'), ThemeMode.dark);
      expect(modoDeTema('sistema'), ThemeMode.system);
    });

    test('no distingue mayúsculas ni espacios', () {
      expect(modoDeTema(' CLARO '), ThemeMode.light);
      expect(modoDeTema('Sistema'), ThemeMode.system);
    });

    test('un valor desconocido o vacío cae en oscuro', () {
      expect(modoDeTema(''), ThemeMode.dark);
      expect(modoDeTema('azul'), ThemeMode.dark);
    });
  });

  group('appThemeModeProvider', () {
    test('sin bandera TEMA arranca en oscuro, como la app de siempre', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(appThemeModeProvider), ThemeMode.dark);
    });

    test('setMode y toggle cambian el modo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(appThemeModeProvider, (_, _) {});
      c.read(appThemeModeProvider.notifier).setMode(ThemeMode.light);
      expect(c.read(appThemeModeProvider), ThemeMode.light);
      c.read(appThemeModeProvider.notifier).toggle();
      expect(c.read(appThemeModeProvider), ThemeMode.dark);
    });
  });
}
