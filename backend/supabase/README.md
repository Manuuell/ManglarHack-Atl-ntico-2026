# Backend de Zanky (Supabase)

Base de datos con PostGIS, reglas de seguridad, funciones del panel y almacenamiento de fotos del reto
**Manglar Hack Atlántico 2026**. Es lo que conecta la app (Flutter), el panel de la CRA (web) y el bot de WhatsApp.

> Este repo es **público**. Aquí no hay claves ni valores reales: solo nombres de variables (`../.env.example`).

## Archivos

| Archivo | Para qué |
|---|---|
| `schema.sql` | Todo el esquema: tablas, trigger de recepción, auditoría, roles, RPC, RLS, storage, datos abiertos. Idempotente. |
| `generar_zonas.mjs` | Lee `app/assets/datos/manglar_zonas.json` y `prioridades_cra.json` y escribe `zonas-N.sql` y `prioridades-N.sql` en partes de ≤ 900 KB (`node backend/supabase/generar_zonas.mjs`). Es la única fuente: no hay `zonas.sql` ni `prioridades.sql` de una pieza. |
| `zonas-1.sql` … `zonas-3.sql` | Las 4 zonas del manglar del Atlántico, capa oficial de la CRA a escala 1:5.000 (649,66 ha, 886 polígonos) como `MultiPolygon`. Generados. |
| `prioridades-1.sql` … `prioridades-6.sql` | Prioridades de conservación de la CRA (Alta/Media/Baja): 458 filas, 9.274 polígonos. La 1 crea la tabla y la vacía; las demás solo insertan. Generados. |
| `seed_demo.sql` | 15 reportes de **demostración** (`[DEMO] …`). Opcional; no son datos reales. |
| `../.env.example` | Nombres de las variables. |

## 1. Crear el proyecto (gratis)

1. Entra a <https://supabase.com>, crea una cuenta y un proyecto nuevo (plan Free). Región cercana (p. ej. São Paulo). Guarda la
   contraseña de la base de datos en tu gestor de contraseñas, no en el repo.
2. En **Settings → API** copia la **Project URL** y la clave **anon**. La **service_role** es secreta: solo para el bot.
3. **SQL Editor → New query**, pega y ejecuta **en este orden**, un archivo por consulta y cada uno entero (ninguno pasa de 900 KB,
   que es lo que aguanta el editor; si te pide confirmar el `delete` de `prioridades-1.sql`, confírmalo: es la tabla vacía de esa carga):

   | # | Archivo | Peso | Qué hace / qué debe decir al final |
   |---|---|---|---|
   | 1 | `schema.sql` | 56 KB | Todo el esquema. Termina sin error. |
   | 2 | `zonas-1.sql` | 463 KB | Inserta zonas (sin comprobación al final). |
   | 3 | `zonas-2.sql` | 612 KB | Inserta zonas. |
   | 4 | `zonas-3.sql` | 363 KB | Última: `zonas_cargadas = 4`, `hectareas ≈ 649,7`. |
   | 5 | `prioridades-1.sql` | 894 KB | Crea `prioridades_cra` si falta, la **vacía** e inserta. |
   | 6 | `prioridades-2.sql` | 898 KB | Solo inserta. |
   | 7 | `prioridades-3.sql` | 894 KB | Solo inserta. |
   | 8 | `prioridades-4.sql` | 893 KB | Solo inserta. |
   | 9 | `prioridades-5.sql` | 898 KB | Solo inserta. |
   | 10 | `prioridades-6.sql` | 251 KB | Última: `filas = 458`, `poligonos = 9274`. |
   | 11 | `seed_demo.sql` | 10 KB | Opcional, solo para demostrar: 15 reportes `[DEMO]`. Muestra los reportes por zona. |

   `ia.sql` (IA en la validación) va aparte, cuando se despliegue la función (ver «IA en la validación»).
   Las partes de `zonas-N` y `prioridades-N` se pueden repetir sin duplicar nada (zonas: *upsert*; prioridades: la parte 1 vacía y
   las otras vuelven a llenar). Si repites prioridades, corre **todas** las partes, empezando por la 1. Si una parte se cae a la mitad,
   vuelve a pegar desde `prioridades-1.sql`. Mientras `prioridades_cra` esté vacía, el servidor no suma la prioridad de conservación
   (los reportes no fallan; solo les falta ese +1 en los puntos de prioridad Alta).
