# Fuentes abiertas para zonas de manglar

La pantalla `PantallaBiodiversidad(zona: zona)` consulta el centro de la zona. Las observaciones son registros históricos cercanos, no un inventario ni una confirmación de presencia actual. Las respuestas se guardan por `zona.id` en el dispositivo: biodiversidad durante 12 horas y nivel del mar con respaldo local al perder señal. Las fotos se cargan desde su URL y requieren conexión si no están en la caché de imágenes del sistema.

| Fuente | Consulta sin clave | Uso, límites y atribución |
| --- | --- | --- |
| [GBIF Occurrence Search](https://techdocs.gbif.org/en/openapi/v1/occurrence) | `api.gbif.org/v1/occurrence/search`, polígono WKT de 0,15° alrededor del centro, `taxonKey=212` para aves y `scientificName` para *Rhizophora*, *Avicennia* y *Laguncularia*. Se piden hasta 12 aves y 8 registros por género. | Máximo 300 resultados por página y 100 000 por búsqueda; la tasa puede variar y responder 429. Cada ficha enlaza al registro y muestra creador y licencia de la imagen si vienen en `media`. Las licencias varían entre registros. [Referencia y tasa](https://techdocs.gbif.org/en/openapi/). |
| [iNaturalist Observations](https://api.inaturalist.org/v1/docs/) | `api.inaturalist.org/v1/observations`, latitud/longitud, radio 20 km, `quality_grade=research`, foto, `locale=es`, hasta 30 resultados. | Recomienda cerca de una petición por segundo y unas 10 000 por día; puede responder 429. Se muestran el enlace de observación, la atribución y la licencia de cada foto cuando están presentes. [Prácticas oficiales](https://www.inaturalist.org/pages/api+recommended+practices). |
| [Open-Meteo Marine](https://open-meteo.com/en/docs/marine-weather-api) | `marine-api.open-meteo.com/v1/marine`, `hourly=sea_level_height_msl`, `cell_selection=sea`, UTC y dos días. | Modelo de nivel sobre el promedio global, no medición de mareógrafo. La precisión costera es limitada y no sirve para navegación. Se atribuye Open-Meteo y a los proveedores del modelo; consultar [licencias y condiciones](https://open-meteo.com/en/terms) antes de uso comercial. Si la variable no viene, la pantalla muestra “Sin estimación”. |

Las tres fuentes se consultan con un máximo de 8 segundos por solicitud. Si una fuente de biodiversidad falla, se conservan los resultados de las otras; si todas fallan, se usa la última copia local. Una respuesta 429 no se reintenta de inmediato. La pantalla etiqueta los datos guardados. Las fichas no añaden una licencia por defecto si falta en el registro.

## Próximos pasos con credenciales

- [NASA FIRMS](https://firms.modaps.eosdis.nasa.gov/api/map_key/): focos de calor, requiere una `MAP_KEY` gratuita. La clave se debe alojar en backend, nunca en la app pública.
- [Sentinel Hub](https://docs.sentinel-hub.com/api/latest/api/overview/authentication/): imágenes satelitales y capas, requiere credenciales OAuth y revisar plan/cuota. Interponer un servicio propio para no distribuir secretos.

## Comprobaciones escritas

`app/test/apis_parseo_test.dart` fija los formatos de GBIF, iNaturalist y Open-Meteo. `app/test/apis_cache_test.dart` usa clientes HTTP falsos: comprueba cero llamadas con caché fresco y respuesta local al fallar la red. La ejecución queda a cargo del orquestador.
