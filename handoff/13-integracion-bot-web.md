# 13 · Integración bot de WhatsApp ↔ web

Rama `bot-web` (desde `zanqui-bot`). Objetivo: que los reportes que entran por Zanky BOT se vean en la web y que la
ida y vuelta (la C.R.A. cambia el estado → el ciudadano se entera) funcione. La app queda fuera por ahora.
Solo se tocó `bot/` y se trajo `datos/cra/manglar_cra_escala_1-5000.geojson` (el mismo archivo, byte a byte, que ya
está en `web-portada`). `web/` no se editó: lo que la web necesita está en la sección 5.

## 1. Flujo de datos

```
 Ciudadano (WhatsApp)
      │  mensajes
      ▼
 Meta Cloud API ──webhook──► Zanky BOT (bot/, Node en el VPS)
                               │ 1. ¿punto en la cobertura C.R.A. 1:5.000 o a ≤ RADIO_INFLUENCIA_M? si no, no hay reporte
                               │ 2. POST /rest/v1/rpc/crear_reporte  {p: fila del contrato, canal 'whatsapp'}
                               │    ← {id, nuevo, id_publico}   (idempotente por UUID; si falla, cola y reintento)
                               │ 3. cada SONDEO_ESTADOS_MS: POST /rpc/estado_de_reportes {ids}  ──► aviso por WhatsApp
                               ▼
                    Supabase byikwyyhdtxldoaahled (backend/supabase, esquema de main)
                      tabla reportes ── trigger recalcula zona, prioridad, confianza
                      vista reportes_publicos (id_publico, tipo, lat/lon a 3 decimales, hora en punto, estado, canal…)
                      RPC cambiar_estado (solo con sesión y rol del panel)
                               ▲                                   ▲
            GET reportes_publicos cada 20 s          cambiar_estado (pendiente en la web: sección 5)
                               │                                   │
                    Web pública mimanglar.sentralabs.co      Panel C.R.A. (web, con sesión)
```

## 2. Diagnóstico (antes de los arreglos)

| Pregunta | Respuesta | Evidencia |
|---|---|---|
| ¿Bot y web apuntan al mismo proyecto y al mismo contrato? | **Sí, si el `.env` del bot tiene el mismo `SUPABASE_URL`.** La web publicada lee `https://byikwyyhdtxldoaahled.supabase.co/rest/v1/reportes_publicos` (visto en el navegador, 27-nov). Los dos escriben con la RPC `crear_reporte` y la clave anon, con las mismas 23 columnas. | `bot/src/backend/supabase.ts` (`crearReporte`, `FilaReporte`); `origin/web-portada:web/src/lib/backend/supabase.ts` (`crearReporte`, `ReporteNuevo`). Ojo: `backend/supabase/schema.sql` en `zanqui-bot` es viejo (no tiene `crear_reporte` ni `id_publico`); el que vale es el de `main`. |
| ¿Un reporte de WhatsApp aparece en el mapa público, y con qué campos? | **Sí**, por la vista `reportes_publicos`: `id_publico, tipo, lat, lon (3 decimales), prioridad, estado, capturado_en (hora en punto), zona, municipio, canal='whatsapp'`. Sin descripción, foto ni reportante. **Pero** la web lo filtra con `enAreaDeReporte` midiendo contra sus 4 polígonos de sector (`poligonosManglar.json`), no contra la cobertura C.R.A.: un reporte válido a más de 500 m de esos 4 polígonos no se pinta. | `reportesStore.ts` → `deFila()` usa `sectorDePunto(f.lat, f.lon, sectores)`; `MapaEnVivo.tsx:53` filtra `enAreaDeReporte(r)`. |
| ¿Cómo se entera el bot de que la C.R.A. cambió un estado? | **De ninguna forma real.** Existía `PATCH /api/reportes/:codigo/estado` con `PANEL_API_KEY`, pero solo cambiaba la copia local del bot (no Supabase) y nadie lo llama: el panel de la web cambia el estado en memoria (modo demostración) y, en producción, debe hacerlo con `cambiar_estado`. «Mis reportes» sí leía el estado real con `estado_de_reportes`, pero solo cuando la persona lo pedía. | `bot/src/index.ts` (PATCH), `origin/web-portada:web/src/lib/reportesStore.ts` (`cambiarEstado` «solo modifica memoria»). |
| ¿La web puede consultar un caso por su código ZK-? | **No.** La vista no publica el id interno (a propósito: con él se leería el estado y la nota de reportes ajenos) y no hay RPC por código. El ZK- son 4 hex del UUID (65.536 valores, con choques): no sirve como llave. `web-ux` solo muestra el ZK- de lo enviado desde ese navegador. | `schema.sql` de main, comentario de la sección 6; `web/src/lib/comunidad/reportesLocales.ts` (`numeroDeCaso`). |
| ¿Coinciden estados, tipos, sectores y regla del área? | **Estados:** mismos ids; etiqueta distinta en `alerta_oficial`. **Tipos:** mismos ids; etiquetas y gravedad distintas. **Sectores:** no (tabla de la sección 6). **Área:** no; el bot pedía confirmar a más de 3 km y aceptaba igual; la web exige cobertura C.R.A. + 500 m. | `bot/src/reportes/modelo.ts`, `origin/web-portada:web/src/lib/catalogos.ts`, `web/src/lib/areaReporte.ts`. |

