# Avisos por zona

SQL a pegar en Supabase (SQL Editor, como `postgres`): `backend/supabase/avisos_zona.sql`. Función: `backend/supabase/functions/avisos-whatsapp/index.ts`. Alta y bandeja en la app: `app/lib/vistas/avisos_zona/`.

## Instalación

Cargar `backend/supabase/avisos_zona.sql` desde SQL Editor como `postgres`, después de `schema.sql`, los archivos de zonas y prioridades, `estadisticas.sql` y `sensores_ingesta.sql`. El archivo se puede volver a ejecutar: crea tablas e índices si faltan y reemplaza las funciones y disparadores con el mismo nombre. No altera reportes existentes.

Un administrador asigna encargados en `encargados_zona` desde un entorno seguro. `zona` debe coincidir con `zonas.id`; `user_id` corresponde a un usuario de `panel_roles` activo con el mismo `rol`. Para WhatsApp se agrega `telefono_e164`. El teléfono de encargado y el del voluntario solo son legibles por el rol de servicio. No hay políticas de lectura pública de estas tablas.

Los reportes se encolan después de insertarse y de que el servidor haya calculado zona y prioridad. Las alertas de `alertas_sensor` se tratan como prioridad alta. Se envía siempre a cada encargado activo de la zona. Prioridad alta: voluntarios activos de la zona dentro de su radio. Media: además deben estar a menos de 2 km. Baja: solo encargados. Cada voluntario admite hasta tres eventos distintos en una hora. La clave única impide duplicar un mismo evento, destinatario, canal y plantilla. El horario silencioso difiere la entrega hasta su fin en hora de Colombia. Los datos de la cola incluyen solo origen, zona, tipo y prioridad; nunca descripción, imagen, identidad ni contacto del denunciante.

`hacerme_voluntario` exige consentimiento explícito Ley 1581 y registra la hora en el servidor. Devuelve `telefono_id`, un token aleatorio que la app guarda localmente: permite `mis_avisos`, `voy_a_ayudar` y `darme_de_baja`. Se guarda solo su hash en Supabase. Si se pierde el token, la persona necesita atención para cancelar o reinscribirse con el mismo número; ningún cliente anónimo puede buscar un teléfono. La baja desactiva al voluntario y bloquea avisos no despachados. El servidor de la app debe proteger el almacenamiento local de ese token de acuerdo con su entorno.

`voy_a_ayudar` registra una sola participación por aviso y encola `zanky_apoyo_confirmado` para el encargado. La bandeja se consulta con `mis_avisos(telefono_id)` en la app y la web. El panel CRA incluye «Avisos de mi zona», que llama `mis_avisos_encargado()` con la sesión autenticada y comprueba el rol vigente en `panel_roles`. La tarjeta `EntradaVoluntario` se conecta desde Inicio o Guardián según `app/lib/vistas/avisos_zona/LEEME.md`.

## WhatsApp y bot de Manuel

