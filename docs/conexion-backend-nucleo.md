# Conexión Frontend–Backend: Núcleo Financiero

Documento de trazabilidad entre el contrato OpenAPI del backend (`api/openapi.yaml` rama `dev`)
y los cambios aplicados al cliente Flutter. Fecha de integración: 2026-10-02.

---

## Contexto

El backend de Vera (Go monolito modular) expone el núcleo financiero a partir de la rama `dev`.
Los endpoints de auth y KYC ya estaban integrados (ver `docs/conexion-backend-auth.md`).
Este documento cubre exclusivamente los nuevos endpoints del módulo `nucleo`.

---

## Archivos nuevos

### `lib/features/nucleo/data/nucleo_repository.dart`

Repositorio central del núcleo financiero. Contiene todos los modelos tipados y los métodos de
acceso al API. Lee el `access_token` desde `flutter_secure_storage` (misma llave que `AuthRepository`).

**Modelos:**

| Modelo | Campos clave | Notas |
|---|---|---|
| `MontoCalculado` | `montoCentavos: BigInt`, `moneda`, `calculadoEn` | Saldo y monto máximo usan el mismo esquema |
| `LineaMovimiento` | `montoCentavos: BigInt`, `motivo: MotivoLinea` | Monto con signo: positivo = a favor, negativo = en contra |
| `Movimiento` | `entryId`, `ocurridoEn`, `lineas[]`, getters `lineaPrincipal` y `montoNeto` | No tiene contraparte ni descripción libre |
| `MovimientosPage` | `items[]`, `nextCursor`, `hasMore` | Paginación por cursor (entry_id) |
| `Deposito` | `id`, `referencia`, `montoCentavos`, `estado: EstadoDeposito` | Estados: pendiente/confirmada/rechazada/expirada |
| `Transferencia` | `id`, `destino`, `montoCentavos`, `estado: EstadoTransferencia` | `destino` es string libre (celular, CVU, etc.) |
| `EnvioPorLlave` | `id`, `tipoLlave`, `llave`, `montoCentavos`, `estado` | Para envíos interbancarios |

**Enum `MotivoLinea`** (derivado del campo `motivo` del contrato):

| Valor del back | Caso del enum | `label` | `esIngreso` |
|---|---|---|---|
| `deposito` | `MotivoLinea.deposito` | "Depósito" | ✅ |
| `transferencia_recibida` | `MotivoLinea.transferenciaRecibida` | "Transferencia recibida" | ✅ |
| `envio` | `MotivoLinea.envio` | "Envío" | ❌ |
| `gravamen` | `MotivoLinea.gravamen` | "GMF" | ❌ |
| `devolucion` | `MotivoLinea.devolucion` | "Devolución" | ✅ |
| `devolucion_gravamen` | `MotivoLinea.devolucionGravamen` | "Dev. GMF" | ✅ |

### `lib/core/network/api_client.dart` (modificado)

Se agregó el método `get()` con soporte para `queryParams` opcionales.
El método `_parseRaw()` devuelve el body completo (para endpoints donde `data` es lista o mapa)
y `_parseMap()` extrae solo el objeto `data`.

---

## Endpoints integrados

| Endpoint | Método repo | Pantalla | Estado |
|---|---|---|---|
| `GET /v1/saldo` | `getSaldo()` | `HomeScreen` header | ✅ Conectado |
| `GET /v1/transferencias/maximo` | `getMontoMaximo()` | `EnviarScreen` (validación) | ✅ Conectado |
| `GET /v1/movimientos` | `getMovimientos()` | `MovimientosTab` (paginado) + preview en `HomeScreen` | ✅ Conectado |
| `POST /v1/depositos` | `recargar()` (sobre `crearDeposito()`) | `RecargarScreen` (`/recargar`), acción "Recargar" del home | ✅ Conectado: abre `url_pago` con `UrlOpener` solo si es segura y conserva el depósito pendiente en `SessionStore` |
| `GET /v1/depositos/{id}` | `getDeposito()` | `RecargarScreen` | ✅ Conectado: sondeo cada 5 s hasta 5 min y al volver a la app, con retoma del depósito pendiente |
| `POST /v1/transferencias` | `transferir()` | `EnviarScreen` | ✅ Conectado, con `idempotency_key` |
| `POST /v1/transferencias/interbancarias` | `enviarPorLlave()` (sobre `transferirInterbancaria()`) | `EnviarLlaveScreen` (`/enviar-llave`), acceso "Enviar por llave" del home | ✅ Conectado, con `idempotency_key`. Al aceptarse muestra "Enviado. Verás el resultado en tu historial." |

