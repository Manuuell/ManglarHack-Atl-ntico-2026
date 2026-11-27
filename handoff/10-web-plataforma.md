# 10 · Web: plataforma abierta y panel de la CRA (rama `web`)

Para quien siga trabajando en la web (Manuel, Ángel o el agente de cualquiera). Escrito por Jerson el 27-11-2026 al subir la
rama `web`. Léanlo junto con `web/CLAUDE.md`, que es la guía técnica que leen los agentes.

## Dónde está y cómo se corre

- **Rama `web`**, carpeta **`web/`**. No se trabaja en `main`: los cambios de la web entran por esta rama.
- Astro 7 (estático, varias páginas) + React 19 en islas + Tailwind v4 + Leaflet/react-leaflet + lucide-react.

```bash
cd web
npm install
npm run dev      # http://localhost:4321
npm run check    # TypeScript estricto: debe dar 0 errores antes de cada commit
npm run build    # 9 páginas estáticas en dist/
```

- Un commit por punto, en español, **sin trailer de coautoría**. `git pull --rebase` antes de subir; nunca `--force`.
- **Ángel arrancó un panel en `panel/`** porque no veía nada nuestro subido. Antes de seguir, decidan entre los tres cuál
  queda: esta rama ya tiene el panel de la Corporación (ver abajo) para no hacerlo dos veces.

## Qué hay (todo funciona en el navegador con datos de ejemplo)

