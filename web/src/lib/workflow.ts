// Contenido del workflow de monitoreo del manglar de la C.R.A., transcrito de su
// visor (https://manglarcra.netlify.app/workflow) el 27 de noviembre de 2026.
// Toda cifra sale de allí; las explicaciones de cada barra («Explicar») se
// conservan como `explicacion`. Los componentes solo leen este archivo y
// `workflowSeries.ts`: nada de párrafos pegados en la interfaz.

import {
  EPISODIOS_LA_NINA, FUENTE_SERIES, SERIE_AGUA, SERIE_DOSEL, SERIE_EXTENSION_ANUAL, SERIE_TEMPERATURA,
} from './workflowSeries';

export const URL_WORKFLOW_CRA = 'https://manglarcra.netlify.app/workflow';
export const FUENTE_WORKFLOW = 'Workflow de monitoreo del manglar de la C.R.A. (manglarcra.netlify.app/workflow), versión 4 · Sentinel-2, radar, elevación y alta resolución, consultado el 27 de noviembre de 2026';
export const VERSION_WORKFLOW = 'Versión 4 · Sentinel-2, radar, elevación y alta resolución';

// ── Sectores ────────────────────────────────────────────────────────────────
// Los ids son los que ya usan los datos de la web, la app y el backend. Su
// equivalencia con los nombres de la C.R.A. está en handoff/11-contenido-cra.md:
// balboa = Puerto Colombia – Balboa – Puerto Velero; manaties = Tubará – Juan de Acosta.
export type SectorWorkflowId = 'mallorquin' | 'balboa' | 'manaties' | 'totumo';

export interface SectorWorkflow {
  id: SectorWorkflowId;
  /** Nombre corto de la C.R.A. */
  nombre: string;
  nombre_largo: string;
  /** Probabilidad alta (0,7 o más), media (0,5 a 0,7) y por revisar (0,3 a 0,5), ha. */
  alta_ha: number; media_ha: number; por_revisar_ha: number;
  /** Manglar probable = alta + media. */
  probable_ha: number;
  /** Total = probable + por revisar (no es manglar confirmado). */
  total_ha: number;
  /** Porcentaje del manglar probable del departamento. */
  pct_departamento: number;
  /** Porcentaje del manglar probable del sector con probabilidad alta. */
  pct_alta_en_sector: number;
  /** Hectáreas de probabilidad alta que coinciden con al menos una cartografía de referencia. */
  alta_coincide_ha: number;
  /** Áreas por revisar: el verdor máximo del dosel desciende / aumenta entre 2016–2017 y 2024–2025, % del área. */
  verdor_por_revisar: { desciende_pct: number; aumenta_pct: number };
  /** Episodios cortos de pérdida recuperados (no cuentan como pérdida confirmada), ha. */
  episodios_cortos: { total_ha: number; uno_dos_ha: number; tres_cinco_ha: number };
  /** Dosel claramente más seco (ΔH ≤ −0,10), algo seco (ΔH ≤ −0,05) y variación mediana de la humedad. */
  dosel_seco_ha: number; dosel_algo_seco_ha: number; variacion_mediana_humedad: number;
  altura_mediana_m: number; altura_dominante_m: number;
  riesgo_medio: number; amenaza: number; vulnerabilidad: number;
  amenazas: { presion: number; retroceso: number; sequia: number };
  riesgo_ha: { bajo: number; medio: number; alto: number; muy_alto: number };
  exposicion: number;
  carbono_t: number;
}

export const SECTORES_WORKFLOW: SectorWorkflow[] = [
  {
    id: 'mallorquin', nombre: 'Mallorquín', nombre_largo: 'Mallorquín – Bocas de Ceniza',
    alta_ha: 262, media_ha: 86, por_revisar_ha: 168, probable_ha: 348, total_ha: 516, pct_departamento: 45,
    pct_alta_en_sector: 75, alta_coincide_ha: 227, verdor_por_revisar: { desciende_pct: 8, aumenta_pct: 15 },
    episodios_cortos: { total_ha: 9.9, uno_dos_ha: 5.4, tres_cinco_ha: 4.5 },
    dosel_seco_ha: 106, dosel_algo_seco_ha: 168, variacion_mediana_humedad: -0.05,
    altura_mediana_m: 11.4, altura_dominante_m: 18.6,
    riesgo_medio: 0.38, amenaza: 0.40, vulnerabilidad: 0.37, amenazas: { presion: 0.78, retroceso: 0.14, sequia: 0.29 },
    riesgo_ha: { bajo: 75, medio: 99, alto: 95, muy_alto: 79 }, exposicion: 0.22, carbono_t: 70659,
  },
  {
    id: 'balboa', nombre: 'Puerto Colombia', nombre_largo: 'Puerto Colombia – Balboa – Puerto Velero',
    alta_ha: 60, media_ha: 32, por_revisar_ha: 106, probable_ha: 91, total_ha: 197, pct_departamento: 12,
    pct_alta_en_sector: 65, alta_coincide_ha: 46, verdor_por_revisar: { desciende_pct: 4, aumenta_pct: 18 },
    episodios_cortos: { total_ha: 2.2, uno_dos_ha: 1.4, tres_cinco_ha: 0.8 },
    dosel_seco_ha: 47, dosel_algo_seco_ha: 78, variacion_mediana_humedad: -0.10,
    altura_mediana_m: 11.1, altura_dominante_m: 16.0,
    riesgo_medio: 0.42, amenaza: 0.25, vulnerabilidad: 0.59, amenazas: { presion: 0.17, retroceso: 0.14, sequia: 0.44 },
    riesgo_ha: { bajo: 13, medio: 21, alto: 27, muy_alto: 30 }, exposicion: 0.08, carbono_t: 16119,
  },
  {
    id: 'manaties', nombre: 'Tubará', nombre_largo: 'Tubará – Juan de Acosta',
    alta_ha: 27, media_ha: 19, por_revisar_ha: 102, probable_ha: 45, total_ha: 148, pct_departamento: 6,
    pct_alta_en_sector: 59, alta_coincide_ha: 21, verdor_por_revisar: { desciende_pct: 1, aumenta_pct: 13 },
    episodios_cortos: { total_ha: 1.0, uno_dos_ha: 0.5, tres_cinco_ha: 0.4 },
    dosel_seco_ha: 37, dosel_algo_seco_ha: 42, variacion_mediana_humedad: -0.15,
    altura_mediana_m: 11.0, altura_dominante_m: 15.0,
    riesgo_medio: 0.44, amenaza: 0.23, vulnerabilidad: 0.64, amenazas: { presion: 0.11, retroceso: 0, sequia: 0.58 },
    riesgo_ha: { bajo: 5, medio: 9, alto: 13, muy_alto: 19 }, exposicion: 0.09, carbono_t: 7263,
  },
  {
    id: 'totumo', nombre: 'Totumo', nombre_largo: 'Totumo – Astilleros – Galerazamba',
    alta_ha: 116, media_ha: 174, por_revisar_ha: 452, probable_ha: 291, total_ha: 742, pct_departamento: 37,
    pct_alta_en_sector: 40, alta_coincide_ha: 78, verdor_por_revisar: { desciende_pct: 8, aumenta_pct: 11 },
    episodios_cortos: { total_ha: 6.5, uno_dos_ha: 4.6, tres_cinco_ha: 1.9 },
    dosel_seco_ha: 72, dosel_algo_seco_ha: 132, variacion_mediana_humedad: -0.04,
    altura_mediana_m: 9.8, altura_dominante_m: 16.3,
    riesgo_medio: 0.33, amenaza: 0.15, vulnerabilidad: 0.51, amenazas: { presion: 0.19, retroceso: 0, sequia: 0.26 },
    riesgo_ha: { bajo: 101, medio: 65, alto: 59, muy_alto: 65 }, exposicion: 0.09, carbono_t: 31428,
  },
];

/** Cifras departamentales. Las de 465 y 775 ha son las mismas en todo el visor de la C.R.A. */
export const CIFRAS = {
  manglar_probable_ha: 775, prob_alta_ha: 465, prob_media_ha: 310, por_revisar_ha: 828,
  alta_coincide_ha: 371, probable_coincide_ha: 486,
  verificacion_pct: 83, verificacion_dentro: 50, verificacion_total: 60,
  perdida_neta_ha: 34.7, perdida_ha: 36.6, ganancia_ha: 1.9,
  /** Se conserva con signo para las pantallas que ya lo usaban. */
  perdida_ha_2016_2025: -34.7,
  extension_2016_ha: 801, extension_2025_ha: 775,
  dosel_seco_2026_ha: 262, dosel_algo_seco_2026_ha: 419,
  altura_mediana_m: 10.7, riesgo_muy_alto_ha: 194, exposicion_media: 0.14,
  carbono_total_t: 125000, carbono_t_c_ha: 270, carbono_suelo_pct: 92, carbono_limite_superior_t_c_ha: 455,
  enterramiento_manglar_t: 753, enterramiento_cienagas_t: 1518, enterramiento_total_t: 2271,
  plan_cubre_ha: 554, plan_fuera_ha: 221,
  invemar_ha: 533, invemar_poligonos: 144,
} as const;

// ── Bloques de contenido ────────────────────────────────────────────────────
export interface Cifra { valor: string; unidad?: string; texto: string }
export interface Barra { etiqueta: string; valor: number; texto: string; explicacion?: string; sector?: SectorWorkflowId }
export interface Serie { nombre: string; color: string; trazo?: string; puntos: readonly (readonly [x: string | number, y: number | null])[] }
export interface GrupoSeries { nombre: string; series: Serie[] }
export interface Banda { desde: string; hasta: string | null; tipo: 'nino' | 'nina'; etiqueta: string }

export type Bloque =
  | { tipo: 'cifras'; items: Cifra[] }
  | { tipo: 'barras'; titulo: string; unidad: string; items: Barra[]; nota?: string }
  | { tipo: 'tabla'; titulo: string; columnas: string[]; filas: { etiqueta: string; valores: (number | null)[] }[]; decimales?: number; colores?: string[]; total?: boolean; nota?: string }
  | { tipo: 'serie'; titulo: string; unidad: string; decimales: number; desdeCero?: boolean; grupos: GrupoSeries[]; bandas?: Banda[]; nota?: string }
  | { tipo: 'texto'; titulo?: string; parrafos: string[] }
  | { tipo: 'formula'; titulo?: string; texto: string; nota?: string }
  | { tipo: 'referencias'; items: { titulo: string; texto: string }[] }
  | { tipo: 'pendiente'; capas: string[]; convenciones?: string[] }
  | { tipo: 'metodologia' };

export interface PestanaWorkflow {
  id: string;
  etiqueta: string;
  titulo: string;
  /** Texto del audio de la sección en el visor de la C.R.A. */
  narracion: string;
  bloques: Bloque[];
  /** Capa que resalta el mapa de esta web. */
  capa: 'cra' | 'sectores';
  /** Rótulo de los sectores en el mapa. */
  rotuloSector?: 'probable' | 'total' | null;
  fuente: string;
}

const n = (v: number, decimales = 0) => v.toLocaleString('es-CO', { minimumFractionDigits: decimales, maximumFractionDigits: decimales });
const firmado = (v: number, decimales = 1) => `${v > 0 ? '+' : v < 0 ? '−' : ''}${n(Math.abs(v), decimales)}`;