---

## Contrato vs. diseño: diferencias relevantes

### 1. `Movimiento` no tiene contraparte ni descripción
No hay `nombre`, `concepto`, ni `contraparte`. Las pantallas de movimientos derivan
el label del `motivo` de la línea principal (primera que no sea gravamen/dev. gravamen)
y el ícono del mismo campo.

### 2. Montos siempre como strings
Todos los montos viajan como `"monto": "18000000"` (centavos, string).
El frontend los parsea como `BigInt` (sin perder precisión) y los muestra con `formatPesos`
(`lib/core/format/pesos.dart`). La serialización inversa (para enviar al back) es el entero en centavos como string.

### 3. Idempotencia obligatoria en mutaciones
`POST /v1/depositos` y `POST /v1/transferencias` requieren `idempotency_key` (max 128 chars).
Ya está implementada: `IdempotencyIntent` (`lib/features/nucleo/data/idempotency_intent.dart`)
genera un UUID v4 con `Random.secure()` y conserva la misma clave mientras el resultado sea
desconocido o reintentable y no cambien destino ni monto. Se renueva con cualquier respuesta
definitiva del servidor.

### 4. Paginación por cursor en movimientos
`GET /v1/movimientos` usa paginación por `entry_id`:
- Primera carga: sin `cursor`
- Siguiente página: `cursor=<entry_id del último item>`
- `meta.has_more: true` indica si hay más páginas

### 5. Token de autenticación
Todos los endpoints del nucleo requieren `Authorization: Bearer <access_token>`.
El token se lee de `flutter_secure_storage` con la llave `'access_token'`
(la misma que escribe `AuthRepository.login()`).

---

## Pantallas modificadas

### `HomeScreen` ✅ Real
- Carga `NucleoRepository.getSaldo()` en `initState`; estados: spinner → monto real → error
- Preview de últimos 3 movimientos vía `FutureBuilder<MovimientosPage>` (limit: 3)
- Saldo mock eliminado
- El saludo usa el nombre guardado con la sesión (nombre completo o razón social). Sin nombre guardado muestra "Hola"
- "Recargar" navega a `/recargar` y "Enviar por llave" a `/enviar-llave`. Los accesos viven en una grilla de 4 columnas
- Si `SessionStore` guarda un depósito pendiente, muestra el aviso "Tienes una recarga pendiente" que lleva a `/recargar`. Se relee al abrir el home y al volver de una pantalla

### `MovimientosTab` ✅ Real
- StatefulWidget; carga `getMovimientos(limit: 50)` en `initState`
- Agrupación por fecha en `_groupByDate()` usando `DateTime` nativo (sin paquetes externos)
- Filtros Todos/Ingresos/Gastos por `lineaPrincipal.motivo.esIngreso`
- Totales de ingresos/gastos calculados en tiempo real desde lista
- Paginación: botón "Cargar más" cuando `_hasMore == true`
- Estados: cargando (spinner), error (ícono + retry), vacío (texto)
- Datos mock `_sections` eliminados

### `EnviarScreen` ✅ Conectada
- Campo destinatario, monto, bottom sheet de confirmación
- Llama `NucleoRepository.transferir()` con `idempotency_key` de `IdempotencyIntent`

---

## Cómo correr el backend en dev

El backend requiere:
- PostgreSQL con los roles `rol_api` y `rol_nucleo` creados y las migraciones aplicadas
- Redis (para auth)
- Variables de entorno del `.env.example`

Pasos mínimos para desarrollo local (macOS):
```bash
# 1. Copiar variables de entorno
cp .env.example .env
# Editar .env con DATABASE_URL, APP_DATABASE_URL, REDIS_URL reales

# 2. Correr migraciones
go run ./cmd/migrate

# 3. Arrancar el servidor
go run ./cmd/api

# El backend queda en http://localhost:8080
```