4. Si cambian los polígonos: `node backend/supabase/generar_zonas.mjs` (reescribe las partes y borra las viejas) y vuelve a pegarlas en orden.
   También sirve `psql "$SUPABASE_DB_URL" -f archivo.sql` por archivo.

### Cómo comprobar que cargó

En el SQL Editor (una consulta por bloque):

```sql
select count(*) as zonas from public.zonas;                                  -- 4
select round((sum(ST_Area(geog)) / 10000)::numeric, 1) as hectareas from public.zonas;   -- ~649,7
select count(*) as filas, sum(ST_NumGeometries(geom)) as poligonos from public.prioridades_cra;   -- 458 y 9274
select count(*) as reportes_demo from public.reportes where descripcion like '[DEMO]%';  -- 15 (si cargaste seed_demo.sql)
```

Prueba de `crear_reporte` con un punto válido (dentro del manglar de Mallorquín; el UUID es de prueba) y otro en Bogotá:

```sql
select public.crear_reporte(jsonb_build_object(
  'id', '99999999-0000-4000-8000-000000000001', 'tipo', 'basuras', 'lat', 11.05617, 'lon', -74.84053,
  'capturado_en', now()::text, 'descripcion', '[PRUEBA] borrar'));
-- debe responder {"id": ..., "nuevo": true, "id_publico": ...}; el mismo id otra vez responde "nuevo": false.

select public.crear_reporte(jsonb_build_object(
  'id', '99999999-0000-4000-8000-000000000002', 'tipo', 'basuras', 'lat', 4.65, 'lon', -74.07,
  'capturado_en', now()::text));
-- debe fallar: punto_fuera_del_atlantico: el punto queda fuera del departamento del Atlántico
```

Y para ver lo que calculó el servidor con el de prueba (zona, dentro del polígono y prioridad):

```sql
select zona, municipio, dentro_poligono, distancia_m, prioridad from public.reportes
 where id = '99999999-0000-4000-8000-000000000001';
```

Para borrar la prueba, mismo procedimiento que para quitar la demostración (el historial es solo-INSERT; ver el encabezado de `seed_demo.sql`),
cambiando el filtro por `descripcion like '[PRUEBA]%'`.

## 2. Crear el primer administrador

1. **Authentication → Users → Add user** (correo y contraseña; marca «Auto Confirm User»).
2. En el SQL Editor (corre como `postgres`):

```sql
insert into public.panel_roles (user_id, rol)
select id, 'admin' from auth.users where email = 'TU-CORREO@ejemplo.com';
```

Desde ahí el admin da y quita roles con `asignar_rol` / `revocar_rol` (RPC). Cada cambio de rol queda en `auditoria`.
Roles: `admin`, `moderador_cra`, `vigia` (verifica, nada más), `aliado` (colegios y aliados: **no** ve reportes; solo
sirve para lo de eventos de la web).

## 3. Variables

**App Flutter** (la clave anon es pública; la protegen las reglas):

```bash
flutter run --dart-define=ZANKY_API=$SUPABASE_URL --dart-define=ZANKY_ANON=$SUPABASE_ANON_KEY
```

**Web (panel y vista pública):** la URL y la clave **anon** del proyecto, con el nombre que use su herramienta
(por ejemplo `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`). El panel inicia sesión con Supabase Auth (correo y contraseña) y
usa el JWT del usuario. **La `service_role` nunca va en la web ni en la app.**

