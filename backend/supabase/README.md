# Backend de Zanqui (Supabase)

Base de datos con PostGIS, reglas de seguridad, funciones del panel y almacenamiento de fotos del reto
**Manglar Hack Atlántico 2026**. Es lo que conecta la app (Flutter), el panel de la CRA (web) y el bot de WhatsApp.

> Este repo es **público**. Aquí no hay claves ni valores reales: solo nombres de variables (`../.env.example`).

## Archivos

| Archivo | Para qué |
|---|---|
| `schema.sql` | Todo el esquema: tablas, trigger de recepción, auditoría, roles, RPC, RLS, storage, datos abiertos. Idempotente. |
| `generar_zonas.mjs` | Lee `app/assets/datos/manglar_zonas.json` y escribe `zonas.sql` (`node backend/supabase/generar_zonas.mjs`). |
| `zonas.sql` | Las 4 zonas de manglar (INVEMAR 2020, provisional) como `MultiPolygon`. Generado, ~500 KB. |
| `seed_demo.sql` | 15 reportes de **demostración** (`[DEMO] …`). Opcional; no son datos reales. |
| `../.env.example` | Nombres de las variables. |

## 1. Crear el proyecto (gratis)

1. Entra a <https://supabase.com>, crea una cuenta y un proyecto nuevo (plan Free). Región cercana (p. ej. São Paulo). Guarda la
   contraseña de la base de datos en tu gestor de contraseñas, no en el repo.
2. En **Settings → API** copia la **Project URL** y la clave **anon**. La **service_role** es secreta: solo para el bot.
3. **SQL Editor → New query**, pega y ejecuta **en este orden** (cada uno entero):
   1. `schema.sql`
   2. `zonas.sql` (si el editor se queja del tamaño, pégalo por partes: cada zona es un `insert` independiente; o
      usa `psql "$SUPABASE_DB_URL" -f zonas.sql`). Al final debe decir `zonas_cargadas = 4`.
   3. `seed_demo.sql` (opcional, solo para demostrar). Al final muestra los reportes por zona.
4. Si cambian los polígonos: `node backend/supabase/generar_zonas.mjs` y vuelve a pegar `zonas.sql` (hace *upsert*).

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
flutter run --dart-define=ZANQUI_API=$SUPABASE_URL --dart-define=ZANQUI_ANON=$SUPABASE_ANON_KEY
```

**Web (panel y vista pública):** la URL y la clave **anon** del proyecto, con el nombre que use su herramienta
(por ejemplo `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`). El panel inicia sesión con Supabase Auth (correo y contraseña) y
usa el JWT del usuario. **La `service_role` nunca va en la web ni en la app.**

**Bot de WhatsApp / scripts del servidor:** `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en un `.env` local (no se sube).

## 4. Qué es público y qué no

| Quién | Puede | No puede |
|---|---|---|
| **Cualquiera** (clave anon) | Crear un reporte; subir `evidencias/<uuid>.jpg`; consultar el estado de **sus** ids; leer la vista `reportes_publicos`; bajar datos abiertos; leer las zonas | Leer la tabla `reportes`, ver fotos, ver descripciones, ver quién reportó |
| **vigia** | Leer la cola de reportes; `en_verificacion` y `verificado`; ver fotos y fichas (auditado) | Alerta oficial, descartar, ver el reportante, gestionar roles |
| **moderador_cra** | Todo el flujo de estados, descartar, abrir expediente, ver el reportante (auditado) | Gestionar roles, leer la auditoría |
| **admin** | Todo lo anterior + roles + leer la auditoría | Modificar o borrar la auditoría (nadie puede) |
| **aliado** | Nada de reportes | — |

Lo que nunca sale al público: descripción, foto, `foto_hash`, `reportante_id`, metadatos de foto, coordenadas exactas
(la vista las redondea a 3 decimales, unos 110 m).

## 5. RPC y endpoints

Con `SUPABASE_URL` y `ANON` como variables de entorno (nunca pegues los valores en el repo).

| Qué | Quién | Llamada |
|---|---|---|
| Crear reporte | anon | `POST /rest/v1/reportes` |
| Subir foto | anon | `POST /storage/v1/object/evidencias/<id>.jpg` |
| `estado_de_reportes(ids)` | anon | `POST /rest/v1/rpc/estado_de_reportes` |
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
curl -s -X POST "$SUPABASE_URL/rest/v1/reportes" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" -H "Prefer: resolution=ignore-duplicates,return=minimal" \
  -d '{"id":"11111111-2222-4333-8444-555555555555","canal":"web","tipo":"tala","descripcion":"Prueba",
       "lat":11.056,"lon":-74.84,"capturado_en":"2026-11-27T15:00:00Z","momento":"ahora","magnitud":"pequena"}'

# Estado de mis reportes (máx. 100 ids)
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/estado_de_reportes" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"ids":["11111111-2222-4333-8444-555555555555"]}'

# Mapa público
curl -s "$SUPABASE_URL/rest/v1/reportes_publicos?select=*&order=capturado_en.desc&limit=50" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON"

# Datos abiertos: CSV (directo de PostgREST), GeoJSON y KML (licencia CC BY 4.0)
curl -s "$SUPABASE_URL/rest/v1/reportes_publicos?select=id,capturado_en,tipo,municipio,zona,prioridad,estado,lat,lon,canal" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Accept: text/csv" -o zanqui_reportes.csv
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/datos_abiertos_geojson" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -o zanqui_reportes.geojson
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/datos_abiertos_kml" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" | jq -r . > zanqui_reportes.kml   # llega como cadena JSON

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
   acota la `confianza` (máx. 80 del teléfono, +10 por corroboración); solo acepta `foto_url = evidencias/<su id>.jpg`. Además,
   `anon` solo tiene permiso de INSERT sobre las 23 columnas del contrato.
3. **El público solo escribe.** No hay política de SELECT para `anon` en `reportes`. Lo público sale de una vista (`reportes_publicos`)
   sin descripción, foto ni reportante, con coordenadas a ~110 m y sin descartados. Los ids de reporte son UUID: `estado_de_reportes`
   solo responde por los que se le pasan (máx. 100).
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
8. **Reintentos sin duplicar.** El `id` lo genera el teléfono; un reintento se ignora en silencio y no gasta el límite.
9. **Roles mínimos.** El vigía solo llega a `verificado`; descartar y abrir expediente son del moderador/admin; el aliado no ve reportes.
10. **Protección del que denuncia.** Anónimo real (`reportante_id` se borra si `anonimo`), `reportante_id` fuera de la lectura del panel
    salvo `ver_reportante()` (auditado), coordenadas a 3 decimales en lo público.

## 7. Pendientes y límites (dichos con honestidad)

- **No se ha ejecutado contra una base real** (no hay Postgres aquí): el SQL está revisado a mano para Postgres 15 + PostGIS 3.
  Hay que correr `schema.sql`, `zonas.sql`, `seed_demo.sql` y la prueba de punta a punta (una vez, con el proyecto real).
- La **IA** (`ia_tipo_detectado`, `ia_confianza`, `ia_motivo`) no está conectada: las columnas existen y las escribe el servicio de IA
  con la `service_role`. La **prioridad** no usa viento de Open-Meteo (la app sí lo suma en su cálculo local).
- No se quitan los metadatos EXIF de la foto en el servidor (haría falta una Edge Function): la app debe quitarlos al capturar.
- Anónimos sin límite en base (ver 7 arriba).
- Los polígonos son la capa INVEMAR 2020 (provisional) y las prioridades de conservación, provisionales hasta validarlas con los mentores.
