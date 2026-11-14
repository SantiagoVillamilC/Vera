# Handoff: avisos, detalle, audio propio, escalón y accesibilidad

Punto de entrada para quien tome las tarjetas de frontend del cierre funcional de Vera. Este documento
dice dónde trabajar, qué leer primero, cómo levantar el backend local, cómo probar sin backend y cómo entregar.
El enunciado, los pasos y los criterios de aceptación de cada tarea viven en su tarjeta de Jira, que es la
fuente de verdad. Aquí no se copian para que no se desfasen.

| Campo | Valor |
| --- | --- |
| Épica | [SCRUM-157](https://adriidiaz1917.atlassian.net/browse/SCRUM-157), Vera: cierre funcional autoalojado |
| Rama de trabajo | `feat/wireframes-bandeja-detalle-audio-escalon-a11y` |
| Base | `origin/main` en `b5ccc3bbb58c0d37cdded58cea9285d89d2518d1` (rediseño VeraDark) |
| App | Flutter 3.47.2 (`.fvmrc`), Dart `^3.12.2`, Material 3, tema oscuro |
| Backend publicado | `SantiagoVillamilC/Backend_Vera`, rama `feat/local-hardware`, commit `7681d889cea161c2bdaf518893ab8c06695a891e` |
| Actualizado | 2026-11-13 |

## 1. Las seis tarjetas, en el orden recomendado

| Orden | Jira | Tarea | Horas | Depende de |
| --- | --- | --- | --- | --- |
| 1 | [SCRUM-158](https://adriidiaz1917.atlassian.net/browse/SCRUM-158) | CF-A4-01 Wireframes de avisos dentro del flujo actual | 4 | ninguna |
| 2 | [SCRUM-161](https://adriidiaz1917.atlassian.net/browse/SCRUM-161) | CF-A4-05 Mostrar qué escalón decidió la categoría | 4 | ninguna |
| 3 | [SCRUM-159](https://adriidiaz1917.atlassian.net/browse/SCRUM-159) | CF-A4-02 Bandeja de avisos con badge y descarte | 10 | ninguna |
| 4 | [SCRUM-160](https://adriidiaz1917.atlassian.net/browse/SCRUM-160) | CF-A4-03 Detalle del aviso y acciones | 6 | CF-A4-02 |
| 5 | [SCRUM-163](https://adriidiaz1917.atlassian.net/browse/SCRUM-163) | CF-A4-04 Reproducción del audio propio del asistente | 8 | ninguna (CF-A3-03 ya está completada) |
| 6 | [SCRUM-162](https://adriidiaz1917.atlassian.net/browse/SCRUM-162) | CF-A4-06 Accesibilidad, escalado de texto y cortes declarados | 4 | ninguna (las pantallas nuevas se prueban al final) |

Por qué este orden: el 01 aprueba el dibujo que guía al 02 y al 03. El 05 es pequeño, independiente y deja
una victoria visible temprano. El 04 puede avanzar en paralelo con un reproductor falso y el simulador de voz
(sección 4). El 06 va al final porque revisa también las pantallas que crean las tareas anteriores.

## 2. Cómo arrancar

1. Comprueba las herramientas: `command -v flutter git`. Para el backend local suma `docker go make python3`.
2. Trabaja en la rama de este documento o en una rama `feat/*` propia por tarjeta que salga de `origin/main`.
   El flujo del repo es `feat/*` a `dev`, luego `staging`, luego `main`, siempre por PR.
3. Instala y verifica la línea base antes de tocar código:

```bash
flutter pub get
flutter analyze        # debe devolver "No issues found"
flutter test           # suite completa en verde
```

4. Lee primero [AGENTS.md](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/AGENTS.md) y
   [CLAUDE.md](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/CLAUDE.md).
   Después abre la tarjeta que vas a tomar y sus enlaces de recursos.

## 3. Qué leer según la tarjeta

Contratos del backend (todos fijados al commit `7681d88`, siguen válidos aunque la rama avance):

| Documento | Lo usan |
| --- | --- |
| [contrato-frontend-avisos.md](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/docs/contrato-frontend-avisos.md) | 01, 02, 03 |
| [contrato-frontend-voz-y-origen.md](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/docs/contrato-frontend-voz-y-origen.md) | 04, 05 |
| [openapi.yaml](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/api/openapi.yaml) | todas las que consumen la API |
| [operacion-demo.md](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/docs/operacion-demo.md) | levantar el backend local |

Los PR [70](https://github.com/SantiagoVillamilC/Backend_Vera/pull/70) y
[71](https://github.com/SantiagoVillamilC/Backend_Vera/pull/71) llevan estos contratos y el escenario de demo
hacia `feat/cierre-ia`. Mientras se fusionan, el commit fijo de arriba es la referencia.

Wireframes de esta rama: [wireframes-avisos.html](https://github.com/SantiagoVillamilC/Vera/blob/2770970ae2c200b27a3481ac5d45d66f37ce66ed/docs/diseno/wireframes-avisos.html)
y [wireframes-avisos.png](https://github.com/SantiagoVillamilC/Vera/blob/2770970ae2c200b27a3481ac5d45d66f37ce66ed/docs/diseno/wireframes-avisos.png).
La tarjeta 01 los revisa y los regenera en esta misma rama.

## 4. Backend local y pruebas sin backend

### 4.1 Backend local completo

El script [levantar-base.sh](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/infra/local/levantar-base.sh)
deja Postgres 16 y Redis 7 en contenedores desechables, aplica migraciones y siembra datos. La secuencia
mínima, desde la raíz del repo del backend, con el cupo de la demo y el emisor de avisos encendido
(`entorno.sh` lo deja apagado a propósito):

```bash
bash infra/local/levantar-base.sh --semilla
set -a && source cargas/inteligencia/entorno.sh && set +a
export AVISOS_ACTIVO=true AVISOS_CUPO=5
out/bin/enriquecer lote 5000
out/bin/api            # queda en http://127.0.0.1:8080
```

- Apunta la app a esa API: emulador Android `--dart-define=API_BASE_URL=http://10.0.2.2:8080`, teléfono
  físico con `adb reverse tcp:8080 tcp:8080` (el valor por defecto `http://localhost:8080` ya sirve).
  Detalle en «Configurar la URL del backend» del
  [README](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/README.md).
- Para entrar desde la app, crea la credencial de un usuario sembrado con
  [login-demo](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/cmd/login-demo/main.go)
  (`-usuario`, `-celular`, `-contrasena`, `-nombre`). Al terminar, `bash infra/local/levantar-base.sh --limpiar` borra los contenedores.
- Para ver los cuatro tipos de aviso de la demo, siembra el escenario con
  [sembrar-escenario-demo.sh](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/infra/local/sembrar-escenario-demo.sh)
  sobre la misma base (`vera_semilla_m8` por defecto). Detalle en
  [escenario-demo.md](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/docs/escenario-demo.md).

### 4.2 Sin backend

- **Avisos y escalón:** inyecta un repositorio falso por constructor, como hace
  [fake_inteligencia.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/home/presentation/fake_inteligencia.dart).
  Los ejemplos JSON de la sección 4 del contrato de avisos sirven de fixtures.
- **Audio:** el simulador
  [simulado.py](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/infra/voz-local/simulado.py)
  usa solo la biblioteca estándar de Python 3 y responde `POST /v1/vera/sintetizar` con seis casos que se eligen
  con la cabecera `X-Simulado-Caso` (`audio`, `degradado`, `sin-consentimiento`, `cuota`, `no-verificable`,
  `sin-configurar`). Para el emulador: `python3 infra/voz-local/simulado.py --host 0.0.0.0 --puerto 8780` y
  `http://10.0.2.2:8780`. El WAV de ejemplo
  [vera-hola.wav](https://github.com/SantiagoVillamilC/Backend_Vera/blob/7681d889cea161c2bdaf518893ab8c06695a891e/infra/voz-local/ejemplos/vera-hola.wav)
  (PCM16 mono 24 kHz, 4,4 s) es el fixture de pruebas. El simulador solo cubre esa ruta: dale su propio
  `ApiClient` al lector de voz y deja el resto de la app contra el backend local. No dejes esa URL en el commit.

## 5. Contrato vigente en una página

Lo que cambió respecto de versiones anteriores del contrato y que conviene tener presente al leer las tarjetas.

**Avisos** (`GET /v1/inteligencia/avisos`, `GET /v1/inteligencia/avisos/{id}`, `POST .../descartar`):

- La bandeja sin parámetros devuelve los avisos cuyo periodo cae en el mes en curso, incluidos `pago_no_alcanza` y
  `cobro_nuevo` cuando su fecha de pago cae en ese mes. `caida_ingreso` pertenece al mes anterior, y un
  `cobro_nuevo` cuyo primer pago fue el mes pasado (en la demo, `2026-10-28`) pertenece a ese mes: ambos llegan
  solo con `?mes=YYYY-MM`. `mes` no se combina con `limite`, `cursor` ni `estado` (responde 400).
- Paginación opcional: `limite` de 1 a 50 (20 por defecto), `estado=vigentes|descartados` y la continuación en el
  encabezado `X-Vera-Siguiente-Cursor`. Ese encabezado no está declarado en el OpenAPI y el `ApiClient.get`
  actual no expone los encabezados de respuesta. Con un cupo de 3 a 5 por mes la primera página alcanza.
- Descartar es idempotente. Si el aviso se creó después del reloj del servidor (la semilla de demo fija el día 19)
  responde 409 `DescarteAnteriorAlAlta`: revierte el descarte optimista y muestra «todavía no se puede descartar».
  Para probar un descarte exitoso, siembra con una `DEMO_FECHA` ya pasada dentro del mes en curso.
- Campo opcional `accion_codigo` con enum `revisar_pagos`, `revisar_ingreso`, `revisar_cobro`,
  `revisar_presupuesto`, `revisar_categoria`. Es la llave del destino, `accion` es solo la etiqueta visible.
  Tolera un código desconocido mostrando el aviso sin botón.
- `severidad_centavos`, `monto_centavos` y `referencia_centavos` son cadenas de dígitos (`BigInt.parse`).
  `referencia_centavos` no viaja en `cobro_nuevo`. `monto_centavos` cambia de significado por tipo (en
  `pago_no_alcanza` es el saldo). `transaccion_id` llega nulo en los cinco tipos.
- Cupo: `GET /v1/inteligencia/resumen` trae `cupo_avisos` (3 por defecto, 5 en la demo) y `avisos_emitidos`
  (vigentes del mes). `ResumenDelMes` en `main` todavía no los lee.

**Origen y escalón** (cada movimiento de `GET /v1/inteligencia/movimientos`): `origen_categoria` (siete valores) y
`escalon` (1 a 7), ambos presentes. Se leen juntos, porque `sin_categoria` con escalón 6 es una abstención del
clasificador y con escalón 7 es que ninguna señal alcanzó.

| `origen_categoria` / `escalon` | Etiqueta |
| --- | --- |
| `memoria` / 1 | Tu corrección |
| `contraparte_interna` / 2 | Cargo de la billetera |
| `mcc` / 3 | Tipo de comercio (MCC) |
| `catalogo` / 4 | Catálogo de marcas |
| `lexico` / 5 | Palabras del nombre |
| `tfidf` / 6 | Modelo de texto (TF-IDF) |
| `sin_categoria` / 6 | Sin categoría, Vera no adivina |
| `sin_categoria` / 7 | Sin categoría |

El texto que aparece al tocar cada chip está en la tarjeta 05 y en el contrato de voz y origen. Un valor
desconocido o ausente no muestra chip. La semilla de demo solo produce `lexico` y `sin_categoria`: las demás combinaciones se prueban
con movimientos armados a mano.

**Voz** (`POST /v1/vera/sintetizar`):

- Requiere sesión (Bearer) y consentimiento de IA vigente. La llamada lleva solo el Bearer de la sesión: no se envía `X-Vera-Token`, ya no se exige y si llega se ignora.
- Cuerpo `{"texto": "..."}` de 1 a 400 caracteres (se cuentan caracteres, usa `texto.runes.length`). Más de 400
  devuelve 422: ni lo intentes y usa la voz del sistema.
- 200 `audio/wav` (PCM16 mono 24 kHz) o 200 JSON degradado `{"audio_disponible": false, "voz_local": true}` con
  la cabecera `X-Vera-Audio: no-disponible`. El degradado es camino normal: cae a la voz del teléfono.
- 401, 403 (`ConsentRequired`), 422, 429 (con `Retry-After`) y 503 conservan el mensaje y usan la voz del teléfono.
- Cuota de 10 por hora por usuario, compartida con el envío de voz. Un turno de voz con su audio gasta 2.
  La respuesta lleva `Cache-Control: no-store`: guarda los bytes en memoria por mensaje para no repetir la llamada.
- El mensaje del asistente y el historial no traen audio: se pide aparte con el texto del mensaje.

## 6. Qué ya tiene la app en `main`

Todo lo siguiente se verificó en el árbol de `b5ccc3b`. Los enlaces apuntan a ese commit.

| Pieza | Archivo | Para qué sirve en estas tareas |
| --- | --- | --- |
| Inicio, saludo y refresco | [home_screen.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/home/presentation/home_screen.dart): `_Saludo`, `_refrescar`, `_abrir` | Contador de avisos y navegación (02) |
| Rutas | [router.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/app/router.dart): `/recargar`, `/estadisticas`, `/inteligencia`, `/asistente` | Rutas nuevas y destinos (02, 03) |
| Modelos de inteligencia | [modelos.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/inteligencia/data/modelos.dart): `OrigenCategoria`, `etiquetaDeOrigen`, `MovimientoEnriquecido`, `ResumenDelMes` | Escalón y cupo (05, 02) |
| Repositorio de inteligencia | [inteligencia_repository.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/inteligencia/data/inteligencia_repository.dart) | Molde del repositorio de avisos (02) |
| Lista enriquecida | [movimientos_enriquecidos_screen.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/inteligencia/presentation/movimientos_enriquecidos_screen.dart): `_TileEnriquecido`, `_EtiquetaDeCategoria` | Chip de escalón (05), molde de pantalla (02) |
| Hoja de corrección | [correccion_sheet.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/inteligencia/presentation/correccion_sheet.dart) | Chip tras corregir (05) |
| Estados de pantalla | [estado_vista.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/core/widgets/estado_vista.dart): `cargando`, `vacio`, `sinRed`, `error`, `deError` | Bandeja y detalle (02, 03) |
| Textos de error | [error_messages.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/core/network/error_messages.dart): `mensajeDeError` | Errores de red y de API (02, 03, 04) |
| Cliente HTTP | [api_client.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/core/network/api_client.dart) | `post` acepta `headers`, `get` no. Ninguno devuelve bytes (04) |
| Voz del sistema | [lector_voz.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/asistente/data/lector_voz.dart): `LectorDeVoz`, `LectorFlutterTts` | Caída a la voz del teléfono (04) |
| Chat | [asistente_screen.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/asistente/presentation/asistente_screen.dart): `_BurbujaView`, `_detenerLectura`, `_alternarGrabacion` | Botones escuchar y detener y ciclo de vida (04) |
| Destino de recarga | [recargar_screen.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/home/presentation/recargar_screen.dart) | Destino propuesto de `revisar_pagos` (03) |
| Barra de navegación | [barra_vera.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/core/widgets/barra_vera.dart) | Fija la escala de texto en 1.0 a propósito (06) |
| Datos de muestra | [estadisticas_screen.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/features/home/presentation/estadisticas_screen.dart) y [tarjeta_muestra.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/lib/core/format/tarjeta_muestra.dart) | Marcar o retirar (06) |

Pruebas que sirven de molde: [inteligencia_repository_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/inteligencia/data/inteligencia_repository_test.dart),
[movimientos_enriquecidos_screen_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/inteligencia/presentation/movimientos_enriquecidos_screen_test.dart),
[home_screen_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/home/presentation/home_screen_test.dart),
[controles_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/home/presentation/controles_test.dart),
[asistente_screen_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/features/asistente/asistente_screen_test.dart) y
[api_client_test.dart](https://github.com/SantiagoVillamilC/Vera/blob/b5ccc3bbb58c0d37cdded58cea9285d89d2518d1/test/core/network/api_client_test.dart).

## 7. Convenciones del repo

- Estado local con `setState`. Riverpod solo para el tema. No crees providers sin necesidad.
- Los repositorios se inyectan por constructor y el constructor sin argumentos debe seguir funcionando.
- Cada pantalla nueva agrega su ruta en `lib/app/router.dart`. Las rutas fuera de `/login*` y `/register*`
  son privadas.
- Sin comentarios salvo que el porqué no sea obvio. Los `.g.dart` no se editan.
- Dependencias nuevas con versión exacta, sin `^` ni `~`, justificadas en el mensaje del commit.
- Colores y estilos salen de los tokens de `lib/core/theme/app_theme.dart`. No se cambia el diseño VeraDark.
- Cada pantalla nueva lleva etiquetas `Semantics` y una prueba de widget a `TextScaler.linear(2.0)`.
- Alcance cerrado por decisión: sin vista de series recurrentes, sin proyección de saldo, sin presupuesto
  configurable y sin avisos push. No se inventan campos ni se recalculan reglas del backend en la app.

## 8. Límites conocidos

- La pestaña Movimientos guarda su filtro Ingresos como estado interno: abrirla ya filtrada no está resuelto,
  la tarjeta 03 propone `/inteligencia` como alternativa.
- La app no tiene pantalla de pagos recurrentes ni detalle de movimiento. Los destinos de la tarjeta 03 usan
  lo que existe.
- El detalle por id (`GET /v1/inteligencia/avisos/{id}`) no indica si el aviso está descartado, y el aviso no
  trae campo de vencimiento. La app lo sabe por la lista de donde lo sacó o por la respuesta del `POST`.
- Los descartados de meses anteriores no se pueden listar. `estado=descartados` cubre solo el mes en curso.
- La latencia de `/sintetizar` con mensajes largos no está medida con el modelo de producción: el audio
  degradado puede aparecer y es un camino normal.
- La API de producción (`veraapp.tech`) corre la versión V0 sin el núcleo financiero: desarrolla contra la API
  local con la base sembrada.
- Si el contrato no coincide con la API real, deja un comentario en la tarjeta con la petición, la respuesta
  recibida y lo que decía el contrato.

## 9. Cómo entregar

1. Un commit propio por tarjeta, con mensaje del tipo `feat(avisos): ...`, `fix(a11y): ...` o
   `docs(avisos): ...`. No mezcles dos tarjetas en un commit.
2. Antes de cada commit, `flutter analyze` sin hallazgos y `flutter test` completo en verde, no solo el
   archivo nuevo.
3. Escribe una prueba por cada criterio de aceptación de la tarjeta y nómbrala con ese criterio.
4. Deja el SHA del commit como comentario de la tarjeta, junto con la salida de `flutter analyze` y
   `flutter test`, y qué quedó fuera y por qué.
5. Abre el PR de la rama hacia `dev` y sigue el flujo `dev`, `staging`, `main`. Nunca se hace push directo a
   `staging` ni a `main`.

## 10. Verificación manual

Con el backend local arriba y la app apuntando a esa API:

1. Inicio: contador de avisos coincide con la bandeja, antes y después de descartar.
2. Bandeja: avisos del mes en curso (sin parámetros) y del mes anterior (`?mes=`), ordenados por prioridad y severidad.
3. Detalle: monto y fecha según el tipo, destino de la acción y ningún enlace de movimiento.
4. Descartar: sale de la lista, no reaparece al reiniciar la app y el 409 se revierte con el mensaje claro.
5. Sin red: error con reintento, nunca una lista vacía.
6. Asistente: escuchar reproduce el WAV, detener lo corta, sin audio suena la voz del teléfono.
7. Movimientos: chip de escalón con su etiqueta, abstención con estilo neutro, «Tu corrección» tras corregir.
8. Texto del sistema al máximo: ninguna pantalla desborda y la barra sigue operable.

Si algo de este documento no coincide con lo que ves en el repo o en la API, no lo implementes a ciegas:
comenta la diferencia en la tarjeta y sigue lo que indique la tarjeta, que es la fuente de verdad.