/** Colores y trazos por sector (el trazo distingue las series sin depender del color). */
export const COLOR_SECTOR: Record<SectorWorkflowId, { color: string; trazo?: string }> = {
  mallorquin: { color: 'var(--color-dorado-500)' },
  balboa: { color: 'var(--color-cra-300)', trazo: '6 3' },
  manaties: { color: 'var(--color-capa-dosel)', trazo: '2 3' },
  totumo: { color: 'var(--color-capa-manglar)', trazo: '10 3 2 3' },
};
const COLOR_PROBABILIDAD = ['var(--color-capa-manglar)', 'color-mix(in srgb, var(--color-capa-manglar) 62%, var(--c-fondo))', 'color-mix(in srgb, var(--color-capa-manglar) 30%, var(--c-fondo))'];
const COLOR_RIESGO = ['var(--color-dorado-100)', 'var(--color-dorado-500)', 'var(--color-capa-recuperacion)', 'var(--color-critica)'];
const COLOR_USOS = ['var(--color-cra-300)', 'var(--color-dorado-500)', 'var(--color-capa-dosel)'];
const COLOR_CARBONO = ['var(--color-dorado-500)', 'var(--color-capa-dosel)', 'var(--color-cra-300)'];

const S = SECTORES_WORKFLOW;
const porSector = (valor: (s: SectorWorkflow) => number, texto: (s: SectorWorkflow) => string, explicacion: (s: SectorWorkflow) => string, largo = true): Barra[] =>
  S.map(s => ({ etiqueta: largo ? s.nombre_largo : s.nombre, valor: valor(s), texto: texto(s), explicacion: explicacion(s), sector: s.id }));

// Episodios de El Niño (Índice Oceánico de El Niño, NOAA) y su efecto en la humedad del dosel.
export const EPISODIOS_EL_NINO = [
  { desde: '2014-10', hasta: '2016-05', intensidad: 2.59, efecto: -0.096, anomalia: { mallorquin: -0.039, balboa: -0.082, manaties: -0.045, totumo: -0.217 }, recuperacion: { mallorquin: '2', balboa: '2', manaties: '2', totumo: '2' } },
  { desde: '2018-09', hasta: '2019-06', intensidad: 1.05, efecto: -0.065, anomalia: { mallorquin: -0.045, balboa: -0.098, manaties: -0.097, totumo: -0.021 }, recuperacion: { mallorquin: 'más de 6', balboa: '5', manaties: '5', totumo: '6' } },
  { desde: '2019-10', hasta: '2020-03', intensidad: 0.75, efecto: -0.060, anomalia: { mallorquin: -0.045, balboa: -0.085, manaties: -0.067, totumo: -0.043 }, recuperacion: { mallorquin: '5', balboa: '2', manaties: '2', totumo: '3' } },
  { desde: '2023-06', hasta: '2024-04', intensidad: 1.99, efecto: -0.006, anomalia: { mallorquin: -0.011, balboa: 0.002, manaties: 0.019, totumo: -0.034 }, recuperacion: { mallorquin: '1', balboa: '1', manaties: '1', totumo: '1' } },
] as const;
const EPISODIO_EN_CURSO = { desde: '2026-04', intensidad: 2.16, efecto: -0.153 } as const;

const BANDAS_ENSO: Banda[] = [
  ...EPISODIOS_EL_NINO.map(e => ({ desde: e.desde, hasta: e.hasta, tipo: 'nino' as const, etiqueta: `El Niño ${e.desde} a ${e.hasta}` })),
  { desde: EPISODIO_EN_CURSO.desde, hasta: null, tipo: 'nino', etiqueta: 'El Niño desde 2026-04, en curso' },
  ...EPISODIOS_LA_NINA.map(([desde, hasta]) => ({ desde, hasta, tipo: 'nina' as const, etiqueta: `La Niña ${desde} a ${hasta}` })),
];

const serieSector = (indice: 1 | 2): Serie[] => S.map(s => ({
  nombre: s.nombre, ...COLOR_SECTOR[s.id],
  puntos: SERIE_DOSEL[({ mallorquin: 'mallorquin', balboa: 'puerto_colombia', manaties: 'tubara', totumo: 'totumo' } as const)[s.id]].map(p => [p[0], p[indice]] as const),
}));

// ── Ciénagas ────────────────────────────────────────────────────────────────
export const CIENAGAS = [
  { id: 'totumo', nombre: 'Ciénaga del Totumo', espejo_ha: 1372, minimo_ha: 682, maximo_ha: 1419, turbidez: 13.3, carbono_t: 878, carros: 440 },
  { id: 'mallorquin', nombre: 'Ciénaga de Mallorquín', espejo_ha: 817, minimo_ha: 738, maximo_ha: 843, turbidez: 11.2, carbono_t: 523, carros: 260 },
  { id: 'balboa', nombre: 'Ciénaga de Balboa', espejo_ha: 150, minimo_ha: 112, maximo_ha: 190, turbidez: 30.9, carbono_t: 96, carros: 50 },
  { id: 'manaties', nombre: 'Ciénaga de Manatíes', espejo_ha: 31, minimo_ha: 27, maximo_ha: 39, turbidez: 7.8, carbono_t: 20, carros: 10 },
  { id: 'el_salado', nombre: 'Ciénaga El Salado', espejo_ha: 2, minimo_ha: 0, maximo_ha: 5, turbidez: 2.7, carbono_t: 1, carros: 0 },
] as const;
const ordenAgua = ['mallorquin', 'totumo', 'balboa', 'manaties', 'el_salado'] as const;

// ── Plan de manejo de la Corporación (página «Acerca de la plataforma») ──────
export const PLAN_MANEJO = {
  ha_total: 19834, poligonos: 5199, manglar_con_accion_ha: 554, manglar_fuera_ha: 221,
  acciones: [
    { id: 'preservacion', nombre: 'Preservación', plan_ha: 10070, manglar_ha: 416 },
    { id: 'restauracion', nombre: 'Restauración', plan_ha: 6088, manglar_ha: 70 },
    { id: 'recuperacion', nombre: 'Recuperación', plan_ha: 2938, manglar_ha: 64 },
    { id: 'rehabilitacion', nombre: 'Rehabilitación', plan_ha: 738, manglar_ha: 4 },
  ],
  nota_capa: 'Capa «Prioridades de conservación» entregada por la Corporación, con zona hidrográfica, prioridad (alta, media, baja), escenario, acción general y regional y figura legal. El acto administrativo que la adopta se citará cuando la Corporación lo confirme.',
  fuente: 'Plataforma abierta de la C.R.A., página «Acerca de la plataforma» (manglarcra.netlify.app/plataforma), consultada el 27 de noviembre de 2026',
} as const;

// ── Metodología: 9 capas y 18 pasos ─────────────────────────────────────────
export interface CapaMetodologia { numero: number; nombre: string; mide: string; datos: string; formula: string; resultado: string; comprobacion: string; pasos: number[] }
export interface PasoMetodologia { numero: number; nombre: string; texto: string; comprobacion: string }

export const CAPAS_METODOLOGIA: CapaMetodologia[] = [
  { numero: 1, nombre: 'Bosque de manglar y altura', mide: 'Altura del dosel, de la que se deriva la biomasa.', datos: 'Mapa global de altura de dosel 2020 (Sentinel-2 calibrado con láser espacial), 10 m; TanDEM-X 2015, 12 m; elevación NASADEM, 30 m.', formula: 'Biomasa = 1,4179 × (0,6337 × altura)^1,6038 (Simard y colaboradores 2019, Américas)', resultado: 'Mediana de 11 m; los árboles dominantes superan 18 m en Mallorquín.', comprobacion: 'Contraste con TanDEM-X 2015.', pasos: [12] },
  { numero: 2, nombre: 'Imágenes de 0,6 metros', mide: 'Lo que se ve a ojo: copa, raíces, agua, arena, construcciones.', datos: 'Esri World Imagery 2023–2026; 524 puntos estratificados; 325 de consenso (104 manglar, 221 otra cobertura).', formula: 'Consenso manglar: leñoso dentro de dos o más capas de referencia. Consenso otra cobertura: sin árboles, o leñoso a más de 300 m de toda capa.', resultado: 'Puntos dudosos excluidos del entrenamiento. La etiqueta de manglar depende de las capas de referencia (ver Método y límites).', comprobacion: 'Verificación visual: 50 de 60 puntos de manglar caen dentro del mapa; 1 de 173 sin árboles.', pasos: [6] },
  { numero: 3, nombre: 'Radar, Sentinel-1 y ALOS', mide: 'Eco de microondas: estructura del bosque, agua lisa y suelo; funciona con nubes.', datos: 'Sentinel-1 banda C (5,6 cm), polarizaciones vertical-vertical y vertical-horizontal, 10 m, 2015–2026. ALOS PALSAR banda L (23,6 cm), horizontal-horizontal y horizontal-vertical, 25 m, 2015–2021.', formula: 'σ⁰ (dB) = 10 · log₁₀(σ⁰); promedio anual, temporada seca y húmeda, variabilidad, diferencia vertical − cruzada', resultado: 'Polarización cruzada: agua −23,8 dB; arena −16,4; manglar −13,8; otro bosque −13,1.', comprobacion: 'Separación de clases medida por variable.', pasos: [5] },
  { numero: 4, nombre: 'Luz reflejada, Sentinel-2', mide: 'Luz del sol reflejada por hojas, agua y suelo en diez longitudes de onda.', datos: 'Bandas 2, 3, 4 (azul, verde, rojo), 5, 6, 7 (borde rojo), 8 y 8A (infrarrojo cercano), 11 y 12 (onda corta); 10 y 20 m; 44 trimestres 2015–2026, mediana sin nubes.', formula: 'Verdor = (B8 − B4)/(B8 + B4) · Manglar = (B8 − B3)/(B11 − B3) · Humedad = (B8A − B11)/(B8A + B11) · Agua = (B3 − B11)/(B3 + B11)', resultado: 'El manglar refleja 0,12 en la banda 11 y el otro bosque 0,17: el agua en sus hojas lo distingue.', comprobacion: 'Versión 1 (2015–2026, trimestre a trimestre): unas 170 ha cambiaban de clase cada trimestre por la estación. Versión 2: falsa ganancia de 181 ha con base en años secos. Ambas llevaron a la versión 3.', pasos: [1, 2, 3, 4, 13] },
  { numero: 5, nombre: 'Probabilidad de manglar', mide: 'Qué tan parecido es cada píxel al manglar de los puntos de consenso.', datos: 'Por píxel: bandas e índices en ventanas de cuatro trimestres (mínimo, mediana, máximo), radar, elevación y altura del dosel.', formula: 'Bosque aleatorio de 500 árboles de decisión, clases balanceadas; P = proporción de árboles que votan manglar', resultado: 'Alta: 0,7 o más (465 ha). Media: 0,5 a 0,7 (310 ha). Por revisar: 0,3 a 0,5 (828 ha).', comprobacion: 'Validación cruzada en cinco partes: exactitud 0,877; acierto en manglar 0,81. Mide la concordancia con etiquetas basadas en capas de referencia.', pasos: [7, 8, 17] },
  { numero: 6, nombre: 'Manglar y cambios confirmados', mide: 'Extensión del manglar y desaparición o aparición sostenida del dosel.', datos: 'Probabilidad de la capa anterior; verdor máximo de cada ventana de cuatro trimestres.', formula: 'Manglar si P ≥ 0,5. Dosel presente si el verdor máximo ≥ 0,4. Pérdida: 6 periodos sin dosel; ganancia: 8 con dosel. Borde interpolado a 2,5 m; unidad mínima 1.600 m².', resultado: '775 ha de manglar probable; 34,7 ha de pérdida neta en la franja de playa de Mallorquín; 801 ha en 2016 y 775 en 2025.', comprobacion: 'Coincidencia con cartografía de referencia (Sørensen-Dice): 0,53, 0,54 y 0,35.', pasos: [9, 10] },
  { numero: 7, nombre: 'Humedad del dosel en 2026', mide: 'Agua en las hojas: un dosel que pierde humedad indica estrés hídrico.', datos: 'Sentinel-2, bandas 8A (865 nm) y 11 (1.610 nm), píxel de 20 m; último año frente a 2024–2025; Índice Oceánico de El Niño.', formula: 'ΔH = mediana(H último año) − mediana(H 2024–2025), suavizado a 15 m. Anomalía estacional frente a la mediana del mismo trimestre.', resultado: '262 ha claramente más secas (ΔH ≤ −0,10). El dosel se seca en cada episodio de El Niño; el episodio de 2026 ya produjo la anomalía más fuerte de la serie.', comprobacion: 'Cinco episodios en once años: muestra corta.', pasos: [11] },
  { numero: 8, nombre: 'Índice de riesgo y presión antrópica', mide: 'Presión humana alrededor del manglar y riesgo combinado de cada píxel.', datos: 'Coberturas clasificadas con Sentinel-2 (construido, cultivos, pastos), vías de OpenStreetMap, retroceso costero 2016–2026, sequía del dosel, forma de los parches.', formula: 'Presión = 1 − Π(1 − Fᵢ·Iᵢ), ponderada por e^(−2,99·d/10 km) (Theobald 2020). Riesgo = 0,5·Amenaza + 0,5·Vulnerabilidad', resultado: '194 ha en el cuartil de mayor riesgo; Tubará 0,44, Puerto Colombia 0,42, Mallorquín 0,38, Totumo 0,33.', comprobacion: 'Normalización entre percentiles 2 y 98; niveles por cuartiles.', pasos: [14] },
  { numero: 9, nombre: 'Carbono', mide: 'Carbono guardado en árboles, raíces y suelo, y carbono que entierran el lodo del manglar y el fondo de las ciénagas cada año.', datos: 'Biomasa satelital de la capa base; carbono del suelo 0–100 cm (Maxwell 2023); tasas de enterramiento de la literatura; emisiones por persona (IDEAM y DANE) y por carro (Unidad de Planeación Minero Energética).', formula: 'C/ha = 0,451 · biomasa + 0,39 · raíces + suelo = 270 t C/ha · Enterramiento = ha × 1,62 (manglar) y ha × 0,64 (ciénagas)', resultado: '125 mil t de carbono en 465 ha; 753 t al año en el manglar y 1.518 en las ciénagas.', comprobacion: 'Un solo valor central por cifra; el escenario alto (455 t/ha) queda como límite superior.', pasos: [15, 16] },
];

