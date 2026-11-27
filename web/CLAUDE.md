# CLAUDE.md

Guía para agentes (Claude Code, Codex) que trabajen en este repositorio.

Proyecto: plataforma web de **Zanqui**, solución de ciencia ciudadana para demostrar el monitoreo de los manglares del departamento del Atlántico (Colombia). Hackatón **ManglarHack Atlántico 2026** (C.R.A. — Corporación Autónoma Regional del Atlántico — y Universidad Simón Bolívar).

El ecosistema tiene tres piezas; esta web es la tercera:

1. **Zanqui en WhatsApp**: mascota y bot con IA (su nombre viene de los zancos del mangle rojo). El ciudadano manda foto + ubicación; la IA clasifica el reporte y le asigna un puntaje de confianza.
2. **App móvil offline-first**: registra reportes sin señal y los sincroniza al reconectar.
3. **Plataforma web** (este repo): mapa público, panel de control de la C.R.A., datos abiertos y comunidad.

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
    catalogos.ts             Etiquetas, íconos y colores por tipo / prioridad / estado / canal
    reportesStore.ts         Estado compartido en memoria entre islas (useSyncExternalStore)
    exportar.ts              Exportación pública CSV, GeoJSON y KML con descarga desde el navegador
    utils.ts                 cn()
  styles/global.css          Tokens de diseño + overrides de Leaflet
  layouts/BaseLayout.astro   <html lang="es">, fuentes, meta, Navbar fija, Footer
  components/
    layout/                  Navbar.astro, Footer.astro
    ui/                      Primitivas Astro: Button, Card, Badge, SectionHeading
    marca/Zanqui.astro        Mascota en SVG
    sections/                Una sección de la página por archivo (Hero, Ecosistema, MapaSection, PanelSection, Comunidad)
    mapa/MapaMonitoreo.tsx   Isla React-Leaflet (client:only="react")
    panel/PanelCRA.tsx       Isla del dashboard (client:load): KPIs, filtros, tabla, exportación
  pages/index.astro          Single page: obtiene datos en el frontmatter y los pasa como props
```

### Flujo de datos

`index.astro` obtiene reportes, historial, polígonos y colegios desde `src/lib/datos.ts`. Al mapa le pasa únicamente `ReportePublico[]` mediante `aReportePublico`; el panel de demostración recibe el contrato completo. La cobertura INVEMAR se obtiene en el navegador con `obtenerCapaManglar`, con estados de carga y error.

El store compartido usa `useSyncExternalStore`: el panel llama `useReportes` y `useHistorial`; el mapa llama `useReportesPublicos`, una proyección que elimina fotos, identidad y precisión y redondea coordenadas. `cambiarEstado` comprueba `TRANSICIONES` y añade auditoría. Al recargar se restauran los ejemplos. En producción permisos, transiciones y auditoría se resuelven en el servidor, nunca en el navegador.

## Esquema de datos

El contrato común del equipo prevalece. La definición completa está en `src/types/manglar.ts`; las etiquetas, iconos, colores y transiciones viven en `src/lib/catalogos.ts`.

- `Reporte`: UUID v4 del dispositivo; canal `app | web | whatsapp`; tipo `tala | quema | relleno | vertimiento | basuras | cano_taponado | fauna | otro`; descripción; `lat`, `lon`, `precision_m`; horas ISO `capturado_en` y `recibido_en`; zona anulable, municipio, `dentro_poligono`, `distancia_m`; prioridad 1–5 propuesta por IA, confianza 0–100; estado; tipo y confianza detectados por IA; URL/hash de foto e identificador del reportante anulables.
- Estados: `recibido`, `en_verificacion`, `verificado`, `alerta_oficial`, `en_atencion`, `cerrado`, `descartado`. Solo una persona verifica y emite una alerta; superar el umbral IA de 80 no sustituye esa decisión.
- `CambioEstado`: id, reporte_id, estado, usuario_id, nota, fecha. Cada reporte tiene recepción y todos los pasos hasta su estado actual.
- `ReportePublico`: omite reportante_id, foto_url, foto_hash y precision_m; añade ubicacion_aproximada. Redondea coordenadas a 2 decimales para tipos sensibles y 3 para el resto.
- Las exportaciones incluyen solo id, capturado_en, tipo, municipio, zona, prioridad, estado, lat, lon y canal. Siempre pasan por privacidad; llevan CC BY 4.0 y Datos de ejemplo.
- Zonas de trabajo: geometrías aproximadas sin área oficial (`area_ha: null`); prioridad propuesta y fuente explícita. Se mantiene el campo `amenazas` del contrato. La cobertura INVEMAR 2020 es independiente del futuro KMZ de la C.R.A.
- Colegio conserva id, nombre, municipio, puntos, reportes_validados, estudiantes y guardian. Ranking y cifras se rotulan como ejemplos.

## Diseño

Basado en el sistema de Innvita (`C:\Nodo`): tokens semánticos como variables CSS, expuestos a Tailwind con `@theme inline`, superficies blancas sobre un fondo apenas tintado, esquinas grandes (`rounded-2xl`/`rounded-3xl`), sombras suaves en vez de bordes duros, tipografía Inter con tracking negativo en titulares.

Utilidades disponibles (definidas en `global.css`):

- Neutros: `bg-fondo`, `bg-fondo-alt`, `bg-superficie`, `border-linea`, `text-texto`, `text-suave`, `text-tenue`.
- Marca: `manglar-950…50` (verde profundo, `manglar-900 = #0b3d2e`), `agua-700…50` (teal, `agua-500 = #14b8a6`).
- Semáforo (cada uno con `-texto` para tipografía AA y `-suave` para fondo de chip): `critica`, `alta` (rojo), `media` (ámbar), `baja` (verde).
- Sombras: `shadow-[var(--c-sombra)]`, `shadow-[var(--c-sombra-alta)]`.

La navegación es fija arriba (`z-[1100]`, por encima de los controles de Leaflet que usan `z-index: 1000`) y `html` tiene `scroll-padding-top` para que las anclas `#inicio`, `#mapa`, `#panel`, `#comunidad` no queden tapadas. El contenedor del mapa lleva `relative z-0` (`isolation`) para que las capas de Leaflet no se monten sobre la navegación.
