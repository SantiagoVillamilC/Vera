# Vera — Billetera Digital

Aplicación móvil de billetera digital para Colombia. Construida con Flutter.

---

## Requisitos del sistema

| Herramienta | Versión mínima | Notas |
|---|---|---|
| Flutter | 3.47.2 | SDK incluido con Dart |
| Dart | 3.12+ | Incluido con Flutter |
| Xcode | 16+ | Solo para iOS/macOS |
| Android Studio / SDK | API 21+ | Solo para Android |
| CocoaPods | 1.15+ | Solo para iOS/macOS |
| Node.js | — | No requerido |

Verificar instalación:

```bash
flutter doctor -v
```

Todos los ítems deben estar en verde antes de continuar.

---

## Clonar el repositorio

```bash
git clone git@github.com:SantiagoVillamilC/Vera.git
cd Vera
```

---

## Instalar dependencias

```bash
flutter pub get
```

Esto instala todos los paquetes listados en `pubspec.yaml`, incluyendo:

| Paquete | Versión | Uso |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | Manejo de estado |
| `riverpod_annotation` | ^2.6.1 | Anotaciones para code gen |
| `go_router` | ^14.6.1 | Navegación declarativa |
| `google_fonts` | ^6.2.1 | Fuente Playfair Display (logo) |

**Dev dependencies** (code generation):

| Paquete | Uso |
|---|---|
| `riverpod_generator` | Genera providers desde anotaciones `@riverpod` |
| `build_runner` | Runner de generación de código |
| `custom_lint` | Reglas de lint para Riverpod |

---

## Generación de código

Después de clonar o al crear/modificar cualquier provider con `@riverpod`, ejecutar:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Para desarrollo continuo (modo watch):

```bash
dart run build_runner watch --delete-conflicting-outputs
```

> Los archivos `.g.dart` son generados automáticamente — **no editar manualmente**.

---

## Correr la aplicación

### Listar dispositivos disponibles

```bash
flutter devices
flutter emulators
```

### iOS (Simulador)

```bash
# Arrancar el simulador primero
open -a Simulator

# Correr en iPhone 17 Pro (ID por defecto del proyecto)
flutter run -d C27183E2-4101-4121-9F96-55E687DA80C8

# O en cualquier simulador disponible
flutter run -d <device-id>
```

### Android (Emulador o dispositivo físico)

```bash
# Verificar que el emulador esté corriendo
flutter emulators --launch <emulator-id>

flutter run -d <device-id>
```

### macOS (desktop)

```bash
flutter run -d macos
```

### Web

```bash
flutter run -d chrome
```

---

## Análisis estático y tests

```bash
# Análisis estático (debe retornar "No issues found")
flutter analyze

# Tests unitarios
flutter test

# Tests con cobertura
flutter test --coverage
```

---

## Estructura del proyecto

```
lib/
├── main.dart                              # Entry point — ProviderScope + runApp
├── app/
│   ├── app.dart                           # MaterialApp.router, tema dark-only
│   └── router.dart                        # GoRouter — todas las rutas
├── core/
│   ├── theme/
│   │   ├── app_theme.dart                 # AppColors, AppGradients, ThemeData
│   │   ├── theme_provider.dart            # Notifier de ThemeMode (@riverpod)
│   │   └── theme_provider.g.dart          # Generado — no editar
│   └── widgets/
│       ├── auth_background.dart           # Fondo oscuro con blobs de luz
│       ├── gradient_button.dart           # Botón con gradiente de marca
│       ├── pin_pad.dart                   # Teclado numérico y dots de PIN
│       ├── vera_animated_logo.dart        # Logo animado (acordeón de tarjetas)
│       └── vera_logo.dart                 # Logo texto simple
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── login_screen.dart          # LoginScreen, PinScreen
    │       ├── recovery_screen.dart       # Recuperación de cuenta
    │       ├── backup_codes_screen.dart   # Códigos de respaldo del registro
    │       └── register_screen.dart       # Persona/Empresa, 4 pasos + OTP
    └── home/
        └── presentation/
            ├── home_screen.dart           # Inicio con saldo y movimientos reales
            ├── enviar_screen.dart         # Envío de dinero
            ├── estadisticas_screen.dart   # Próximamente
            └── tarjetas_tab.dart          # Próximamente
```

---

## Rutas de navegación

| Ruta | Pantalla | Descripción |
|---|---|---|
| `/login` | `LoginScreen` | Ingreso de número de celular |
| `/login/pin` | `PinScreen` | PIN de 6 dígitos |
| `/login/recovery` | `RecoveryScreen` | Recuperación de cuenta (correo) |
| `/login/recovery/otp` | `RecoveryOtpScreen` | Código OTP y código de respaldo |
| `/login/recovery/new-pin` | `NewPinScreen` | Nueva contraseña con `reset_token` |
| `/register` | `RegisterScreen` | Registro multi-paso |
| `/register/backup-codes` | `BackupCodesScreen` | Códigos de respaldo reales (`extra`: `List<String>`) |
| `/home` | `HomeScreen` | Inicio (post-autenticación) |
| `/enviar` | `EnviarScreen` | Envío de dinero |
| `/estadisticas` | `EstadisticasScreen` | Próximamente |

El login no tiene OTP intermedio: celular y luego `PinScreen`. Hoy `PinScreen` pide un PIN de 6 dígitos en pantalla, pero el contrato (`openapi.yaml`, `LoginRequest.contrasena`) exige una contraseña de 8 a 64 caracteres. Ese cambio de pantalla está pendiente y es del lote de auth.

---

## Configurar la URL del backend

La app se conecta al backend mediante la variable de compilación `API_BASE_URL`. Hay varias formas de configurarla según el entorno:

### Emulador Android
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

### Dispositivo físico o simulador iOS
Reemplaza `IP_LOCAL` con la IP de tu computadora en la red local:
```bash
flutter run --dart-define=API_BASE_URL=http://IP_LOCAL:8080
```

### Alternativa: adb reverse (Android)
Si prefieres usar `localhost` en un dispositivo físico Android:
```bash
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

**Valor por defecto:** `http://localhost:8080` (desarrollo local).

> Nota: La producción (veraapp.tech) aún corre la versión V0 del API sin el núcleo financiero.

---

## Variables de entorno / Configuración pendiente

Los siguientes valores deben configurarse antes de conectar el backend:

| Variable | Descripción |
|---|---|
| Tokens JWT | Se guardan con `flutter_secure_storage` (implementado en `AuthRepository`) |
| Biometría | Integrar `local_auth` para desbloqueo con huella |

> Cerrar sesión está pendiente: el botón de Perfil aún no hace nada (la lógica existe en `AuthRepository.logout()`, falta conectarla en el lote de auth). Estadísticas y Tarjetas muestran "Próximamente" porque no tienen contrato en el backend.

---

## Ramas del repositorio

| Rama | Propósito |
|---|---|
| `main` | Código estable / producción |
| `staging` | Validación previa a producción |
| `dev` | Integración de features |
| `feat/auth-ui` | UI de autenticación (activa) |

El flujo de trabajo es: `feat/*` → PR → `dev` → PR → `staging` → PR → `main`.

---

## Convenciones de código

- Se usa `setState` en los widgets con estado local. Riverpod solo se usa para el tema (`theme_provider`)
- Los repositorios se inyectan por constructor y sus constructores sin argumentos deben seguir funcionando
- Sin comentarios salvo que el *por qué* no sea obvio
- Archivos `.g.dart` son generados — nunca editar
- Feature-first: cada feature vive en `lib/features/<nombre>/`
