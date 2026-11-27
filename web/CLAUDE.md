# CLAUDE.md

Guía para agentes (Claude Code, Codex) que trabajen en este repositorio.

Proyecto: plataforma web de **Sanky**, solución de ciencia ciudadana para monitorear en tiempo real los manglares del departamento del Atlántico (Colombia). Hackatón **ManglarHack Atlántico 2026** (C.R.A. — Corporación Autónoma Regional del Atlántico — y Universidad Simón Bolívar).

El ecosistema tiene tres piezas; esta web es la tercera:

1. **Sanky en WhatsApp**: mascota y bot con IA (su nombre viene de los zancos del mangle rojo). El ciudadano manda foto + ubicación; la IA clasifica el reporte y le asigna un puntaje de confianza.
2. **App móvil offline-first**: registra reportes sin señal y los sincroniza al reconectar.
3. **Plataforma web** (este repo): mapa en vivo, panel de control de la C.R.A., datos abiertos y comunidad.

## Comandos

```bash
npm run dev      # Servidor de desarrollo en http://localhost:4321
npm run check    # astro check: TypeScript estricto en .astro, .ts y .tsx
npm run build    # Build estático a dist/
npm run preview  # Sirve dist/
```

No hay suite de pruebas. `npm run check` y `npm run build` son la puerta de calidad: ambos deben pasar antes de cada commit.

## Stack

- **Astro 7** (salida estática, una sola página `src/pages/index.astro`).
- **React 19** vía `@astrojs/react` para las islas interactivas.
- **Tailwind CSS v4** vía `@tailwindcss/vite` (no `@astrojs/tailwind`: ese paquete solo soporta Astro ≤ 5 y Tailwind 3). No hay `tailwind.config.*`: los tokens viven en `src/styles/global.css` con `@theme inline`.
- **Leaflet 1.9 + react-leaflet 5** para el mapa. Teselas de OpenStreetMap / CARTO.
- **lucide-react** para íconos, también dentro de `.astro` (Astro los renderiza como SVG estático sin hidratar).
- `clsx` + `tailwind-merge` en `cn()` (`src/lib/utils.ts`).

## Reglas críticas

1. **El mapa se renderiza solo en el cliente.** Todo componente que importe `leaflet` o `react-leaflet` se monta con `client:only="react"`. Leaflet toca `window` al importarse; con SSR el build falla con `window is not defined`. Nunca importar Leaflet desde frontmatter de `.astro` ni desde un módulo que también usen componentes renderizados en servidor.
2. **Toda la interfaz en español** (textos, `aria-label`, `title`, mensajes, nombres de archivo exportados). Código y nombres de variables también en español cuando sean del dominio (`reportes`, `prioridad`, `zona`).
3. **Datos desacoplados.** Los componentes nunca importan los JSON de `src/data/` directamente: piden los datos a `src/lib/datos.ts`. Para conectar la base de datos real o el GeoJSON oficial de la C.R.A., solo cambia ese archivo (las funciones ya son `async`).
4. **Paleta eco-tech con semáforo de prioridad** (ver "Diseño"). Los colores de prioridad salen de `src/lib/catalogos.ts`, nunca escritos a mano en un componente.
5. **Commits**: uno por implementación, mensaje en español y **sin trailer de coautoría** (`Co-Authored-By` ni similares).

## Arquitectura

```
src/
  data/                      Datos mock (reemplazables)
    poligonosManglar.json    GeoJSON FeatureCollection de zonas de manglar
    mockReportes.json        Reportes ciudadanos (WhatsApp / app)
    colegios.json            Ranking de colegios participantes
  types/
    manglar.ts               Tipos del dominio (fuente de verdad del esquema)
  lib/
    datos.ts                 Capa de acceso a datos (async). Único lector de src/data/
    catalogos.ts             Etiquetas, íconos y colores por tipo / prioridad / estado / origen
    reportesStore.ts         Estado compartido en memoria entre islas (useSyncExternalStore)
    exportar.ts              Exportación CSV y GeoJSON con descarga desde el navegador
    utils.ts                 cn()
  styles/global.css          Tokens de diseño + overrides de Leaflet
  layouts/BaseLayout.astro   <html lang="es">, fuentes, meta, Navbar fija, Footer
  components/
    layout/                  Navbar.astro, Footer.astro
    ui/                      Primitivas Astro: Button, Card, Badge, SectionHeading
    marca/Sanky.astro        Mascota en SVG
    sections/                Una sección de la página por archivo (Hero, Ecosistema, MapaSection, PanelSection, Comunidad)
    mapa/MapaMonitoreo.tsx   Isla React-Leaflet (client:only="react")
    panel/PanelCRA.tsx       Isla del dashboard (client:load): KPIs, filtros, tabla, exportación
  pages/index.astro          Single page: obtiene datos en el frontmatter y los pasa como props
```

