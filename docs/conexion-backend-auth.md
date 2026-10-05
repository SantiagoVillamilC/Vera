# Conexión Frontend–Backend: Módulo Auth

Documento de trazabilidad entre el contrato OpenAPI del backend (`api/openapi.yaml`) y los cambios aplicados al cliente Flutter.

---

## Archivos nuevos

### `lib/core/network/api_client.dart`
Cliente HTTP base. Parsea el envelope `{success, data, error, meta}` de todas las respuestas y lanza `ApiException` cuando `success: false`.

- `ApiException.code` refleja el catálogo PascalCase del back (`InvalidCredentials`, `OtpInvalid`, `OtpExpired`, etc.)
- Timeout de 15 s en todas las peticiones
- Header `Authorization: Bearer <token>` opcional por llamado

### `lib/core/network/app_config.dart`
URL base configurable en tiempo de compilación.
Default: `http://localhost:8080` para desarrollo local.

Para configurar la URL según el entorno, ver la sección "Configurar la URL del backend" en [README.md](../README.md#configurar-la-url-del-backend).

### `lib/features/auth/data/auth_repository.dart`
Repositorio con todos los llamados al API de auth. Incluye modelos tipados (`LoginResult`, `RegisterResult`, `VerifyPhoneResult`, `ConsentimientoInput`) y gestión de tokens con `flutter_secure_storage`.

---

## Dependencias agregadas (`pubspec.yaml`)

| Paquete | Versión | Uso |
|---|---|---|
| `http` | ^1.2.2 | Peticiones HTTP |
| `flutter_secure_storage` | ^9.2.4 | Almacenamiento seguro de tokens JWT |

---

## Endpoints conectados

| Endpoint | Pantalla | Método en repositorio |
|---|---|---|
| `POST /v1/auth/login` | `PinScreen` (campo de contraseña oculto) | `AuthRepository.login()` |
| `POST /v1/auth/register` | `RegisterScreen` | `AuthRepository.registerPersona()` / `registerEmpresa()` |
| `POST /v1/auth/register/verify-phone` | `_OtpRegisterScreen` | `AuthRepository.verifyPhone()` |
| `POST /v1/auth/otp/resend` | `_OtpRegisterScreen` | `AuthRepository.resendOtp()` (con el `challenge_id` vigente) |
| `POST /v1/auth/logout` | Botón "Cerrar sesión" de Perfil | `AuthRepository.logout()` (Bearer y refresh token) |
| `POST /v1/auth/recovery/request` | `RecoveryScreen` | `AuthRepository.recoveryRequest()` |
| `POST /v1/auth/recovery/verify` | `RecoveryOtpScreen` | `AuthRepository.recoveryVerify()` |
| `POST /v1/auth/recovery/reset` | `NewPinScreen` | `AuthRepository.recoveryReset()` |

---

## Correcciones de contrato aplicadas

### 1. Login sin OTP
**Antes:** Flujo de 3 pasos, celular → PIN → OTP WhatsApp.  
**Ahora:** Flujo de 2 pasos, celular → `PinScreen` → tokens directos.

El endpoint `POST /v1/auth/login` devuelve `{access_token, refresh_token, usuario}` sin paso OTP intermedio. `OtpLoginScreen` y la ruta `/login/otp` se eliminaron.

`PinScreen` pide una contraseña de 8 a 64 caracteres en un campo oculto (`LoginRequest.contrasena`). La ruta `/login/pin` conserva su nombre. Al autenticar se guardan tokens y perfil (nombre o razón social y tipo de cuenta), y el saludo del Home usa el nombre guardado.

El rango de 8 a 64 caracteres es un supuesto del lote 0 tomado de `openapi.yaml:1091-1097`, pendiente de confirmar por Santiago y Valeria.

### 2. Formato E.164 en `celular`
**Antes:** Se enviaba el número como el usuario lo ingresaba (`3001234567`).  
**Ahora:** `AuthRepository.toE164()` convierte automáticamente a `+573001234567` antes de cualquier llamado al API.

### 3. `consentimientos` obligatorio en registro
**Antes:** El registro no enviaba consentimientos.  
**Ahora:** El paso final del registro muestra dos casillas, `tratamiento_datos` y `whatsapp_optin`, y el botón queda deshabilitado hasta marcar ambas. El body de `POST /v1/auth/register` incluye siempre:
```json
[
  {"tipo": "tratamiento_datos", "version_texto": "v1", "aceptado": true},
  {"tipo": "whatsapp_optin", "version_texto": "v1", "aceptado": true}
]
```
La versión es la constante `AuthRepository.versionConsentimientos` (`v1`). Sin ambos consentimientos aceptados el repositorio no envía la petición, y el back responde `ConsentRequired`.

Los textos legales de los consentimientos son marcadores pendientes en la migración (decisión 2). Las etiquetas de las casillas son cortas y neutras, sin redacción legal.

### 4. `verify-phone` usa `{celular, codigo}`
**Antes:** Se enviaba `{challenge_id, codigo}`.  
**Ahora:** El endpoint `POST /v1/auth/register/verify-phone` recibe `{celular, codigo}` según el contrato (`VerifyPhoneRequest`). El `challenge_id` venía de la respuesta de registro y se usa solo para el reenvío: `POST /v1/auth/otp/resend` lleva el `challenge_id` vigente, y el contador de 60 s solo reinicia cuando el reenvío responde 200.

### 5. Códigos de respaldo reales
**Antes:** La pantalla `BackupCodesScreen` mostraba códigos mock.  
**Ahora:** La respuesta de `verify-phone` incluye `codigos_respaldo` (10 códigos de un solo uso). Se pasan como `extra` (`List<String>`) en la navegación a `/register/backup-codes`. Si no llegan códigos reales (lista vacía o `extra` de otro tipo), la pantalla no inventa ninguno: muestra un error en español con un botón que lleva a `/login`. Tras confirmar los códigos de respaldo, la app va a `/login` (la cuenta recién creada inicia sesión con su contraseña).

### 6. Recuperación usa correo, no teléfono
**Antes:** `RecoveryScreen` pedía el número de celular.  
**Ahora:** `POST /v1/auth/recovery/request` recibe `{correo}`. La pantalla tiene un campo de email.

### 7. Segundo factor obligatorio en recovery verify
**Antes:** `RecoveryOtpScreen` solo pedía el código OTP de 6 dígitos.  
**Ahora:** `POST /v1/auth/recovery/verify` requiere `{challenge_id, codigo, segundo_metodo: {tipo: "codigo_respaldo", codigo: "..."}}`. La pantalla tiene un campo adicional para el código de respaldo.

### 8. Recovery reset recibe `reset_token`
**Antes:** `NewPinScreen` recibía `{phone, challengeId}`.  
**Ahora:** Recibe solo `{resetToken}` que proviene de la respuesta de `recovery/verify`. Llama a `POST /v1/auth/recovery/reset` con `{reset_token, nueva_contrasena}`.

---

## Flujos actualizados

### Login
```
LoginScreen (celular)
  → PinScreen (contraseña)
      POST /v1/auth/login {celular, contrasena}
      ← {access_token, refresh_token, usuario}
      → HomeScreen (saludo con el nombre guardado)
```

### Cerrar sesión
```
PerfilTab (botón "Cerrar sesión")
  POST /v1/auth/logout (Authorization: Bearer <access>, body con el refresh token)
  → borra tokens y perfil del almacenamiento seguro
  → LoginScreen
```

### Registro
```
RegisterScreen paso 1–4
  POST /v1/auth/register {tipo_cuenta, ...campos, consentimientos}
  ← {id, celular, desafio: {challenge_id}}
  → _OtpRegisterScreen (celular, challengeId)
      POST /v1/auth/register/verify-phone {celular, codigo}
      ← {id, celular, estado, codigos_respaldo[]}
      → BackupCodesScreen (codigos_respaldo)
          → LoginScreen (tras confirmar)
```

### Recuperación de contraseña
```
RecoveryScreen (correo)
  POST /v1/auth/recovery/request {correo}
  ← {challenge_id}
  → RecoveryOtpScreen (correo, challengeId)
      POST /v1/auth/recovery/verify {challenge_id, codigo, segundo_metodo}
      ← {reset_token}
      → NewPinScreen (resetToken)
          POST /v1/auth/recovery/reset {reset_token, nueva_contrasena}
          → LoginScreen
```

---

## Manejo de errores

Los errores del back llegan como `ApiException.code` (PascalCase). Las pantallas muestran `SnackBar` con `exception.message` y, en el caso de OTP inválido o expirado, resetean el campo de entrada.

Códigos relevantes para auth:
| Código | Significado |
|---|---|
| `InvalidCredentials` | Celular o contraseña incorrectos |
| `OtpInvalid` | Código OTP incorrecto |
| `OtpExpired` | OTP vencido: el usuario debe reenviar |
| `OtpTooManyAttempts` | Demasiados intentos fallidos |
| `OtpResendCooldown` | Reenvío solicitado muy pronto (enfriamiento de 60 s) |
| `OtpTooManyResends` | Demasiados reenvíos del código |
| `TooManyRequests` | Demasiadas peticiones: se pide intentar más tarde (la espera crece de 1 a 15 minutos) |
| `ChallengeInvalid` | El desafío ya no es válido |
| `DuplicateIdentifier` | Ya existe una cuenta con ese dato |
| `ConsentRequired` | Falta aceptar algún consentimiento obligatorio |
| `AccountSuspended` | Cuenta suspendida |
| `PhoneUnverified` | Celular no verificado |
| `ResetInvalid` | Token de restablecimiento inválido o vencido |
| `AuthUnavailable` | Redis o canal OTP no disponible (503) |

---

## Pendiente en el cliente (lote de auth)

| Item | Detalle |
|---|---|
| N-17 | Contexto de empresa en login |
| Textos legales de consentimiento (decisión 2) | Marcadores pendientes en la migración, sin redacción legal en la app |
| Salida del lado del servidor (N-6, S8) | `logout` borra la sesión local, la invalidación en el servidor depende de S8 |
| Biometría (SCRUM-81) | Sin implementar |
| Contraseña de 8 a 64 caracteres | Supuesto del lote 0 (`openapi.yaml:1091-1097`), por confirmar con Santiago y Valeria |