Desde Flutter:
Para configurar la URL según el entorno (emulador, dispositivo físico, etc.), ver la sección "Configurar la URL del backend" en [README.md](../README.md#configurar-la-url-del-backend).

---

## Pendiente de conectar

| Funcionalidad | Endpoint | Prioridad |
|---|---|---|
| Estadísticas reales | Sin endpoint en el contrato | Media: `EstadisticasScreen` y `TarjetasTab` muestran datos de muestra con aviso "(WIP)" por decisión D6. El Balance de estadísticas y la lista de movimientos son reales |

### No verificado todavía

- Los builds de APK e iOS del CI con el plugin nativo `url_launcher` no se ejecutaron en el entorno de desarrollo de este lote. Solo se verificaron `flutter analyze`, las pruebas y `flutter build web`.
- `ios/Podfile.lock` se actualiza con `pod install` en macOS, que no estaba disponible aquí.
- La apertura real de `url_pago` en un navegador del dispositivo no se probó en equipo físico.

---

## Errores del núcleo y del API

Los errores siguen el mismo envelope `{success: false, error: {code, message}}`. El cliente
mapea por `code`, nunca por `message` (viene en inglés), con `mensajeDeError` en
`lib/core/network/error_messages.dart`. Códigos del catálogo `APIError.code` de
`api/openapi.yaml` más los que emiten `internal/nucleo/handler.go` y
`internal/platform/httpserver/health.go`.

### Del núcleo financiero (`handler.go`)

| Código | HTTP | Significado |
|---|---|---|
| `InsufficientFunds` | 422 | El monto supera el saldo disponible |
| `OperationLimitExceeded` | 422 | El monto supera el límite por operación |
| `MonthlyQuotaExceeded` | 422 | Se agotó la cuota mensual |
| `IdempotencyConflict` | 409 | La `idempotency_key` se reutilizó con datos distintos |
| `RecipientNotFound` | 404 | El destino no existe |
| `SelfTransferNotAllowed` | 422 | El destino es el propio usuario |
| `DirectoryUnavailable` | 503 | El directorio de llaves no está disponible |
| `TargetNotAllowed` | 400 | Se intentó apuntar a la cuenta de otro usuario |
| `DepositNotFound` | 404 | El depósito no existe |
| `ConfirmationConflict` | 409 | La confirmación no coincide con el depósito |
| `LateConfirmation` | 409 | El depósito ya no estaba pendiente |
| `ValidationError` | 400 o 422 | Regla incumplida (monto, moneda, destino, límite de página) |
| `Unauthorized` | 401 | Token ausente, vencido o alterado |
| `NotFound` | 404 | Recurso inexistente |

### Del servidor (`health.go`)

| Código | HTTP | Significado |
|---|---|---|
| `NotReady` | 503 | Una dependencia (base de datos) no responde en `/readyz` |

### Catálogo general (`openapi.yaml`, `APIError.code`)

`BadRequest`, `ValidationError`, `Unauthorized`, `InvalidCredentials`, `AccountSuspended`,
`AccountClosed`, `OtpInvalid`, `OtpExpired`, `ChallengeInvalid`, `OtpTooManyAttempts`,
`OtpResendCooldown`, `RefreshInvalid`, `RefreshReused`, `SessionNotFound`, `NoCompanyRole`,
`ContextInvalid`, `ResetInvalid`, `SecondFactorRequired`, `KycRequired`, `ConsentRequired`,
`DuplicateIdentifier`, `PhoneUnverified`, `OtpTooManyResends`, `PhoneChangeCooldown`,
`TooManyRequests`, `NotImplemented`, `PayloadTooLarge` (cuerpo mayor a 1 MiB),
`RecipientNotFound`, `SelfTransferNotAllowed`, `MethodNotAllowed`, `NotFound`,
`AuthUnavailable`, `OtpDeliveryFailed`, `Timeout` (504), `WhatsappUnicoCanal` (409),
`InternalError` (siempre genérico).

Los identificadores `SaldoInsuficiente`, `MontoInvalido`, `DestinoNoEncontrado`, `LimiteKYC`,
`RielNoDisponible` y `CustodioNoDisponible` no existen en el contrato.