**Bot de WhatsApp / scripts del servidor:** `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en un `.env` local (no se sube).

## 4. Qué es público y qué no

| Quién | Puede | No puede |
|---|---|---|
| **Cualquiera** (clave anon) | Crear un reporte (solo con `crear_reporte`); subir `evidencias/<uuid>.jpg`; consultar el estado de **sus** ids; leer la vista `reportes_publicos`; bajar datos abiertos; leer las zonas | Leer la tabla `reportes`, ver fotos, ver descripciones, ver quién reportó |
| **vigia** | Leer la cola de reportes; `en_verificacion` y `verificado`; ver fotos y fichas (auditado) | Alerta oficial, descartar, ver el reportante, gestionar roles |
| **moderador_cra** | Todo el flujo de estados, descartar, abrir expediente, ver el reportante (auditado) | Gestionar roles, leer la auditoría |
| **admin** | Todo lo anterior + roles + leer la auditoría | Modificar o borrar la auditoría (nadie puede) |
| **aliado** | Nada de reportes | — |

Lo que nunca sale al público: el **id interno** del reporte (con él se consulta el estado y de él sale el número de caso
ZK-XXXX), descripción, foto, `foto_hash`, `reportante_id`, metadatos de foto, coordenadas exactas (la vista las redondea a
3 decimales, unos 110 m) y la hora exacta (la vista la da en punto). La vista y los datos abiertos usan `id_publico`, otro UUID al
azar sin relación con el id interno.

## 5. RPC y endpoints

Con `SUPABASE_URL` y `ANON` como variables de entorno (nunca pegues los valores en el repo).

| Qué | Quién | Llamada |
|---|---|---|
| `crear_reporte(p jsonb)` | anon | `POST /rest/v1/rpc/crear_reporte` con `{"p": {...}}` → `{id, nuevo, id_publico}` |
| Subir foto | anon | `POST /storage/v1/object/evidencias/<id>.jpg` |
| `estado_de_reportes(ids)` | anon | `POST /rest/v1/rpc/estado_de_reportes` (devuelve también `id_publico`) |
| `reportes_publicos` | anon | `GET /rest/v1/reportes_publicos` |
| `datos_abiertos_geojson()` | anon | `POST /rest/v1/rpc/datos_abiertos_geojson` |
| `datos_abiertos_kml()` | anon | `POST /rest/v1/rpc/datos_abiertos_kml` |
| CSV abierto | anon | `GET /rest/v1/reportes_publicos` con `Accept: text/csv` |
| `mi_rol()` | sesión | `POST /rest/v1/rpc/mi_rol` |
| `cambiar_estado(p_id, p_estado, p_nota, p_nota_publica)` | panel | `POST /rest/v1/rpc/cambiar_estado` |
| `ver_reporte(p_id)` | panel | `POST /rest/v1/rpc/ver_reporte` (audita `miro_reporte`) |
| `ver_reportante(p_id)` | moderador, admin | `POST /rest/v1/rpc/ver_reportante` (audita `miro_reportante`) |
| `url_foto(p_id)` | panel | `POST /rest/v1/rpc/url_foto` (audita `miro_foto`) y luego Storage firma la URL |
| `asignar_rol(p_user, p_rol)` / `revocar_rol(p_user)` | admin | `POST /rest/v1/rpc/...` |
| Cola del panel | panel | `GET /rest/v1/reportes?select=<columnas>` (ver nota) |

Los parámetros de las RPC del panel llevan prefijo `p_` (para no chocar con los nombres de columnas).

```bash
# Crear un reporte (lo que hace la app). El servidor recalcula zona, prioridad, estado y hora de recepción.
# Responde 200 {"id":..., "nuevo": true|false, "id_publico": ...}. Repetirlo da nuevo=false y una sola fila.
# Un dato inválido da 400 con «motivo: explicación» (p. ej. punto_fuera_del_atlantico): la app no lo reintenta.
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/crear_reporte" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"p":{"id":"11111111-2222-4333-8444-555555555555","canal":"web","tipo":"tala","descripcion":"Prueba",
       "lat":11.056,"lon":-74.84,"capturado_en":"2026-11-27T15:00:00Z","momento":"ahora","magnitud":"pequena"}}'

# Estado de mis reportes (máx. 100 ids)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/estado_de_reportes" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"ids":["11111111-2222-4333-8444-555555555555"]}'

# Mapa público
curl -s "$SUPABASE_URL/rest/v1/reportes_publicos?select=*&order=capturado_en.desc&limit=50" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON"

# Datos abiertos: CSV (directo de PostgREST), GeoJSON y KML (licencia CC BY 4.0)
curl -s "$SUPABASE_URL/rest/v1/reportes_publicos?select=id_publico,capturado_en,tipo,municipio,zona,prioridad,estado,lat,lon,canal" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Accept: text/csv" -o zanky_reportes.csv
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/datos_abiertos_geojson" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -o zanky_reportes.geojson
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/datos_abiertos_kml" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" | jq -r . > zanky_reportes.kml   # llega como cadena JSON