## 3. Arreglos del bot (rama `bot-web`)

1. **Área de reporte** (`geo/zonas.ts`): la ubicación se cruza con `AREA_REPORTE_GEOJSON` (C.R.A. 1:5.000, 886 polígonos).
   Dentro o a ≤ `RADIO_INFLUENCIA_M` (500 m), se acepta. Más lejos no se crea el reporte: «Ese punto queda fuera del manglar;
   si afecta a uno cercano, comparte la ubicación del manglar afectado», con botones *📍 Cambiar ubicación* / *🏠 Volver al menú*.
   Reemplaza la confirmación «a más de 3 km». Comprobado: Mallorquín (11.0412, −74.8706) dentro; centro de Barranquilla
   (10.9878, −74.7889) a 7.164 m, rechazado. También se lee el archivo de zonas v2 de `main` (con `unidad`), para que el bot no se
   rompa al unirse con main (las distancias salen iguales que con el GeoJSON).
2. **Aviso de cambio de estado** (`backend/avisos.ts`): sondeo de `estado_de_reportes` cada `SONDEO_ESTADOS_MS` (5 min) para los
   reportes enviados «con mi número» y no cerrados ni descartados. Avisa una vez por cambio, con la nota pública, y guarda
   `estadoAvisado` en la copia del bot (un reinicio no repite). Tres fallos seguidos (por ejemplo, fuera de la ventana de 24 h de
   WhatsApp) y se deja ese estado. Con backend conectado el `PATCH` del panel responde 409.
3. **Número de caso**: se guarda el `id_publico` que devuelve `crear_reporte`. Si se define `SEGUIMIENTO_URL`, el mensaje de envío
   y los avisos llevan `<SEGUIMIENTO_URL>#caso=<uuid>` (el uuid va en el fragmento, no viaja al servidor). Vacío: no hay enlace.
4. **Etiquetas**: tipos y estados con las etiquetas de `web/src/lib/catalogos.ts` (larga en resúmenes, corta en la lista).
5. **Primer mensaje**: si el texto ya describe una amenaza («están talando mangle en la ciénaga»: tala, quema, basuras, relleno,
   vertimiento, caño taponado, fauna), va directo a reportar con ese tipo y ese texto como descripción (pide antes el
   consentimiento). Las preguntas y lo de jornadas siguen al menú o a la IA. El saludo abre el menú; el registro de vigía se
   ofrece **después** del envío.

