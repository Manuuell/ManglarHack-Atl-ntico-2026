# Ficha técnica · Zanky

Manglar Hack Atlántico 2026 · reto de ciencia ciudadana de la C.R.A. · equipo SENTRALABS · UTB.
Revisada contra el código de `main` el 27-11-2026.

**Qué es.** Es monitoreo ciudadano de las amenazas al manglar del Atlántico. Se reporta por app, WhatsApp o web, con ubicación, foto y prioridad. Los reportes llegan a un servidor común y a un panel de verificación de la C.R.A., y salen a un mapa abierto y a datos abiertos. Además hay alertas ambientales y jornadas comunitarias.

## Herramientas y tecnologías

| Componente | Tecnologías (versión) | Para qué |
|---|---|---|
| App móvil | Flutter 3.44 / Dart 3.12; `flutter_map` 8.3, `geolocator` 14, `image_picker` 1.2; también compilada para la web | Reportar sin señal (cola local), GPS o punto en el mapa, foto, prioridad, mapa, alertas y avisos, jornadas, «mis reportes», datos abiertos, tarjeta de guardián y modo evento por QR |
| Web | Astro 7.4, React 19.3, Tailwind CSS 4.3, Leaflet 1.9 + react-leaflet 5, lucide-react | Portada comunitaria en vivo, reportar, alertas, jornadas, visores (riesgo, agua, workflow), plataforma de la C.R.A., panel y administración |
| Zanky BOT | Node.js ≥ 20, TypeScript 5.7, Express 4.21; API oficial de WhatsApp Cloud (Meta) | Reportar por conversación (texto, ubicación, foto y notas de voz), número de caso, aviso de cambio de estado, jornadas, alertas, invitaciones y datos abiertos |
| Servidor común | Supabase: Postgres + PostGIS, Auth, Storage (fotos en un depósito privado), RLS y funciones | En el servidor, nunca en el cliente: sector, área de influencia de 500 m, prioridad 1–5, confianza 0–100, corroboración, permisos por rol y auditoría |
| Alertas del manglar | Motor en el servidor del bot, cada 10 min | Mar de leva, pleamar con oleaje, lluvia y viento fuertes, riesgo de incendio y fuego cerca del manglar |
| Sensores (en desarrollo) | ESP32 (nivel de agua, salinidad por TDS, temperatura), ingesta con token por sensor | Lecturas automáticas que complementan el reporte ciudadano |
| Publicación | Servidor Ubuntu con nginx y HTTPS; dominios mimanglar.sentralabs.co (web y app) y zanqui.sentralabs.co (bot); servicios con systemd | Web estática, app web, bot y copia de los datos de la C.R.A. cada 15 min |

## Modelos de IA

| Dónde | Modelo | Para qué | Estado |
|---|---|---|---|
| Zanky BOT y burbuja de la web | OpenAI **gpt-4o-mini** | Conversar: explicar, responder preguntas libres sobre el manglar y llevar a la persona a reportar o a una jornada. Reportar sigue siendo un flujo guiado; reconocer la amenaza en el texto («están talando mangle…») se hace con reglas, no con IA | En uso |
| Zanky BOT | OpenAI **gpt-4o-mini-transcribe** | Transcribir las notas de voz de WhatsApp. Después siguen la conversación como texto (máximo 20 audios por persona en una hora) | En uso |
| Servidor (clasificar la foto) | Anthropic **Claude Haiku 5.5** | Dar una pista sobre si la foto coincide con el tipo reportado. Es una pista para quien verifica: no confirma nada ni identifica personas | Escrito y con pruebas, todavía no desplegado |
| Construcción del software | **Claude Code** con Claude Opus 5.5 y Claude Sonnet 5.5 (Anthropic) | Análisis del reto, código de la app, la web, el bot y el servidor, revisión y documentación | Usado en el hackatón |
| Arte de Zanky | Muse de Meta (`muse-image-1.0`); Google Flow (Nano Banana 2.1 y Omni 1.2 Flash); Vision de Apple para recortar el fondo | Personaje, poses, stickers, avatar del bot y clips de video | Usado; las imágenes llevan los metadatos que indican que son generadas con IA |

## Datos

| Fuente | Qué se usa |
|---|---|
| C.R.A. | Cobertura de manglar a 1:5.000, prioridades de conservación del plan de manejo, workflow del manglar (manglar probable, cambios y dosel), API de gestión del riesgo (puntos críticos, focos de calor, calidad del agua) y noticias |
| IDEAM | Estaciones automáticas (WIS2) y pronóstico WRF y WW3 |
| DIMAR | Tablas de marea |
| INVEMAR | Capa Nacional de Manglares 2020, como referencia |
| OpenStreetMap y Esri | Mapas base e imágenes satelitales |

## Validación y privacidad

- **La confianza se calcula en el servidor.** La del teléfono vale como máximo 80. La corroboración (otra persona reporta el mismo tipo de amenaza a 1 km o menos, en ±3 h) suma hasta 10. Lo demás lo deciden la IA y las personas.
- La huella SHA-256 de la foto delata las fotos repetidas. Los límites de envío frenan el abuso.
- Cada cambio de estado queda en la auditoría, y quien reporta recibe el aviso por WhatsApp.
- Lo público no lleva nombre, teléfono ni foto, y la ubicación va difuminada. Los datos personales se tratan según la Ley 1581 de 2012. Los datos abiertos van con licencia CC BY 4.0.
