# Correcciones Auth UI — Vera

Documento de trazabilidad entre el esquema de base de datos de autenticación y la UI de Flutter.

---

## Contexto

Se revisó el diagrama ER del esquema `auth` de la base de datos y se identificaron 5 discrepancias
con la implementación inicial del front-end. Todas fueron corregidas en la rama `feat/auth-corrections`.

---

## Correcciones aplicadas

### 1. Campo `nacida_en` en `auth.personas`

**Tabla afectada:** `auth.personas`  
**Campo:** `nacida_en DATE`

**Problema:** El paso de identidad del registro para personas naturales no incluía el campo de fecha de nacimiento.

**Corrección aplicada:**
- Archivo: `lib/features/auth/presentation/register_screen.dart`
- Agregado `_nacidaEnCtrl` como `TextEditingController` en `_RegisterScreenState`.
- Agregado en `dispose()`.
- Pasado a `_PersonaIdentityStep` vía parámetro `nacidaEnCtrl`.
- `_PersonaIdentityStep` renderiza el campo con un `GestureDetector` que abre `DatePicker` (rango 1900–hoy).
- El valor se formatea como `YYYY-MM-DD` antes de enviarse al backend.

---

### 2. Campo `terminos_version` en `auth.consentimientos`

**Tabla afectada:** `auth.consentimientos`  
**Campo:** `texto_id` (FK a `auth.textos_consentimiento.version`)

**Problema:** El paso de contraseña en el registro no informaba al usuario la versión de los Términos y Condiciones que estaba aceptando, ni enviaba ese dato al backend.

**Corrección aplicada:**
- Archivo: `lib/features/auth/presentation/register_screen.dart`
- Agregado `_termsVersion = 'v1.0'` como campo de estado.
- Pasado a `_PasswordStep` vía parámetro `termsVersion`.
- `_PasswordStep` muestra un banner informativo con la versión vigente (`Términos y Condiciones — v1.0`).
- El valor debe incluirse en el payload de `POST /auth/register`.

---

### 3. Pantalla de códigos de respaldo (`auth.codigos_respaldo`)

**Tabla afectada:** `auth.codigos_respaldo`

**Problema:** Al completar el OTP de registro, la app navegaba directamente a `/home` sin mostrar los códigos de respaldo generados por el backend.

**Corrección aplicada:**
- Creado: `lib/features/auth/presentation/backup_codes_screen.dart`
  - `BackupCodesScreen`: muestra hasta 8 códigos en un grid 2×4.
  - Botón "Copiar todos" guarda los códigos en el portapapeles.
  - Checkbox de confirmación (`_confirmed`) desbloquea el botón "Ir a mi cuenta".
  - Acepta `List<String> codes` como parámetro extra; si está vacío muestra códigos mock.
- Actualizado: `lib/features/auth/presentation/register_screen.dart`
  - `_OtpRegisterScreen._verify()` ahora navega a `/register/backup-codes` en lugar de `/home`.
- Actualizado: `lib/app/router.dart`
  - Ruta `/register/backup-codes` → `BackupCodesScreen`.

---

### 4. Flujo de recuperación de PIN (`auth.tokens_restablecimiento`)

**Tabla afectada:** `auth.tokens_restablecimiento`

**Problema:** El botón "¿Olvidaste tu PIN?" en `PinScreen` no estaba conectado a ninguna ruta.

**Corrección aplicada:**
- Creado: `lib/features/auth/presentation/recovery_screen.dart`
  - `RecoveryScreen`: confirma el celular del usuario y dispara el OTP de restablecimiento.
  - `RecoveryOtpScreen`: verifica el OTP con `proposito = restablecimiento`.
  - `NewPinScreen`: 2 pasos (ingreso + confirmación del nuevo PIN); valida que ambos coincidan con shake animation.
- Actualizado: `lib/features/auth/presentation/login_screen.dart`
  - `PinScreen` — `onPressed` del botón "¿Olvidaste tu PIN?" ahora navega a `/login/recovery` con `extra: widget.phone`.
- Actualizado: `lib/app/router.dart`
  - Rutas anidadas bajo `/login/recovery`:
    - `/login/recovery` → `RecoveryScreen`
    - `/login/recovery/otp` → `RecoveryOtpScreen`
    - `/login/recovery/new-pin` → `NewPinScreen`

---

### 5. Copia del OTP según `proposito` en `auth.desafios`

**Tabla afectada:** `auth.desafios`  
**Campo:** `proposito` (enum: `registro | login | restablecimiento`)

**Problema:** Las pantallas de OTP usaban un título genérico ("Código de verificación") sin distinguir el propósito del desafío.

**Corrección aplicada:**
- `OtpLoginScreen` (login): título "Código de verificación", descripción indica WhatsApp.
- `_OtpRegisterScreen` (registro): título "Verifica tu número", descripción indica que es para confirmar el registro.
- `RecoveryOtpScreen` (restablecimiento): título "Código de restablecimiento", deja claro el contexto de recuperación de PIN.

---

## Rutas actualizadas

| Ruta | Widget | `extra` |
|---|---|---|
| `/login` | `LoginScreen` | — |
| `/login/pin` | `PinScreen` | `String` (celular) |
| `/login/otp` | `OtpLoginScreen` | `Map<String,dynamic>` {phone, challengeId} |
| `/login/recovery` | `RecoveryScreen` | `String` (celular) |
| `/login/recovery/otp` | `RecoveryOtpScreen` | `Map<String,dynamic>` {phone, challengeId} |
| `/login/recovery/new-pin` | `NewPinScreen` | `Map<String,dynamic>` {phone, challengeId} |
| `/register` | `RegisterScreen` | — |
| `/register/backup-codes` | `BackupCodesScreen` | `List<String>?` (códigos) |
| `/home` | `HomeScreen` | — |

---

## Pendiente (backend)

| Item | Endpoint | Nota |
|---|---|---|
| Enviar `nacida_en` | `POST /auth/register` | Formato `YYYY-MM-DD` |
| Enviar `terminos_version` | `POST /auth/register` | Valor fijo `v1.0` hasta que se versioneen T&C |
| Recibir `codigos_respaldo` | `POST /auth/register/verify-phone` response | Pasar como `extra` a `BackupCodesScreen` |
| Reset PIN | endpoint pendiente de definir | Body: `{challengeId, nuevo_pin}` |
| OTP proposito | `POST /auth/login` / `verify-otp` | Incluir `proposito` en request body |
