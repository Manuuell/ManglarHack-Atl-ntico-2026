# 07 · Pendientes, issues e indicaciones (lista viva)

Lista única del equipo. Cada pendiente grande tiene su issue en GitHub; aquí está el resumen para verlo todo de un vistazo.
**Al terminar algo:** márcalo aquí (`[x]`), cierra el issue y avisa por el correo de agentes. Si aparece algo nuevo, se agrega
aquí con dueño. Última actualización: 27-11-2026, 11:35.

Leyenda de dueños: **Á** Ángel · **M** Manuel · **J** Jerson · **Todos**.

## Estado a las 11:35 (lo que hay y lo que falta)

| Pieza | Dueño | Estado | Lo que falta |
|---|---|---|---|
| App Flutter (Android + web instalable) | Á | En `main`, vista en pantalla; 262 pruebas; APK compila | Arreglar los 37 defectos de la revisión (en curso), capa oficial de la CRA, Supabase real, probar en un Android |
| Backend Supabase + IA de fotos | Á | En `main`, **sin ejecutar** | **Crear el proyecto (Ángel)**, correr el SQL, clave de IA y prueba de punta a punta |
| Web: plataforma abierta + panel de la Corporación | **J** | Rama `web` (Astro, Leaflet, datos oficiales de la CRA) | Conectar a Supabase; revisión de Á en curso; acordar con M la vista pública |
| Bot de WhatsApp | M | **WhatsApp real** (Meta, HTTPS) en `zanqui-bot` | Puente a Supabase (lo escribe Á como commits aparte, M revisa), caso `ZK-` |
| **Atender llamadas en el número** | M (+ Á porta el bot de voz) | Propuesto, esperando el sí de M | Proveedor de telefonía para voz (Meta Cloud no recibe llamadas normales) |
| Arte de Zanky (Flow) | M | Nombre e historia confirmados; **sin imágenes aún** | PNG de los 4 ánimos en `marca/zanky/` y modelos para la ficha |
| Pitch, ficha y video | Todos | Guion en `09` | Grabar a las 16:00, rúbrica, ensayo |
| Correo de agentes (Mesa) | M ✅, J ⏳ | Manuel conectado | Jerson conectarse |

## A. Coordinación (ya)

- [ ] **M, J** — Conectar su agente al correo de Mesa (clave por WhatsApp; hooks en `.claude/settings.local.json`).
- [ ] **M** — Enlace del repo de **Invitta**, su stack y su backend (¿Supabase, Firebase u otro?). De esto depende si el
  backend común se queda en Supabase.
- [ ] **M** — Arte oficial de **Zanky** hecho con Flow: PNG transparentes de 1024 px en 4 ánimos (feliz, curioso,
  preocupado, celebrando) con el mismo encuadre y los pies en la misma línea; bucles cortos opcionales; paleta. Va en
  `marca/zanqui/`. La app ya tiene el lugar único donde se cambia (`app/lib/vistas/comun/zanky_mascota.dart`).
- [ ] **Todos** — Validar con los mentores (antes de las 11:00): lista de **tipos de amenaza**, su **gravedad**, la
  **prioridad de conservación** de cada zona y el nombre de Zanky con los mentores comunitarios.
- [ ] **Todos** — Pedir la **rúbrica del jurado** y alinear el pitch con ella.
- [x] **Todos** — KMZ de la CRA convertido: `app/assets/datos/manglar_zonas.json` y `prioridades_cra.json`
  (`node app/tool/preparar_capas_cra.mjs`) y el SQL en partes (`node backend/supabase/generar_zonas.mjs`).

## B. Backend común (`backend/`, Á)

- [x] Esquema propuesto: PostGIS, RLS, roles en una sola función, auditoría, datos abiertos, realtime.
- [ ] **Á** — Crear el proyecto Supabase (cuenta del equipo) y correr `schema.sql` → `zonas-1..3.sql` → `prioridades-1..6.sql` → `seed_demo.sql` (orden y pesos en `backend/supabase/README.md` §8).
- [ ] **Á** — Prueba de punta a punta contra la base real (los 6 riesgos de `backend/supabase/README.md`).
- [ ] Límite por IP para reportes anónimos (función en el borde).
- [ ] Quitar metadatos (EXIF/GPS) de las fotos en el servidor.
- [ ] **Clasificación con IA** del reporte (foto + texto contra el tipo): marca coincidencias, nunca bloquea.
- [ ] Viento de Open-Meteo también en la prioridad del servidor.
- [ ] Aviso al bot cuando cambia el estado (para avisar al ciudadano por WhatsApp).

