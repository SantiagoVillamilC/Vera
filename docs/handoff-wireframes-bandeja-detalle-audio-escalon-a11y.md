# Handoff: avisos visibles, detalle, audio propio, escalón y accesibilidad

## 0. Encabezado

| Campo | Valor |
| --- | --- |
| Rama | `feat/wireframes-bandeja-detalle-audio-escalon-a11y` |
| Base | `origin/main` en `b5ccc3b` (rediseño VeraDark, PR #28) |
| Dueña | Laura (Valeria Rojas), frontend Flutter |
| Fecha | 2026-11-12 |
| Repo | `SantiagoVillamilC/Vera` |
| App | Flutter 3.47.2, Dart `^3.12`, Material 3, tema oscuro |

Alcance: seis tareas de frontend, `CF-A4-01` a `CF-A4-06`. Nada de backend, nada de ledger, nada de IA.
El trabajo es aditivo sobre `origin/main`. Las seis palabras de la rama son las seis tareas:
`wireframes`, `bandeja`, `detalle`, `audio`, `escalon`, `a11y`.

Regla dura: si algo de lo que este documento afirma no se puede verificar en la rama, no lo implementes
y pregunta. Todas las líneas citadas se verificaron en `b5ccc3b` con `git show` y `rg` el 2026-11-12.

---

## 1. Estado verificado

### 1.1 Repo y rama

- `origin/main` = `origin/dev` = `b5ccc3b`.
- El checkout local de trabajo (`Vera/`, rama `ci/analyze-excluye-generados`, `dc20e76`) está
  **12 commits atrás** de `origin/main`. No desarrolles ahí. Usa la rama nueva, que sale de `b5ccc3b`.
- La rama nueva vive en el worktree `/tmp/vera-handoff-laura` y ya trae copiados los wireframes en
  `docs/diseno/`. No se ha committeado todavía.
- `pubspec.yaml` no tiene reproductor de audio; solo `record` (`pubspec.yaml:43`) y `flutter_tts`
  (`pubspec.yaml:47`).
- Rutas existentes: `/home` (`lib/app/router.dart:98`), `/asistente` (`:106`), `/recargar`
  (`:126`), `/estadisticas` (`:133`), `/inteligencia` (`:137`).

### 1.2 Lo que ya existe en la app

| Pieza | Archivo y línea | Qué aporta |
| --- | --- | --- |
| Home con saludo, saldo, accesos y preview | `lib/features/home/presentation/home_screen.dart:214` (`_InicioTab`), `:298` (`_Saludo`), `:341` (`_TarjetaSaldo`), `:569` (`_AccesosCard`) | Dónde entra el aviso inline y la campana |
| Barra de navegación | `lib/core/widgets/barra_vera.dart:7` | Fija el escalado de texto en `:31-33` |
| Lista enriquecida con chip de categoría | `lib/features/inteligencia/presentation/movimientos_enriquecidos_screen.dart:355` (`_TileEnriquecido`), `:372-376` (origen como texto suelto), `:405` y `:453` (`_EtiquetaDeCategoria`), `:551` (`_SugeridaBadge`) | Base del chip de escalón |
| Modelo de movimientos y origen | `lib/features/inteligencia/data/modelos.dart:7-18` (enum), `:33-43` (etiquetas), `:79-82` (parse) | Traducción de origen, hoy incompleta |
| Repositorio de inteligencia | `lib/features/inteligencia/data/inteligencia_repository.dart:22-34` (movimientos), `:38-46` (resumen), `:51-67` (correcciones) | Patrón para el repo de avisos |
| Cliente HTTP | `lib/core/network/api_client.dart:86-106` (`post`, acepta `headers`), `:107-129` (`get`, **no** acepta `headers`) | Falta una ruta para bytes |
| Estados de pantalla | `lib/core/widgets/estado_vista.dart:17-52` (`cargando`, `vacio`, `sinRed`, `error`, `deError`) | Estados de la bandeja |
| Voz local | `lib/features/asistente/data/lector_voz.dart:17-63` (`LectorFlutterTts`) | Fallback de A4-04 |
| Chat y burbujas | `lib/features/asistente/presentation/asistente_screen.dart:25-57` (`_Burbuja`), `:117` (lector), `:470-484` (leer/detener), `:1168` (`_BurbujaView`) | Dónde va escuchar/detener |
| Estadísticas | `lib/features/home/presentation/estadisticas_screen.dart:18-54` (series de muestra), `:585` (gasto real por categoría) | Datos inventados de A4-06 |
| Tarjetas de muestra | `lib/core/format/tarjeta_muestra.dart:3-10` | Datos inventados de A4-06 |

### 1.3 Lo que no existe

- No hay pantalla, modelo, repo ni llamada de avisos. El endpoint no tiene consumidor.
- No hay pantalla de detalle de aviso.
- No hay reproductor de audio ni petición de bytes al backend.
- No hay chip del escalón; `origen_categoria` se pinta como texto de fecha (`:372-376`).
- No hay endpoint de detalle de aviso ni paginación ni filtro `estado` (eso es `CF-B-01` y `CF-B-02`,
  asignadas a Santiago y todavía pendientes).
- No hay endpoint ni UI de series recurrentes, y **no se va a crear** (decisión de alcance).

---

## 2. Recursos que ya hicimos y que debes usar

### 2.1 Wireframes (sí existen, están identificados)

| Recurso | Dónde está | Para qué |
| --- | --- | --- |
| `wireframes-avisos.html` | Copia versionable en esta rama: `docs/diseno/wireframes-avisos.html`. Original: `/home/chris/Documents/universidad-2026B/proyecto-fin-de-grado/wireframes-avisos.html` | Abre en el navegador: cuatro pantallas de baja fidelidad y la tabla de correspondencia con el contrato |
| `wireframes-avisos.png` | Copia versionable: `docs/diseno/wireframes-avisos.png` | La misma pieza como imagen, para la diapositiva |
| `ANALISIS-VIABILIDAD-2026-11-09.md` | `/home/chris/Documents/universidad-2026B/proyecto-fin-de-grado/` §2.2, §2.3, §2.4, §4 arreglo 1, Anexo A decisiones 7 y 10 | Por qué cada tarea existe y qué se cortó |
| `jira-cierre-funcional-2026-11-09.yaml` | Mismo directorio. Tarjetas `CF-A4-01` a `CF-A4-06` | Enunciado literal de cada tarjeta: contexto, criterios, horas |
| `cierre-funcional-tablero.html` | Mismo directorio | Tablero: 30 tarjetas, 12 completadas, 1 parcial, 17 pendientes |
| `GUION-SUSTENTACION-HABITOS-2026-10-31.md` | Mismo directorio | Cómo se cuenta el hábito en la sustentación |
| `videos-demo/GUION-RECORRIDO-APP-2026-10-28.md` | Mismo directorio | Recorrido pantalla por pantalla y datos de demo |
| `Backend_Vera/docs/escenario-demo.md` | Repo `Backend_Vera` | Siembra determinista: 50 movimientos y tres avisos |
| `Backend_Vera/api/openapi.yaml:942` y `:985` | Repo `Backend_Vera` | Contrato de listar y descartar |
| `Backend_Vera/api/openapi.yaml:3457` | Repo `Backend_Vera` | Esquema `InteligenciaAviso` |
| `Backend_Vera/api/openapi.yaml:1330` | Repo `Backend_Vera` | `POST /v1/vera/sintetizar` |
| `Backend_Vera/api/openapi.yaml:3245` | Repo `Backend_Vera` | `OrigenEnriquecido` (siete valores) |

### 2.2 Qué dicen los wireframes, en corto

Cuatro pantallas:

- **A. Inicio:** un aviso inline entre el saldo y los accesos, con monto y fecha; máximo uno.
  La campana con contador lleva al centro.
- **B. Centro de notificaciones:** una lista, sin pestañas ni filtros, ordenada por prioridad y
  severidad; descarte por deslizamiento o botón; tope de tres por mes.
- **C. Detalle:** explica el cálculo con `texto`, `porque`, `severidad_centavos` y `periodo`;
  acción principal según el tipo.
- **D. Vacío:** explica qué falta y no promete avisos que el sistema no puede sostener.

Tabla de correspondencia del HTML:

| Aviso | Dónde | Acción principal | Campos |
| --- | --- | --- | --- |
| `pago_no_alcanza` | Inicio + centro + detalle | Recargar | `titulo`, `texto`, `porque`, `severidad_centavos`, `periodo`, `transaccion_id` |
| `cobro_nuevo` | Centro + detalle | Ver movimiento | `titulo`, `texto`, `porque`, `periodo`, `transaccion_id` |
| `presupuesto_anticipado` | Centro + detalle | Ver resumen del mes | `titulo`, `texto`, `porque`, `periodo` |
| `categoria_sobre_media` | Centro + detalle | Ver categoría | `titulo`, `texto`, `porque`, `periodo` |
| `caida_ingreso` | Centro + detalle | Entendido | `titulo`, `texto`, `porque`, `periodo` |

Fuera de alcance por decisión: vista de series recurrentes, proyección de saldo, presupuesto
configurable por el usuario y avisos push. No las agregues.

### 2.3 Textos que el backend envía (literales)

`porque` y `accion` son constantes por tipo (`Backend_Vera/internal/inteligencia/avisos/texto.go:32`):

| Tipo | `porque` | `accion` |
| --- | --- | --- |
| `pago_no_alcanza` | Los pagos recurrentes de la ventana suman más que tu saldo. | Ver los pagos que vencen |
| `caida_ingreso` | El ingreso del último mes completo quedó por debajo de lo habitual. | Ver mis ingresos |
| `cobro_nuevo` | Apareció una llave recurrente que no estaba en tu historial. | Ver el cobro y su próximo vencimiento |
| `presupuesto_anticipado` | El gasto acumulado del mes supera lo habitual de tus meses completos. | Ver los gastos de este mes |
| `categoria_sobre_media` | El acumulado de esta categoría supera lo habitual de tus meses completos. | Ver los movimientos de esta categoría |

`titulo` y `texto` se generan por fila y traen montos y fechas. **No los compongas tú**: pinta lo que
llega. Ejemplos reales de plantilla (`texto.go:95-145`):

- `pago_no_alcanza`: «Tus próximos pagos suman más que tu saldo», «Tu saldo es $X y los pagos
  recurrentes que vencen desde YYYY-MM-DD suman $Z».
- `cobro_nuevo`: «Apareció un cobro nuevo», «Apareció un cobro de $X el YYYY-MM-DD y ya se repite o
  está declarado como recurrente».
- `caida_ingreso`: «Tu ingreso bajó», «El ingreso de <mes> fue $X. Lo habitual en tus meses
  anteriores es $Z».
- `presupuesto_anticipado`: «Tu gasto va por encima de lo habitual», «En <mes> llevas $X en gastos.
  Lo habitual en tus meses completos es $Z».
- `categoria_sobre_media`: «Gastas más en <categoría>», «En <mes> llevas $X en <categoría>. Lo
  habitual en esa categoría es $Z».

---

## 3. Contrato de avisos, al día

### 3.1 Listar

`GET /v1/inteligencia/avisos` (`openapi.yaml:942`)

- Autenticado con Bearer.
- Query opcional `mes=YYYY-MM`; por defecto el mes en curso. El periodo es el mes del hecho, no la
  fecha de entrega.
- Respuesta 200:

```json
{
  "success": true,
  "data": [
    {
      "id": "0f4e...-uuid",
      "tipo": "pago_no_alcanza",
      "clave": "pago-luz-2026-11",
      "periodo": "2026-11-20",
      "severidad_centavos": "5000000",
      "prioridad": 1,
      "titulo": "Tus próximos pagos suman más que tu saldo",
      "texto": "Tu saldo es $32.100 y los pagos recurrentes que vencen desde 2026-11-20 suman $50.000.",
      "porque": "Los pagos recurrentes de la ventana suman más que tu saldo.",
      "accion": "Ver los pagos que vencen",
      "transaccion_id": null,
      "creado_en": "2026-11-12T13:00:00-05:00"
    }
  ],
  "error": null,
  "meta": null
}
```

Reglas de formato:

- `severidad_centavos` es **string** de dígitos, no número. Convierte con `BigInt.parse`.
- `prioridad` es entero de 1 a 5.
- `periodo` es una fecha `YYYY-MM-DD`, no un mes.
- `transaccion_id` es UUID o `null`.
- `tipo` es uno de los cinco valores de la tabla de arriba.
- La bandeja devuelve **solo vigentes del mes**; los descartados salen de la lista.
- No hay límite ni cursor todavía. La siembra deja tres avisos como máximo, así que hoy cabe de sobra.

### 3.2 Descartar

`POST /v1/inteligencia/avisos/{id}/descartar` (`openapi.yaml:985`)

- Sin cuerpo.
- 200: `{"success":true,"data":{"id":"...","descartado_en":"..."},"error":null,"meta":null}`.
- Idempotente: repetir devuelve el mismo instante.
- 404 uniforme para ajeno e inexistente; 400 si el id no es UUID; 401 sin sesión; 429 cuota; 500/504.
- Descartar libera cupo: sale de la bandeja y deja de contar.

### 3.3 Cupo

`GET /v1/inteligencia/resumen` trae `cupo_avisos` (tope, hoy 3) y `avisos_emitidos` (vigentes del
mes, sin descartados), ambos enteros (`openapi.yaml:3398-3404`). El modelo
`ResumenDelMes` (`lib/features/inteligencia/data/modelos.dart:183-206`) hoy **ignora** esos dos
campos; extiéndelo con valores opcionales para mostrar el cupo sin romper la pantalla de
estadísticas.

### 3.4 Audio del asistente

`POST /v1/vera/sintetizar` (`openapi.yaml:1330`)

- Requiere sesión, consentimiento del asistente y cabecera `X-Vera-Token`.
- Cuerpo `{"texto":"..."}`, de 1 a 8192 bytes.
- 200 `audio/wav` (PCM16 mono 24 kHz) **o** 200 JSON degradado
  `{"audio_disponible":false,"voz_local":true}` con cabecera `X-Vera-Audio: no-disponible`.
- La app debe usar su voz local cuando llegue el JSON degradado o falle la reproducción.
- **Bloqueo conocido:** la app no tiene forma de obtener `X-Vera-Token`. La API lo compara con
  `VERA_VOZ_TOKEN`, que es un secreto de servidor (`internal/platform/httpserver/vera_sintesis.go:17`).
  Para la demo se puede pasar por `--dart-define=VERA_VOZ_TOKEN=...` (mismo valor del servidor), pero
  eso es deuda de seguridad, no solución. Pide al carril backend un token efímero por usuario o
  aceptar solo la sesión. Mientras tanto, deja A4-04 funcionando con un doble de prueba y un
  fallback local; no bloquees el resto.

### 3.5 Escalón

`GET /v1/inteligencia/movimientos` devuelve `origen_categoria` (siete valores:
`memoria`, `contraparte_interna`, `mcc`, `catalogo`, `lexico`, `tfidf`, `sin_categoria`) y, en la rama
`feat/cierre-ia` del backend, también `escalon` entero de 1 a 7 (`openapi.yaml:3245` y `:3237-3240`).
En `origin/main` del backend ese campo **todavía no está pusheado**; en la app debe ser opcional y
caer limpio cuando no venga.

Mapa recomendado del escalón, alineado con la cascada:

| Escalón | Señal | Etiqueta visible | Explicación |
| --- | --- | --- | --- |
| 1 | Memoria privada | Tu corrección | Lo confirmaste antes para este comercio |
| 2 | Contraparte interna | Contacto | Es alguien de la billetera |
| 3 | MCC | Comercio | Lo dijo el giro del comercio en el QR |
| 4 | Catálogo | Catálogo de marcas | La marca está en el catálogo curado |
| 5 | Léxico | Descripción | Lo dijo el texto del movimiento |
| 6 | TF-IDF | Clasificador | Lo dedujo el modelo de texto |
| 7 | Sin categoría | Sin categoría | Ninguna señal fue suficiente; es abstención, no error |

Nota: el enum `OrigenCategoria` de la app (`modelos.dart:7-18`) conserva `llm` y `manual`, que ya no
se escriben. No los borres a ciegas si hay datos viejos, pero no los presentes como señales nuevas.

---

## 4. Las seis tareas, una por una

Cada tarjeta se cierra con **su propio commit** y su SHA se anota en el YAML (`estado: completada`,
`evidencia: <sha>`). No mezcles dos tarjetas en un commit.

### 4.1 CF-A4-01 · Wireframes de avisos dentro del flujo actual (4 h)

**Objetivo.** Revisar y aprobar los wireframes que ya existen, no volver a dibujarlos.

**Ya está hecho.** `wireframes-avisos.html` con las pantallas A, B, C y D, la tabla de campos por
tipo y la nota de alcance. Está copiado en esta rama.

**Entregable.**
1. La revisión escrita, campo por campo, contra el contrato de la sección 3.
2. Correcciones al HTML si algo no cuadra. Sospechosos ya detectados: el wireframe habla de «Avisos 2»
   y de «junio»; el contrato no trae un contador aparte, el badge sale del largo de la lista; el
   periodo es una fecha, no un mes; el cupo es 3 y no todos los meses se llenan.
3. Una diapositiva que explique el flujo completo: Inicio, campana, bandeja, detalle y vacío.
4. Confirmación explícita de lo que **no** se hace: series recurrentes, proyección de saldo,
   presupuesto configurable, push.

**Criterios de aceptación.**
- Los wireframes cubren Inicio, centro, detalle y vacío.
- Cada campo dibujado existe en `InteligenciaAviso`.
- El flujo se explica en una diapositiva sin pantallas nuevas más allá de la bandeja.

**Dónde tocar.** `docs/diseno/wireframes-avisos.html` (si corriges), más el commit de la revisión.
No toques `lib/` en esta tarjeta.

**Prueba.** Abre el HTML en el navegador y compara la tabla con el JSON de la sección 3.1.

**Commit.** `docs(avisos): aprueba los wireframes y su correspondencia con el contrato`.

---

### 4.2 CF-A4-02 · Bandeja de avisos con badge y descarte (10 h)

**Objetivo.** Que el usuario vea los avisos que el backend ya calcula, los descarte y no reaparezcan.

**Ya está hecho.** Los cinco detectores, el listado y el descarte; `EstadoVista`; el patrón de
repositorio y pantalla de `movimientos_enriquecidos_screen.dart`.

**Entregable.**
1. Modelo `AvisoInteligencia` con `fromJson` tolerante: `severidad_centavos` string, `periodo` fecha,
   `transaccion_id` nullable, `tipo` desconocido no revienta.
2. `AvisosRepository` (o métodos en `InteligenciaRepository`) con `listar({String? mes})` y
   `descartar(String id)`.
3. `BandejaAvisosScreen` que use `EstadoVista.cargando`, `EstadoVista.vacio`, `EstadoVista.deError`
   con reintento.
4. Badge en `_Saludo` (`home_screen.dart:298`) con el número de vigentes; navega a `/avisos` y recarga
   al volver, igual que `_abrir` en el Home.
5. Descarte optimista: quita de la lista y revierte con aviso si el POST falla.
6. Indicador de cupo cuando `avisos_emitidos >= cupo_avisos`; para eso lee `resumen` y extiende
   `ResumenDelMes` con `cupoAvisos` y `avisosEmitidos` opcionales.
7. Ruta `/avisos` en `lib/app/router.dart`.

**Diseño recomendado.**
- Sigue el patrón de `MovimientosEnriquecidosScreen(repository: ...)`: inyecta el repo para las
  pruebas.
- No recalcules la regla en la app. Si el backend no manda un aviso, no lo inventes.
- Un solo `ListView` con tarjetas; no pestañas ni filtros, tal como el wireframe B.
- El badge debe ser independiente del contador de avisos del Home; no dupliques la consulta en cada
  reconstrucción.
- Con red caída muestra error y reintento, nunca lista vacía.

**Criterios de aceptación.**
- Con el escenario de siembra, la app muestra al menos un aviso por familia presente (hoy tres tipos:
  `caida_ingreso`, `cobro_nuevo`, `pago_no_alcanza`).
- Descartar quita el aviso de la lista y persiste tras reiniciar la app.
- Sin red, error con reintento.
- Badge correcto después de descartar y después de recargar el Home.

**Pruebas.**
- `test/features/inteligencia/data/avisos_modelos_test.dart`: parse completo, `transaccion_id` nulo,
  severidad string grande, tipo desconocido.
- `test/features/inteligencia/presentation/bandeja_avisos_screen_test.dart`: lista, vacío, error de
  red y reintento, descarte optimista y reversión.
- `test/features/home/presentation/home_aviso_test.dart`: badge y navegación, con repo falso.
- Usa `MockClient` de `package:http/testing` como en `inteligencia_repository_test.dart`, o un fake
  de repo por inyección.

**Commits.** `feat(avisos): agrega la bandeja con badge y descarte` y, si separas, un segundo para las
pruebas. Ideal: uno solo.

---

### 4.3 CF-A4-03 · Detalle del aviso y acciones (6 h)

**Objetivo.** Que abrir un aviso explique de dónde sale y qué puede hacer el usuario.

**Ya está hecho.** Todos los campos del detalle ya vienen calculados; solo falta la pantalla.

**Entregable.**
1. `DetalleAvisoScreen` con `titulo`, `texto`, `porque`, `periodo` y `severidad_centavos` formateados
   con `formatPesos(BigInt.parse(...))`.
2. Acciones por `tipo`, no por parsear la frase:
   - `pago_no_alcanza` → `/recargar`.
   - `cobro_nuevo` → `/inteligencia` (lista de movimientos) si hay `transaccion_id`; si no, sin enlace.
   - `categoria_sobre_media` → `/inteligencia`.
   - `presupuesto_anticipado` → `/estadisticas`.
   - `caida_ingreso` → `/inteligencia`.
   - Siempre: descartar desde el detalle, que actualiza lista y badge.
3. Estados: aviso vencido, aviso ya descartado y aviso de un mes anterior. Si no hay detalle por id
   todavía, muestra un estado claro en vez de una pantalla rota.
4. Ruta `/avisos/:id`. Recibe el objeto por `state.extra`; si `extra` falta (enlace directo o recarga),
   lista los avisos del mes y busca por id. Si no aparece, muestra «No encontramos este aviso» con
   volver.
5. El botón usa `accion` como etiqueta y el mapa por `tipo` como destino. No inventes rutas nuevas.

**Diseño recomendado.**
- Una sola pantalla que se adapta al tipo, no una por tipo.
- `transaccion_id == null` implica no pintar «Ver movimiento». Nunca un enlace muerto.
- No dependas de `CF-B-01`: cuando Santiago entregue `GET /v1/inteligencia/avisos/{id}`, cambia el
   fallback por la consulta directa; deja el código preparado con un método `obtener(id)` que hoy
   reusa el listado.
- Descartar desde el detalle debe regresar a la bandeja con la lista ya sin ese aviso.

**Criterios de aceptación.**
- Un `pago_no_alcanza` muestra monto y fecha y lleva a recargar.
- Un aviso sin `transaccion_id` no muestra enlace roto.
- Descartar desde el detalle actualiza bandeja y badge.
- La pantalla sobrevive a abrirla con un id directo (hoy, vía listado).
- Un aviso de un mes anterior o vencido se explica como tal.

**Pruebas.**
- `test/features/inteligencia/presentation/detalle_aviso_screen_test.dart`: tres acciones, aviso sin
  transacción, descarte, id inexistente, `extra` nulo.
- Reusa el fake de repo de A4-02.

**Commit.** `feat(avisos): agrega detalle del aviso con acciones por tipo`.

---

### 4.4 CF-A4-04 · Reproducción del audio propio del asistente (8 h)

**Objetivo.** Que suene el audio de Kokoro, no solo la voz del teléfono.

**Ya está hecho.** Grabación y envío de voz, `LectorFlutterTts` para el fallback, la respuesta del chat
con `texto` y el endpoint `POST /v1/vera/sintetizar` en el backend (`feat/cierre-ia`).

**Entregable.**
1. Dependencia de audio elegida y justificada en el commit: tamaño, licencia, Android e iOS. Pin exacto
   en `pubspec.yaml` con lockfile.
2. Método para pedir el WAV como bytes. `ApiClient.get` hoy no acepta cabeceras extra ni devuelve bytes
   (`api_client.dart:107-129`); agrega `postBytes` o una variante con `headers` que reuse `_request` y
   no intente parsear JSON cuando el `Content-Type` es `audio/wav`.
3. Servicio de reproducción (interfaz + implementación) para poder probar sin audio real.
4. Botón «Escuchar» y «Detener» en la tarjeta de respuesta del asistente (`_BurbujaView`, `:1168`),
    debajo del texto, con `Semantics` y etiquetas claras.
5. Al llegar la respuesta: si `_leerEnVozAlta` está activo, reproduce el WAV del backend; si el
   endpoint devuelve `audio_disponible:false` o falla, usa `LectorFlutterTts` y no muestra error
   alarmante.
6. Ciclo de vida: detener al salir de la pantalla, al grabar de nuevo, al pedir otra respuesta y al
   reproducir otro mensaje.
7. No bloquees por el token: implementa con un doble de prueba y deja el header configurable. Para la
   demo local usa `String.fromEnvironment('VERA_VOZ_TOKEN')` y documenta la deuda en el commit.

**Diseño recomendado.**
- Reproductor pequeño antes del primero que aparezca: `audioplayers` con `BytesSource` o `just_audio`
  con una fuente por bytes; ambos MIT. Evita el paquete de voz del sistema como reproductor.
- No descargues audio si el usuario no toca «Escuchar» y la preferencia de lectura está apagada.
- Cachea por `mensaje_id` o por hash del texto dentro de la sesión; repetir el mismo texto no debe
  volver a sintetizar.
- El audio se pide **aparte** del turno del chat: `RespuestaAsistente` no trae audio
  (`openapi.yaml:3992-4014`).

**Criterios de aceptación.**
- Un mensaje con audio del backend se reproduce dentro de la app.
- Con audio ausente, suena la voz local y se indica con discreción.
- Salir de la pantalla detiene el audio.
- `flutter analyze` y `flutter test` pasan con la dependencia nueva.
- La app no pide audio si no hay red o no hay sesión.

**Pruebas.**
- `test/features/asistente/audio_reproduccion_test.dart` con reproductor falso y endpoint falso:
  éxito, degradado JSON, 401, timeout, detener.
- Extiende `asistente_voz_test.dart` para el fallback.

**Commit.** `feat(asistente): reproduce el audio propio con fallback a la voz local`.

---

### 4.5 CF-A4-05 · Mostrar qué escalón decidió la categoría (4 h)

**Objetivo.** Convertir la cascada en algo señalable en la demo y la sustentación.

**Ya está hecho.** La traducción de origen a etiqueta (`modelos.dart:33-43`) y el chip de categoría
(`movimientos_enriquecidos_screen.dart:453`) con `onTap` que abre la corrección.

**Entregable.**
1. `escalon` opcional en `MovimientoEnriquecido.fromJson`; si no viene, se usa `origen_categoria`.
2. Mapa de escalón a etiqueta y explicación de la tabla de la sección 3.5.
3. Chip discreto en `_TileEnriquecido`, junto al chip de categoría (`:405`), con nombre legible y no
   el número crudo. Al tocar, muestra la explicación (hoja o tooltip accesible).
4. Abstención: `sin_categoria` se muestra como «Sin categoría» y se explica; nunca vacío ni como error.
5. Caída limpia si `escalon` no llega o está fuera de 1 a 7.

**Diseño recomendado.**
- Reutiliza `_EtiquetaDeCategoria` como base visual; no inventes otro sistema de chips.
- Mantén `origen_categoria` como fuente de verdad cuando `escalon` falta, y muestra el escalón cuando
   llega. Los siete escalones y los siete orígenes deben mapear al mismo vocabulario visible.
- Quita `origen` como texto de la línea de fecha si ahora vive en el chip; evita duplicarlo.
- No toques el backend; esto es solo presentación.

**Criterios de aceptación.**
- Un movimiento decidido por catálogo muestra «Catálogo de marcas».
- Un movimiento sin categoría muestra la abstención, no un valor vacío.
- Si el backend no envía `escalon`, la interfaz no se rompe y cae a `origen_categoria`.
- El chip tiene etiqueta semántica y se puede tocar con lector de pantalla.

**Pruebas.**
- Extiende `movimientos_enriquecidos_screen_test.dart` con `escalon` presente, ausente, `sin_categoria`
   y valor inválido.
- `test/features/inteligencia/data/modelos_escalon_test.dart` para el parse.

**Commit.** `feat(inteligencia): muestra el escalón que decidió la categoría`.

---

### 4.6 CF-A4-06 · Accesibilidad, escalado de texto y cortes declarados (4 h)

**Objetivo.** Que la app no desborde con texto grande y que deje de presentar datos inventados como
reales.

**Ya está hecho.** Tema y estilos centralizados, etiquetas semánticas en partes del Home y las gráficas,
y la identificación interna de las series de muestra (`estadisticas_screen.dart:18-54`) y de las
tarjetas (`tarjeta_muestra.dart:3-10`).

**Entregable.**
1. Quitar el candado de escalado de `BarraVera` (`barra_vera.dart:31-33`) o rehacer la barra para que
   crezca sin desbordar; es el punto más frágil.
2. Revisar a escala 2.0 las pantallas nuevas: bandeja, detalle, aviso inline y burbujas del audio.
3. Etiquetas semánticas en tarjetas de aviso, botón de escuchar, detener y descartar.
4. Marca visible de datos de muestra en estadísticas y tarjetas, o retirar la serie inventada de la
   vista pública. Si cuesta rotularla, quítala: es preferible a mentir.
5. Pruebas de widget con `textScaler: TextScaler.linear(2.0)`.

**Criterios de aceptación.**
- Con escala 2.0 ninguna pantalla nueva desborda (sin `RenderFlex overflow`).
- Las tarjetas de aviso y los controles de audio tienen etiqueta semántica.
- La app no presenta datos de muestra como si fueran del usuario.
- La barra de navegación sigue usable a escala 2.0.

**Pruebas.**
- `test/features/home/presentation/escala_texto_test.dart` con Home, bandeja y detalle a 2.0.
- Extiende `wip_controles_test.dart` si rotulas la muestra.
- Usa `flutter_test` con `tester.view.physicalSize` como en `home_screen_test.dart`.

**Commit.** `fix(a11y): soporta texto grande y declara los datos de muestra`.

---

## 5. Orden y dependencias

```
A4-01 wireframes
   └─ A4-02 bandeja + badge + descarte
         └─ A4-03 detalle + acciones

A4-05 escalón (independiente, toca otra pantalla)

A4-04 audio (puede empezar ya con dobles; requiere backend para la demo)
   └─ depende de A3-03, ya cerrada en Backend_Vera (08af2b1)

A4-06 accesibilidad (al final, cuando existan las pantallas nuevas)
```

Regla práctica: **A4-01 primero** porque aprueba el diseño; **A4-02** desbloquea casi todo; **A4-03**
después; **A4-05** en paralelo si sobra carril; **A4-04** en paralelo con un doble; **A4-06** al final.

---

## 6. Lo que no se toca

- Nada de `Backend_Vera`: ni contrato, ni handlers, ni migraciones. Si falta un endpoint, se pide.
- Nada de ledger, dinero, transferencias ni autenticación.
- No se crea vista de series recurrentes ni proyección de saldo.
- No se agregan pantallas nuevas fuera de la bandeja y el detalle.
- No se inventan campos ni se recalculan reglas del backend en la app.
- No se reescribe el diseño VeraDark ni se cambian tokens de color.
- No se toca `origin/main`; todo va en la rama nueva.
- No se hace push sin autorización de Christian.

---

## 7. Cómo trabajar con agentes

### 7.1 Regla de oro

Un agente por tarjeta, un worktree por agente, un commit por tarjeta. No dejes que dos agentes
escriban en el mismo checkout. No lances cinco agentes en paralelo sobre el mismo repo.

### 7.2 Preparación

```bash
cd ~/Documents/universidad-2026B/proyecto-fin-de-grado/Vera
git fetch origin
git worktree add -b feat/a4-02-bandeja /tmp/vera-a4-02 origin/main
cd /tmp/vera-a4-02
flutter pub get
flutter analyze
flutter test
```

Repite cambiando rama y carpeta por tarjeta. La rama general
`feat/wireframes-bandeja-detalle-audio-escalon-a11y` ya existe para el documento y los wireframes.

### 7.3 Prompt de arranque para el agente

Copia esto tal cual y cambia solo lo que está entre corchetes:

```text
Eres un agente de frontend Flutter en el repo Vera. Trabajas en un worktree limpio sobre
origin/main (b5ccc3b), rama feat/[TARJETA]. Lee primero AGENTS.md y CLAUDE.md.

Tarjeta: [CF-A4-XX, título].
Documento de contexto: docs/handoff-wireframes-bandeja-detalle-audio-escalon-a11y.md,
sección [4.X]. Léela completa antes de tocar código.

Objetivo: [una frase].
Entregables: [lista de la sección 4.X].
Criterios de aceptación: [lista].
Archivos que puedes tocar: [lista].
Archivos prohibidos: lib/app/router.dart solo para la ruta nueva; nada de backend.

Reglas:
1. No inventes campos ni endpoints. Usa el contrato de la sección 3.
2. No agregues dependencias salvo [la de audio, si aplica], y justifícala.
3. Escribe pruebas de widget/datos para cada criterio.
4. Al terminar corre flutter analyze y flutter test; pega la salida.
5. Haz un solo commit con el mensaje [mensaje].
6. Si algo no se puede verificar, detente y pregunta; no adivines.

Empieza leyendo los archivos citados y devuelve un plan de 5 líneas antes de editar.
```

### 7.4 Qué pedirle al agente al final

- Salida literal de `flutter analyze` y `flutter test`.
- `git diff --stat` y el SHA del commit.
- Qué criterios de aceptación cubrió y con qué prueba.
- Qué quedó fuera y por qué.
- Captura o descripción del estado visual, si aplica.

### 7.5 Revisión antes de aceptar

- El diff solo toca los archivos permitidos.
- No hay cambios de contrato ni de backend.
- No hay `print`, `TODO` ni código muerto.
- Las pruebas nombran el criterio que cubren.
- El commit cabe en una frase.

---

## 8. Definición de terminado

Una tarjeta está terminada cuando:

- `flutter analyze` devuelve «No issues found».
- `flutter test` pasa completo, no solo el archivo nuevo.
- Los criterios de aceptación de la sección 4 se cumplen y tienen prueba.
- No se tocó backend ni se agregaron rutas no pedidas.
- El commit está hecho en la rama de la tarjeta y el SHA se anotó en el YAML como `evidencia`.
- El tablero se regeneró (`python3 generar-tablero-cierre.py` en `proyecto-fin-de-grado`) si cambió
  el estado.

---

## 9. Verificación y demo

### 9.1 App

```bash
cd /tmp/vera-a4-XX
flutter pub get
flutter analyze
flutter test
flutter test test/features/inteligencia/presentation/bandeja_avisos_screen_test.dart
```

### 9.2 Backend y datos de demo

```bash
cd ~/Documents/universidad-2026B/proyecto-fin-de-grado/Backend_Vera
export DATABASE_URL='postgres://dueno:CLAVE@127.0.0.1:55437/vera_semilla_demo?sslmode=disable'
export DEMO_USUARIO='11111111-1111-4111-8111-111111111111'
export DEMO_FECHA='2026-11-19'
bash infra/local/sembrar-escenario-demo.sh
bash infra/local/sembrar-escenario-demo.sh
```

Esperado: 50 movimientos, 7 series maduras y tres avisos, `caida_ingreso=1`, `cobro_nuevo=1`,
`pago_no_alcanza=1`. La siembra es idempotente; la segunda corrida debe dar los mismos conteos.

Para entrar desde la app, prepara la credencial de demo con el flujo existente:

```bash
out/bin/login-demo -usuario <UUID> -celular 3001234567 -contrasena Vera-Demo-2026 -nombre 'Laura'
```

Si usas el backend completo, `./infra/local/demostrar.sh` levanta Postgres, Redis, migra, siembra,
emite avisos y deja la API en `:8080`.

### 9.3 Checklist manual

1. Home: campana con contador correcto.
2. Bandeja: tres avisos, orden por prioridad y severidad.
3. Detalle de `pago_no_alcanza`: monto, fecha, porqué y acción a recargar.
4. Detalle de `cobro_nuevo`: enlace al movimiento solo si hay `transaccion_id`.
5. Descartar: sale de la lista, badge baja, reiniciar app y sigue descartado.
6. Vacío: mensaje que explica, no lista en blanco.
7. Sin red: error con reintento.
8. Asistente: escuchar reproduce el WAV; detener corta; sin WAV suena la voz local.
9. Movimiento por catálogo: chip «Catálogo de marcas»; abstención: «Sin categoría».
10. Texto 2.0: ninguna pantalla nueva desborda.

---

## 10. Riesgos y cabos sueltos

| Riesgo | Estado | Qué hacer |
| --- | --- | --- |
| `X-Vera-Token` no lo puede obtener la app | Confirmado | Doble de prueba y `--dart-define` para la demo; pedir token efímero al backend |
| `GET /avisos/{id}` no existe | Confirmado | `CF-B-01` de Santiago; hoy pasar el objeto y buscar en el listado |
| Paginación y `estado` no existen | Confirmado | `CF-B-02`; hoy la lista cabe entera, no inventes cursor |
| `escalon` no está en `origin/main` del backend | Confirmado | Campo opcional y caída a `origen_categoria` |
| Enum `llm` y `manual` obsoletos | Confirmado | No presentarlos; no borrar si hay datos viejos |
| `BarraVera` fija el escalado en 1 | Confirmado (`barra_vera.dart:31-33`) | A4-06 lo corrige |
| Estadísticas y tarjetas con datos de muestra | Confirmado | A4-06 rotula o retira |
| `ApiClient.get` no acepta cabeceras ni bytes | Confirmado (`api_client.dart:107-129`) | A4-04 agrega la variante |
| Cupo real no está en `ResumenDelMes` | Confirmado | Extenderlo con campos opcionales |
| El checkout local está 12 commits atrás | Confirmado | Trabajar desde `origin/main` en worktrees |
| El backend tarda 45 s por turno y el audio es aparte | Documentado | No bloquear el turno por el audio |

---

## 11. Anexos

### 11.1 Archivos que tocará cada tarjeta

| Tarjeta | Archivos nuevos | Archivos existentes |
| --- | --- | --- |
| A4-01 | ninguno | `docs/diseno/wireframes-avisos.html` |
| A4-02 | `lib/features/inteligencia/data/avisos.dart`, `avisos_repository.dart`, `lib/features/inteligencia/presentation/bandeja_avisos_screen.dart`, `aviso_tarjeta.dart`; pruebas | `home_screen.dart`, `router.dart`, `inteligencia_repository.dart`, `modelos.dart` |
| A4-03 | `lib/features/inteligencia/presentation/detalle_aviso_screen.dart`; pruebas | `router.dart`, `bandeja_avisos_screen.dart` |
| A4-04 | `lib/features/asistente/data/reproductor_audio.dart`, `sintesis_repository.dart`; pruebas | `pubspec.yaml`, `api_client.dart`, `asistente_screen.dart` |
| A4-05 | pruebas | `modelos.dart`, `movimientos_enriquecidos_screen.dart` |
| A4-06 | pruebas | `barra_vera.dart`, `estadisticas_screen.dart`, `tarjeta_muestra.dart`, pantallas nuevas |

### 11.2 Contrato en una frase por campo

| Campo | Tipo | Uso |
| --- | --- | --- |
| `id` | UUID | Clave de lista, detalle y descarte |
| `tipo` | enum de 5 | Decide color, icono y destino de la acción |
| `clave` | string | Identidad del aviso; no se muestra |
| `periodo` | fecha `YYYY-MM-DD` | Se muestra como fecha, no como mes |
| `severidad_centavos` | string de dígitos | Monto de referencia; `BigInt.parse` |
| `prioridad` | 1 a 5 | Orden de la bandeja |
| `titulo` | string | Encabezado de la tarjeta |
| `texto` | string | Explicación del cálculo |
| `porque` | string | Causa técnica legible |
| `accion` | string | Etiqueta del botón; el destino sale de `tipo` |
| `transaccion_id` | UUID o null | Enlace al movimiento, solo si existe |
| `creado_en` | date-time | No se muestra; sirve para depurar |

### 11.3 Glosario mínimo

- **Aviso:** tarjeta calculada por el backend a partir de hábitos; no es push.
- **Bandeja:** la lista de avisos vigentes del mes.
- **Cupo:** máximo de avisos del mes; hoy 3; descartar libera cupo.
- **Escalón:** señal de la cascada que decidió la categoría, de 1 a 7.
- **Abstención:** `sin_categoria`; el sistema no afirmó nada, y eso es información.
- **Degradado:** respuesta 200 sin audio; la app usa su voz local.

### 11.4 Qué preguntar antes de desviarse

1. ¿Falta un endpoint? Pregunta a Christian, no lo simules con datos fijos.
2. ¿El wireframe contradice el contrato? Gana el contrato; corrige el wireframe.
3. ¿La acción no tiene pantalla destino? No inventes ruta; usa la lista o el resumen.
4. ¿El audio no está disponible? Fallback local; no bloquees el chat.
5. ¿Un campo nuevo? Primero el contrato, después la app.

---

## 12. Primer comando

```bash
cd /tmp/vera-handoff-laura && git status --short && ls docs/diseno && flutter --version
```

Debe mostrar la rama `feat/wireframes-bandeja-detalle-audio-escalon-a11y`, los dos archivos de
wireframes y Flutter 3.47.2. Si algo no coincide, para y reporta.
