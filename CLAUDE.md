# Vera — Flutter App

## Stack

- **Flutter** + Dart SDK ^3.12
- **State management**: `flutter_riverpod` 2.x con code generation (`riverpod_annotation` + `riverpod_generator`)
- **Navegación**: `go_router` 14.x con `MaterialApp.router`
- **UI**: Material 3 (`useMaterial3: true`), tema claro/oscuro
- **Org**: `com.xisfo`

## Comandos esenciales

```bash
# Correr en simulador iOS (iPhone 17 Pro)
flutter run -d C27183E2-4101-4121-9F96-55E687DA80C8

# Correr en Android o macOS
flutter run -d <device-id>        # ver IDs: flutter devices

# Regenerar código Riverpod (obligatorio tras agregar/modificar providers)
dart run build_runner build --delete-conflicting-outputs

# Modo watch durante desarrollo
dart run build_runner watch --delete-conflicting-outputs

# Análisis estático
flutter analyze

# Tests
flutter test
flutter test --coverage            # con cobertura LCOV

# Listar dispositivos disponibles
flutter devices
flutter emulators
```

## Estructura de carpetas (feature-first)

```
lib/
├── main.dart                         # ProviderScope + runApp
├── app/
│   ├── app.dart                      # MaterialApp.router, consume AppThemeMode
│   └── router.dart                   # GoRouter — todas las rutas van aquí
├── core/
│   └── theme/
│       ├── app_theme.dart            # ThemeData light/dark (seed: Colors.indigo)
│       ├── theme_provider.dart       # AppThemeMode notifier (@riverpod)
│       └── theme_provider.g.dart     # generado — no editar
└── features/
    └── <feature>/
        ├── data/                     # repositorios, fuentes de datos, modelos
        ├── domain/                   # entidades, casos de uso (opcional)
        └── presentation/             # screens, widgets, providers de UI
```

### Convención para nuevas features

1. Crear carpeta `lib/features/<nombre>/`
2. Subdividir en `data/`, `domain/`, `presentation/` según complejidad
3. Providers Riverpod van en `presentation/` (providers de UI) o `data/` (providers de repositorio)
4. Agregar ruta en `lib/app/router.dart`
5. Correr `dart run build_runner build` tras crear providers

## Providers Riverpod

Usar siempre code generation con `@riverpod`:

```dart
// lib/features/home/presentation/counter_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'counter_provider.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;
  void increment() => state++;
}
```

El provider generado se llama `counterProvider`. Para leerlo: `ref.watch(counterProvider)`.

## Navegación (go_router)

Todas las rutas se declaran en `lib/app/router.dart`. Usar `context.go('/ruta')` para navegar, `context.push('/ruta')` para apilar.

## Tema

El notifier `AppThemeMode` (en `core/theme/theme_provider.dart`) controla el `ThemeMode` global:
- `ref.read(appThemeModeProvider.notifier).toggle()` — alterna light/dark
- `ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark)` — fuerza modo

## Reglas de código

- Sin comentarios salvo que el WHY no sea obvio
- Sin `setState` — usar Riverpod
- Widgets sin estado → `ConsumerWidget`; con estado local → `ConsumerStatefulWidget`
- Archivos `.g.dart` son generados — nunca editar manualmente
- No agregar manejo de errores para casos que no pueden ocurrir

## Skills disponibles

Las siguientes skills de Flutter están configuradas en `.claude/skills/`:

| Skill | Uso |
|---|---|
| `dart-add-unit-test` | Escribir unit tests |
| `dart-collect-coverage` | Generar reporte de cobertura |
| `dart-fix-runtime-errors` | Depurar errores en tiempo de ejecución |
| `dart-generate-test-mocks` | Crear mocks con mockito |
| `dart-resolve-package-conflicts` | Resolver conflictos de versiones |
| `dart-run-static-analysis` | Análisis estático + auto-fix |
| `dart-use-pattern-matching` | Aplicar pattern matching de Dart 3 |
| `dart-use-primary-constructors` | Sintaxis de constructores modernos |
| `flutter-add-integration-test` | Tests de integración con `integration_test` |
| `flutter-add-widget-preview` | Previews interactivos de widgets |
| `flutter-add-widget-test` | Tests de UI con `WidgetTester` |
| `flutter-apply-architecture-best-practices` | Arquitectura en capas |
| `flutter-build-responsive-layout` | Layouts adaptativos |
| `flutter-fix-layout-issues` | Corregir overflow y constraints |
| `flutter-implement-json-serialization` | Modelos JSON (`fromJson`/`toJson`) |
| `flutter-use-http-package` | Cliente HTTP REST |