La función `avisos-whatsapp` atiende solo peticiones `POST` autenticadas con `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`. Programar una invocación periódica desde un cron seguro. Configurar `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `META_TOKEN` y `META_PHONE_ID` como secretos del entorno; opcionalmente `META_GRAPH_VERSION` (por defecto `v26.0`). Nunca llevar la clave de servicio al cliente Flutter. Sin las dos variables `META_*`, la función entra en **modo seco**: registra únicamente el número de pendientes, sin reclamar ni marcar avisos. Con Meta configurado, reclama un lote de 20 con bloqueo `FOR UPDATE SKIP LOCKED`, envía cada plantilla y marca el resultado. Los fallos esperan 30, 60, 120… segundos hasta un máximo de una hora; tras cinco intentos quedan para revisión manual. La cola tiene semántica de al menos una entrega: si Meta acepta y falla la confirmación en base, un reintento puede repetir el mensaje.

El servidor del bot de Manuel puede consumir la misma cola en lugar de esta función: llamar `tomar_avisos` con `{"canal":"whatsapp","limite":20}` usando **solo** `service_role`, despachar cada elemento de forma aislada y llamar `marcar_aviso` con `{"id":"…","estado":"enviado"}` únicamente tras confirmación de Meta; usar `fallido` si no se confirmó. Los registros reclamados quedan `proceso`; un bloqueo abandonado se recupera pasados 10 minutos. No ejecutar ambos consumidores sobre los mismos avisos sin coordinar la operación. El bot debe pedir y conservar la decisión de consentimiento antes de inscribir a una persona y respetar su baja. No guardar ni registrar en logs teléfonos, tokens o cuerpos de mensajes.

## Plantillas que se deben aprobar en Meta

Idioma `es_CO`; variables de texto del **cuerpo**, sin encabezado ni botones. Nombres y texto exactos:

| Nombre | Cuerpo |
| --- | --- |
| `zanky_alerta_zona` | `Zanky: hay un aviso en {{1}} por {{2}}. Prioridad: {{3}}. Si puedes ayudar, abre la sección Avisos cerca de ti en la app.` |
| `zanky_apoyo_confirmado` | `Zanky: una persona voluntaria confirmó que ayudará en {{1}} con el aviso de {{2}}. Revisa el panel de tu zona.` |

Solicitar la aprobación antes de activar el envío real. La función usa las variables en ese orden y solo marca `enviado` cuando la API confirma al menos un identificador de mensaje. [Referencia oficial de Cloud API](https://developers.facebook.com/documentation/business-messaging/whatsapp/overview) y [versiones de Graph API](https://developers.facebook.com/docs/graph-api/changelog/versions).

## Límites actuales

El canal `correo` existe en la estructura y en la cola para una integración posterior; no hay dirección de correo ni trabajador de entrega, por eso la app lo muestra desactivado. La ubicación seleccionada manualmente usa el centro aproximado de la zona; el GPS se redondea a tres decimales antes de enviar. Las pruebas Dart están escritas en `app/test/avisos_zona_*_test.dart`, pero deben ejecutarse por el orquestador junto con la verificación SQL y una prueba de plantillas aprobadas en Meta.

El consentimiento de la RPC anónima es una declaración del cliente; aún no se verifica que quien se inscribe controle el número. Antes de activar campañas reales a voluntarios, incorporar verificación del número u otro control de titularidad y conservar el comprobante de aceptación. La aceptación de la solicitud por Cloud API no equivale a confirmación de entrega en el teléfono: para esa trazabilidad haría falta procesar webhooks de estado.

## Cola de avisos: forma exacta para el bot de Manuel

Tabla `public.avisos_salientes` (solo `service_role`; RLS activa y sin políticas para `anon`/`authenticated`):

| Columna | Tipo | Significado |
| --- | --- | --- |
| `id` | uuid | Identificador del aviso (el que se pasa a `marcar_aviso`). |
| `origen` / `origen_id` | text | `reporte`, `sensor` o `participacion` y su id. |
| `destinatario_tipo` / `destinatario_id` | text / uuid | `voluntario` o `encargado`. |
| `canal` | text | `whatsapp`, `app` o `correo`. El bot toma `whatsapp`. |
| `plantilla` | text | `zanky_alerta_zona` o `zanky_apoyo_confirmado` (aprobadas en Meta, `es_CO`). |
| `datos` | jsonb | Solo `zona`, `tipo`, `prioridad` (texto). Nunca descripción, foto ni identidad del denunciante. |
| `estado` | text | `pendiente` → `proceso` → `enviado` o `fallido`. |
| `intentos` | int | Se incrementa al tomar el aviso; tras 5 queda para revisión manual. |
| `disponible_en` | timestamptz | No se toma antes (horario silencioso y espera entre reintentos). |

Uso recomendado (solo con la clave de servicio, desde el servidor del bot):

1. `POST {SUPABASE_URL}/rest/v1/rpc/tomar_avisos` con `{"canal":"whatsapp","limite":20}`. Devuelve una lista de
   `{"id","canal","plantilla","datos":{"zona","tipo","prioridad"},"intentos","telefono_e164"}`. Los avisos quedan en `proceso`
   y un bloqueo abandonado se recupera a los 10 minutos. Ya excluye voluntarios dados de baja y encargados inactivos.
2. Enviar la plantilla con parámetros de cuerpo en este orden: `zanky_alerta_zona` → `[zona, tipo, prioridad]`;
   `zanky_apoyo_confirmado` → `[zona, tipo]`.
3. `POST .../rpc/marcar_aviso` con `{"id":"…","estado":"enviado"}` solo con confirmación de Meta, o `"fallido"` (espera
   30 s, 60 s, 120 s… hasta 1 h).
4. `POST .../rpc/contar_avisos_pendientes` con `{"canal":"whatsapp"}` devuelve cuántos esperan (modo seco).

Consentimiento y baja en el bot: el alta solo existe con consentimiento Ley 1581 (la RPC `hacerme_voluntario` lo exige y
guarda la hora). Si la persona escribe BAJA, STOP, «darme de baja» o «no me interesa», el bot debe llamar a
`darme_de_baja` con el token de la persona o avisar a un administrador; las frases están en
`app/lib/datos/avisos_zona/reglas.dart` (`interpretarRespuesta`), portadas de `campanaReco.ts` del bot.

## Sin credenciales de Meta

La Edge Function no falla: sin `META_TOKEN` y `META_PHONE_ID` responde `200 {"modo":"seco","pendientes":N}` y deja los
avisos en cola (`pendiente`). Los avisos del canal `app` no necesitan Meta: la app los lee con `mis_avisos`.
