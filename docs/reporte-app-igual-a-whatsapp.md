# Un reporte de la app llega igual que uno de WhatsApp

La app y el bot de WhatsApp aplican las mismas reglas, con los mismos textos. El servidor y el panel reciben un reporte
idéntico venga del canal que venga, también si se hizo sin señal y se envió después.

| Bot de WhatsApp | App | Estado |
|---|---|---|
| 8 tipos con su gravedad (tala 5, quema 5, relleno 4, vertimiento 4, caño tapado 4, fauna 4, basuras 2, otra 2) | Los mismos identificadores y gravedades (`tipos.dart`) | igual |
| Consentimiento Ley 1581 y opción anónima | Bienvenida o perfil, e interruptor «anónimo» en Detalles | igual |
| Ubicación por GPS o por enlace | GPS sin señal, pin en el mapa o enlace de Google Maps (`metodo_ubicacion` gps/enlace) | igual |
| Rechaza puntos fuera del Atlántico (10,2–11,4 N; −75,7 a −74,4 O) | Misma caja; no deja seguir y explica por qué | igual |
| Dentro del polígono del manglar, distancia, influencia de 500 m, zona y municipio | Mismo cálculo local con la capa de la C.R.A. en caché; el servidor lo recalcula con PostGIS | igual |
| A más de 3 km: «¿Seguro que es ahí?» | Hoja con «Sí, es ahí» o «Cambiarla» | igual |
| Foto opcional, sin arriesgarse; huella SHA-256 | Cámara o galería, `foto_hash`; la foto sube al enviar | igual |
| Descripción de hasta 1000 caracteres | Pregunta de seguimiento propia de cada tipo; corte a 1000 | igual |
| Cuándo (ahora, hoy, antes) y tamaño (pequeña, mediana, grande) | Los mismos valores | igual |
| Recordar el 123 | Aviso si es fuego o tala y está pasando ahora | igual |
| Resumen de 6 filas antes de enviar | «Revisa tu reporte» con las mismas filas, en el mismo orden | igual |
| Prioridad 1–5: gravedad ± zona, −1 si está lejos, −1 si fue antes, +1 si es grande, +1 si hay reportes cercanos | La misma regla (`prioridad.dart`), +1 por viento en quemas y «¿Por qué prioridad X?»; manda la del servidor | igual |
| Confianza 0–80 | `confianzaCanal()`, misma fórmula | igual |
| Pausa tras 5 reportes en una hora | Zanky pregunta antes de seguir («Es algo nuevo» o «Ahora no») | igual |
| Número de caso `ZK-` + 4 hex del identificador | `Reporte.caso`, idéntico | igual |
| Clasificación de la foto con IA | La hace el servidor al recibir cualquier reporte con foto; la app no guarda claves | igual |
| Enviado, pendiente o rechazado | Cola sin señal con reintento y los mismos tres mensajes | igual |
| «Listo: tu reporte ZK-… ya llegó» y «Novedad de tu reporte…» | Avisos en Mis reportes | igual |
| `sincronizado_tarde` si tarda más de 10 min | Se marca si se capturó sin señal | criterio propio |
