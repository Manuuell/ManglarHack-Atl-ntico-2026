# Panel CRA dentro de la app

La vista de administración de Zanky: la bandeja donde el equipo de la CRA verifica los reportes, con
sus avisos. No es una pestaña: se entra desde **Guardián** (una fila discreta al final, «Panel CRA»;
con sesión iniciada aparece además un ícono con contador en la cabecera y un número en la pestaña).

## Cómo se entra

| Situación | Qué pasa |
|---|---|
| Build con `ZANKY_API` y `ZANKY_ANON` | Pide **correo y contraseña** (Supabase Auth, `/auth/v1/token`). Después llama a `mi_rol()`: el rol lo confirma el servidor contra `panel_roles`, no el token. Sin rol, no entra. |
| Build sin servidor | Solo se ofrece la **demostración**: 12 reportes de ejemplo en el teléfono, rotulada «Datos de ejemplo… Nada llega a la CRA». Incluye «Simular llegada» para ver el aviso y el contador. |

La sesión vive **solo en memoria** (no se guarda ningún token en el teléfono ni en el navegador): al
cerrar la app hay que volver a entrar. Se renueva sola con el `refresh_token` mientras está abierta.
Enlace mágico: no está hecho (ver «Fuera»).

## Qué hay

- **Bandeja** (`bandeja_admin.dart`): filtros Pendientes / Aprobados / Rechazados / Todos con su conteo;
  pendientes primero y, dentro, mayor prioridad CRA y más reciente. Cada fila: tipo, zona, hace cuánto,
  prioridad, estado, distancia al manglar, confianza y si trae foto. Tirar para actualizar.
- **Detalle** (`detalle_admin.dart`): foto grande (toque = pantalla completa con zoom), cifras, lo que
  contó la persona, mapa chico del punto y las acciones.
  - **Aprobar** → `verificado`.
  - **Rechazar** → `descartado`, con motivo obligatorio (lo lee quien reportó).
  - **Pedir más datos** → `en_verificacion` con un mensaje de hasta 280 letras (lo lee quien reportó).
  - Cada una pasa por una hoja de confirmación y después **Deshacer** durante 6 s (ver abajo).
- **Resumen** (`resumen_admin.dart`): hoy / 7 días: nuevos, alta prioridad (4 y 5), esperan decisión,
  barras por zona y por tipo, y los últimos 7 días.
- **Avisos** (`../comun/capa_avisos.dart`, `../../datos/avisos_ciudadano.dart`).

## Contenido editable (segmento «Contenido»)

`contenido/seccion_contenido_admin.dart` + `../../datos/admin/contenido_panel.dart`. Cada sección pide su permiso
(los nombres de `permisos_rol.sql`):

| Sección | Permiso | Qué se edita |
|---|---|---|
| Portada | `editar_contenido` | Mensaje destacado y aviso del día (con interruptor). Se ven arriba de Inicio (`contenido/franja_portada.dart`). |
| Jornadas | `gestionar_jornadas` | Crear, editar, cerrar/reabrir y quitar: título, fecha y hora, lugar, foto (https) y cupos «sin límite» o número. Aún no salen en la cartelera de Comunidad (pendiente). |
| Noticias | `editar_contenido` | Fijar arriba (hasta 3) u ocultar. Comunidad las ordena y filtra (`contenido_publico.dart`). |
| Puntos QR | `gestionar_puntos` | Activar o apagar cada punto (el servidor cambia `puntos_zanky.activo`). |
| Umbrales | `gestionar_puntos` | Umbral de alerta por medida; el servidor lo copia a `sensores.umbral_alerta`. |
| Historial | (todo el equipo) | Quién cambió qué y cuándo (`historial_panel`, últimos 50). |

Cada guardado se ve al instante, ofrece **Deshacer** (que también queda en el historial) y, si el servidor no lo acepta,
vuelve atrás y dice por qué. Origen a la vista: demostración (en memoria), valores de fábrica (sin `contenido_editable.sql`,
no deja guardar), copia del teléfono sin señal. Teléfono: segmentos, una sección a la vez; desde 900 px: lista a la izquierda.
Pruebas: `test/contenido_panel_test.dart`.

