# CLAUDE.md — web/

Guía para agentes (Claude Code, Codex) que trabajan en `web/`. Las reglas del equipo están en `../CLAUDE.md` y `../handoff/05-coordinacion-y-reglas.md`, y mandan sobre esta guía.

**Qué es:** la aplicación web del reto ManglarHack Atlántico 2026 (equipo SENTRALABS · UTB, para la C.R.A.). Replica la identidad y la información de la plataforma de la Corporación ([manglarcra.netlify.app](https://manglarcra.netlify.app)) y la extiende: aquí se integra todo lo que llega de la **app móvil** y del **bot de WhatsApp de Zanky** (la mascota; su nombre viene de los zancos del mangle rojo y de los zanqueros del Carnaval).

Rama de trabajo: **`web`** (nunca `main`). Un commit por punto, en español, **sin trailer de coautoría**. `git pull --rebase` antes de subir; nunca `--force`.

## Comandos

```bash
npm run dev      # http://localhost:4321
npm run check    # astro check (TS estricto en .astro/.ts/.tsx)
npm run build    # build estático a dist/ (antes baja la copia de datos de la C.R.A.)
npm run cra:copiar  # solo actualiza public/cra/ con los datos de manglarcra.netlify.app
```

No hay pruebas automatizadas: `check` y `build` deben pasar antes de cada commit, y cada pantalla se mira en el navegador antes de darla por buena.

## Stack

Astro 7 (estático, varias páginas) · React 19 (`@astrojs/react`) para islas · Tailwind v4 (`@tailwindcss/vite`; tokens en `src/styles/global.css`, sin `tailwind.config`) · Leaflet 1.9 + react-leaflet 5 (teselas OpenStreetMap) · lucide-react · `cn()` en `src/lib/utils.ts`.

## Reglas críticas

1. **Leaflet solo en cliente**: todo componente que importe `leaflet`/`react-leaflet` se monta con `client:only="react"` y con un `slot="fallback"` del mismo alto.
2. **Todo en español**, también `aria-label`, `title` y nombres de archivos descargados.
3. **Datos desacoplados**: solo `src/lib/datos.ts` (reportes, zonas, capas) y `src/lib/plataforma/datos.ts` (actores, acciones…) leen `src/data/`. Sus funciones son `async` para cambiarlas por la API del backend.
4. **Honestidad del dato**: toda cifra lleva su fuente; los datos inventados se rotulan **«Datos de ejemplo»**; lo que no funciona aún se dice («pendiente del KMZ de la C.R.A.», «se conectará al backend»). Manglar **probable**, nunca «confirmado».
5. **Privacidad**: lo público pasa por `aReportePublico` (sin foto, sin reportante, coordenadas difuminadas). Correos y teléfonos de actores nunca se muestran en vistas públicas.
6. **Permisos y auditoría**: en esta demo los cambios de estado viven en el navegador (memoria o `localStorage`) y se rotulan «Modo demostración». En producción los decide el servidor (rol comprobado en un solo lugar + línea de auditoría).
7. **Área de reporte**: solo se admiten denuncias dentro de la cobertura de manglar de la C.R.A. a 1:5.000 (`datos/cra/manglar_escala_1-5000.gdb.zip`) o a menos de 500 m de ella (área de influencia). Lo de fuera (por ejemplo, el casco urbano de Barranquilla) no se publica y el panel lo marca para descartar. La regla vive en `src/lib/areaReporte.ts` (`enAreaDeReporte`, `evaluarUbicacion`, `LIMITES_MANGLAR` para que los mapas no se salgan de la zona); el servidor la aplica al recibir.
8. **Catálogos únicos**: etiquetas, colores, estados y transiciones salen de `src/lib/catalogos.ts` (reportes) y `src/lib/plataforma/catalogos.ts` (plataforma). Nunca reescribirlos en un componente.

## Rutas

| Ruta | Qué es |
|---|---|
| `/` | Portada comunitaria en vivo (`src/styles/portada.css` + `src/scripts/portada.ts` + `src/components/comunidad/`): cabecera que pasa a cápsula al bajar; hero con el mapa satelital y la lista «Ahora en el manglar» (reportes de la comunidad y jornadas); «Reportar un problema» (tipo, ubicación en el mapa con la regla del área de reporte, foto, detalles, consentimiento); próximas jornadas con inscritos; avisos en tiempo real (otras pestañas incluidas, vía `lib/comunidad/reportesLocales.ts`). Sin texto del reto: solo lo que hace la comunidad |
| `/workflow` | Mapa 2D + panel derecho con pestañas Síntesis, Extensión, Cambios, Dosel 2026, Altura, Agua, Presión, Carbono, Método y Fuentes |
| `/plataforma` | Inicio de la plataforma abierta (mapa del manglar y de las acciones, estado del manglar, acciones en curso) |
| `/plataforma/registro` | Registro de actor |
| `/plataforma/proponer` | Proponer acción marcando el sitio en el mapa |
| `/plataforma/seguimiento` | Seguimiento de acciones + jornadas (inscripción, invitación, calendario; base Innvita) |
| `/plataforma/jornadas` | Jornadas comunitarias: cartelera con tarjetas, invitación por enlace (`?jornada=`) con inscripción y consentimiento, WhatsApp, compartir, Google Calendar, `.ics`, QR y cartel imprimible (A4, con dos QR: inscripción e «Interactúa con Zanky»); botón y QR «Interactúa con Zanky» que abren la app en `/app/?evento=<id>` (`urlEventoZanky`, `PUBLIC_URL_APP`); crear jornada ligada a una acción |
| `/app/` | Versión web de la app Flutter (experiencia del evento con Zanky). No la genera Astro: se publica aparte en el servidor y el despliegue de la web no la toca |
| `/plataforma/monitoreo` | Monitoreo comunitario: reportes de Zanky (app/bot/web) y fotos georreferenciadas |
| `/plataforma/proyectos` | Plantillas prellenadas (Metodología General Ajustada, nota conceptual) |
| `/plataforma/panel` | Panel de la Corporación: acciones, reportes ciudadanos, capas KMZ, auditoría, roles de demostración |

Todas las páginas de la plataforma usan `src/layouts/PlataformaLayout.astro` (cabecera con logo C.R.A., título y barra de pestañas).

## Arquitectura

```
src/
  data/                         mocks y datos (solo los leen las capas de datos)
    mockReportes.json           reportes ciudadanos (contrato común)
    historialEstados.json       auditoría de reportes
    poligonosManglar.json       4 sectores C.R.A. aproximados (envolvente INVEMAR)
    colegios.json               ranking (ejemplo)
    plataforma/*.json           actores, acciones, cambios de acción, jornadas, monitoreos
  types/manglar.ts              contrato común de reportes
  types/plataforma.ts           actores, acciones, jornadas, monitoreo
  lib/datos.ts                  reportes, zonas, capa INVEMAR (URL_CAPA_INVEMAR, obtenerCapaManglar)
  lib/catalogos.ts              tipos/estados/prioridad/canal de reportes
  lib/privacidad.ts             aReportePublico
  lib/reportesStore.ts          estado compartido de reportes + historial
  lib/exportar.ts               CSV, GeoJSON y KML públicos
  lib/workflow.ts               cifras y pestañas del workflow, construidas del resumen de la C.R.A. (con respaldo fijo)
  lib/cra.ts, useWorkflowCRA.ts lectura en vivo de /cra/data/core.json (ver «Datos de la C.R.A. en vivo»)
  lib/plataforma/               datos.ts, catalogos.ts, almacen.ts (store persistente), …
  layouts/                      BaseLayout.astro, PlataformaLayout.astro
  components/                   layout/, ui/, marca/ (Zanky), mapa/, panel/, workflow/, plataforma/
  pages/                        rutas de la tabla
public/marca/logo-cra-blanco.png
```

La capa de manglar de INVEMAR 2020 se importa con `?url` desde `../datos/` (por eso `vite.server.fs.allow: ['..']`). El KMZ oficial de la C.R.A. se convierte a GeoJSON (script y carga en el panel) y reemplaza a los sectores aproximados.

## Contrato común de reportes (de `../handoff/05`)

- tipos `tala | quema | relleno | vertimiento | basuras | cano_taponado | fauna | otro`;
- estados `recibido → en_verificacion → verificado → alerta_oficial → en_atencion → cerrado`, o `descartado`;
- `id` UUID del dispositivo; `capturado_en` (dispositivo) y `recibido_en` (servidor); canal `app | web | whatsapp`; prioridad 1–5 propuesta por IA (semáforo: 4–5 alta, 3 media, 1–2 baja) y confianza 0–100.

## Plataforma (modelo de la C.R.A.)

- **Actor**: tipo (comunidad u organización de base, entidad pública, academia, empresa, ONG, ciudadano), sector de interés y papel (proponer y ejecutar, coparticipar, monitorear y reportar, financiar o cooperar). Tratamiento de datos según Ley 1581 de 2012.
- **Acción**: tipo (siembra, restauración hidrológica, solución basada en la naturaleza, conservación y vigilancia), sitio en el mapa, hectáreas, acción y prioridad heredadas del plan de manejo, lista de requerimientos, comunidad coparticipante.
- **Estados de acción**: `propuesta → en_revision → (con_observaciones ↔ en_revision) → aprobada → en_ejecucion → cerrada`.
- **Jornada** (base Innvita): actividad con fecha, punto de encuentro, cupos e inscritos, ligada a una acción.
- **Reporte de monitoreo**: plántulas vivas (%), altura media (cm), fotografías ubicadas, observaciones.
- **Sectores**: Mallorquín (Mallorquín – Bocas de Ceniza), Balboa (Puerto Colombia – Balboa – Puerto Velero), Manatíes (Tubará – Juan de Acosta; correspondencia por confirmar con la C.R.A.), Totumo (Totumo – Astilleros – Galerazamba).

## Cifras del workflow (fuente: workflow de la C.R.A., manglarcra.netlify.app)

775 ha de manglar probable en 2025 (465 con probabilidad alta + 310 media) · 828 ha por revisar · por sector (probable + por revisar): Mallorquín 516, Balboa 197, Manatíes (Tubará – Juan de Acosta) 148, Totumo 742 · pérdida −34,7 ha entre 2016 y 2025 · 262 ha con dosel más seco en 2026 · altura mediana del dosel 10,7 m · 194 ha en riesgo muy alto · carbono 125 mil t, 270 t C/ha (92 % en el suelo). Capa INVEMAR 2020 (referencia nacional): 144 polígonos, 533 ha.

## Datos de la C.R.A. en vivo (`/cra/`)

La web usa los mismos datos que publica la C.R.A. en manglarcra.netlify.app y se actualiza sola cuando cambian. Ese sitio no deja que otro dominio lea sus datos desde el navegador, así que se copian al nuestro:

- `scripts/copiar-cra.mjs` baja `data/core.json` y las imágenes y audios que nombra a `public/cra/` (ignorada en git). Solo baja lo que cambió (ETag), valida la forma de `core.json` y, si llega roto o el sitio no responde, conserva la última copia buena. Escribe `espejo.json` con la fecha de revisión.
- Corre antes de `dev` y de `build` (con `--suave`: avisa pero no falla sin red), así que `dist/cra/` siempre lleva una copia.
- En el VPS lo corre cada 15 minutos `mimanglar-cra.timer` (unidades en `scripts/vps/`, script en `~/mimanglar-cra/`) sobre `/var/www/mimanglar/cra`. Si un despliegue con `rsync --delete` la pisa, el temporizador la repone.
- La web lee la copia con `cargarCRA()` (`src/lib/cra.ts`) y `useWorkflowCRA()`; `construirWorkflow()` arma cifras, sectores y pestañas. Si la copia no responde, se usan `RESPALDO_CRA` (cifras del 27-11-2026) y se dice en pantalla.
- `/workflow` incrusta además el visor original de la C.R.A. (capas, vista 3D y audios) desde manglarcra.netlify.app.
- Instalar o actualizar en el VPS: copiar `copiar-cra.mjs` a `~/mimanglar-cra/`, `sudo install -m 644 scripts/vps/mimanglar-cra.* /etc/systemd/system/`, `sudo systemctl daemon-reload && sudo systemctl enable --now mimanglar-cra.timer`. Registro: `journalctl -u mimanglar-cra.service`.

## Diseño (identidad C.R.A. modernizada)

- Fondo azul institucional profundo (`bg-fondo` #082B45, `bg-fondo-alt`), tarjetas azul intermedio (`bg-superficie`, `bg-superficie-alta`), texto blanco (`text-texto`, `text-suave`, `text-tenue`), líneas finas translúcidas (`border-linea`, `border-linea-suave`). Los tokens semánticos viven en `src/styles/global.css`: no escribir hex sueltos en un componente.
- Acento **dorado** (`dorado-500` #EDB512, `dorado-300`): rótulos, pestaña activa (píldora dorada), botones primarios (`rounded-full bg-dorado-500 text-cra-950`). Azul C.R.A. `cra-950…100` (`cra-700` = #005F96).
- Tipografía: titulares en **Figtree** (`titular`: 800, interlineado apretado, sin mayúsculas forzadas), texto en **Inter**. `rotulo` para eyebrows (mayúsculas, espaciado 0.16em, normalmente `text-dorado-300`). `resalte` para una palabra destacada del titular (píldora dorada girada). `vidrio` para la barra flotante.
- Esquinas redondeadas: `rounded-sm` vale 14 px en toda la web; tarjetas `rounded-3xl`, paneles grandes `rounded-[2rem]`, botones y pestañas `rounded-full`.
- Navegación: barra flotante tipo píldora (`CabeceraCRA`), pegada arriba, con «Reportar con Zanky». La plataforma usa pestañas en píldora desplazables.
- Entrada al bajar: clase `revelar` (solo se oculta si corrió el JavaScript; respeta `prefers-reduced-motion`).
- A 360 px nada mueve la página a lo ancho: los hijos de `.grid`/`.flex` en `main` tienen `min-width: 0` y `html, body` usan `overflow-x: clip`. Las tablas anchas van dentro de `overflow-x-auto`.
- Capas, plan de manejo y semáforo de prioridad: igual que antes (`capa-*`, `plan-*`, `alta`/`media`/`baja`/`critica`).
- Toques de 44 px o más, letra legible al sol, estados vacío/carga/error en cada pantalla.