# Panel (JWT = access_token del usuario que inició sesión, NO la clave anon)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/cambiar_estado" \
  -H "apikey: $ANON" -H "Authorization: Bearer $JWT_PANEL" -H "Content-Type: application/json" \
  -d '{"p_id":"<uuid>","p_estado":"en_verificacion","p_nota":"Llamé al vigía","p_nota_publica":"Un vigía lo está revisando"}'

# Foto: 1) autoriza y audita; 2) pide la URL firmada a Storage (60 s)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/url_foto" \
  -H "apikey: $ANON" -H "Authorization: Bearer $JWT_PANEL" -H "Content-Type: application/json" -d '{"p_id":"<uuid>"}'
curl -s -X POST "$SUPABASE_URL/storage/v1/object/sign/evidencias/<uuid>.jpg" \
  -H "apikey: $ANON" -H "Authorization: Bearer $JWT_PANEL" -H "Content-Type: application/json" -d '{"expiresIn":60}'
```

**Estados válidos** (`cambiar_estado`): `recibido → en_verificacion → verificado → alerta_oficial → en_atencion → cerrado`, de uno en
uno; a `descartado` desde cualquier estado abierto (solo moderador y admin, con nota); `descartado → en_verificacion` reabre.
`alerta_oficial` genera el expediente `CRA-MH-AAAA-NNNN`. `descartado` y `cerrado` exigen nota.

**Cola del panel:** la lectura directa de `reportes` está permitida solo a roles activos y **no incluye `reportante_id`**, así que
`select=*` falla: lista las columnas (`id,tipo,descripcion,lat,lon,estado,prioridad,confianza,capturado_en,recibido_en,zona,municipio,
dentro_poligono,distancia_m,corroboraciones,foto_url,expediente,nota_publica,ia_tipo_detectado,ia_confianza,ia_motivo,sincronizado_tarde`).

**Tiempo real:** `reportes` está en la publicación `supabase_realtime`. Realtime respeta RLS: solo el panel con rol recibe eventos.
**Al reconectar el canal el panel debe RELEER toda la lista**, porque lo ocurrido mientras estaba desconectado no se reenvía.
(Los eventos llevan las columnas de la fila completa; como solo los reciben roles del panel, no cambia quién puede verlas.)

## 6. Decisiones de seguridad y por qué

1. **Un solo guardián, `panel_rol_de(uid)`.** Lee la tabla `panel_roles` y no el token: quitar un rol (o `activo=false`) cierra el
   acceso en la siguiente llamada aunque la sesión siga viva. Todas las políticas y RPC pasan por ahí. Solo puedes preguntar por ti
   mismo (nadie puede listar quién es admin).
2. **El servidor no se fía del cliente.** El trigger `BEFORE INSERT` recalcula zona, municipio, `dentro_poligono`, `distancia_m`,
   `prioridad`, `corroboraciones`; fuerza `estado='recibido'` y `recibido_en=now()`; anula `ia_*`, `expediente` y `nota_publica`;
   acota la `confianza` (máx. 80 del teléfono, +10 por corroboración); solo acepta `foto_url = evidencias/<su id>.jpg`; recorta la
   descripción a 1000 puntos de código y corrige a `now()` una hora de captura en el futuro o anterior a 2020. Además, `anon` **no
   tiene ningún permiso sobre la tabla**: crea reportes solo con `crear_reporte(p jsonb)` (SECURITY DEFINER, `search_path` fijo), que
   valida el contrato e inserta con `ON CONFLICT (id) DO NOTHING`. Antes se insertaba directo con `Prefer: resolution=ignore-duplicates`:
   ese `ON CONFLICT` exige SELECT y, con SELECT, Postgres aplica las políticas SELECT de RLS a la fila nueva; como `anon` no tiene
   ninguna, todo reporte fallaba con 42501.
3. **El público solo escribe.** No hay política de SELECT para `anon` en `reportes`. Lo público sale de una vista (`reportes_publicos`)
   sin id interno, descripción, foto ni reportante, con coordenadas a ~110 m, hora en punto y sin descartados. Los ids internos son
   UUID que no se publican en ninguna parte: `estado_de_reportes` solo responde por los que se le pasan (máx. 100).
4. **Auditoría solo-INSERT.** Sin permisos de UPDATE/DELETE para nadie por la API, y un trigger impide modificar o borrar (ni el
   dueño por error). Registra quién, qué, sobre qué, cuándo y detalle, incluidos `miro_foto`, `miro_reporte` y `miro_reportante`.
   Las funciones del panel auditan **dentro de la misma transacción**: si la auditoría falla, la acción no ocurre.
5. **Fotos privadas con rastro obligatorio.** El bucket es privado (5 MB, jpeg/png/webp). `anon` solo puede subir
   `<uuid>.jpg` (y reemplazarla 7 días, para reintentos). Leerla exige haber pasado por `url_foto()` en los últimos 2 minutos, así
   que no se puede ver una foto sin dejar `miro_foto`, ni llamando a Storage directo. SQL no puede firmar URLs: lo hace Storage.
6. **Funciones sin EXECUTE por defecto.** Supabase concede EXECUTE a `anon` en todo lo nuevo; aquí se revoca y se concede función por
   función. Todas llevan `set search_path` fijo (contra secuestro de funciones).
7. **Anti-spam por capas.** Trigger: máx. 10 reportes por hora por `reportante_id` (HTTP 429). Los **anónimos
   (`reportante_id` nulo) no se limitan en la base**: ese límite va en el borde (reglas de tasa por IP de Cloudflare, o una Edge Function
   delante). Un `reportante_id` lo elige el cliente, así que es un freno suave, no una defensa contra un atacante decidido; la defensa
   real es que **una persona decide** antes de cualquier alerta oficial.
8. **Reintentos sin duplicar.** El `id` lo genera el teléfono; un reintento responde `nuevo: false`, no duplica y no gasta el límite.
9. **Roles mínimos.** El vigía solo llega a `verificado`; descartar y abrir expediente son del moderador/admin; el aliado no ve reportes.
10. **Protección del que denuncia.** Anónimo real (`reportante_id` se borra si `anonimo`), `reportante_id` fuera de la lectura del panel
    salvo `ver_reportante()` (auditado), coordenadas a 3 decimales en lo público.

## 7. Pendientes y límites (dichos con honestidad)

- **No se ha ejecutado contra una base real** (no hay Postgres aquí): el SQL está revisado a mano para Postgres 15 + PostGIS 3.
  Hay que correr `schema.sql`, `zonas-N.sql`, `prioridades-N.sql`, `seed_demo.sql` y la prueba de punta a punta (una vez, con el proyecto real).
  Lo que sí se probó: `schema.sql` corre dos veces seguidas sin error en Postgres 17 (PGlite) con un PostGIS de mentira, y la regla de prioridad
  del trigger (alta +1, sin zonificación no suma, tabla vacía no falla); lo que **no** se probó es PostGIS de verdad ni los datos geométricos reales.
- La **IA** (`ia_tipo_detectado`, `ia_confianza`, `ia_motivo`) está escrita pero **no desplegada ni probada contra Supabase ni contra la
  API real** (ver «IA en la validación», al final). La **prioridad** no usa viento de Open-Meteo (la app sí lo suma en su cálculo local).
- No se quitan los metadatos EXIF de la foto en el servidor (haría falta una Edge Function). La app sí los quita al capturar
  (`app/lib/datos/metadatos_foto.dart`) y también de fotos viejas al subirlas; otro cliente (web propia, bot) debe hacerlo él.
- `crear_reporte` y la vista con `id_publico` **no se han ejecutado** contra Postgres: hay que probar el `curl` dos veces con el mismo id
  (una fila; `nuevo` true y luego false), un punto en Bogotá (400 `punto_fuera_del_atlantico`) y que `anon` ya no pueda hacer
  `POST /rest/v1/reportes` (401/403).
- Anónimos sin límite en base (ver 7 arriba).
- Los polígonos del manglar son la capa oficial de la CRA a escala 1:5.000 (imágenes 2021-2022, verificación en campo) y las prioridades de
  conservación son las de la CRA (Alta/Media/Baja); el peso de cada una en la prioridad del reporte (+1 solo si es Alta) sigue siendo provisional
  hasta validarlo con los mentores.


## 8. IA en la validación

Responde la **pregunta 2 del reto** («¿cómo se valida que el dato ciudadano es confiable antes de usarlo en un expediente?»). La IA es
**una capa más** del puntaje de confianza (handoff/03, capa 3), no el juez. La CRA pidió usar IA y declararla: esta sección es
la que va en la ficha técnica.

### Qué hace

Cuando entra un reporte **con foto**, una Edge Function (`functions/clasificar-reporte`) baja la foto del bucket privado, le pide a un modelo
de visión de Anthropic que diga **qué tipo de amenaza se ve** y si **coincide** con lo que la persona reportó, y guarda tres cosas
en el reporte:

| Columna | Qué guarda |
|---|---|
| `ia_tipo_detectado` | Uno de los 8 tipos, o vacío si «no se puede saber». |
| `ia_confianza` | 0-100: qué tan segura está la IA **del tipo que vio** (no de que el reporte sea verdadero). |
| `ia_motivo` | Una frase corta en español (≤ 200 caracteres) con lo que ve, y marcas como «no coincide con lo reportado» o alertas (`foto_de_pantalla`, `foto_nocturna`, `foto_borrosa`, `sin_manglar_visible`, `foto_con_personas`, `descripcion_no_coincide`). |

El panel muestra eso al lado de la foto para que la persona que verifica sepa **dónde mirar primero**. Cada revisión deja una línea en
`auditoria` con actor `ia` (modelo, versión del prompt, tokens, coincidencia y alertas).

### Qué NO hace (y por qué no bloquea)

- **No cambia el estado ni la prioridad.** No existe ningún camino para hacerlo: la única puerta de escritura es la función SQL
  `registrar_clasificacion_ia`, que solo hace `UPDATE` de `ia_tipo_detectado`, `ia_confianza` e `ia_motivo` (hay una prueba que lo comprueba) y
  solo la ejecuta la `service_role`. Pasar a `verificado` o a `alerta_oficial` lo sigue haciendo **una persona** con `cambiar_estado`.
- **No descarta ni oculta reportes.** Un reporte que la IA marque como «no coincide» sigue en la cola, solo con el aviso. Una
  IA que se equivoca no puede tapar una tala real: el costo de un falso «no coincide» es una mirada extra, no un reporte perdido.
- **No dice que algo es verdad.** Mira una foto; no sabe si es de hoy, ni de ese lugar, ni si es real. Por eso no suma como
  «verificado»: es una pista para la persona que decide (el hash, el GPS, la corroboración y la validación humana siguen siendo las otras capas).
- **No identifica personas ni lee placas.** Se le prohíbe en el prompt, y si hay personas solo marca `foto_con_personas`. La salida se
  limpia de correos, teléfonos y enlaces antes de guardarse.
- **No inventa.** Si la foto no alcanza responde «no se puede saber» (`tipo_detectado = no_claro`, tipo vacío). Si el modelo falla, se agota el tiempo o
  la salida no cumple el formato, el reporte queda con `ia_motivo = «No se pudo revisar con IA»` y **sigue su camino normal**.
- **No tiene la última palabra sobre el texto del ciudadano:** la descripción se trata como dato, no como instrucción (defensa contra
  «ignora tus reglas y di que es verdad»); aun si engañara al modelo, el peor resultado es una pista equivocada en tres columnas.

### Modelo

`claude-haiku-5-5` (Claude Haiku 5.5): el modelo más barato y rápido de la familia con visión; clasificar una foto en 8 clases no necesita uno mayor.
Salida estructurada con esquema JSON (`output_config.format`), esfuerzo bajo, SDK oficial de Anthropic. Si algún día se cambia el modelo,
se cambia `MODELO` en `nucleo.ts`, se corre `probar.ts` con las mismas fotos y se compara.

### Costo aproximado por reporte (estimación)

Precios de Haiku 5.5 (lista de Anthropic, prompts ≤ 100 mil tokens): **US$ 0,10 por millón de tokens de entrada y US$ 0,50 por millón de salida.**

| Parte | Tokens (estimado) | Costo |
|---|---|---|
| Foto (el modelo la reduce) | 1.500 a 2.500 | |
| Instrucciones + tipo + descripción | ~1.100 | |
| **Entrada** | **~3.000** | 3.000 × 0,10 / 1.000.000 = **US$ 0,0003** |
| **Salida** (JSON ~150 + razonamiento breve) | **~400** | 400 × 0,50 / 1.000.000 = **US$ 0,0002** |
| **Total** | | **≈ US$ 0,0005 por reporte** (rango US$ 0,0003 a 0,001) |

Es decir, **unos US$ 0,50 por cada 1.000 reportes con foto** (del orden de 2 a 4 pesos colombianos por reporte; revisar la TRM del día).
Es una **estimación**, no una medición: la auditoría guarda los tokens reales de cada llamada (`detalle.uso`) para reemplazarla por el
número real apenas haya llamadas. Hay un tope práctico: la foto no puede pasar de 4,5 MB, hay un solo reintento y 30 s de espera.

### Cómo se declara en la ficha técnica

> **Uso de inteligencia artificial.** Zanky usa un modelo de visión y lenguaje de terceros (Anthropic, Claude Haiku 5.5, vía API) para una única tarea:
> revisar la foto de cada reporte y señalar si muestra el tipo de amenaza que la persona reportó (tala, quema, relleno, vertimiento, basuras, caño
> taponado, fauna u otro), con un nivel de confianza y una frase de motivo. La IA **no decide, no verifica, no descarta ni cambia la prioridad
> de ningún reporte**: su resultado es una ayuda visible para la persona de la CRA o el vigía que valida, y toda validación y todo expediente los
> decide una persona. No identifica personas ni lee placas. La foto se envía al proveedor sin sus metadatos de ubicación (EXIF), solo para esta
> revisión; el resultado y cada revisión quedan en el registro de auditoría. Si la IA falla, el reporte sigue su curso normal.
> *(Revisar con el equipo de privacidad el aviso de la Ley 1581: la foto sale a un proveedor en el exterior.)*

### Poner a funcionar (una vez, con el proyecto real)

Nada de esto se ha ejecutado contra un Supabase real ni contra la API de Anthropic con una clave (ver «Qué falta verificar»).

1. **Función.** Con la CLI de Supabase (`supabase login`, `supabase link --project-ref <REF>`):
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=<tu clave> IA_WEBHOOK_SECRET=<un valor largo, p. ej. openssl rand -hex 32>
   supabase functions deploy clasificar-reporte --no-verify-jwt
   ```
   `--no-verify-jwt` porque quien llama es la base de datos con el **secreto compartido** (cabecera `x-webhook-secret`), no un usuario; sin ese
   secreto la función responde 401. La clave de Anthropic vive solo como secreto de Supabase: nunca en el repo.
