# 04 · Datos

## Polígonos del manglar

- **Oficiales, de la CRA:** los entregan en **KMZ**. Son 4 zonas, unas 775 ha. Cuando lleguen, guárdenlos en `datos/cra/` y conviértanlos a GeoJSON con cualquiera de estas dos formas:
  ```bash
  ogr2ogr -f GeoJSON datos/cra/manglar_cra.geojson datos/cra/archivo.kmz
  ```
  O descomprimir el KMZ (es un ZIP con `doc.kml`) y convertir en https://mapshaper.org.
- **Mientras tanto, la capa de INVEMAR:** [`datos/manglares_atlantico_invemar_2020.geojson`](../datos/manglares_atlantico_invemar_2020.geojson).
  - Es la Capa Nacional de Manglares (INVEMAR, 1:25.000, imagen de 2020), filtrada al Atlántico: 144 polígonos, **533 ha**.
  - **No es la capa de la CRA.** Sirve para probar el *point-in-polygon* mientras llega el KMZ.
  - Se descargó del servicio público de ArcGIS de INVEMAR: `https://gis.invemar.org.co/arcgis/rest/services/SIGMA/MANGLARES_COLOMBIA/MapServer/0`.
- **Punto de prueba:** Ciénaga de Mallorquín, lat `11.04`, lon `-74.86`.

## Datos satelitales: no van en la herramienta ciudadana

La CRA lo aclaró: los datos satelitales son de su visor interno. La herramienta ciudadana solo debe **georreferenciar el suceso en tiempo real desde el celular**.

## Datos públicos opcionales (extras para el panel)

Se probaron el 27-11-2026 y no necesitan clave:

| Fuente | Uso posible en el panel | URL |
|---|---|---|
| Open-Meteo | Viento y lluvia actuales, útiles para priorizar un incendio | `https://api.open-meteo.com/v1/forecast?latitude=11.04&longitude=-74.86&current=temperature_2m,precipitation,wind_speed_10m,wind_direction_10m&timezone=America%2FBogota` |
| Open-Meteo Marine | Oleaje y nivel del mar | `https://marine-api.open-meteo.com/v1/marine?latitude=11.07&longitude=-74.86&current=wave_height,sea_level_height_msl&timezone=America%2FBogota` |
| iNaturalist | Biodiversidad observada por ciudadanos en la zona | `https://api.inaturalist.org/v1/observations?nelat=11.08&nelng=-74.82&swlat=11.00&swlng=-74.92&order_by=observed_on&order=desc` |

Con clave gratuita:
- **NASA FIRMS:** focos de calor, que pueden corroborar un reporte de incendio.
- **Global Forest Watch:** alertas de pérdida de vegetación.

**IDEAM en datos.gov.co no sirve para tiempo real en el Atlántico:** el último dato es de julio de 2026.

## Mapas base

- **OpenStreetMap:** con `flutter_map` en la app y Leaflet o MapLibre en la web. Para la app sin conexión, descargar antes las teselas de la zona costera.
- **Google Maps:** aceptar enlaces compartidos («pin») como forma alternativa de dar la ubicación, como sugirió la CRA.