### Flujo de datos

`index.astro` llama en su frontmatter a `obtenerReportes()`, `obtenerPoligonos()` y `obtenerColegios()` de `src/lib/datos.ts` y pasa el resultado como props a las secciones e islas. Las islas no hacen fetch propio.

El mapa y el panel son islas React separadas (raíces distintas), pero comparten **un solo estado en memoria**: `src/lib/reportesStore.ts` es un módulo singleton en el navegador. Cada isla llama a `useReportes(iniciales)`, que inicializa el store la primera vez y luego solo se suscribe. Cuando el panel cambia un reporte a `validado` o `escalado` con `actualizarEstado(id, estado)`, el popup del mapa refleja el cambio sin recargar. El estado no persiste: al recargar vuelve el mock.

Para pasar a "tiempo real" de verdad, `reportesStore` es el punto donde enchufar una suscripción (WebSocket, Firestore `onSnapshot`, Supabase Realtime) que llame a `reemplazarReportes()`.

## Esquema de datos

Fuente de verdad: `src/types/manglar.ts`. Resumen:

### Reporte (`mockReportes.json`: `Reporte[]`)

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `string` | `"R-2026-0001"` |
| `origen` | `"whatsapp" \| "app"` | Canal por el que llegó |
| `tipo` | `"amenaza" \| "siembra" \| "limpieza" \| "avistamiento"` | |
| `titulo` | `string` | Corto, en español |
| `descripcion` | `string` | 1–2 frases |
| `lat`, `lng` | `number` | WGS84, dentro del polígono de su zona |
| `zona` | `string` | Igual a `properties.nombre` de un polígono |
| `prioridad` | `"alta" \| "media" \| "baja"` | |
| `confianza_ia` | `number` | 0–100, puntaje del clasificador de Sanky |
| `estado` | `"pendiente" \| "validado" \| "escalado"` | `escalado` = escalado a expediente sancionatorio de la C.R.A. |
| `autor` | `string` | Nombre del ciudadano o colegio |
| `fecha` | `string` | ISO 8601 con zona `-05:00` |
| `foto_url` | `string` | Placeholder `https://placehold.co/...` |

### Zona de manglar (`poligonosManglar.json`: GeoJSON `FeatureCollection<Polygon>`)

`properties`: `id` (slug), `nombre`, `municipio`, `prioridad` (`"critica" \| "alta" \| "media" \| "baja"`, prioridad de conservación), `area_ha`, `especies` (`string[]`), `amenazas` (`string[]`), `descripcion`. Coordenadas `[lng, lat]` (orden GeoJSON), anillo cerrado. Son polígonos **aproximados** a la espera del GeoJSON oficial de la C.R.A.

Zonas: Ciénaga de Mallorquín (crítica), Puerto Colombia (alta), Tubará (media), Juan de Acosta / Piojó (alta).

### Colegio (`colegios.json`: `Colegio[]`)

`id`, `nombre`, `municipio`, `puntos`, `reportes_validados`, `estudiantes`, `guardian` (`boolean`: insignia "Guardián del Manglar").

### Reglas derivadas (en `src/lib/catalogos.ts`)

- `UMBRAL_IA = 80`: un reporte con `confianza_ia >= 80` cuenta como "validado por IA".
- Amenaza crítica activa: `tipo === "amenaza"` y `prioridad === "alta"`.
- Insignia Guardián: la trae el dato (`guardian`), no se calcula.

## Diseño

Basado en el sistema de Innvita (`C:\Nodo`): tokens semánticos como variables CSS, expuestos a Tailwind con `@theme inline`, superficies blancas sobre un fondo apenas tintado, esquinas grandes (`rounded-2xl`/`rounded-3xl`), sombras suaves en vez de bordes duros, tipografía Inter con tracking negativo en titulares.

Utilidades disponibles (definidas en `global.css`):

- Neutros: `bg-fondo`, `bg-fondo-alt`, `bg-superficie`, `border-linea`, `text-texto`, `text-suave`, `text-tenue`.
- Marca: `manglar-950…50` (verde profundo, `manglar-900 = #0b3d2e`), `agua-700…50` (teal, `agua-500 = #14b8a6`).
- Semáforo (cada uno con `-texto` para tipografía AA y `-suave` para fondo de chip): `critica`, `alta` (rojo), `media` (ámbar), `baja` (verde).
- Sombras: `shadow-[var(--c-sombra)]`, `shadow-[var(--c-sombra-alta)]`.

La navegación es fija arriba (`z-[1100]`, por encima de los controles de Leaflet que usan `z-index: 1000`) y `html` tiene `scroll-padding-top` para que las anclas `#inicio`, `#mapa`, `#panel`, `#comunidad` no queden tapadas. El contenedor del mapa lleva `relative z-0` (`isolation`) para que las capas de Leaflet no se monten sobre la navegación.