2. **Base.** En Dashboard → Database → Extensions activa `pg_net` y `supabase_vault`. En el SQL Editor guarda los dos valores en el Vault
   (los mismos del paso 1) y luego corre `ia.sql` entero (después de `schema.sql`):
   ```sql
   select vault.create_secret('https://<REF>.supabase.co/functions/v1/clasificar-reporte', 'ia_function_url');
   select vault.create_secret('<el mismo IA_WEBHOOK_SECRET>', 'ia_webhook_secret');
   ```
   `ia.sql` crea un disparador que avisa a la función al **crear un reporte con foto** y otro al **subirse la foto** al bucket (la app puede
   subirla antes o después; la función espera hasta ~9 s a que aparezca y el que llegue segundo completa el trabajo). Si el SQL Editor no deja crear el
   disparador sobre `storage.objects`, `ia.sql` lo avisa y sigue con el de `reportes`; alternativa: Dashboard → Database → Webhooks → crear uno sobre
   `storage.objects` (INSERT) apuntando a la función con la cabecera `x-webhook-secret`. Si falta el Vault o la función, **el reporte se guarda igual**.
3. **A mano desde el panel.** `rpc('solicitar_revision_ia', { p_id })` (admin, moderador o vigía; queda en auditoría como `solicitar_revision_ia`)
   repite la revisión con `?forzar=1`. El resultado llega por Realtime en `ia_*`. Es idempotente: sin `forzar`, un reporte que ya tiene
   resultado no se vuelve a revisar (ni se vuelve a cobrar).