export const PASOS_METODOLOGIA: PasoMetodologia[] = [
  { numero: 1, nombre: 'Literatura', texto: 'Métodos para delimitar manglar en el trópico y en Colombia.', comprobacion: 'Bunting y colaboradores 2022; Baloloy y colaboradores 2020; Murillo-Sandoval y colaboradores 2022.' },
  { numero: 2, nombre: 'Insumos', texto: 'Sentinel-2 nivel 2A: 44 compuestos trimestrales de mediana, bandas 2 a 12; cartografía de referencia 2017, 2020 y portafolio.', comprobacion: 'Nubes excluidas con la clasificación de escena.' },
  { numero: 3, nombre: 'Versión 1', texto: 'Clasificación trimestre a trimestre, bosque aleatorio de 200 árboles entrenado con la capa 2020.', comprobacion: 'Diagnóstico: unas 170 ha cambiaban de clase cada trimestre por efecto estacional.' },
  { numero: 4, nombre: 'Versión 2', texto: 'Línea base, regla de persistencia y reentrenamiento con muestras de alta resolución.', comprobacion: 'Variante A: falsa ganancia de 181 ha. Variante B: 454 ha, coincidencia 0,42.' },
  { numero: 5, nombre: 'Versión 3, variables', texto: 'Sentinel-2 en ventanas de cuatro trimestres, radar Sentinel-1 y ALOS, elevación, agua y altura del dosel.', comprobacion: 'Separación de clases medida por variable.' },
  { numero: 6, nombre: 'Muestra', texto: '524 puntos interpretados en imágenes de 0,6 m; 325 de consenso.', comprobacion: 'Dudosos excluidos del entrenamiento.' },
  { numero: 7, nombre: 'Clasificador', texto: 'Bosque aleatorio de 500 árboles; probabilidad por píxel.', comprobacion: 'Validación cruzada en cinco partes: exactitud 0,877.' },
  { numero: 8, nombre: 'Umbrales', texto: 'Alta ≥ 0,7 (465 ha); media 0,5–0,7 (310 ha); por revisar 0,3–0,5 (828 ha).', comprobacion: '50 de 60 puntos de manglar dentro del mapa.' },
  { numero: 9, nombre: 'Delimitación', texto: 'Interpolación a 2,5 m, suavizado de Chaikin, unidad mínima 1.600 m².', comprobacion: 'Sørensen-Dice: 0,53, 0,54 y 0,35 con las capas de referencia.' },
  { numero: 10, nombre: 'Cambios', texto: 'Dosel presente si verdor máximo ≥ 0,4; pérdida tras 6 periodos, ganancia tras 8.', comprobacion: '34,7 ha de pérdida neta, toda en Mallorquín; episodios cortos separados.' },
  { numero: 11, nombre: 'Dosel', texto: 'ΔHumedad del último año frente a 2024–2025; anomalía por episodio de El Niño.', comprobacion: '262 ha claramente más secas; secado en cada episodio.' },
  { numero: 12, nombre: 'Altura', texto: 'Mediana y árboles dominantes (percentil 90) del mapa de 2020.', comprobacion: 'Contraste con TanDEM-X 2015.' },
  { numero: 13, nombre: 'Agua', texto: 'Espejo de agua y turbidez de cinco ciénagas.', comprobacion: 'Turbidez relativa, sin calibrar; calibración pendiente con la red de monitoreo.' },
  { numero: 14, nombre: 'Presión y riesgo', texto: 'H = 1 − Π(1 − F·I); Riesgo = 0,5·Amenaza + 0,5·Vulnerabilidad.', comprobacion: 'Percentiles 2 y 98; cuartiles.' },
  { numero: 15, nombre: 'Carbono', texto: '270 t C/ha; 125 mil t; enterramiento de 1,62 y 0,64 t/ha al año.', comprobacion: 'Valor central y límite superior.' },
  { numero: 16, nombre: 'Equivalencias', texto: 'Toneladas de dióxido de carbono traducidas a personas y carros.', comprobacion: '5,43 t por persona al año; 7,4 t por carro al año.' },
  { numero: 17, nombre: 'Revisión crítica', texto: 'Consolidado de 465 y 775 ha, reglas de color, textos sin siglas.', comprobacion: 'Las etiquetas de entrenamiento dependen de las capas de referencia.' },
  { numero: 18, nombre: 'Pendientes', texto: 'Etiquetas independientes, reentrenamiento con las 828 ha por revisar, calibración de turbidez, nivel del mar.', comprobacion: '' },
];

export const NOTA_CAPAS_VIVAS = 'En el visor de la C.R.A., «Capas vivas» muestra las nueve capas como láminas apiladas de un recuadro de 5,6 × 5,6 km de la Ciénaga de Mallorquín: cada lámina es un mapa real del mismo lugar, de las fuentes abajo a los productos arriba, con deslizadores para separarlas y girarlas y líneas punteadas que siguen los puntos interpretados.';

// ── Pestañas ────────────────────────────────────────────────────────────────
const tablaPorSector = (titulo: string, columnas: string[], valores: (s: SectorWorkflow) => number[], extra: Partial<Extract<Bloque, { tipo: 'tabla' }>> = {}): Bloque =>
  ({ tipo: 'tabla', titulo, columnas, filas: S.map(s => ({ etiqueta: s.nombre, valores: valores(s) })), ...extra });

