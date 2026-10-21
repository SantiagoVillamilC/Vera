# Changelog

Todos los cambios notables de este proyecto están documentados aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

---

## [Unreleased] controles sin destino marcados (WIP)

### Added
- Insignia `WipBadge` en los controles sin destino o sin acción: cuatro accesos rápidos del Home (Pagar servicios, Pedir tarjeta, Mis claves, Remuneración), la pastilla "Mis CVUs", la campana de Enviar, las siete filas de menú de Perfil, el chip "Agregar" de Tarjetas y "Ver todos" y el menú de Estadísticas.
- Etiqueta semántica "en desarrollo" en los accesos rápidos sin destino.
- Pruebas de widget de las marcas, del `NumPad` y de la cuadrícula a 320x640 y 360x640 con escala de texto 1.0 y 1.3.

### Changed
- Estadísticas y Tarjetas muestran datos de muestra por decisión de Christian (D6): el contrato no tiene endpoint de estadísticas ni de tarjetas. El Balance de estadísticas y la lista de movimientos son reales.
- Los accesos rápidos sin destino ya no muestran el SnackBar "Próximamente" y no responden al toque. El micrófono y la pestaña de Copilot muestran "Vera copilot (WIP)".
- Las filas de Perfil sin acción pierden el chevrón y los subtítulos que prometían funciones inexistentes.
- La tecla biométrica del `NumPad` se oculta, con el mismo tamaño para no descentrar el 0, hasta que exista el callback (SCRUM-81).
- La altura de las celdas de accesos rápidos crece con la escala de texto. El título "Últimos Movimientos" se recorta con puntos suspensivos y la mini tarjeta no escala su texto, para evitar desbordes con escala 1.3.

---

## [Unreleased] home conectado: recarga y envío por llave

### Added
- Rutas privadas `/recargar` (`RecargarScreen`) y `/enviar-llave` (`EnviarLlaveScreen`). Sin sesión redirigen a `/login`.
- Acceso "Enviar por llave" en el home.
- Aviso "Tienes una recarga pendiente" en el home cuando `SessionStore` guarda un depósito pendiente. Lleva a `/recargar` y se relee al volver de una pantalla.
- Pruebas de router (rutas privadas) y del home (navegación, aviso y 320x640 sin desborde).

### Changed
- "Recargar" del home navega a `/recargar` y ya no muestra el SnackBar "Próximamente".
- La grilla de accesos rápidos pasa de 3 a 4 columnas. "Mis claves" usa un ícono de candado para no repetir la llave.
- `docs/conexion-backend-nucleo.md`: depósitos e interbancaria pasan de "Repo listo, UI pendiente" a conectados.

### No verificado
- Los builds de APK e iOS del CI con el plugin nativo `url_launcher` no se ejecutaron en el entorno de desarrollo.
- `ios/Podfile.lock` se actualiza con `pod install` en macOS.

---

## [Unreleased] auth conectado: contraseña, consentimientos, reenvío y cerrar sesión

### Added
- Registro con casillas de consentimiento `tratamiento_datos` y `whatsapp_optin`, ambos `v1`, y botón deshabilitado hasta marcar ambas.
- Reenvío de OTP por `POST /v1/auth/otp/resend` con el `challenge_id` vigente. El contador de 60 s reinicia solo con 200.
- Cerrar sesión conectado: `logout` con Bearer y refresh token, borra tokens y perfil, y vuelve a `/login`.
- Perfil de sesión (nombre o razón social y tipo de cuenta) guardado al iniciar sesión.
- Parámetro opcional de repositorio en las pantallas de auth, `HomeScreen` y `PerfilTab` para pruebas con fakes.

### Changed
- Login y reset piden una contraseña de 8 a 64 caracteres en un campo oculto. Las rutas `/login/pin` y `/login/recovery/new-pin` se conservan.
- Tras los códigos de respaldo se va a `/login`.
- El saludo del Home usa el nombre guardado.
- Mensajes de error de reenvío y límites de peticiones revisados en `mensajeDeError`.
- `docs/conexion-backend-auth.md` documenta ambos consentimientos con `v1` (antes solo `tratamiento_datos` con `v1.0`).

### Pendiente
- N-17: contexto de empresa en login.
- Textos legales de consentimiento (decisión 2): las etiquetas son cortas y neutras.
- Salida del lado del servidor para N-6 (S8).
- Biometría (SCRUM-81).
- Supuesto del lote 0 de la contraseña de 8 a 64 (`openapi.yaml:1091-1097`), por confirmar con Santiago y Valeria.

---

## [Unreleased] limpieza de código muerto, mocks y documentación

### Removed
- `OtpLoginScreen` y la ruta `/login/otp`: el login no tiene OTP intermedio.
- Códigos de respaldo de ejemplo en `BackupCodesScreen`.
- Cifras, movimientos, tarjeta y nombres inventados en `EstadisticasScreen`, `TarjetasTab` y `PerfilTab`.

### Changed
- `BackupCodesScreen` sin códigos reales muestra un error en español con un botón que va a `/login`.
- `EstadisticasScreen` y `TarjetasTab` muestran "Próximamente". `PerfilTab` muestra "Mi cuenta" sin datos de ejemplo.
- Documentación (`README.md`, `CLAUDE.md`, `AGENTS.md`, `docs/`) alineada con el código: rutas actuales, Flutter 3.47.2, `setState` con Riverpod solo para el tema, `idempotency_key` implementada y tabla de errores del núcleo reconstruida desde el contrato.

### Pendiente (lote de auth)
- `PinScreen` aún pide un PIN de 6 dígitos y el contrato exige una contraseña de 8 a 64 caracteres.
- El botón "Cerrar sesión" de Perfil aún no hace nada.

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