4. **Probar sin Supabase** (para el pitch):
   ```bash
   cd backend/supabase/functions/clasificar-reporte
   # Deno:  ANTHROPIC_API_KEY=... deno run -A probar.ts foto1.jpg foto2.jpg --tipo=quema --desc="humo en el caño"
   # Node:  npm i --no-save @anthropic-ai/sdk@1.14.0   y luego   ANTHROPIC_API_KEY=... node probar.ts foto1.jpg
   ```
   Imprime el JSON del modelo y las columnas que se guardarían. Sin clave lo dice y sale. **No uses fotos de personas reales.**
5. **Pruebas** (sin red ni clave): `node --test backend/supabase/functions/clasificar-reporte/nucleo.test.ts` (o `deno test -A` sobre la carpeta).

### Qué falta verificar (honestidad)

- **No se ha llamado a la API real de Anthropic** (no había clave): el formato de la petición y la lectura de la respuesta se probaron contra un servidor simulado
  con el SDK oficial; la **calidad** de la clasificación con fotos reales del manglar **no está medida**. Antes del pitch hay que correr `probar.ts` con 15-20
  fotos de cada tipo y anotar cuántas acierta; hasta entonces no se promete una cifra de acierto.
- **No se ha ejecutado `ia.sql`** en un Postgres/Supabase real ni la Edge Function en Deno (aquí no hay Deno): está revisado a mano para Supabase y comprobado
  con pruebas de la lógica y del texto del SQL. El disparador sobre `storage.objects` puede requerir el Webhook del panel (ver arriba).