## Deshacer sin tocar el servidor

El esquema no permite volver atrás un estado. Por eso la decisión se **ve al instante** pero solo sale
al servidor pasados 6 s (`ControladorAdmin.plazoDeshacer`); mientras tanto «Deshacer» la quita sin que
el servidor se entere. Si llega otra decisión antes, la anterior sale primero; al salir del panel lo
pendiente se manda. Si el servidor la rechaza (rol sin permiso, otro la cambió antes…), el reporte
vuelve a como estaba y se muestra por qué.

## Servidor

- Lee `reportes` directamente (RLS `reportes_panel_lee`, columnas concedidas: nunca `reportante_id`).
- Foto: `url_foto(id)` (comprueba rol y **audita** «miro_foto») y luego URL firmada de Storage de 60 s.
  Por eso la lista no carga fotos: cada foto vista deja rastro y solo se pide al abrir el detalle.
- Decisiones: `panel_aprobar` y `panel_pedir_datos` (**nuevas**, en `backend/supabase/admin_app.sql`) y
  `cambiar_estado` (ya existía) para rechazar.
- **Sin `admin_app.sql` la app sigue funcionando**: aprobar hace dos llamadas a `cambiar_estado`
  (`en_verificacion` y luego `verificado`) y pedir datos funciona solo si el reporte aún está en
  `recibido` (con otro estado avisa que falta cargar el archivo).

## Notificaciones

- **Equipo (con la app abierta)**: consulta cada 30 s (`ControladorAdmin.cada`), se pausa en segundo plano
  y consulta al volver. Lo que aparece y no estaba es «nuevo»: baja un aviso arriba en cualquier pestaña
  («Reporte nuevo · Abrir panel»), sube el contador del ícono y de la pestaña Guardián, y se limpia al
  abrir la bandeja.
- **Navegador (solo web, solo si el admin lo activa)**: el interruptor «Avisarme en el navegador…» de la
  bandeja pide permiso (Notification API) y desde entonces cada llegada dispara una notificación del
  navegador. Solo mientras la pestaña está abierta. En el teléfono no existe: allí vale el aviso de la app.
- **Ciudadano**: al volver a abrir la app, `EstadoZanky` trae los estados; si el de un reporte propio
  cambió desde la última vez que lo vio (`avisos.vistos.v1` en SharedPreferences) cae un aviso («Aprobaron
  tu reporte de tala…», «No se pudo confirmar… «motivo»», «Piden más datos…»). Una sola vez por cambio. La
  primera vez que corre esta función no avisa de lo que ya estaba.

## Accesibilidad y movimiento

Toques de al menos 44 px (comprobado por las pruebas), `Semantics` en filas, cifras, barras, avisos
(`liveRegion` + `anunciar`) y segmentos (`selected`). Filtros que se desplazan de lado, cifras en `Wrap`,
cabecera de la bandeja dentro de la lista: sin desbordes a 360 px con letra ×2. Con «reducir
movimiento»: sin escalonado, barras que no crecen, esqueleto quieto, sin cuenta atrás animada.

## Pruebas

`test/admin_datos_test.dart` (filtros, orden, cifras, decisiones con Deshacer, consulta periódica,
avisos, contrato con Supabase con servidor falso) y `test/admin_vistas_test.dart` (pantallas a 360×800 y
390×844 con letra ×1, ×1,3 y ×2, y los flujos).

## Fuera (no hecho)

- **Supabase Realtime**: no se usa; hay consulta cada 30 s. Un canal websocket pide un paquete nuevo y
  releer toda la lista al reconectar; la consulta ya cumple «menos de 30 s» y no añade dependencias.
- **Enlace mágico**: solo correo y contraseña.
- Aviso cuando la app está cerrada (push): necesita FCM/Web Push; hoy el aviso al ciudadano es «al volver
  a abrir la app», como se pidió.
- Roles `aliado` (no lee reportes: el servidor lo bloquea) y gestión de roles: se hace por SQL.