`npm run build` y `npm run simular` pasan (la simulación cubre el primer mensaje con amenaza, el registro después, el punto en
Barranquilla rechazado, la caída del backend con reintento y dos cambios de estado avisados una sola vez cada uno).

## 4. Prueba de punta a punta (bot → Supabase → web)

**Hecha el 27-nov-2026 a las 13:39 (hora de Colombia; 18:39:02 UTC). Caso `ZK-0A6B`.**

- El bot (conversación real en modo simulación de WhatsApp, credenciales del `.env` del bot en el VPS, mismo proyecto
  `byikwyyhdtxldoaahled` que la web) creó el reporte con `crear_reporte`: tala, sin foto, anónimo, descripción
  «PRUEBA de integración — descartar», en 11.0412, −74.8706. Servidor: `nuevo`, prioridad 5, estado `recibido`.
- Id interno `0a6bc25b-127f-515f-8b00-856e55c28316` · id público `ea5ec438-cb9f-45b8-a67c-b981ae42c112`.
- `reportes_publicos` lo devuelve: `tipo tala, lat 11.041, lon -74.871, estado recibido, canal whatsapp,
  capturado_en 18:00 UTC (hora en punto), zona mallorquin, municipio Barranquilla – Puerto Colombia`.
- En https://mimanglar.sentralabs.co/ (que lee esa vista de ese proyecto) aparece en la lista en vivo como
  «Tala o corte de mangle · Mallorquín · en la última hora · RECIBIDO». La portada no muestra el canal; el dato sí lo trae.
- **Pendiente: que la C.R.A. (o quien tenga rol en el panel) descarte `ZK-0A6B`** con `cambiar_estado` → `descartado`.
  No se puede desde la clave pública.

Pasos para repetirla (desde `bot/`):

1. `bot/.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` del proyecto de la web (git ignora `bot/.env`: `.gitignore:2`).
2. `npm run prueba:real -- --si` → recorre la conversación real (sin mandar nada a WhatsApp) y crea UN reporte «PRUEBA de
   integración — descartar» (tala, sin foto, anónimo) en Mallorquín. Imprime hora, ZK-, id interno, id público y la fila de
   `reportes_publicos`.
3. Abrir https://mimanglar.sentralabs.co/ (la web relee cada 20 s) y buscar el punto de tala en Mallorquín con canal WhatsApp.
4. **Pedir a la C.R.A. que lo descarte** en el panel (`cambiar_estado` → `descartado`): así sale de la vista pública.

## 5. Lo que tiene que hacer la web para cerrar el ciclo

- **Consulta del caso** (página de seguimiento, la construye `web-ux`): leer `location.hash` (`#caso=<uuid>`), llamar
  `estado_de_reportes([uuid])` con la clave anon y mostrar `ZK-` + 4 hex del uuid, estado (etiqueta y descripción de
  `catalogos.ts`), nota pública, fecha, y resaltar en el mapa el `id_publico`. No hace falta tocar el esquema. **No** crear una
  RPC por código ZK- solo: 4 hex se recorren en minutos. Cuando exista, poner su URL en `SEGUIMIENTO_URL` del bot.
- **Panel con sesión**: iniciar sesión (Supabase Auth) con rol en `panel_roles`, leer la tabla `reportes` completa (la política
  `reportes_panel_lee` lo permite), ver foto con `url_foto` + URL firmada, y cambiar estado con
  `rpc/cambiar_estado {p_id, p_estado, p_nota, p_nota_publica}`. Hoy el panel cambia el estado solo en memoria.
- **Mapa**: filtrar por área con la cobertura C.R.A. (`/datos/manglar-cra.geojson`), no con los 4 polígonos de sector, para que
  no se oculten reportes que el bot y el servidor aceptan.