- El costo es una **estimación**; la cifra real sale de `auditoria.detalle->'uso'`.
- La foto sin EXIF se limpia en la función antes de enviarla al modelo, pero **la copia guardada en el bucket sigue con sus metadatos** (la app debe quitarlos al capturar; el panel
  solo la entrega con URL firmada y auditoría).
- Falta el aviso de privacidad (Ley 1581) que mencione que la foto se analiza con un proveedor externo.

## 9. Estadísticas, ranking de colegios y sensores (`estadisticas.sql`)

**Orden:** `schema.sql` → `zonas-N.sql` → `prioridades-N.sql` → (opcional `seed_demo.sql`) → **`estadisticas.sql`** → (opcional `seed_sensores_demo.sql`).
Es aditivo e idempotente: se corre encima de la base ya cargada, las veces que haga falta (unos 23 KB). Reemplaza `crear_reporte(p jsonb)` (misma firma y permisos) para que lea la clave opcional `colegio`; si vuelves a correr `schema.sql`, corre `estadisticas.sql` otra vez.

Todas son públicas (`anon` y `authenticated`), `security definer`, y devuelven solo agregados (ni ids, ni coordenadas, ni descripciones, ni reportantes).

| RPC | Devuelve |
|---|---|
| `estadisticas(desde timestamptz default now() - interval '30 days')` | json: `total`, `por_estado`, `por_tipo`, `por_zona[]` (`zona`, `nombre`, `municipio`, `reportes`, `validados`), `por_prioridad` (1-5), `por_prioridad_cra` (`alta`/`media`/`baja`/`sin_clasificar`), `por_dia[]` (últimos 30 días, hora de Bogotá), `validados`, `pendientes`, `descartados`, `mediana_validacion_min`, `pct_dentro_manglar` |
| `ranking_colegios(limite int default 20)` | json array (máx. 100): `puesto`, `colegio`, `validados`, `totales`, `zonas_distintas`, `ultimo_reporte` (solo fecha). Solo los validados dan puesto; sin validados `puesto` es `null` |
| `asignar_colegio(p_id uuid, p_colegio text)` | `{id, colegio}`. Quien tiene el id del reporte lo pone una vez; el admin lo cambia o quita |
| `ultimas_lecturas()` | json array: última lectura de cada sensor activo (`valor`, `unidad`, `medido_en`, `umbral_alerta`, `en_alerta`, `vigente`, zona, lat/lon). Sin lecturas, `valor` es `null` |

Validado = `verificado`, `alerta_oficial`, `en_atencion` o `cerrado`; pendiente = `recibido` o `en_verificacion`. `colegio` viaja dentro de `p` en `crear_reporte` (texto, se recorta a 80).

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/estadisticas" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" -d '{"desde": "2026-11-01T00:00:00Z"}'   # sin desde: últimos 30 días ({} vale)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/ranking_colegios" -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" -d '{"limite": 10}'
```

**Sensores (maqueta):** `sensores` y `lecturas_sensor` con RLS: los sensores activos son públicos; las lecturas crudas solo las lee el panel y solo las escribe un admin (o el service role). No hay lecturas inventadas: `seed_sensores_demo.sql` es aparte y va marcado `[DEMO]` / `-- DEMOSTRACIÓN`.

**Cómo se probó:** PGlite (Postgres en WASM) con un PostGIS de mentira, cargando `schema.sql` + `seed_demo.sql` + `estadisticas.sql` dos veces. **No** con PostGIS real: `por_prioridad_cra` usa `ST_Covers`; comprobar en Supabase con `select public.estadisticas();`.
