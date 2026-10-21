# Vera — Flutter App

## Stack

| Capa | Tecnología |
|---|---|
| Framework | Flutter 3.47.2 / Dart SDK ^3.12 |
| Estado | `setState` en widgets. `flutter_riverpod` 2.x + `riverpod_annotation` solo para el tema |
| Navegación | `go_router` 14.x con `MaterialApp.router` |
| Tipografía | `google_fonts` 6.x — Playfair Display (logo) |
| Tema | Material 3, **dark-only** (`ThemeMode.dark` forzado) |
| Org | `com.xisfo` |

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
├── main.dart                              # ProviderScope + runApp
├── app/
│   ├── app.dart                           # MaterialApp.router, dark-only
│   └── router.dart                        # GoRouter — todas las rutas
├── core/
│   ├── theme/
│   │   ├── app_theme.dart                 # AppColors, AppGradients, ThemeData
│   │   ├── theme_provider.dart            # AppThemeMode notifier (@riverpod)
│   │   └── theme_provider.g.dart          # generado — no editar
│   └── widgets/                           # componentes reutilizables globales
│       ├── auth_background.dart           # fondo oscuro con blobs de luz
│       ├── gradient_button.dart           # botón con gradiente de marca
│       ├── pin_pad.dart                   # PinDots + NumPad para PIN/OTP
│       ├── vera_animated_logo.dart        # logo animado (acordeón de tarjetas)
│       └── vera_logo.dart                 # logo texto simple
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── login_screen.dart          # LoginScreen, PinScreen
    │       ├── recovery_screen.dart       # Recuperación de cuenta
    │       ├── backup_codes_screen.dart   # Códigos de respaldo reales
    │       └── register_screen.dart       # RegisterScreen + OtpRegisterScreen
    └── home/
        └── presentation/
            ├── home_screen.dart           # saldo y movimientos reales
            ├── enviar_screen.dart         # envío de dinero
            ├── enviar_llave_screen.dart   # envío por llave Bre-B
            ├── recargar_screen.dart       # recarga con url_pago y sondeo
            ├── estadisticas_screen.dart   # Balance y movimientos reales, resto de muestra (WIP)
            └── tarjetas_tab.dart          # Datos de muestra (WIP)
