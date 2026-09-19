# Changelog

Todos los cambios notables de este proyecto están documentados aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

---

## [Unreleased] — feat/auth-ui

### Added
- **Sistema de diseño** (`lib/core/theme/`)
  - `AppColors`: paleta completa oscura — fondos, superficies, gradientes de marca (`#7B5EA7 → #4B3BC4`), acentos cyan/verde, jerarquía de texto y bordes.
  - `AppGradients`: gradientes reutilizables `brand`, `brandVertical` y `card`.
  - `ThemeData` 100% oscuro con `InputDecoration`, `ElevatedButton`, `TextTheme` y `SnackBar` configurados.
  - Dependencia `google_fonts ^6.2.1` para tipografía **Playfair Display** (serif) en el logo.

- **Componentes compartidos** (`lib/core/widgets/`)
  - `AuthBackground`: fondo oscuro con blobs de luz radial (violeta y cyan).
  - `GradientButton`: botón con gradiente de marca, estado de carga y sombra glow.
  - `PinDots`: indicadores de puntos animados para PIN/OTP (escala + glow al rellenar).
  - `NumPad`: teclado numérico circular con feedback háptico y tecla biométrica.
  - `VeraAnimatedLogo`: logo completo con 3 tarjetas en animación **acordeón** (abanico continuo), entrada spring, levitación y tipografía Playfair Display.
  - `VeraCardIcon`: icono de tarjeta animado compacto para sub-pantallas.

- **Flujo de autenticación** (`lib/features/auth/presentation/`)
  - **Login — 3 pasos:**
    1. Ingreso de número de celular (+57, formato colombiano, validación 10 dígitos).
    2. PIN de 6 dígitos con teclado numérico custom y opción biométrica.
    3. Verificación OTP (6 dígitos vía WhatsApp) con contador de reenvío 60 s.
  - **Registro — 4 pasos + OTP:**
    1. Selector de tipo de cuenta: **Persona natural** / **Empresa** (tarjetas animadas).
    2. Datos de contacto (persona: nombre, correo, celular | empresa: razón social, NIT, correo, celular).
    3. Identidad (persona: tipo/número documento CC/CE/PA | empresa: representante legal completo).
    4. Contraseña con barra de fortaleza en tiempo real (Débil → Fuerte).
    5. Verificación OTP del celular post-submit.
  - Contratos de endpoint mapeados: `POST /auth/register`, `POST /auth/register/verify-phone`, `POST /auth/login`, `POST /auth/login/verify-otp`. Llamadas API y token storage marcadas con `// TODO`.

- **Navegación** (`lib/app/router.dart`)
  - Entry point: `/login` (sin landing page).
  - Rutas anidadas: `/login/pin`, `/login/otp`, `/register`, `/home`.

### Changed
- `lib/core/theme/app_theme.dart`: reescrito desde cero con la paleta de marca Vera (fondo `#07080F`, gradiente violeta, acentos cyan/verde).
- `lib/main.dart`: simplificado a `ProviderScope + App`.
- `pubspec.yaml`: agregado `google_fonts ^6.2.1`.

### Removed
- Scaffolding inicial: `auth_service`, `login_screen`, `pin_screen`, `register_screen` (versiones placeholder).
- Features stub: `copilot/`, `receipts/`, `transfers/`, `wallets/`.
- Core antiguo: `app_colors.dart`, `app_typography.dart`, `error_banner.dart`, `loading_indicator.dart`, `primary_button.dart`.
- Red antigua: `api_client.dart`, `api_exception.dart`.
- Auth utils: `dynamic_key.dart`, `pin_storage.dart`, `token_storage.dart`.

---

## [0.1.0] — 2026-09-17 — Initial scaffold

### Added
- Estructura inicial del proyecto Flutter (`flutter create`).
- Dependencias base: `flutter_riverpod`, `riverpod_annotation`, `go_router`.
- Dev dependencies: `riverpod_generator`, `build_runner`, `custom_lint`.
- `CLAUDE.md` con arquitectura feature-first, comandos esenciales y convenciones de código.
- Soporte multi-plataforma: iOS, Android, macOS, Linux, Windows, Web.