export const PESTANAS_WORKFLOW: PestanaWorkflow[] = [
  {
    id: 'sintesis', etiqueta: 'Síntesis', titulo: 'El manglar en cifras', capa: 'sectores', rotuloSector: 'probable', fuente: FUENTE_WORKFLOW,
    narracion: 'El manglar del departamento del Atlántico tiene 465 hectáreas con probabilidad alta de ser manglar en 2024 y 2025, 310 con probabilidad media y 828 por revisar, que son el insumo para reentrenar el modelo. De las 465 hectáreas de probabilidad alta, 371 coinciden con la cartografía de referencia; del manglar probable, 486 de 775. El 83 por ciento de los puntos interpretados como manglar en imágenes de alta resolución caen dentro del mapa. Esas 465 hectáreas guardan 125 mil toneladas de carbono, a 270 toneladas por hectárea, y el fondo de las cinco ciénagas entierra 1.518 toneladas de carbono al año. Mallorquín y Bocas de Ceniza reúnen 348 hectáreas de manglar probable, el 45 por ciento; el Totumo, Astilleros y Galerazamba, 291; Puerto Colombia, Balboa y Puerto Velero, 91; y Tubará y Juan de Acosta, 45. Las cifras de 465 y 775 hectáreas son las mismas en todo el visor.',
    bloques: [
      { tipo: 'cifras', items: [
        { valor: '465', unidad: 'ha', texto: 'Con probabilidad alta de ser manglar en 2024–2025.' },
        { valor: '310', unidad: 'ha', texto: 'Con probabilidad media (0,5 a 0,7).' },
        { valor: '828', unidad: 'ha', texto: 'Por revisar (0,3 a 0,5), insumo para reentrenar el modelo.' },
        { valor: '371 de 465', unidad: 'ha', texto: 'De probabilidad alta coinciden con la cartografía de referencia; 486 de 775 del manglar probable.' },
        { valor: '83 %', texto: 'De los puntos interpretados como manglar en imágenes de alta resolución caen dentro del mapa (50 de 60).' },
        { valor: '125 mil', unidad: 't de carbono', texto: 'Almacenadas en las 465 ha (270 por hectárea).' },
        { valor: '1.518', unidad: 't de carbono al año', texto: 'Enterradas en el fondo de las cinco ciénagas.' },
      ] },
      { tipo: 'barras', titulo: 'Manglar probable por sector', unidad: 'ha', items: porSector(s => s.probable_ha, s => `${n(s.probable_ha)} ha · ${s.pct_departamento} %`,
        s => `${n(s.probable_ha)} hectáreas de manglar probable en 2024–2025 (probabilidad del modelo de 0,5 o más), el ${s.pct_departamento} % del departamento. De ellas, ${n(s.alta_ha)} tienen probabilidad alta. Altura mediana del dosel: ${n(s.altura_mediana_m, 1)} m.`, false) },
      { tipo: 'barras', titulo: 'Hectáreas con probabilidad alta, por sector', unidad: 'ha', items: porSector(s => s.alta_ha, s => `${n(s.alta_ha)} ha`,
        s => `${n(s.alta_ha)} hectáreas con probabilidad de manglar de 0,7 o más, el ${s.pct_alta_en_sector} % del manglar probable del sector. ${n(s.alta_coincide_ha)} de ellas coinciden con al menos una cartografía de referencia. El modelo combina Sentinel-2, radar Sentinel-1 y ALOS, elevación y altura de dosel, entrenado con 325 puntos de consenso.`) },
      { tipo: 'pendiente', capas: ['Manglar por nivel de probabilidad', 'Límite de 10 kilómetros'], convenciones: ['Probabilidad alta, 0,7 o más', 'Probabilidad media, 0,5 a 0,7', 'Por revisar, 0,3 a 0,5', 'Límite de 10 kilómetros'] },
    ],
  },
  {
    id: 'extension', etiqueta: 'Extensión', titulo: 'Extensión probable en 2024–2025', capa: 'cra', rotuloSector: 'total', fuente: `${FUENTE_WORKFLOW}; Capa Nacional de Manglares 2020; capa C.R.A. e INVEMAR 2017; portafolio de ecosistemas de la C.R.A.`,
    narracion: 'El manglar probable de 2024 y 2025 suma 775 hectáreas, de las cuales 465 tienen probabilidad alta, de 0,7 o más, y 310 probabilidad media, entre 0,5 y 0,7. Otras 828 hectáreas tienen probabilidad entre 0,3 y 0,5 y quedan por verificar: 452 en el Totumo, 168 en Mallorquín, 106 en Puerto Colombia y 102 en Tubará. La coincidencia con la cartografía de referencia, medida con el coeficiente de Sørensen Dice, es de 0,53 con la Capa Nacional de Manglares de 2020, 0,54 con la capa de 2017 de la Corporación y el Instituto de Investigaciones Marinas y Costeras, y 0,35 con el portafolio de ecosistemas. En la verificación visual, 50 de 60 puntos interpretados como manglar caen dentro del mapa, y solo 1 de 173 puntos sin árboles. El plan de manejo de la Corporación cubre 554 de las 775 hectáreas.',
    bloques: [
      { tipo: 'cifras', items: [{ valor: '775', unidad: 'ha', texto: 'De manglar probable; 465 con probabilidad alta.' }, { valor: '554 de 775', unidad: 'ha', texto: 'Dentro de la zonificación del plan de manejo de la Corporación; 221 ha quedan fuera.' }] },
      tablaPorSector('Hectáreas por nivel de probabilidad de ser manglar, por sector', ['Alta, 0,7 o más', 'Media, 0,5 a 0,7', 'Por revisar, 0,3 a 0,5', 'Total'], s => [s.alta_ha, s.media_ha, s.por_revisar_ha, s.total_ha], { colores: COLOR_PROBABILIDAD, total: true }),
      { tipo: 'barras', titulo: 'Áreas con probabilidad intermedia de ser manglar, por verificar (0,3 a 0,5)', unidad: 'ha', items: porSector(s => s.por_revisar_ha, s => `${n(s.por_revisar_ha)} ha`,
        s => `${n(s.por_revisar_ha)} hectáreas leñosas con probabilidad entre 0,3 y 0,5, fuera del manglar probable. Entre 2016–2017 y 2024–2025 el verdor máximo del dosel desciende en el ${s.verdor_por_revisar.desciende_pct} % de esta área y aumenta en el ${s.verdor_por_revisar.aumenta_pct} %. Son el insumo para reentrenar el modelo con verificación en campo o en imagen.`) },
      { tipo: 'barras', titulo: 'Coincidencia con la cartografía de referencia de manglar (coeficiente de Sørensen-Dice, 0 a 1)', unidad: 'índice', items: [
        { etiqueta: 'Capa Nacional de Manglares 2020 (536 ha)', valor: 0.53, texto: '0,53', explicacion: 'La capa tiene 536 hectáreas en el Atlántico y 350 coinciden con el manglar probable.' },
        { etiqueta: 'Corporación e Instituto de Investigaciones Marinas y Costeras 2017 (758 ha)', valor: 0.54, texto: '0,54', explicacion: 'La capa tiene 758 hectáreas en el Atlántico y 411 coinciden con el manglar probable.' },
        { etiqueta: 'Portafolio de ecosistemas de la Corporación (571 ha)', valor: 0.35, texto: '0,35', explicacion: 'La capa tiene 571 hectáreas en el Atlántico y 236 coinciden con el manglar probable.' },
      ], nota: 'Coeficiente = 2 × área común / (área del visor + área de la capa); 1 es coincidencia total. Las capas no tienen acto administrativo que las adopte como cartografía oficial; son referencia.' },
      { tipo: 'barras', titulo: 'Verificación visual con imágenes de alta resolución: puntos dentro del manglar de referencia', unidad: 'puntos', items: [
        { etiqueta: 'Sin árboles (agua, arena, pantano, construcción)', valor: 1 / 173, texto: '1 de 173', explicacion: 'De 173 puntos interpretados sin árboles, 1 queda dentro del manglar probable.' },
        { etiqueta: 'Interpretados como manglar', valor: 50 / 60, texto: '50 de 60', explicacion: 'De 60 puntos interpretados como manglar, 50 quedan dentro del manglar probable (83 %).' },
        { etiqueta: 'Leñosos dudosos', valor: 59 / 81, texto: '59 de 81', explicacion: 'De 81 puntos leñosos que la interpretación visual no pudo asignar, 59 quedan dentro del manglar probable.' },
        { etiqueta: 'Interpretados como otro bosque', valor: 98 / 210, texto: '98 de 210', explicacion: 'De 210 puntos interpretados como otro bosque, 98 quedan dentro del manglar probable. Una parte puede ser manglar que la imagen no permite distinguir y otra es error del modelo.' },
      ], nota: 'La barra muestra la proporción de puntos de cada categoría que cae dentro del manglar probable.' },
      { tipo: 'texto', parrafos: ['En el visor de la C.R.A., morado es probabilidad de 0,7 o más; magenta, entre 0,5 y 0,7; rosa claro, entre 0,3 y 0,5, áreas por revisar. Sobre la imagen satelital se pueden activar las áreas por revisar, la Capa Nacional de Manglares 2020 y el plan de manejo de la Corporación.'] },
      { tipo: 'pendiente', capas: ['Manglar de referencia 2024–2025 por nivel de probabilidad', 'Áreas por revisar', 'Imagen satelital de alta resolución (Esri World Imagery)'], convenciones: ['Probabilidad alta, 0,7 o más', 'Probabilidad media, 0,5 a 0,7', 'Por revisar, 0,3 a 0,5'] },
    ],
  },
  {
    id: 'cambios', etiqueta: 'Cambios', titulo: 'Cambios confirmados, 2016–2025', capa: 'sectores', fuente: `${FUENTE_WORKFLOW}; ${FUENTE_SERIES}`,
    narracion: 'Entre 2016 y 2025 se confirmaron 36,6 hectáreas de pérdida y 1,9 de ganancia: una pérdida neta de 34,7 hectáreas, toda en la franja de playa al occidente de la barra de Mallorquín. Son unos tres kilómetros de franja de manglar sobre la costa, en tres tramos de 1.200, 1.050 y 710 metros. El carbono de esa franja equivale, como máximo, a lo que emiten 5.500 colombianos en un año, o Barranquilla en día y medio. La franja sostenía unas 3,5 toneladas de pescado y jaiba al año, el sustento de un pescador, y unos 500 mil cangrejos juveniles. Una pérdida se confirma cuando el dosel falta seis periodos seguidos; una ganancia, cuando aparece ocho. Los episodios cortos que se recuperaron suman 9,9 hectáreas en Mallorquín, 6,5 en el Totumo, 2,2 en Puerto Colombia y 1 en Tubará, y no cuentan como pérdida.',
    bloques: [
      { tipo: 'cifras', items: [{ valor: '34,7', unidad: 'ha', texto: 'De pérdida neta confirmada, 2016–2025: 36,6 perdidas y 1,9 ganadas.' }] },
      { tipo: 'serie', titulo: 'Extensión anual del manglar probable', unidad: 'ha', decimales: 1, desdeCero: true, grupos: [{ nombre: 'Departamento', series: [{ nombre: 'Manglar probable', color: 'var(--color-capa-manglar)', puntos: SERIE_EXTENSION_ANUAL }] }],
        nota: 'Hasta 2025: 36,6 ha de pérdida y 1,9 de ganancia confirmadas. 2026 queda fuera: tiene tres trimestres y la regla exige seis. El visor de la C.R.A. redondea a 801 ha en 2016 y 775 en 2025.' },
      { tipo: 'cifras', items: [
        { valor: '3 km', texto: 'De franja de manglar perdidos sobre la costa, en tres tramos de 1.200, 1.050 y 710 m y unos 11 m de ancho.' },
        { valor: 'hasta 5.500', unidad: 'colombianos', texto: 'Su emisión de un año equivale al carbono de esa franja (8.190 t); Barranquilla en día y medio.' },
        { valor: '3,5 t', unidad: 'de pescado y jaiba al año', texto: 'Que esa franja sostenía, el sustento de un pescador (102 kg por hectárea, Ciénaga Grande de Santa Marta).' },
        { valor: '500 mil', unidad: 'cangrejos juveniles al año', texto: '145 por cada 100 m², densidad modelada para Colombia.' },
      ] },
      { tipo: 'barras', titulo: 'Mayores cambios confirmados, todos en Mallorquín', unidad: 'ha', items: ([[-13.0, 2022], [-12.0, 2020], [-7.3, 2019], [-0.8, 2020], [0.6, 2022], [-0.6, 2019], [-0.5, 2024], [-0.5, 2019]] as const).map(([ha, anio]) => ({
        etiqueta: `${ha < 0 ? 'Pérdida' : 'Ganancia'} ${anio}`, valor: ha, texto: `${firmado(ha)} ha`,
        explicacion: ha < 0
          ? `${n(-ha, 1)} hectáreas donde el dosel desapareció durante seis periodos consecutivos después de ocho periodos con manglar; la pérdida se confirma hacia ${anio}.`
          : `${n(ha, 1)} hectáreas donde el dosel apareció durante ocho periodos consecutivos después de seis sin manglar; la ganancia se confirma hacia ${anio}.`,
      })) },
      { tipo: 'barras', titulo: 'Episodios cortos de pérdida que se recuperaron, por sector', unidad: 'ha', items: porSector(s => s.episodios_cortos.total_ha, s => `${n(s.episodios_cortos.total_ha, 1)} ha`,
        s => `${n(s.episodios_cortos.total_ha, 1)} hectáreas de manglar probable perdieron el dosel entre uno y cinco periodos y lo recuperaron: ${n(s.episodios_cortos.uno_dos_ha, 1)} ha en episodios de uno o dos periodos y ${n(s.episodios_cortos.tres_cinco_ha, 1)} en episodios de tres a cinco. No cuentan como pérdida confirmada.`) },
      { tipo: 'texto', titulo: 'Regla de confirmación', parrafos: [
        'Una pérdida se confirma cuando el dosel falta durante seis periodos consecutivos y antes hubo manglar ocho periodos; una ganancia exige lo inverso. Cada periodo es una ventana móvil de cuatro trimestres. La pérdida neta de 34,7 ha se calcula en píxeles con la unidad mínima de 1.600 m², la misma base de las 465 y 775 ha. Las pérdidas están en la franja de playa al occidente de la barra de Mallorquín.',
        'Fuentes de las equivalencias: IDEAM 2024 y DANE (5,43 t de dióxido de carbono por persona al año); Contreras Araque 2016; zu Ermgassen y colaboradores 2025; Pendleton y colaboradores 2012 (al perderse un manglar se emite entre el 25 y el 100 % de su carbono superficial, por eso se dice «hasta»).',
      ] },
      { tipo: 'pendiente', capas: ['Cambios confirmados por año (pérdidas y ganancias)', 'Manglar en el año seleccionado'], convenciones: ['Manglar en el año seleccionado', 'Pérdida confirmada (−)', 'Ganancia confirmada (+)'] },
    ],
  },
  {
    id: 'dosel', etiqueta: 'Dosel 2026', titulo: 'Un dosel más seco en 2026', capa: 'sectores', fuente: `${FUENTE_WORKFLOW}; ${FUENTE_SERIES}; Índice Oceánico de El Niño (NOAA); IDEAM, estación automática del aeropuerto Ernesto Cortissoz`,
    narracion: 'En el último año, 262 hectáreas de manglar tienen el dosel claramente más seco que en 2024 y 2025, y 419 muestran algún secado. El parche más seco tiene 28,7 hectáreas en Mallorquín. Por sector, el dosel claramente más seco ocupa 106 hectáreas en Mallorquín, 72 en el Totumo, 47 en Puerto Colombia y 37 en Tubará. El dosel se seca en cada episodio de El Niño y se recupera en La Niña. El episodio fuerte de 2015 y 2016 bajó la humedad del dosel y el manglar se recuperó en dos trimestres; el moderado de 2018 y 2019 tardó más de cinco. El episodio de 2023 y 2024 casi no lo afectó, porque venía de tres años de La Niña. El episodio que empezó en abril de 2026 ya produjo la anomalía más fuerte de la serie en Puerto Colombia y Tubará, y es la causa más probable de las 262 hectáreas secas.',
    bloques: [
      { tipo: 'cifras', items: [{ valor: '262', unidad: 'ha', texto: 'De manglar con el dosel claramente más seco en el último año; 419 con algún secado.' }] },
      { tipo: 'barras', titulo: 'Parches más secos en 2026, durante el episodio de El Niño en curso', unidad: 'ha', items: ([
        ['Mallorquín', 1, 28.7, 0.18, 0.46], ['Mallorquín', 2, 21.9, 0.19, 0.32], ['Tubará', 3, 14.0, 0.15, 0.26], ['Totumo', 4, 12.5, 0.20, 0.26], ['Mallorquín', 5, 12.0, 0.18, 0.30],
        ['Mallorquín', 6, 10.9, 0.21, 0.34], ['Totumo', 7, 8.1, 0.22, 0.29], ['Puerto Colombia', 8, 7.9, 0.16, 0.25], ['Puerto Colombia', 9, 6.0, 0.17, 0.25], ['Mallorquín', 10, 6.0, 0.12, 0.18],
      ] as const).map(([sector, p, ha, media, max]) => ({ etiqueta: `${sector} · parche ${p}`, valor: ha, texto: `${n(ha, 1)} ha`,
        explicacion: `${n(ha, 1)} hectáreas de manglar continuo con el índice de humedad del dosel ${n(media, 2)} unidades por debajo de su valor de 2024–2025 en promedio (hasta ${n(max, 2)} en su punto más seco).` })),
        nota: 'En el visor de la C.R.A., al seleccionar un parche la gráfica de El Niño muestra su propia serie trimestral; esas series por parche no se publican como tabla.' },
      { tipo: 'barras', titulo: 'Dosel claramente más seco por sector', unidad: 'ha', items: porSector(s => s.dosel_seco_ha, s => `${n(s.dosel_seco_ha)} ha`,
        s => `${n(s.dosel_seco_ha)} de ${n(s.probable_ha)} hectáreas del sector tienen el índice de humedad del dosel 0,10 o más por debajo de 2024–2025, y ${n(s.dosel_algo_seco_ha)} están 0,05 o más por debajo. La variación mediana del sector es ${firmado(s.variacion_mediana_humedad, 2)}.`) },
      { tipo: 'barras', titulo: 'Efecto de cada episodio de El Niño en la humedad del dosel', unidad: 'anomalía', items: [
        ...EPISODIOS_EL_NINO.map(e => ({ etiqueta: `${e.desde} a ${e.hasta} · intensidad ${n(e.intensidad, 2)}`, valor: e.efecto, texto: firmado(e.efecto, 3),
          explicacion: `Anomalía media de la humedad del dosel durante el episodio: ${S.map(s => `${s.nombre} ${firmado(e.anomalia[s.id], 3)}`).join('; ')}. Trimestres hasta recuperar la humedad normal: ${S.map(s => `${s.nombre} ${e.recuperacion[s.id]}`).join('; ')}.` })),
        { etiqueta: `${EPISODIO_EN_CURSO.desde} a hoy · intensidad ${n(EPISODIO_EN_CURSO.intensidad, 2)}`, valor: EPISODIO_EN_CURSO.efecto, texto: firmado(EPISODIO_EN_CURSO.efecto, 3),
          explicacion: 'Episodio en curso según el Índice Oceánico de El Niño (2,16 en julio–septiembre de 2026). En el tercer trimestre de 2026 la anomalía de humedad fue −0,10 en Mallorquín, −0,23 en Puerto Colombia, −0,17 en Tubará y −0,12 en el Totumo: la más fuerte de la serie en Puerto Colombia y Tubará.' },
      ] },
      { tipo: 'serie', titulo: 'Humedad del dosel por sector', unidad: 'índice de humedad', decimales: 2, grupos: [{ nombre: 'Sectores', series: serieSector(2) }], bandas: BANDAS_ENSO },
      { tipo: 'serie', titulo: 'Verdor del dosel por sector', unidad: 'índice de verdor', decimales: 2, grupos: [{ nombre: 'Sectores', series: serieSector(1) }], bandas: BANDAS_ENSO },
      { tipo: 'serie', titulo: 'Contexto: anomalía mensual de la temperatura del aire, aeropuerto Ernesto Cortissoz', unidad: '°C', decimales: 2, bandas: BANDAS_ENSO,
        grupos: [{ nombre: 'Estación', series: [{ nombre: 'Anomalía de temperatura', color: 'var(--color-capa-recuperacion)', puntos: SERIE_TEMPERATURA }] }],
        nota: 'Temperatura media mensual de la estación automática del aeropuerto Ernesto Cortissoz (Soledad), del Instituto de Hidrología, Meteorología y Estudios Ambientales, menos la media del mismo mes en 2015–2025. Los meses sin dato (2016-07, 2018-12, 2019-01, 2021-01 a 2021-09, 2022-01 a 2022-07 y 2022-11) quedan en blanco. La lluvia de la misma estación automática no se muestra: la serie publicada tiene acumulados mensuales de hasta 23.866 mm en 2018, incompatibles con el clima local, y se está buscando la serie de la estación convencional. Último dato: 2026-10, +1,0 °C.' },
      { tipo: 'texto', parrafos: [
        'El mapa de calor de la C.R.A. muestra la diferencia del índice de humedad del dosel entre el último año y 2024–2025, suavizada a 15 metros: verde más húmedo, rojo más seco. El dosel se seca en los cuatro sectores durante El Niño y se recupera en La Niña; la correlación entre el Índice Oceánico y la anomalía de humedad va de −0,34 en Tubará a −0,64 en el Totumo con un trimestre de retraso. El episodio de 2023–2024 casi no afectó al dosel porque venía de tres años de La Niña.',
        'Episodios según el umbral oficial de 0,5 durante cinco estaciones seguidas (Administración Nacional Oceánica y Atmosférica de Estados Unidos). Cinco episodios en once años es una muestra corta.',
      ] },
      { tipo: 'pendiente', capas: ['Mapa de calor de la humedad del dosel, 2026 frente a 2024–2025'], convenciones: ['Más húmedo que 2024–2025 (+0,02 o más)', 'Sin cambio claro', 'Algo más seco (−0,05 a −0,10)', 'Claramente más seco (−0,10 o menos)'] },
    ],
  },
  {
    id: 'altura', etiqueta: 'Altura', titulo: 'La estructura del dosel', capa: 'sectores', fuente: `${FUENTE_WORKFLOW}; Lang y colaboradores (2023), mapa global de altura de dosel 2020`,
    narracion: 'La altura mediana del dosel es de 10,7 metros en el conjunto del manglar probable, según el mapa global de 2020. Por sector: 11,4 metros en Mallorquín, 11,1 en Puerto Colombia, 11 en Tubará y 9,8 en el Totumo. Los árboles dominantes, el 10 por ciento más alto, superan 18,6 metros en Mallorquín, 16,3 en el Totumo, 16 en Puerto Colombia y 15 en Tubará. Esa medida muestra hasta dónde se desarrolla el manglar en cada sector y es la que usa la fórmula de biomasa. El Totumo tiene la mediana más baja, pero sus rodales dominantes superan a los de Puerto Colombia y Tubará. Mallorquín alcanza sus mayores alturas en los rodales que reciben agua del río Magdalena. Diferencias menores de un metro entre sectores no son significativas.',
    bloques: [
      { tipo: 'cifras', items: [{ valor: '10,7', unidad: 'm', texto: 'Altura mediana del dosel dentro del manglar probable.' }] },
      { tipo: 'barras', titulo: 'Altura mediana por sector', unidad: 'm', items: porSector(s => s.altura_mediana_m, s => `${n(s.altura_mediana_m, 1)} m`,
        s => `Altura mediana del dosel de ${n(s.altura_mediana_m, 1)} m; los árboles dominantes (10 % más alto) superan ${n(s.altura_dominante_m, 1)} m. Mapa de altura de 2020 de Lang y colaboradores (2023), a 10 metros, calibrado con el láser de la misión GEDI.`) },
      { tipo: 'barras', titulo: 'Altura de los árboles dominantes (10 % más alto)', unidad: 'm', items: porSector(s => s.altura_dominante_m, s => `${n(s.altura_dominante_m, 1)} m`,
        s => `Altura mediana del dosel de ${n(s.altura_mediana_m, 1)} m; los árboles dominantes (10 % más alto) superan ${n(s.altura_dominante_m, 1)} m. Mapa de altura de 2020 de Lang y colaboradores (2023), a 10 metros, calibrado con el láser de la misión GEDI.`) },
      { tipo: 'texto', parrafos: [
        'Muestra hasta dónde se desarrolla el manglar en cada sector. La mediana mezcla franjas jóvenes, bordes y rodales maduros; esta medida resume la décima parte más alta del dosel y es la que usa la fórmula de biomasa. El Totumo tiene la mediana más baja, pero sus rodales dominantes superan a los de Puerto Colombia y Tubará. Mallorquín alcanza 18,6 m en los rodales que reciben agua del río Magdalena.',
        'Altura del mapa de Lang y colaboradores (2023) para 2020, a 10 metros, con error de varios metros por píxel; diferencias menores de 1 m entre sectores no son significativas. Manglar y otro bosque tienen alturas similares, de modo que la altura sirve para estructura y biomasa y no para delimitar.',
      ] },
      { tipo: 'pendiente', capas: ['Altura del dosel en 2020'], convenciones: ['0 a 5 m', '5 a 10 m', '10 a 15 m', '15 a 20 m', 'Más de 20 m'] },
    ],
  },
  {
    id: 'agua', etiqueta: 'Agua', titulo: 'El agua conecta el manglar', capa: 'cra', fuente: `${FUENTE_WORKFLOW}; ${FUENTE_SERIES}; Dogliotti y colaboradores (2015)`,
    narracion: 'El espejo de agua mediano entre 2015 y 2026 es de unas 1.372 hectáreas en la Ciénaga del Totumo, 817 en Mallorquín, 150 en Balboa, 31 en Manatíes y 2 en El Salado. Un píxel cuenta como agua cuando el índice de agua de Sentinel 2 es mayor que cero. La turbidez es un indicador relativo sin calibración en campo: sirve para comparar trimestres y ciénagas entre sí. Queda pendiente calibrarla con las mediciones de la red de monitoreo del Instituto de Investigaciones Marinas y Costeras, excluir las orillas someras y cruzarla con la altura y el verdor del manglar. El fondo de las cinco ciénagas entierra unas 1.518 toneladas de carbono al año.',
    bloques: [
      { tipo: 'cifras', items: [{ valor: '817', unidad: 'ha', texto: 'De espejo de agua, mediana 2015–2026 · Ciénaga de Mallorquín.' }] },
      { tipo: 'barras', titulo: 'Ciénagas: espejo de agua mediano 2015–2026', unidad: 'ha', items: CIENAGAS.map(c => ({ etiqueta: c.nombre, valor: c.espejo_ha, texto: `${n(c.espejo_ha)} ha`,
        explicacion: `Espejo de agua mediano de ${n(c.espejo_ha)} hectáreas entre 2015 y 2026, con mínimo de ${n(c.minimo_ha)} y máximo de ${n(c.maximo_ha)}. Turbidez relativa mediana: ${n(c.turbidez, 1)}, un indicador comparativo sin calibración en campo. Carbono enterrado en el fondo: ${n(c.carbono_t)} t al año (0,64 t por hectárea al año).` })) },
      { tipo: 'serie', titulo: 'Espejo de agua por trimestre', unidad: 'ha', decimales: 1, grupos: ordenAgua.map(id => ({ nombre: CIENAGAS.find(c => c.id === id)!.nombre,
        series: [{ nombre: 'Espejo de agua', color: 'var(--color-capa-agua)', puntos: SERIE_AGUA[id].map(p => [p[0], p[1]] as const) }] })),
        nota: 'Solo los trimestres con imagen útil. En el visor de la C.R.A. se elige la ciénaga con un clic en su barra.' },
      { tipo: 'serie', titulo: 'Turbidez relativa, sin calibrar', unidad: 'turbidez relativa', decimales: 1, grupos: ordenAgua.map(id => ({ nombre: CIENAGAS.find(c => c.id === id)!.nombre,
        series: [{ nombre: 'Turbidez relativa', color: 'var(--color-dorado-500)', puntos: SERIE_AGUA[id].map(p => [p[0], p[2]] as const) }] })) },
      { tipo: 'texto', titulo: 'Método y pendientes', parrafos: [
        'Un píxel cuenta como agua cuando el índice (B3 − B11)/(B3 + B11) es mayor que 0. La turbidez usa el algoritmo de Dogliotti y colaboradores (2015) sobre las bandas 4 y 8A, con reflectancia sin corrección específica para agua: sirve para comparar trimestres y ciénagas entre sí.',
        'Pendiente: calibrarla con las mediciones de turbidez y sólidos suspendidos de la red de monitoreo del Instituto de Investigaciones Marinas y Costeras en Mallorquín y Balboa, excluir los píxeles de orilla somera (Mallorquín tiene 0,6 m de profundidad media) y cruzarla con la altura y el verdor del manglar por zona.',
      ] },
      { tipo: 'pendiente', capas: ['Frecuencia de agua superficial, 2015–2026'], convenciones: ['Agua permanente', 'Agua ocasional', 'Manglar probable'] },
    ],
  },
  {
    id: 'presion', etiqueta: 'Presión', titulo: 'Presión antrópica y riesgo', capa: 'sectores', fuente: `${FUENTE_WORKFLOW}; Theobald y colaboradores (2020); OCDE y Centro Común de Investigación (2008); IPCC (2022)`,
    narracion: 'El índice de riesgo mide qué tan expuesto está cada píxel de manglar a perderse. Combina con el mismo peso la amenaza, que suma la presión humana en 10 kilómetros, el retroceso de la costa y el secado del dosel, y la vulnerabilidad, mayor cerca del borde y en parches pequeños. Va de 0 a 1 y se divide en cuatro niveles. 194 hectáreas están en el nivel muy alto. El riesgo medio es de 0,44 en Tubará, 0,42 en Puerto Colombia, 0,38 en Mallorquín y 0,33 en el Totumo. En Mallorquín la amenaza principal es la presión antrópica; en Tubará y Puerto Colombia, la sequía del dosel. La exposición media del manglar a la presión humana en 2023 a 2026 es de 0,14; en Mallorquín llega a 0,22.',
    bloques: [
      { tipo: 'texto', parrafos: ['El índice de riesgo mide qué tan expuesto está cada píxel de manglar a perderse. Combina dos partes con el mismo peso. La amenaza es lo que presiona al manglar desde afuera: la presión humana en 10 km alrededor (construcciones, vías, cultivos y pastos, con más peso para lo cercano), el retroceso de la costa y el secado del dosel en 2026. La vulnerabilidad es qué tan frágil es el manglar en ese punto: mayor cerca del borde del parche y en parches pequeños. El índice va de 0 a 1 y se divide en cuatro niveles iguales: bajo, medio, alto y muy alto. Un valor de 0,6 o más se marca como extremo.'] },
      { tipo: 'formula', texto: 'Riesgo = 0,5 × Amenaza + 0,5 × Vulnerabilidad', nota: 'Organización para la Cooperación y el Desarrollo Económicos y Centro Común de Investigación, 2008; marco del Grupo Intergubernamental de Expertos sobre el Cambio Climático, 2022.' },
      { tipo: 'cifras', items: [{ valor: '194', unidad: 'ha', texto: 'En el nivel de riesgo muy alto.' }] },
      { tipo: 'barras', titulo: 'Riesgo medio por sector, 0 a 1', unidad: 'índice', items: porSector(s => s.riesgo_medio, s => n(s.riesgo_medio, 2),
        s => `Riesgo medio de ${n(s.riesgo_medio, 2)}: mitad amenaza (${n(s.amenaza, 2)}) y mitad vulnerabilidad (${n(s.vulnerabilidad, 2)}). Componentes de la amenaza: presión antrópica ${n(s.amenazas.presion, 2)}, retroceso costero ${n(s.amenazas.retroceso, 2)} y sequía del dosel ${n(s.amenazas.sequia, 2)}. ${n(s.riesgo_ha.muy_alto)} de ${n(s.probable_ha)} hectáreas están en el nivel muy alto.`) },
      tablaPorSector('Hectáreas por nivel de riesgo', ['Bajo', 'Medio', 'Alto', 'Muy alto', 'Total'], s => [s.riesgo_ha.bajo, s.riesgo_ha.medio, s.riesgo_ha.alto, s.riesgo_ha.muy_alto, s.probable_ha],
        { colores: COLOR_RIESGO, total: true, nota: 'Límites entre niveles: 0,27, 0,39 y 0,48 (bajo hasta 0,266; medio hasta 0,386; alto hasta 0,477; muy alto más de 0,477; extremo 0,6 o más).' }),
      tablaPorSector('Amenazas medias por sector, 0 a 1 cada una', ['Presión antrópica', 'Retroceso costero', 'Sequía del dosel', 'Amenaza media'], s => [s.amenazas.presion, s.amenazas.retroceso, s.amenazas.sequia, s.amenaza],
        { decimales: 2, nota: 'Presión antrópica: índice de modificación humana en 10 km ponderado por distancia (Theobald y colaboradores, 2020), normalizado entre los percentiles 2 y 98 del manglar. Retroceso costero: cercanía a tierra convertida en agua de mar entre 2016–2017 y 2024–2026, con decaimiento exponencial de 200 m. Sequía del dosel: pérdida de humedad del dosel en el último año frente a 2024–2025. La amenaza media es el promedio de las tres.' }),
      { tipo: 'barras', titulo: 'Zonas de mayor riesgo', unidad: 'ha', items: ([
        ['Mallorquín', 'presión antrópica', 8.4, 0.54, 0.67, 0.42], ['Mallorquín', 'retroceso costero', 6.1, 0.55, 0.70, 0.40], ['Mallorquín', 'presión antrópica', 4.9, 0.49, 0.36, 0.62],
        ['Totumo', 'sequía del dosel', 4.8, 0.55, 0.49, 0.61], ['Mallorquín', 'sequía del dosel', 3.4, 0.50, 0.45, 0.55], ['Totumo', 'sequía del dosel', 3.2, 0.51, 0.43, 0.60],
        ['Puerto Colombia', 'sequía del dosel', 2.9, 0.52, 0.33, 0.71], ['Mallorquín', 'sequía del dosel', 2.9, 0.51, 0.44, 0.59], ['Mallorquín', 'presión antrópica', 2.7, 0.50, 0.36, 0.65],
        ['Mallorquín', 'presión antrópica', 2.7, 0.53, 0.35, 0.72],
      ] as const).map(([sector, amenaza, ha, indice, am, vul]) => ({ etiqueta: `${sector} · ${amenaza}`, valor: ha, texto: `${n(ha, 1)} ha`,
        explicacion: `${n(ha, 1)} hectáreas continuas en el nivel muy alto (índice medio ${n(indice, 2)}; amenaza ${n(am, 2)}, vulnerabilidad ${n(vul, 2)}). La amenaza principal es ${amenaza}.` })) },
      { tipo: 'cifras', items: [{ valor: '0,14', unidad: 'de 0 a 1', texto: 'Exposición media del manglar a la presión antrópica en 10 kilómetros, 2023–2026. El visor de la C.R.A. también la muestra para 2016–2018 y 2019–2022 en el mapa.' }] },
      { tipo: 'barras', titulo: 'Exposición por sector', unidad: 'índice', items: [...S].sort((a, b) => b.exposicion - a.exposicion).map(s => ({ etiqueta: s.nombre_largo, valor: s.exposicion, texto: n(s.exposicion, 2), sector: s.id,
        explicacion: `Exposición media del manglar de ${n(s.exposicion, 2)} en 2023–2026: promedio del índice de modificación humana en 10 kilómetros, ponderado por la distancia al manglar.` })) },
      { tipo: 'tabla', titulo: 'Usos del suelo por anillo de distancia, hectáreas (2023–2026)', columnas: ['Construido', 'Cultivos', 'Pastos', 'Total'], colores: COLOR_USOS, total: true, filas: [
        { etiqueta: '0–0,5 km', valores: [572, 421, 224, 1217] }, { etiqueta: '0,5–1 km', valores: [396, 571, 266, 1232] },
        { etiqueta: '1–5 km', valores: [2202, 2920, 2728, 7851] }, { etiqueta: '5–10 km', valores: [4409, 2871, 5204, 12484] },
      ] },
      { tipo: 'formula', titulo: 'Presión antrópica', texto: 'H = 1 − Π(1 − F · I)', nota: 'F es la fracción del píxel ocupada por cada uso e I su intensidad (construido 0,85; vía principal 0,80; suelo desnudo antrópico 0,65; cultivos 0,45; vía menor 0,44; pastos 0,28; trocha 0,15). La exposición promedia H con el peso e^(−2,99 · d/10 km).' },
      { tipo: 'pendiente', capas: ['Índice de riesgo del manglar', 'Presión antrópica en 10 km (2016–2018, 2019–2022, 2023–2026)'], convenciones: ['Riesgo bajo, hasta 0,266', 'Medio, hasta 0,386', 'Alto, hasta 0,477', 'Muy alto, más de 0,477', 'Extremo, 0,6 o más'] },
    ],
  },
  {
    id: 'carbono', etiqueta: 'Carbono', titulo: 'El carbono también está en el suelo', capa: 'sectores', fuente: `${FUENTE_WORKFLOW}; Maxwell y colaboradores (2023); Simard y colaboradores (2019); Hutchings y colaboradores (2020); Rodríguez-Reales y colaboradores (2025); Suplemento de Humedales 2013; IDEAM; DANE; UPME`,
    narracion: 'Las 465 hectáreas de manglar con probabilidad alta guardan 125 mil toneladas de carbono, a 270 toneladas por hectárea: lo que emiten 84 mil colombianos en un año. El 92 por ciento está en el lodo del primer metro. Cada hectárea guarda la emisión anual de 182 colombianos. El suelo del manglar entierra 753 toneladas de carbono al año, lo que emiten 370 carros particulares, y el fondo de las cinco ciénagas, 1.518 toneladas, lo que emiten 750 carros. Entre manglar y ciénagas, 2.271 toneladas al año: 1.130 carros o 1.500 colombianos. Por sector, la reserva es de 71 mil toneladas en Mallorquín, 31 mil en el Totumo, 16 mil en Puerto Colombia y 7 mil en Tubará. En Mallorquín, el rodal que recibe agua del río guarda 122 toneladas de carbono aéreo por hectárea, frente a 23,5 y 11,6 en los rodales de agua mixta y marina. El límite superior es de 455 toneladas por hectárea.',
    bloques: [
      { tipo: 'cifras', items: [
        { valor: '125 mil', unidad: 't de carbono', texto: 'Guardadas en 465 ha de manglar con probabilidad alta: lo que emiten 84.400 colombianos en un año.' },
        { valor: '270', unidad: 't C/ha', texto: 'La emisión anual de 182 colombianos, guardada en una hectárea.' },
        { valor: '92 %', texto: 'Está en el lodo del primer metro (248 de 270 t por hectárea).' },
        { valor: '753', unidad: 't C al año', texto: 'Enterradas en el suelo del manglar: lo que emiten 370 carros particulares.' },
        { valor: '1.518', unidad: 't C al año', texto: 'En el fondo de las cinco ciénagas: lo que emiten 750 carros.' },
        { valor: '2.271', unidad: 't C al año', texto: 'Entre manglar y ciénagas: 1.130 carros o 1.500 colombianos.' },
        { valor: '67 de 775', unidad: 'ha', texto: 'Cubiertas por los mapas globales de suelo.' },
      ] },
      { tipo: 'tabla', titulo: 'Carbono por hectárea, toneladas (valor central)', columnas: ['Suelo, 0 a 100 cm', 'Biomasa aérea', 'Raíces', 'Total'], colores: COLOR_CARBONO, total: true, decimales: 1,
        filas: [{ etiqueta: 'Valor central', valores: [248, 17, 4.5, 270] }], nota: 'Límite superior: 455 t por hectárea, con la biomasa medida en campo en Mallorquín (49,6), raíces de clima húmedo (19) y el valor por defecto de suelo de 386.' },
      { tipo: 'barras', titulo: 'Componentes del carbono por hectárea', unidad: 't C/ha', items: [
        { etiqueta: 'Suelo, 0 a 100 cm', valor: 248, texto: '248 t C/ha', explicacion: 'Promedio del mapa global de carbono orgánico del suelo de Maxwell y colaboradores (2023) en las 67 hectáreas donde coincide con el manglar; intervalo de predicción del 95 % de 82 a 419.' },
        { etiqueta: 'Biomasa aérea', valor: 17, texto: '17 t C/ha', explicacion: 'Alometría de las Américas de Simard y colaboradores (2019) sobre la altura de dosel de 2020, fracción de carbono 0,451. La medición de campo en Mallorquín da 49,6.' },
        { etiqueta: 'Raíces', valor: 4.5, texto: '4,5 t C/ha', explicacion: 'Razón raíz/tallo de 0,29 (trópico seco) y fracción de carbono de 0,39.' },
        { etiqueta: 'Valor central', valor: 270, texto: '270 t C/ha', explicacion: 'Suelo del mapa global de Maxwell y colaboradores (2023) en las 67 ha con dato, biomasa aérea satelital y raíces con razón raíz/tallo de clima seco. Es el valor con el que se calculan todas las cifras del visor.' },
      ] },
      { tipo: 'barras', titulo: 'Reserva por sector, toneladas de carbono', unidad: 't C', items: porSector(s => s.carbono_t, s => `${n(Math.round(s.carbono_t / 1000))} mil t`,
        s => `${n(s.carbono_t)} toneladas de carbono en ${n(s.alta_ha)} hectáreas con probabilidad alta, a 270 toneladas por hectárea. Las diferencias entre sectores son solo de área: no hay datos de suelo en Tubará ni en el Totumo.`) },
      { tipo: 'barras', titulo: 'Carbono enterrado al año en el fondo de las ciénagas, toneladas', unidad: 't C', items: CIENAGAS.map(c => ({ etiqueta: c.nombre, valor: c.carbono_t, texto: `${n(c.carbono_t)} t`,
        explicacion: `${n(c.carbono_t)} toneladas de carbono al año: espejo de agua mediano × 0,64 t por hectárea al año, tasa de enterramiento de largo plazo en fondos de estuario (Hutchings y colaboradores 2020; intervalo 0,44 a 0,97). Equivale a lo que emiten ${n(c.carros)} carros particulares. En ninguna de las ciénagas se ha medido la tasa.` })) },
      { tipo: 'barras', titulo: 'Agua dulce y carbono aéreo en Mallorquín, t C por hectárea', unidad: 't C/ha', items: [
        { etiqueta: 'Rodal con agua del río, árboles de 12,6 m', valor: 122, texto: '122', explicacion: 'Estación Río (33,6 ha), con agua dulce del río Magdalena; domina Avicennia germinans; 4.098,6 toneladas de carbono aéreo (Rodríguez-Reales y colaboradores, 2025).' },
        { etiqueta: 'Rodal de agua mixta, árboles de 4,7 m', valor: 23.5, texto: '23,5', explicacion: 'Estación Laguna (74,8 ha), en Punta de Félix, mezcla de agua del río y del mar; domina Rhizophora mangle; 1.761 toneladas de carbono aéreo.' },
        { etiqueta: 'Rodal con influencia marina, árboles de 4,9 m', valor: 11.6, texto: '11,6', explicacion: 'Estación Mar (9 ha), cerca de la playa Puerto Mocho; domina Laguncularia racemosa; 104,6 toneladas de carbono aéreo.' },
      ] },
      { tipo: 'barras', titulo: 'Biomasa satelital de occidente a oriente en Mallorquín, t/ha', unidad: 't/ha', items: ([
        ['Occidente, lado del mar', 7.4, 20.1, '506,9 y 510,0', 12.6, null], ['Centro occidental', 8.3, 21.8, '510,0 y 512,5', 97.2, 10.1], ['Centro', 14.0, 48.9, '512,5 y 514,5', 103.4, 11.6],
        ['Centro oriental', 14.8, 53.7, '514,5 y 516,5', 46.6, 13.3], ['Oriente, lado del río', 12.0, 38.6, '516,5 y 520,1', 87.8, 8.2],
      ] as const).map(([franja, altura, biomasa, este, ha, tandem]) => ({ etiqueta: `${franja} · ${n(altura, 1)} m`, valor: biomasa, texto: n(biomasa, 1),
        explicacion: `Franja entre ${este} km de coordenada este: ${n(ha, 1)} hectáreas, altura mediana de ${n(altura, 1)} m en 2020${tandem === null ? '' : ` (${n(tandem, 1)} m con TanDEM-X en 2015)`} y biomasa aérea satelital de ${n(biomasa, 1)} toneladas por hectárea.` })) },
      { tipo: 'barras', titulo: 'Posición respecto al agua abierta, hectáreas', unidad: 'ha', items: ([
        ['Borde, hasta 30 m del agua abierta', 'borde, hasta 30 m del agua abierta', 76, 31, 10.4, 30.6, 259, 7.3], ['Intermedio, 30 a 150 m', 'intermedio, 30 a 150 m', 223, 32, 10.0, 32.0, 269, 23.8], ['Interior, más de 150 m', 'interior, más de 150 m', 475, 38, 11.0, 37.6, 231, 35.6],
      ] as const).map(([etiqueta, franja, ha, tha, altura, biomasa, suelo, dato]) => ({ etiqueta, valor: ha, texto: `${n(ha)} ha · ${tha} t/ha`,
        explicacion: `${n(ha)} hectáreas en la franja ${franja}: altura mediana de ${n(altura, 1)} m, biomasa aérea satelital de ${n(biomasa, 1)} toneladas por hectárea y ${n(suelo)} toneladas de carbono en el suelo según el mapa global, con dato en ${n(dato, 1)} hectáreas.` })),
        nota: 'El visor de la C.R.A. rotula la primera barra con 76,4 ha.' },
      { tipo: 'texto', parrafos: [
        'Enterramiento en el suelo del manglar: 1,62 toneladas de carbono por hectárea al año, intervalo de 1,3 a 2,0 (Suplemento de Humedales de 2013). Enterramiento no es balance neto: una ciénaga con exceso de nutrientes como Mallorquín puede emitir metano y dióxido de carbono.',
        'Equivalencias: 5,43 t de dióxido de carbono por persona al año (inventario nacional 2021 del IDEAM entre población del DANE) y 7,4 t por carro al año (25.550 km al año y 30,7 km por galón, Unidad de Planeación Minero Energética; 8,887 kg por galón).',
        'La pérdida de 36,4 hectáreas en la costa de Mallorquín contenía unas 437 toneladas de carbono en árboles y 8.180 en el suelo del primer metro.',
      ] },
      { tipo: 'pendiente', capas: ['Biomasa aérea satelital del manglar'], convenciones: ['Biomasa aérea, 0 a 15 t/ha', '15 a 30', '30 a 50', '50 a 80', 'Más de 80 t/ha'] },
    ],
  },
  {
    id: 'metodo', etiqueta: 'Método', titulo: 'Método y límites', capa: 'cra', fuente: FUENTE_WORKFLOW,
    narracion: 'La muestra tiene 524 puntos interpretados en imágenes de 60 centímetros. El entrenamiento usó 325 puntos de consenso: manglar es el punto leñoso respaldado por al menos dos capas de referencia, y no manglar es el punto sin árboles o el leñoso lejos de toda capa. Por eso las etiquetas de manglar dependen de las capas de referencia, y la exactitud de 0,877 mide la concordancia con ellas, no con el manglar real. Para que el modelo identifique el ecosistema por sí mismo, las etiquetas deben venir de campo o de interpretación experta. Las 828 hectáreas por revisar son el lugar donde nuevas etiquetas rinden más. El estudio carece de puntos de campo, la turbidez está sin calibrar y la tasa de enterramiento de las ciénagas viene de estuarios de Estados Unidos.',
    bloques: [
      { tipo: 'texto', parrafos: [
        'Muestra de 524 puntos interpretados en imágenes de 0,6 metros: 173 sin árboles y 351 leñosos.',
        'Entrenamiento con puntos de consenso: manglar es el punto leñoso respaldado por al menos dos capas de referencia (104); no manglar es el punto sin árboles o el leñoso a más de 300 m de toda capa (221). Las etiquetas de manglar dependen, por tanto, de las capas de referencia: el modelo aprende a reproducir dónde esas capas ponen manglar, con las variables satelitales como medio. Para que identifique el ecosistema por sí mismo, las etiquetas deben venir de campo o de interpretación experta de rasgos propios del manglar.',
        'Variables: Sentinel-2 en ventanas de cuatro trimestres, radar Sentinel-1, radar ALOS de banda L, elevación, frecuencia de agua y altura de dosel. Bosque aleatorio de 500 árboles.',
        'El estado de referencia es 2024–2025. Un cambio se confirma cuando el dosel desaparece seis periodos o aparece ocho. Todas las superficies usan la unidad mínima de 1.600 m².',
      ] },
      { tipo: 'barras', titulo: 'Validación cruzada sobre el consenso', unidad: 'proporción', items: [
        { etiqueta: 'Acierto de lo marcado como manglar', valor: 0.81, texto: '0,81', explicacion: 'De los puntos de consenso que el modelo marca como manglar, el 81 % es manglar según el consenso (exactitud del usuario).' },
        { etiqueta: 'Manglar de consenso encontrado', valor: 0.81, texto: '0,81', explicacion: 'De los 104 puntos de manglar de consenso, el modelo encuentra el 81 % (exactitud del productor).' },
        { etiqueta: 'Exactitud global', valor: 0.88, texto: '0,88', explicacion: 'Proporción de los 325 puntos de consenso clasificados correctamente en validación cruzada de cinco partes: 0,877.' },
      ], nota: 'Estas cifras miden la concordancia con etiquetas basadas en capas de referencia, no con el manglar real. 524 puntos interpretados; el 0,81 es la media armónica de las exactitudes del usuario y del productor.' },
      { tipo: 'texto', titulo: 'Límites', parrafos: ['El estudio carece de puntos de campo. Las 828 hectáreas por revisar son el lugar donde nuevas etiquetas rinden más. Las pérdidas detectadas son solo las drásticas: paso a agua, arena o suelo desnudo. La turbidez está sin calibrar. La tasa de enterramiento de las ciénagas viene de estuarios de Estados Unidos. El análisis del nivel del mar con DeltaDTM y FABDEM está pendiente.'] },
    ],
  },
  {
    id: 'fuentes', etiqueta: 'Fuentes', titulo: 'Datos y referencias', capa: 'cra', fuente: FUENTE_WORKFLOW,
    narracion: 'Imágenes Sentinel 2 y Sentinel 1 del programa Copernicus; radar ALOS de la agencia espacial japonesa; imágenes de alta resolución de Esri; Capa Nacional de Manglares de 2020, capa de 2017 de la Corporación y el Instituto de Investigaciones Marinas y Costeras, portafolio de ecosistemas y zonificación de prioridades de conservación de la Corporación Autónoma Regional del Atlántico; altura de dosel de Lang y colaboradores 2023; Índice Oceánico de El Niño de la Administración Nacional Oceánica y Atmosférica de Estados Unidos; presión antrópica de Theobald y colaboradores 2020; carbono de Simard, Maxwell, Hutchings y Rodríguez Reales; equivalencias con el inventario nacional de emisiones del IDEAM, la población del DANE y la Unidad de Planeación Minero Energética. El visor aplica los criterios de nivel doble A de la Resolución 1519 de 2020 del Ministerio de Tecnologías de la Información y las Comunicaciones.',
    bloques: [
      { tipo: 'referencias', items: [
        { titulo: 'Imágenes ópticas y de radar', texto: 'Sentinel-2 y Sentinel-1, programa Copernicus, catálogo Planetary Computer. ALOS PALSAR, agencia espacial japonesa.' },
        { titulo: 'Alta resolución', texto: 'Esri World Imagery, imágenes de 2023 a 2026.' },
        { titulo: 'Cartografía de referencia de manglar', texto: 'Capa Nacional de Manglares 2020; capa 2017 de la Corporación y el Instituto de Investigaciones Marinas y Costeras; portafolio de ecosistemas y zonificación de prioridades de conservación de la Corporación Autónoma Regional del Atlántico.' },
        { titulo: 'Altura de dosel', texto: 'Lang y colaboradores, 2023; Simard y colaboradores, 2025.' },
        { titulo: 'Lógica temporal', texto: 'Bunting y colaboradores, 2022; Diniz y colaboradores, 2019; Awty-Carroll y colaboradores, 2019.' },
        { titulo: 'Dosel, sequía y El Niño', texto: 'Lovelock y colaboradores, 2017; Lagomasino y colaboradores, 2021; Índice Oceánico de El Niño, Administración Nacional Oceánica y Atmosférica de Estados Unidos.' },
        { titulo: 'Temperatura del aire', texto: 'Instituto de Hidrología, Meteorología y Estudios Ambientales, conjunto de datos abiertos Temperatura (estación automática del aeropuerto Ernesto Cortissoz, código 0029045190), consultado el 17 de octubre de 2026; anomalía frente a la media mensual 2015–2025 de la misma estación. Episodios de El Niño y La Niña según el Índice Oceánico de El Niño de la Administración Nacional Oceánica y Atmosférica.' },
        { titulo: 'Agua', texto: 'Dogliotti y colaboradores, 2015; informes de la red de vigilancia de aguas marinas y costeras, Instituto de Investigaciones Marinas y Costeras y Corporación, 2021, 2023 y 2025.' },
        { titulo: 'Presión antrópica', texto: 'Theobald y colaboradores, 2020.' },
        { titulo: 'Índice de riesgo', texto: 'Grupo Intergubernamental de Expertos sobre el Cambio Climático, 2022; Goldberg y colaboradores, 2020; Mafi-Gholami y colaboradores, 2020; Bryan-Brown y colaboradores, 2020; Fan y colaboradores, 2024; OCDE y Centro Común de Investigación, 2008.' },
        { titulo: 'Carbono', texto: 'Rodríguez-Reales y colaboradores, 2025; Suplemento de Humedales 2013; Maxwell y colaboradores, 2023; Simard y colaboradores, 2019; Hutchings y colaboradores, 2020; Duarte, Middelburg y Caraco, 2005; Pendleton y colaboradores, 2012; Alongi, 2020; Rosentreter y colaboradores, 2018.' },
        { titulo: 'Equivalencias', texto: 'IDEAM, Inventario Nacional de Emisiones 1990–2021; DANE, población 2021 y proyección de Barranquilla 2025; Unidad de Planeación Minero Energética, 2009; factor de 8,887 kg de dióxido de carbono por galón; Contreras Araque, 2016; zu Ermgassen y colaboradores, 2025; McIvor y colaboradores, 2012; Horstman y colaboradores, 2014.' },
        { titulo: 'Accesibilidad (visor de la C.R.A.)', texto: 'El visor aplica los criterios de nivel AA de la Resolución 1519 de 2020 del Ministerio de Tecnologías de la Información y las Comunicaciones, anexo 1: textos alternativos y tablas de datos para mapas y gráficas, contraste de al menos 4,5 a 1 en textos, navegación por teclado con foco visible, enlace para saltar al contenido, ventana de explicación que se cierra con Escape, anuncios para lectores de pantalla, idioma declarado, movimiento solo a pedido y texto ampliable al 200 %. La escena 3D es una vista complementaria: todos los datos están en el panel y en el mapa 2D. El color nunca es el único medio: los valores con signo llevan signo o palabra.' },
        { titulo: 'Identidad visual (visor de la C.R.A.)', texto: 'Tipografía Lato y azul institucional del Manual de Identidad Visual 2024 de la Corporación; las escalas de datos usan una paleta propia para no confundir sectores con variables. Logotipo de la Corporación incluido por indicación de la entidad.' },
        { titulo: 'Esta web', texto: 'Mantiene el azul institucional y el logotipo de la Corporación con titulares en Figtree y texto en Inter. Cada gráfica trae su tabla de datos y cada explicación se abre como una fila desplegable con el teclado. Mapa base © colaboradores de OpenStreetMap; cobertura de manglar de la C.R.A. a escala 1:5.000.' },
      ] },
    ],
  },
  {
    id: 'metodologia', etiqueta: 'Metodología', titulo: 'Metodología del workflow para la definición de ecosistemas de manglar', capa: 'sectores', fuente: FUENTE_WORKFLOW,
    narracion: 'Metodología del flujo de trabajo para la definición de ecosistemas de manglar, en dieciocho pasos en el orden en que se hicieron. Primero la literatura sobre delimitación de manglar en el trópico. Luego los insumos: 44 compuestos trimestrales de Sentinel 2 entre 2015 y 2026 y la cartografía de referencia. La versión 1 clasificó trimestre a trimestre y mostró que unas 170 hectáreas cambiaban de clase por la estación. La versión 2 probó una línea base y una regla de persistencia. La versión 3 integró radar Sentinel 1 y ALOS, elevación, agua y altura del dosel, con 524 puntos interpretados en imágenes de 60 centímetros y 325 de consenso. Un bosque aleatorio de 500 árboles da la probabilidad de manglar por píxel, validada en cinco partes con exactitud de 0,877. Los umbrales separan 465 hectáreas de probabilidad alta, 310 de probabilidad media y 828 por revisar. El borde se interpola a 2,5 metros con unidad mínima de 1.600 metros cuadrados. Los cambios se confirman tras seis periodos sin dosel u ocho con dosel. Siguen el dosel y El Niño, la altura, el agua, la presión y el riesgo, el carbono y las equivalencias cotidianas. La imagen muestra cada capa como un mapa real de la Ciénaga de Mallorquín.',
    bloques: [{ tipo: 'metodologia' }],
  },
];