```

### Convención para nuevas features

1. Crear carpeta `lib/features/<nombre>/`
2. Subdividir en `data/`, `domain/`, `presentation/` según complejidad
3. El estado local va con `setState`. Riverpod solo si hace falta un provider global
4. Agregar ruta en `lib/app/router.dart`
5. Correr `dart run build_runner build` solo si se crean providers con `@riverpod`

## Sistema de diseño

Todos los tokens están en `lib/core/theme/app_theme.dart`.

### AppColors — colores de marca

```dart
AppColors.background      // #07080F — fondo principal
AppColors.surface         // #0F1020 — superficie de cards
AppColors.surfaceVariant  // #161829 — inputs, chips
AppColors.gradientStart   // #7B5EA7 — violeta claro (inicio del gradiente)
AppColors.gradientMid     // #6C4FD9 — violeta medio
AppColors.gradientEnd     // #4B3BC4 — violeta oscuro
AppColors.accent          // #00D4FF — cyan
AppColors.accentGreen     // #00E5A0 — verde éxito
AppColors.error           // #FF5B79 — rojo
AppColors.textPrimary     // #FFFFFF
AppColors.textSecondary   // #8B8FAD
AppColors.textMuted       // #454761
AppColors.border          // #1E2038
AppColors.borderGlass     // rgba blanco al 15%
```

### AppGradients

```dart
AppGradients.brand         // gradiente horizontal #7B5EA7 → #4B3BC4
AppGradients.brandVertical // gradiente vertical
AppGradients.card          // gradiente oscuro para cards
```

### Widgets del sistema de diseño

| Widget | Uso |
|---|---|
| `AuthBackground` | Envuelve pantallas de auth; fondo con blobs de luz |
| `GradientButton` | CTA principal con gradiente y glow. Acepta `loading`, `icon`, `onPressed: null` para estado disabled |
| `PinDots` | Indicadores para PIN/OTP (`length`, `filled`) |
| `NumPad` | Teclado numérico circular con `onDigit`, `onDelete`, `onBiometric` |
| `VeraAnimatedLogo` | Logo completo con 3 tarjetas en acordeón + texto Playfair Display |
| `VeraCardIcon` | Icono compacto animado para sub-pantallas |

## Providers Riverpod (solo el tema)

Riverpod solo se usa para el tema. Si se agrega un provider, usar code generation con `@riverpod`:

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

Entry point: `/login` (sin landing page). Rutas actuales:

| Ruta | Widget | Extra |
|---|---|---|
| `/login` | `LoginScreen` | - |
| `/login/pin` | `PinScreen` | `String phone` |
| `/login/recovery` | `RecoveryScreen` | - |
| `/login/recovery/otp` | `RecoveryOtpScreen` | `Map {correo, challengeId}` |
| `/login/recovery/new-pin` | `NewPinScreen` | `String` (reset_token) |
| `/register` | `RegisterScreen` | - |
| `/register/backup-codes` | `BackupCodesScreen` | `List<String>` (códigos reales) |
| `/home` | `HomeScreen` | - |
| `/enviar` | `EnviarScreen` | - |
| `/enviar-llave` | `EnviarLlaveScreen` | - |
| `/recargar` | `RecargarScreen` | - |
| `/estadisticas` | `EstadisticasScreen` | - |

Todas las rutas fuera de `/login*` y `/register*` son privadas: sin sesión redirigen a `/login`.

Navegar con `context.go('/ruta')` (reemplaza) o `context.push('/ruta')` (apila).

## Flujo de autenticación

### Login (sin OTP intermedio)
1. `LoginScreen`: celular (+57, 10 dígitos)
2. `PinScreen`: contraseña de 8 a 64 caracteres en un campo oculto (`LoginRequest.contrasena`). El nombre y la ruta `/login/pin` se conservan. `NewPinScreen` (`/login/recovery/new-pin`) usa la misma regla. `NumPad` y `PinDots` siguen existiendo por las pantallas de OTP.

Cerrar sesión: el botón de Perfil llama a `AuthRepository.logout()` (Bearer y refresh token), borra tokens y perfil, y va a `/login`. El saludo del Home usa el nombre guardado.

Las pantallas reciben el repositorio por un parámetro opcional de constructor (por defecto el real) para pruebas con fakes.

Pendientes: N-17 (contexto de empresa en login), textos legales de consentimiento (decisión 2), salida del lado del servidor para N-6 (S8), biometría (SCRUM-81) y el supuesto del lote 0 de la contraseña de 8 a 64 (`openapi.yaml:1091-1097`), por confirmar con Santiago y Valeria.

### Registro
1. Selector de tipo: `_AccountType.persona` | `_AccountType.empresa`
2. Datos de contacto (campos distintos por tipo)
3. Identidad (documento personal o representante legal)
4. Contraseña (de 8 a 64 caracteres, barra de fortaleza) y casillas de consentimiento `tratamiento_datos` y `whatsapp_optin` (ambos `v1`), botón deshabilitado hasta marcar ambas
5. `_OtpRegisterScreen`: verificación de celular, reenvío por `POST /v1/auth/otp/resend` con el `challenge_id` vigente (el contador solo reinicia con 200)
6. `BackupCodesScreen` y luego `/login`

### Endpoints conectados

Ver `docs/conexion-backend-auth.md` y `docs/conexion-backend-nucleo.md`. Los tokens se guardan con `flutter_secure_storage` (nunca `SharedPreferences` en texto plano).

## Tema

La app usa **dark-only**. `AppTheme.dark` es el único tema activo en `app.dart`:

```dart
theme: AppTheme.dark,
darkTheme: AppTheme.dark,
themeMode: ThemeMode.dark,
```

El `theme_provider.dart` existe para futura funcionalidad pero actualmente no se consume.

## Reglas de código

- Se usa `setState` en widgets con estado local. Riverpod solo para el tema
- Los repositorios se inyectan por constructor y sus constructores sin argumentos deben seguir funcionando
- Sin comentarios salvo que el *por qué* no sea obvio
- Archivos `.g.dart` son generados — nunca editar manualmente
- Sin manejo de errores para casos que no pueden ocurrir
- Sin abstracciones prematuras — 3 líneas similares > helper innecesario

## Ramas del repositorio

| Rama | Propósito |
|---|---|
| `main` | Código estable / producción |
| `staging` | Validación previa a producción |
| `dev` | Integración de features (base de PRs) |
| `feat/*` | Features en desarrollo |

Flujo: `feat/*` → PR → `dev` → PR → `staging` → PR → `main`.

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
