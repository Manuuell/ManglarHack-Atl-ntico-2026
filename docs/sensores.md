# Sensores: de la estación al panel

## Ruta de datos

`ESP32 → WiFi + HTTPS → lectura-sensor → sensor_tokens (SHA-256) → registrar_lote_sensor → lecturas_sensor + alertas_sensor → ultimas_lecturas() → panel_sensores.html`.

Cada fila de `sensores` representa **una magnitud**, no la estación completa. Una estación de tres sondas necesita tres UUID y tres tokens; con turbidez, cuatro. `tipo` del lote debe coincidir con `sensores.tipo`. Un token solo autoriza su sensor. La función acepta 1–32 lecturas de ese mismo tipo, de los últimos siete días, y limita a una petición aceptada cada 30 segundos por sensor. Respuestas habituales: `200` con contadores, `401` token o sensor no autorizado, `422` datos inválidos, `429` límite de tasa (`Retry-After: 30`). Los valores que alcanzan `umbral_alerta` crean una fila en `alertas_sensor`; la alerta orienta revisión humana, no declara una emergencia oficial.

## Activación y administración

1. En el SQL Editor de Supabase, cargar `backend/supabase/schema.sql`, los archivos `zonas-N.sql` / `prioridades-N.sql` que correspondan y luego **`backend/supabase/estadisticas.sql`**. Este último ya crea `sensores`, `lecturas_sensor` y `ultimas_lecturas()` y no se modifica. Cargar después **`backend/supabase/sensores_ingesta.sql`**. Se puede repetir; si ya hay lecturas duplicadas con el mismo `sensor_id` y `medido_en`, resolverlas antes de crear el índice único.
2. Dar de alta cada magnitud desde la sesión **admin** del panel mediante `sensores` (`nombre`, `tipo`, `zona_id`, `lat`, `lon`, `umbral_alerta`, `activo`). El esquema existente solo permite esta escritura al admin. Hasta integrar el formulario de gestión en la web, hacerlo en SQL Editor con rol postgres. Elegir umbral dentro del rango físico y con criterio ambiental local: `nivel_agua` 0–10 m, `salinidad` 0–60 ppt, `temperatura` −5–60 °C, `turbidez` 0–4000 NTU. `null` desactiva la alerta de ese canal.
3. Generar **un token aleatorio de 32 bytes por sensor** y guardar solo su SHA-256. En SQL Editor (rol postgres), reemplazar el UUID de ejemplo por el creado, ejecutar y copiar el token que sale **una sola vez** al `config.h` local del equipo:

   ```sql
   set search_path = public, extensions;
   with nuevo as materialized (select encode(gen_random_bytes(32), 'hex') as token),
   guardado as (
     insert into public.sensor_tokens(sensor_id, token_sha256)
     select 'UUID_DEL_SENSOR'::uuid, encode(digest(nuevo.token, 'sha256'), 'hex') from nuevo
     on conflict (sensor_id) do update set token_sha256 = excluded.token_sha256,
       creado_en = now(), ultimo_envio = null
     returning sensor_id
   )
   select nuevo.token from nuevo, guardado;
   ```

   `gen_random_bytes` / `digest` requieren `pgcrypto` disponible en el proyecto Supabase. Si `digest` vive en `extensions`, usar `extensions.digest`. Copiar el token solo al equipo; nunca a commits, capturas, logs ni al panel público. Para rotar, repetir la sentencia y actualizar el firmware. El token anterior deja de funcionar inmediatamente. Desactivar `sensores.activo` revoca la ingesta.
4. Desplegar `backend/supabase/functions/lectura-sensor` con `supabase functions deploy lectura-sensor --no-verify-jwt`. Supabase inyecta `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` a la función; no poner la clave de servicio en el microcontrolador. La función rechaza peticiones sin el token del sensor.
5. Abrir `tools/panel_sensores.html` en un navegador. Muestra primero **DATOS FICTICIOS** para el pitch. Para datos reales, introducir la URL de Supabase y la clave **publicable/anon** y pulsar «Ver lecturas en vivo». Consulta la RPC `ultimas_lecturas()`; jamás pide la clave de servicio ni tokens de sensores. Los campos de conexión no se guardan. Para verificar alertas persistidas, el personal autorizado puede consultar `alertas_sensor` con su sesión de panel.

La vista de administración definitiva debe ofrecer alta/edición del sensor, umbrales, desactivación, rotación de token con revelado único y listado de alertas. La página entregada es una **vista de lecturas**, no un formulario administrativo autenticado.

## Demostración reproducible