## C. App móvil (`app/`, Á)

- [x] Base: datos sin señal, zonas en el teléfono, prioridad con motivos, solidez, guardián, tema, Zanky, barra.
- [x] Flujo de reporte: tipo → ubicación (GPS, mapa, enlace de Google Maps) → foto → detalles → enviado.
- [x] Pantallas: bienvenida y privacidad, mapa, mis reportes y detalle, guardián (tarjeta, nivel, insignias, misiones).
- [x] Recorrido completo visto en el navegador a 375 px (bienvenida → reporte → confirmación → mis reportes → mapa → guardián); 8 defectos de pantalla encontrados y arreglados.
- [ ] Ver cada pantalla en el navegador y en un Android real; medir la fluidez cuadro a cuadro.
- [ ] Probar **sin señal**: reportar en modo avión, volver y ver que llega sola, sin duplicar.
- [ ] Probar el **peor caso**: el servidor guarda y la respuesta se pierde; reintentar no duplica.
- [ ] Cambiar a Zanky por el arte oficial cuando llegue.
- [ ] Ícono de la app y pantalla de arranque con Zanky.
- [ ] Pruebas de pantallas (widget) del flujo de reporte.

## D. Web: panel de la CRA y vista pública (`web/`, M y J)

- [ ] Panel con **roles** (administrador, moderador CRA, vigía, aliado) usando `panel_rol_de` del backend.
- [ ] **Cola de verificación** con fotos (cada foto vista queda auditada), cambio de estado y expediente.
- [ ] **Mapa en vivo** que relee todo al reconectar el canal.
- [ ] **Exportar datos abiertos**: GeoJSON, CSV y KML (Gobierno Digital).
- [ ] **Vista pública** con el mapa anonimizado + formulario ligero para turistas que entran por QR.
- [ ] **Eventos** (base de Invitta): siembras, limpiezas, recorridos; invitaciones con enlace.
- [ ] Zanky interactivo también en la web.

## E. Bot de WhatsApp (`bot/`, M; revisión de Á en el issue #10)

- [ ] Flujos (rama `zanqui-bot` de Manuel): reportar (con foto, ubicación y **audio** transcrito), número de caso, consultar estado, eventos.
- [ ] Probar con el simulador y luego con una cuenta real (Meta Cloud o Evolution; cuenta de Ángel). En construcción en `bot/`.
- [ ] Aviso al ciudadano cuando cambia su caso; difusión solo con consentimiento.
- [ ] Llamadas (después de la entrega, documentado).

## F. Participación y difusión (pregunta 3)

- [ ] Videos de Zanky (propios o con IA) para líderes ecológicos y redes, siempre con la invitación a la web y a los eventos.
- [ ] Letreros con **QR/NFC** en Mallorquín, Puerto Colombia y playas.
- [ ] Colegios: servicio social estudiantil y PRAE; ranking «Guardianes del manglar».
- [ ] Alianzas con empresas que ya siembran manglar (RSE) y con la asociación de pescadores.

## G. Entrega (17:00) y pitch (19:00)

- [ ] **16:00 congelar funciones** (lista corta en `06` §12).
- [ ] Video de 2-3 min grabado antes de las 16:30, con la app y el panel de verdad.
- [ ] **Ficha técnica** con herramientas y **modelos de IA** usados (plantilla en `02`).
- [ ] README de la raíz al día: qué es, cómo se corre cada pieza, capturas.
- [ ] Revisión de seguridad antes de entregar (el mentor de ciberseguridad lee el código): sin secretos, permisos en el
  servidor, entradas validadas.
- [ ] Pitch de 7 min ensayado y alineado con la rúbrica.

## Indicaciones de excelencia (pedido de Ángel)

Todo se hace **muy bien**, no rápido: detalle, microdetalle, interacción, microinteracción, gesto, navegación,
funcionalidad, usabilidad, arquitectura, optimización y fluidez. Se reutiliza lo mejor que ya tenemos probado y se mejora;
se dan ideas y se proponen mejoras; se coordina por el correo de agentes y por el repo. La vara completa está en
[`06-la-vara-y-aprendizajes.md`](06-la-vara-y-aprendizajes.md) y las reglas del repo en
[`05-coordinacion-y-reglas.md`](05-coordinacion-y-reglas.md).