Replica la identidad y la información de la plataforma de la CRA ([manglarcra.netlify.app](https://manglarcra.netlify.app)):
fondo azul institucional, tarjetas azul intermedio, acentos dorados, Lato, titulares en mayúsculas, logo blanco de la CRA.

| Ruta | Qué hace |
|---|---|
| `/` | Portada como la de la CRA: «EL MANGLAR DEL ATLÁNTICO» y dos entradas (Workflow y Plataforma). |
| `/workflow` | Mapa 2D + panel con 10 pestañas (Síntesis… Fuentes) y las cifras del workflow de la CRA con su fuente. |
| `/plataforma` | Inicio: mapa del manglar y de las acciones con el **plan de manejo real de la CRA**, estado del manglar, acciones en curso, últimos reportes de Zanky, próximas jornadas. |
| `/plataforma/registro` | Registro de actor (Ley 1581; el correo nunca se publica). |
| `/plataforma/proponer` | Proponer una acción marcando el sitio: hereda acción, prioridad, unidad hidrográfica y escenario **de la capa de prioridades de la CRA en ese punto**. |
| `/plataforma/seguimiento` | Seguimiento con detalle, requerimientos, observaciones y línea de tiempo; **jornadas** (base Innvita): inscripción, invitación por WhatsApp, enlace, `.ics`; enlaces `?accion=` y `?jornada=`. |
| `/plataforma/monitoreo` | Reportes ciudadanos de Zanky (app, bot, web) en mapa público anonimizado + exportación CSV/GeoJSON/KML; reporte de monitoreo con **fotos georreferenciadas** (EXIF, GPS del teléfono o mapa; miniaturas sin metadatos); ranking de colegios. |
| `/plataforma/proyectos` | Plantillas prellenadas (Metodología General Ajustada y nota conceptual) con los datos del sitio y del workflow; lo desconocido queda [entre corchetes]; descargar, copiar e imprimir. |
| `/plataforma/panel` | Panel de la Corporación con **roles de demostración**: decisiones sobre acciones (observaciones obligatorias), alertas calculadas de los datos, cola de reportes ciudadanos por rol, auditoría unificada, carga de KMZ/KML → GeoJSON. |

## Datos de la CRA ya integrados (en `datos/cra/`)

- `prioridades_conservacion_cra.kmz` → `npm run capas:prioridades` → `web/public/datos/prioridades-cra.geojson`
  (3.392 polígonos recortados a los 4 sectores; acción del plan, prioridad, unidad hidrográfica, escenario, figura legal).
  Ojo: la capa original es departamental y **sus áreas se superponen entre escenarios**; no publicar sumas de hectáreas de ella.
- `manglar_escala_1-5000.gdb.zip` → `manglar_cra_escala_1-5000.geojson` (WGS84, completo, útil para el backend) →
  `npm run capas:manglar` → `web/public/datos/manglar-cra.geojson`. **Cobertura de manglar 1:5.000: 886 polígonos, 649,7 ha,
  Maxar 2021–2022, verificada en campo.** Reemplaza a INVEMAR en los mapas. Para regenerar el GeoJSON desde la GDB hace falta
  GDAL (geopandas/pyogrio).
- Los 4 sectores (`web/src/data/poligonosManglar.json`) son envolventes aproximadas de la capa de manglar: Mallorquín, Balboa,
  Manatíes (Tubará – Juan de Acosta, correspondencia por confirmar con la CRA) y Totumo.

## Área de reporte: solo el manglar y su entorno

Se admiten denuncias **dentro de la cobertura de manglar de la CRA a 1:5.000 o a menos de 500 m de ella** (área de influencia,
porque un vertimiento o un caño taponado afectan desde fuera). Lo de fuera —por ejemplo, el casco urbano de Barranquilla— no
corresponde a la herramienta: no se publica y el panel lo marca para descartar. Los mapas no se salen de la zona del manglar.

- Web: `web/src/lib/areaReporte.ts` (`enAreaDeReporte`, `evaluarUbicacion`, `RADIO_INFLUENCIA_M = 500`, `LIMITES_MANGLAR`).
- **Backend, app y bot deben aplicar la misma regla** con `datos/cra/manglar_cra_escala_1-5000.geojson`: calcular
  `dentro_poligono` y `distancia_m` contra esa cobertura y rechazar (o pedir confirmación) por encima de 500 m, con un mensaje
  claro al ciudadano. Hoy `backend/supabase` calcula la distancia contra `zonas`: hay que acordarlo con Ángel.

## Reglas que no se negocian (de 05 y 06)

- **Honestidad del dato:** toda cifra con fuente; lo inventado lleva «Datos de ejemplo»; manglar **probable, no confirmado**.
- **Privacidad:** lo público pasa por `aReportePublico` (sin foto, sin reportante, coordenadas difuminadas). Nunca correos ni
  teléfonos en vistas públicas.
- **Leaflet solo con `client:only="react"`** y un `slot="fallback"` del mismo alto.
- Tipos, estados, prioridades y transiciones salen **solo** de `web/src/lib/catalogos.ts` y `web/src/lib/plataforma/catalogos.ts`.
- Todo en español; toques de 44 px; estados vacío/carga/error en cada pantalla.

## Lo que falta para conectarla al backend (Supabase de `backend/`)

El contrato de la web ya coincide con `backend/supabase/schema.sql` (tipos, estados, canal, UUID del dispositivo, prioridad
1–5, `capturado_en`/`recibido_en`). Pasos:

1. **Lectura**: cambiar el cuerpo de las funciones `async` de `web/src/lib/datos.ts` (reportes, historial) y
   `web/src/lib/plataforma/datos.ts` (actores, acciones…) por llamadas a Supabase. Lo público lee la vista
   `reportes_publicos`; los datos abiertos, `datos_abiertos_geojson()` / `datos_abiertos_kml()`.
2. **Tiempo real**: `web/src/lib/reportesStore.ts` tiene `reemplazarReportes()`: enchufar ahí la suscripción realtime y releer
   todo al reconectar.
3. **Escritura y permisos**: el panel hoy cambia estados en el navegador (`cambiarEstado`, `cambiarEstadoAccion`). En producción
   debe llamar la RPC `cambiar_estado(p_id, p_estado, p_nota)`; el rol lo decide `panel_rol_de()` en el servidor.
   Equivalencia de roles: `administrador → admin`, `moderador → moderador_cra`, `vigia → vigia`, `colegio → aliado`.
   El selector «Ver como» del panel es solo demostración y debe desaparecer con el inicio de sesión real.
4. **Fotos del panel**: usar `url_foto()` / `ver_reportante()` para que cada vista quede auditada.
5. Acciones, actores, jornadas y monitoreos **no existen aún en el esquema**: hay que crear sus tablas (el modelo está en
   `web/src/types/plataforma.ts`) o dejarlos como demostración rotulada.
6. Al conectar, quitar los rótulos «Datos de ejemplo» solo de lo que ya venga de la base.

## Pendientes de la web (marcar también en `07`)

- [x] `/plataforma/proyectos`.
- [ ] Conexión a Supabase (pasos de arriba) y mapa en vivo.
- [ ] Formulario ligero para turistas que entran por QR (canal `web`), con UUID generado en el navegador.
- [ ] Zanky con el arte oficial de Flow (`web/src/components/marca/Zanky.astro` es el único lugar a cambiar).
- [ ] Revisar cada pantalla a 375 px y con letra al 130 %.