- **Aviso al bot**: no hace falta para el MVP (el bot sondea cada 5 min). Si se quiere inmediato, después: un Database Webhook
  de Supabase (o una Edge Function) sobre `historial_estado` que haga `POST` al bot con un secreto, y el bot avisa al momento.
  El sondeo se queda como respaldo.
- **WhatsApp fuera de 24 h**: para avisar días después hace falta una plantilla aprobada por Meta (`estado_reporte`). Sin ella,
  el aviso solo llega si la persona escribió en las últimas 24 h; el estado siempre se ve en «Mis reportes».

## 6. Diferencias que quedan (no se resolvieron a ciegas)

| Qué | Bot / servidor / app | Web | Quién decide |
|---|---|---|---|
| Ids de sector | `mallorquin`, `tubara`, `juan_de_acosta`, `piojo` (contrato y `zonas` del servidor) | `mallorquin`, `balboa`, `manaties`, `totumo` (`poligonosManglar.json`) | Equipo, con la C.R.A. |
| Nombre de sector | Ciénaga de Mallorquín · Costa de Tubará · Costa de Juan de Acosta · Ciénaga del Totumo (app en main: `sectorCra` Mallorquín · Balboa · Manatíes · Totumo) | Portada (`poligonosManglar.json`): Mallorquín · Balboa · Manatíes · Totumo. Nombres de la C.R.A. en `origin/web:web/src/lib/workflow.ts`: Mallorquín – Bocas de Ceniza · Puerto Colombia – Balboa – Puerto Velero · Tubará – Juan de Acosta · Totumo – Astilleros – Galerazamba (handoff/11: «Manatíes» es una ciénaga, no un sector) | Equipo, con la C.R.A. |
| Municipio | Barranquilla – Puerto Colombia · Tubará · Juan de Acosta · Piojó | Barranquilla · Puerto Colombia y Tubará · Tubará y Juan de Acosta · Piojó | Equipo |
| Gravedad de tipo | caño taponado 4, fauna 4, otro 2 (servidor) | 3, 3, 1 | Vale la del servidor; la web solo la muestra |
| Etiqueta `alerta_oficial` | ahora «Alerta oficial» (igual) | «Alerta oficial» | — |
| Área para pintar en el mapa | cobertura C.R.A. 1:5.000 + 500 m | 4 polígonos de sector + 500 m | Web (sección 5) |

## 7. Variables de entorno del bot (solo nombres)

`PORT`, `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_VERIFY_TOKEN`, `META_APP_SECRET`, `GRAPH_API_VERSION`,
`PANEL_API_KEY`, `HASH_SALT`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `JORNADAS_URL`, `DATA_DIR`, `ZONAS_GEOJSON`,
`AREA_REPORTE_GEOJSON` (nueva), `RADIO_INFLUENCIA_M`, `SONDEO_ESTADOS_MS` (nueva), `SEGUIMIENTO_URL` (nueva),
`OPENAI_API_KEY`, `OPENAI_MODEL`, `OPENAI_BASE_URL`, `CHAT_WEB`, `CHAT_ORIGENES`, `CHAT_POR_IP`, `CHAT_POR_HORA`.
En el VPS hay que copiar `datos/cra/manglar_cra_escala_1-5000.geojson` junto al bot (o apuntar `AREA_REPORTE_GEOJSON`); si
no está, el bot avisa en el log y mide el área contra `ZONAS_GEOJSON`.

## 8. Lo que falta para la app

- Usar la misma regla de área (cobertura C.R.A. + 500 m) antes de enviar; en main ya carga la capa 1:5.000.
- Seguimiento: la app guarda el uuid y ya consulta `estado_de_reportes`; puede abrir la misma página de seguimiento de la web
  con `#caso=<uuid>`.
- Avisos: notificación local al ver un cambio en `estado_de_reportes` (la app no tiene WhatsApp ni push del servidor).
- Mismas etiquetas de tipo/estado que la web y los mismos nombres de sector, cuando el equipo decida la tabla de la sección 6.
