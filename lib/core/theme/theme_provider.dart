import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

/// Modo de tema elegido al compilar con `--dart-define=TEMA=claro|oscuro|sistema`.
const String _temaDeEntorno = String.fromEnvironment(
  'TEMA',
  defaultValue: 'oscuro',
);

/// Traduce el nombre de la bandera TEMA a un [ThemeMode].
///
/// Cualquier valor desconocido cae en oscuro, que es el modo de siempre.
ThemeMode modoDeTema(String nombre) => switch (nombre.trim().toLowerCase()) {
  'claro' => ThemeMode.light,
  'sistema' => ThemeMode.system,
  _ => ThemeMode.dark,
};

/// Única fuente de verdad del modo de tema. Arranca en el valor de TEMA.
@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => modoDeTema(_temaDeEntorno);

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setMode(ThemeMode mode) => state = mode;
}
