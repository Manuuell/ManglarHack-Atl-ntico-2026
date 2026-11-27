# Arte de Zanky

Zanky es un mangle rojo con raíces en zancos y cintas de carnaval, la mascota que guía al ciudadano al reportar.
La imagen de referencia del personaje es [`zanky-referencia.jpg`](zanky-referencia.jpg). Todas las demás imágenes se
hicieron partiendo de ella, para que el personaje se vea igual en todas.

## Qué hay en cada carpeta

| Carpeta | Qué tiene |
|---|---|
| `zanky-referencia.jpg` | El diseño elegido (era la propuesta 2, «tierno»). |
| `materiales/` | Hoja de personaje (01) con 4 vistas, expresiones (02), poses para la app (03 a 08: bienvenida, reportando, sin conexión, validado, alerta, celebración), etapas de crecimiento (09), foto de perfil de WhatsApp (10), ícono de la app (11), hoja de stickers (12) y portada 16:9 (13). |
| `materiales/vistas/` | Hojas de vista rápida que juntan varios materiales en una sola imagen. |
| `escenas-video/` | Los cuadros iniciales de 3 de los clips de video (alerta, sin señal y celebración) y una hoja con cuadros de los 4 clips. El cuadro de la intro es la portada `materiales/13-portada-16x9.jpg`. |
| `propuestas/` | Las otras propuestas de diseño que se descartaron, y dos hojas que las comparan. |

## Herramientas y modelos de IA (para la ficha técnica)

| Herramienta | Modelo | Para qué se usó |
|---|---|---|
| Muse, de Meta | `muse-image-1.0` (edición con imagen de referencia) | Propuestas de diseño y todos los `materiales/`. |
| Google Flow | Nano Banana 2.1 | Los cuadros iniciales de `escenas-video/`. |
| Google Flow | Omni 1.2 Flash | Los 4 clips de 8 s (intro, alerta, sin señal, celebración), descargados en 1080p. No están en el repo por su peso, unos 33 MB. |

Las imágenes conservan los metadatos que ponen Meta y Google para indicar que son generadas con IA. No tienen
ubicación GPS.

## Paleta de referencia

| Uso | Color |
|---|---|
| Hojas | `#2E7D32` / `#43A047` |
| Corteza | `#8B3A2B` |
| Raíces | `#6D3B2A` |
| Agua (fondo principal) | `#1FA2A6` |
| Carnaval: amarillo | `#F9C80E` |
| Carnaval: rojo | `#E63946` |
| Carnaval: verde | `#2A9D8F` |

## Lo que falta

- Los **PNG transparentes de 1024 px en 4 ánimos** (feliz, curioso, preocupado, celebrando) para la app, con el mismo
  encuadre y los pies en la misma línea. Todas las imágenes de aquí tienen fondo, así que todavía no sirven para
  reemplazar a Zanky en `app/lib/vistas/comun/zanky_mascota.dart`.
