# Zanqui: monitoreo ciudadano del manglar del Atlántico

Proyecto para **Manglar Hack Atlántico 2026**, organizado por la CRA y la Universidad Simón Bolívar.

**Zanqui** es una herramienta de ciencia ciudadana para que cualquier persona (habitantes, pescadores, colegios o turistas) reporte **en tiempo real y con ubicación** las amenazas al manglar del Atlántico. Funciona con o sin internet. Los reportes llegan a un panel de la Corporación, donde se priorizan y se validan, y se publican como datos abiertos.

## Componentes

| Carpeta | Componente | Estado |
|---|---|---|
| `app/` | App móvil (Flutter) | En construcción |
| `web/` | Aplicación web: panel de la CRA y vista pública | En construcción |
| `bot/` | Bot de WhatsApp | En construcción |
| `datos/` | Polígonos del manglar y datos de prueba | Capa de INVEMAR de referencia |
| `handoff/` | Documentación del equipo: reto, solución y datos | Ver [handoff/README.md](handoff/README.md) |

## Datos

- `datos/manglares_atlantico_invemar_2020.geojson`: Capa Nacional de Manglares de **INVEMAR** (2020, escala 1:25.000), filtrada al departamento del Atlántico. Fuente: servicio público ArcGIS de INVEMAR (SIGMA). Se usa como referencia mientras llegan los polígonos oficiales de la CRA.
