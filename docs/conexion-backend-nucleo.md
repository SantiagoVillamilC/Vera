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
| `MontoCalculado` | `montoCentavos: int`, `moneda`, `calculadoEn` | Saldo y monto máximo usan el mismo esquema |
| `LineaMovimiento` | `montoCentavos: int`, `motivo: MotivoLinea` | Monto con signo: positivo = a favor, negativo = en contra |
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
| `GET /v1/transferencias/maximo` | `getMontoMaximo()` | `EnviarScreen` (validación) | ⏳ Repo listo, UI pendiente |
| `GET /v1/movimientos` | `getMovimientos()` | `MovimientosTab` (paginado) + preview en `HomeScreen` | ✅ Conectado |
| `POST /v1/depositos` | `crearDeposito()` | Acción "Recargar" (home) | ⏳ Repo listo, pantalla pendiente |
| `GET /v1/depositos/{id}` | `getDeposito()` | — | ⏳ Repo listo, sin pantalla |
| `POST /v1/transferencias` | `transferir()` | `EnviarScreen` | ⚠️ UI lista, idempotency_key pendiente |
| `POST /v1/transferencias/interbancarias` | `transferirInterbancaria()` | — | ⏳ Repo listo, sin pantalla |

---

## Contrato vs. diseño: diferencias relevantes

### 1. `Movimiento` no tiene contraparte ni descripción
**Contrato real:**
```json
{
  "entry_id": 1234,
  "ocurrido_en": "2026-10-01T08:02:00Z",
  "moneda": "COP",
  "lineas": [
    { "monto": "18000000", "motivo": "transferencia_recibida" },
    { "monto": "-540000",  "motivo": "gravamen" }
  ]
}
```
No hay `nombre`, `concepto`, ni `contraparte`. Las pantallas de movimientos derivan
el label del `motivo` de la línea principal (primera que no sea gravamen/dev. gravamen)
y el ícono del mismo campo.

### 2. Montos siempre como strings
Todos los montos viajan como `"monto": "18000000"` (centavos, string).
El frontend los parsea con `int.tryParse()`. La serialización inversa
(para enviar al back) es `'$centavos'` donde `centavos = pesos * 100`.

### 3. Idempotencia obligatoria en mutaciones
`POST /v1/depositos` y `POST /v1/transferencias` requieren `idempotency_key` (max 128 chars).
Como el proyecto no tiene el paquete `uuid`, se genera con:
```dart
String _generateKey() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final hash = now.hashCode ^ Object.hash(now, 'vera');
  return 'vera-${now.toRadixString(16)}-${hash.toRadixString(16)}';
}
```

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
- Saldo mock `_saldoCentavos = 14512356` eliminado
- Nombre aún mock (`_mockNombre = 'Elisa'`) — pendiente conectar `AuthRepository.getNombreCompleto()`

### `MovimientosTab` ✅ Real
- StatefulWidget; carga `getMovimientos(limit: 50)` en `initState`
- Agrupación por fecha en `_groupByDate()` usando `DateTime` nativo (sin paquetes externos)
- Filtros Todos/Ingresos/Gastos por `lineaPrincipal.motivo.esIngreso`
- Totales de ingresos/gastos calculados en tiempo real desde lista
- Paginación: botón "Cargar más" cuando `_hasMore == true`
- Estados: cargando (spinner), error (ícono + retry), vacío (texto)
- Datos mock `_sections` eliminados

### `EnviarScreen` ⚠️ UI lista, API pendiente de idempotency_key
- UI completa con campo destinatario, monto, bottom sheet de confirmación
- Falta agregar `idempotency_key` y llamar `NucleoRepository.transferir()`

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
| Recargar saldo | `POST /v1/depositos` | Alta — acción "Recargar" en home |
| Consultar estado recarga | `GET /v1/depositos/{id}` | Media — flujo post-depósito |
| Monto máximo en enviar | `GET /v1/transferencias/maximo` | Media — validación pre-envío |
| Envíos interbancarios | `POST /v1/transferencias/interbancarias` | Media — tab de tarjetas/CVU |
| Estadísticas reales | `GET /v1/movimientos` agrupado | Media — `EstadisticasScreen` |

---

## Errores del nucleo

Los errores siguen el mismo envelope `{success: false, error: {code, message}}`.
Códigos relevantes del nucleo:

| Código | Significado |
|---|---|
| `SaldoInsuficiente` | El monto supera el saldo disponible |
| `MontoInvalido` | Monto <= 0 o mal formateado |
| `DestinoNoEncontrado` | El `destino` no corresponde a ningún usuario Vera |
| `IdempotencyConflict` | La `idempotency_key` ya existe con datos distintos |
| `LimiteKYC` | La operación supera el límite del nivel KYC del usuario |
| `RielNoDisponible` | El simulador de riel no responde (503) |
| `CustodioNoDisponible` | El simulador de custodia no responde (504) |
