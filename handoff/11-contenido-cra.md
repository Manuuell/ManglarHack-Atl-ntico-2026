# 11 · Contenido de la C.R.A. en nuestra web (rama `web-contenido-cra`)

Objetivo: que la C.R.A. pueda quedarse con **nuestra** web sin perder **nada** de su plataforma actual
([manglarcra.netlify.app](https://manglarcra.netlify.app)). Transcrito con el navegador el **27-11-2026**. Léase con
`10-web-plataforma.md` y `web/CLAUDE.md`.

## Dónde vive el contenido

- `web/src/lib/workflow.ts`: sectores (`SECTORES_WORKFLOW`), cifras departamentales (`CIFRAS`), las 11 pestañas del
  visor (`PESTANAS_WORKFLOW`) como **bloques tipados** (cifras, barras con su «Explicar», tablas, series, textos,
  fórmulas, referencias, capa pendiente), el plan de manejo (`PLAN_MANEJO`), las 9 capas y los 18 pasos de la metodología.
- `web/src/lib/workflowSeries.ts`: series transcritas de los datos que publica el visor de la C.R.A.
  (`data/core.json`): extensión anual 2016–2025, verdor y humedad del dosel por sector (44 trimestres), espejo de agua y
  turbidez de las 5 ciénagas, anomalía de temperatura del aeropuerto Ernesto Cortissoz y episodios de La Niña.
- `web/src/lib/plataforma/acerca.ts`: textos de «Acerca de la plataforma» y «Lo que agregó el equipo».
- Componentes que solo pintan esos datos: `web/src/components/workflow/BloquesWorkflow.tsx` y `VisorWorkflow.tsx`,
  `web/src/pages/plataforma/acerca.astro`. Ningún párrafo de la C.R.A. está pegado en un componente.
- Si la C.R.A. actualiza su workflow (cada trimestre), se cambian estos dos archivos de `lib/` y nada más.

## Sectores: nombres de la C.R.A. e ids que se conservan

Antes la web decía «Balboa 197, Totumo 148, Manatíes 742»: los totales de Tubará y Totumo estaban cruzados y los nombres
no eran los de la C.R.A. Ahora:

| id (no cambia) | Nombre corto C.R.A. | Nombre largo | Total (ha) | Alta | Media | Por revisar | Manglar probable |
|---|---|---|---|---|---|---|---|
| `mallorquin` | Mallorquín | Mallorquín – Bocas de Ceniza | 516 | 262 | 86 | 168 | 348 (45 %) |
| `balboa` | Puerto Colombia | Puerto Colombia – Balboa – Puerto Velero | 197 | 60 | 32 | 106 | 91 (12 %) |
| `manaties` | Tubará | Tubará – Juan de Acosta | 148 | 27 | 19 | 102 | 45 (6 %) |
| `totumo` | Totumo | Totumo – Astilleros – Galerazamba | 742 | 116 | 174 | 452 | 291 (37 %) |

- Los ids `balboa` y `manaties` se mantienen porque ya los usan `mockReportes.json`, `plataforma/*.json`, la capa
  `prioridades-cra.geojson`, `types/` y el backend. Cambiarlos rompería datos. Equivalencia: **`balboa` = Puerto Colombia**,
  **`manaties` = Tubará**.
- Los polígonos de `poligonosManglar.json` ya estaban bien ubicados (Tubará–Juan de Acosta en `manaties`); solo cambia su
  `nombre`. Siguen siendo envolventes **aproximadas** de INVEMAR 2020: no son los límites oficiales de la C.R.A.
- **Discrepancia por resolver con Ángel:** la app (`app/lib/datos/zonas.dart`) guarda `sectorCra` como «Mallorquín»,
  «Balboa», «Manatíes» y «Totumo» y arma etiquetas como «Sector Balboa (Tubará)». La C.R.A. no usa «Manatíes» como
  sector (es una de sus cinco **ciénagas**, de 31 ha) ni «Balboa» como nombre corto. Hay que acordar si la app pasa a
  los nombres de la C.R.A. y confirmar que «Balboa (Tubará)» no mezcla dos sectores. Anotado también en `10`.

## Inventario página por página

### Portada `/` de la C.R.A. → nuestra `/`
| Contenido C.R.A. | En nuestra web |
|---|---|
| «Departamento del Atlántico · Monitoreo satelital 2015–2026», «El manglar del Atlántico», subtítulo de herramientas tecnológicas e IA | `/` (portada de Manuel) |
| Entrada 1 Workflow y Entrada 2 Plataforma, con sus textos | `/`, tarjetas de entrada |
| Créditos: Sentinel-2 Copernicus, escena 3D, C.R.A. | Pie de página y `/workflow#fuentes` |
| Video de fondo | No se trajo (es decorativo; ver abajo) |

### `/workflow` de la C.R.A. → nuestro `/workflow` (cada pestaña abre con `#id`)
| Pestaña C.R.A. | Nuestra pestaña | Qué hay |
|---|---|---|
| Síntesis | `#sintesis` | 465 / 310 / 828 ha; 371 de 465 y 486 de 775 con la referencia; 83 % (50 de 60); 125 mil t C; 1.518 t C al año; manglar probable por sector con % y su explicación; probabilidad alta por sector con su explicación |
| Extensión | `#extension` | 775 ha; tabla y barras apiladas por nivel y sector; 828 ha por revisar por sector con su verdor; Sørensen-Dice 0,53 (Capa Nacional 2020, 536 ha), 0,54 (C.R.A.+INVEMAR 2017, 758 ha), 0,35 (portafolio, 571 ha) con la fórmula; verificación visual por categoría; 554 de 775 ha en el plan de manejo |
| Cambios | `#cambios` | Serie anual 2016–2025 (801 → 775 ha) con tabla; 36,6 perdidas, 1,9 ganadas, 34,7 netas; las 4 equivalencias (3 km, 5.500 colombianos, 3,5 t de pesca, 500 mil cangrejos); los 8 mayores cambios; episodios recuperados por sector (1–2 y 3–5 periodos); regla de confirmación y fuentes de equivalencias |
| Dosel en 2026 | `#dosel` | 262 y 419 ha; los 10 parches; dosel seco por sector (≤ −0,10 y ≤ −0,05, variación mediana); efecto de los 5 episodios de El Niño con anomalía y recuperación por sector; nota de temperatura del aeropuerto y serie mensual; series trimestrales de humedad y verdor por sector con bandas de El Niño y La Niña; correlación −0,34 a −0,64 |
| Altura | `#altura` | 10,7 m; mediana y árboles dominantes por sector con explicación; notas de Lang 2023 y del error |
| Agua | `#agua` | Las 5 ciénagas (espejo mediano, mínimo, máximo, turbidez, carbono enterrado); series trimestrales de espejo de agua y turbidez de cada ciénaga (selector); método y pendientes |
| Presión antrópica | `#presion` | Explicación y fórmula del riesgo; 194 ha; riesgo medio por sector con amenaza y vulnerabilidad; tabla de hectáreas por nivel y límites; tabla de amenazas; 10 zonas de mayor riesgo; exposición 0,14 y por sector; usos del suelo por anillo; fórmula H = 1 − Π(1 − F·I) con intensidades |
| Carbono | `#carbono` | 125 mil t, 270 t C/ha, 92 %, 753, 1.518, 2.271 t al año y 67 de 775 ha, cada una con su equivalencia; desglose suelo 248 / biomasa 17 / raíces 4,5 y límite superior 455; reserva por sector; enterramiento por ciénaga; rodales de Mallorquín (122 / 23,5 / 11,6); gradiente occidente–oriente; posición respecto al agua; notas de enterramiento, equivalencias y la pérdida de 36,4 ha |
| Método y límites | `#metodo` | Muestra, consenso, variables, regla de cambio; validación cruzada (0,81 / 0,81 / 0,88) con su aclaración; límites |
| Fuentes | `#fuentes` | Las 12 categorías de referencias, accesibilidad e identidad visual del visor de la C.R.A., y una nota de esta web |
| Workflow (metodología) | `#metodologia` | Las 9 capas con Mide, Datos, Fórmula o regla, Resultado, Comprobación y sus pasos; los 18 pasos con su comprobación; texto de «Capas vivas» |
| Texto del audio de cada sección | Cada pestaña | Desplegable «Resumen de la sección (texto del audio de la C.R.A.)» |
| «Explicar» de cada barra | Cada barra | Fila desplegable accesible con teclado |
| Mapa con sectores | Mapa 2D | Sectores con nombre y hectáreas correctas, ventana con su resumen |

### `/plataforma` de la C.R.A. («Acerca de la plataforma») → nuestra `/plataforma/acerca`
| Contenido C.R.A. | En nuestra web |
|---|---|
| Plan de manejo: 19.834 ha en 5.199 polígonos; 554 de 775 ha con acción (416, 70, 64 y 4); 221 fuera | `/plataforma/acerca`, cifras, barra de las 775 ha y tabla por acción |
| Tabla de hectáreas por acción (plan y manglar dentro) | `/plataforma/acerca` |
| Nota de la capa «Prioridades de conservación» | `/plataforma/acerca`; la capa se dibuja en `/plataforma` |
| Mapa del plan (imagen) | No se copió la imagen: dibujamos la capa real en `/plataforma` y `/plataforma/proponer` |
| «Qué hará la plataforma» (8 puntos) | `/plataforma/acerca`, cada uno con enlace a donde está en esta web |
| «Lo que la plataforma devuelve al workflow» | `/plataforma/acerca` |
| «Condiciones para la fase 2» | `/plataforma/acerca` |
| — (nuevo) «Lo que agregó el equipo» | `/plataforma/acerca`: reportes de Zanky (app, bot, web), área de reporte, capas oficiales, jornadas, roles y auditoría, datos abiertos |

Enlaces a la página: pie de página («Acerca de la plataforma») e inicio de la plataforma (bajo «Estado del manglar»).
No está en la barra de pestañas porque esa barra vive en `layouts/`, que no se tocó.

### `/maqueta` de la C.R.A. (plataforma abierta, 7 pestañas) → nuestras `/plataforma/*`
| Pestaña C.R.A. | En nuestra web |
|---|---|
| Inicio (mapa del manglar y de las acciones, estado del manglar, acciones en curso) | `/plataforma` |
| Registro de actor (tipo, nombre, correo, sector, papel, Ley 1581, actores registrados) | `/plataforma/registro` |
| Proponer acción (sitio en el mapa, acción y prioridad heredadas, requerimientos por tipo, comunidad) | `/plataforma/proponer` |
| Seguimiento (tabla y detalle) | `/plataforma/seguimiento` |
| Monitoreo (plántulas vivas, altura, fotos ubicadas, observaciones) | `/plataforma/monitoreo` |
| Proyectos (Metodología General Ajustada y nota conceptual prellenadas) | `/plataforma/proyectos` |
| Panel de la Corporación (estados, hectáreas propuestas, decisiones, alertas del workflow) | `/plataforma/panel` |

Los sectores de esos formularios ya usan los nombres largos de la C.R.A. (salen de `SECTORES` en
`web/src/lib/plataforma/catalogos.ts`).

## Lo que no se pudo traer, y por qué

| Qué | Motivo | Qué hay en su lugar |
|---|---|---|
| **Escena 3D** (botón 2D · 3D y «Capas vivas» de la metodología) | Es una escena construida por la C.R.A. con sus rásteres; no tenemos los insumos ni el modelo, y la propia C.R.A. la declara complementaria («todos los datos están en el panel y en el mapa 2D»). | Todos los datos en el panel; texto de «Capas vivas» en `#metodologia` con el rótulo de pendiente. |
| **Audios** de cada sección | Son archivos de voz de la C.R.A.; no se copian sin su permiso. | El **texto** de cada audio está en cada pestaña. |
| **Capas ráster**: probabilidad de manglar (alta, media, por revisar), cambios confirmados por año, mapa de calor del dosel, altura del dosel, índice de riesgo y presión antrópica, biomasa aérea, frecuencia de agua | No nos las han entregado. El visor de la C.R.A. las sirve en sus propios archivos (`data/hl.json`, `img/*`), pero no son datos entregados para reutilizar. | Cada pestaña dice «Capa de la C.R.A. pendiente de entrega» con sus convenciones. Nunca se inventan. Al recibirlas, se cargan como capa del mapa. |
| **Imagen satelital Esri** (World Imagery) | Usarla exige aceptar los términos de Esri (cuenta de ArcGIS y atribución) y no se ha gestionado; la C.R.A. puede hacerlo si quiere esa capa. | Mapa base de OpenStreetMap. |
| Video de fondo de la portada | Decorativo y pesado. | Portada de Manuel. |
| Serie por parche del dosel (al elegir un parche, la C.R.A. dibuja su serie) y anomalía trimestral por sector | No se publica como tabla en el visor. | Se cuenta en la nota de la pestaña; quedan las series de humedad y verdor por sector. |

## Para cuando llegue la siguiente actualización trimestral

1. Repetir la transcripción: en `/workflow` de la C.R.A. cada pestaña se abre con los botones `tab-sin` … `tab-fue` y
   `tab-wf`; el texto sale de `document.body.innerText` y las explicaciones de cada barra `[role=button][data-r]`
   aparecen en `#pop`. Las series están en `data/core.json` (`t_area`, `t_ind`, `t_agua`, `clima`, `oni`).
2. Cambiar `web/src/lib/workflow.ts` y `workflowSeries.ts`; `npm run check` avisa si falta un campo.
3. Pedir a la C.R.A. los rásteres en GeoTIFF o teselas para quitar los rótulos de «pendiente de entrega».