Ejecutar `node tools/simular_sensor.mjs` sin variables: imprime cuatro peticiones ficticias sin tocar Supabase. Los UUID coinciden con `seed_sensores_demo.sql` y representan una magnitud por zona. El lote de Mallorquín contiene una subida de 0,82 a 1,72 m; si el umbral es 1,5 m se registra una alerta. Las otras zonas enseñan salinidad, temperatura y turbidez. No presentar esos números como mediciones reales.

Para enviar a un proyecto de **demostración**, cargar `seed_sensores_demo.sql` después de `estadisticas.sql`, crear los cuatro tokens y pasar `ZANKY_SENSOR_URL` y `ZANKY_SENSOR_TOKEN`. Este último acepta un JSON con UUID → token; un único token solo funciona para el sensor al que pertenece. El simulador sale con error si falta alguno. No repetirlo en menos de 30 segundos por sensor. La semilla agrega lecturas ficticias; borrarla antes de uso real.

Comprobaciones locales: `node --check tools/simular_sensor.mjs`, `node tools/simular_sensor.mjs` y `node --experimental-strip-types --test tools/probar_ingesta.test.mjs`. Si Deno está instalado, ejecutar `deno check backend/supabase/functions/lectura-sensor/index.ts`.

## En la app: «Sensores del manglar»

- **Dónde:** tarjeta «Sensores del manglar» en Inicio (todos los roles) y botón de sensores en la cabecera del panel CRA.
  Un toque abre la pantalla; cada estación abre su detalle (deslizar desde el borde vuelve; mantener presionada una
  estación da «Ver detalle» y «Compartir lectura»; tirar hacia abajo actualiza).
- **Qué muestra:** mapa chico y lista de estaciones por zona (las sondas de una misma zona forman una estación), última
  lectura de cada sonda, estado (en línea si llegó hace 25 min o menos; «sin datos hace X» si no; «aún sin lecturas»),
  mini gráfica de las últimas 12 h con la línea del umbral, umbrales explicados en lenguaje simple y una alerta roja
  cuando una lectura de menos de 6 h llega al umbral (`en_alerta` de la RPC o el umbral de referencia).
- **De dónde:** `ultimas_lecturas()` con la clave anon (`--dart-define=ZANKY_API=… --dart-define=ZANKY_ANON=…`), cada
  minuto mientras la pantalla está abierta. La RPC solo da la última lectura: la gráfica se arma con las lecturas que el
  teléfono fue viendo. Sin señal se muestra la copia guardada con su hora. Sin servidor o sin ninguna lectura, la app
  muestra lecturas simuladas con el rótulo **«DEMOSTRACIÓN · datos de ejemplo»**.
- **Umbral:** desde `estadisticas_parche_1.sql` solo el admin recibe `umbral_alerta`; los demás ven el umbral de
  referencia de la app (1,5 m, 45 ppt, 34 °C, 100 NTU), rotulado «de referencia».

Para la demo en vivo: cargar `seed_sensores_demo.sql`, crear los tokens y correr
`ZANKY_SENSOR_URL=… ZANKY_SENSOR_TOKEN='{"UUID":"token",…}' node tools/simular_sensor.mjs`; en menos de un minuto la
tarjeta de Inicio pasa a «Alerta: nivel del agua en Ciénaga de Mallorquín» (1,72 m contra 1,5 m). Sin variables, el
simulador solo imprime y la app sigue en modo demostración.

## Lo que ve el ciudadano y qué decir en el pitch

En la vista ciudadana se muestran zona, magnitud, valor aproximado, fecha, vigencia y un aviso «supera el umbral; revisar». No mostrar tokens, historial crudo, ubicación exacta de sondas ni afirmar que el sensor valida una denuncia. **Antes de exponer una vista ciudadana en producción**, revisar que la RPC heredada `ultimas_lecturas()` actualmente devuelve latitud/longitud exactas a `anon`; esta página las omite visualmente, pero la respuesta HTTP aún las contiene. Publicar una RPC agregada por zona o ajustar esos permisos en una migración coordinada con el panel.

Guion breve: «Una estación mide el caño y conserva lecturas si pierde WiFi. Al volver la señal, la función comprueba su token y guarda cada lectura una vez. Si el nivel supera un umbral local, el panel muestra una alerta para que un vigía la revise. Hoy estos cuatro números son una simulación; el montaje y la calibración en campo son el siguiente paso». No afirmar que existe una estación instalada ni que la salinidad TDS es de calidad marina.

## Verificaciones pendientes de campo

La función y el SQL no se han desplegado contra un proyecto real en este worktree; comprobar permisos de RPC, política RLS, CORS según despliegue del panel, rotación y reintentos con respuesta perdida. El sketch tampoco se ha compilado en una placa ni validado con sondas reales. Medir autonomía de batería, cobertura, deriva, precisión de patrones y resistencia a corrosión antes de instalarlo.
