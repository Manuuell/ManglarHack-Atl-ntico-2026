// Cifras y pestañas del workflow de la C.R.A. Se construyen siempre del mismo
// resumen: el que llega en vivo de /cra/data/core.json (ver cra.ts y
// useWorkflowCRA) o, si la copia no responde, RESPALDO_CRA, que es el mismo
// resumen tomado del core.json de la C.R.A. el 27-11-2026.
import type { AudioCRA, ResumenCRA, SectorCRA } from './cra';

export type SectorWorkflowId = 'mallorquin' | 'balboa' | 'manaties' | 'totumo';

export interface SectorWorkflow {
  id: SectorWorkflowId;
  nombre: string;
  nombre_cra: string;
  total_ha: number;
  probable_ha: number;
  prob_alta_ha: number;
  por_revisar_ha: number;
  dosel_seco_ha: number;
  riesgo_medio: number;
  riesgo_muy_alto_ha: number;
  perdida_ha: number;
  ganancia_ha: number;
  altura_mediana_m: number;
  carbono_t: number;
}

export const FUENTE_WORKFLOW = 'Workflow de monitoreo del manglar de la C.R.A. (manglarcra.netlify.app), actualización 2025–2026';

// Zona del workflow de la C.R.A. → sector de esta web (los polígonos de poligonosManglar.json).
// La zona 3 (Tubará – Juan de Acosta) es el sector «Manatíes»: correspondencia por confirmar con la C.R.A.
const SECTOR_POR_ZONA: Record<SectorCRA['zona'], { id: SectorWorkflowId; nombre: string }> = {
  1: { id: 'mallorquin', nombre: 'Mallorquín' },
  2: { id: 'balboa', nombre: 'Balboa' },
  3: { id: 'manaties', nombre: 'Manatíes' },
  4: { id: 'totumo', nombre: 'Totumo' },
};

export const RESPALDO_CRA: ResumenCRA = {
  sectores: [
    { zona: 1, sector: 'Mallorquín – Bocas de Ceniza', referencia_ha: 347.6, segura_ha: 261.7, media_ha: 85.9, intermedia_ha: 168.3, perdida_ha: 36.4, ganancia_ha: 1.5, altura_mediana_m: 11.4, dosel_seco_ha: 106.1, riesgo_medio: 0.383, riesgo_muy_alto_ha: 79.2, carbono_t: 70659 },
    { zona: 2, sector: 'Puerto Colombia – Balboa – Puerto Velero', referencia_ha: 91.4, segura_ha: 59.7, media_ha: 31.6, intermedia_ha: 105.8, perdida_ha: 0, ganancia_ha: 0, altura_mediana_m: 11.1, dosel_seco_ha: 47.4, riesgo_medio: 0.418, riesgo_muy_alto_ha: 30.3, carbono_t: 16119 },
    { zona: 3, sector: 'Tubará – Juan de Acosta', referencia_ha: 45.4, segura_ha: 26.9, media_ha: 18.5, intermedia_ha: 102.3, perdida_ha: 0.2, ganancia_ha: 0.4, altura_mediana_m: 11, dosel_seco_ha: 36.7, riesgo_medio: 0.436, riesgo_muy_alto_ha: 19, carbono_t: 7263 },
    { zona: 4, sector: 'Totumo – Astilleros – Galerazamba', referencia_ha: 290.5, segura_ha: 116.4, media_ha: 174.1, intermedia_ha: 451.8, perdida_ha: 0, ganancia_ha: 0, altura_mediana_m: 9.8, dosel_seco_ha: 71.8, riesgo_medio: 0.331, riesgo_muy_alto_ha: 65.3, carbono_t: 31428 },
  ],
  altura_mediana_m: 10.7,
  carbono_t: 125000,
  carbono_t_ha: 270,
  carbono_suelo_t_ha: 248,
  area_anual: [[2016, 800.6], [2025, 774.8]],
  agua: [
    { cienaga: 'Ciénaga del Totumo', mediana_ha: 1371.5 }, { cienaga: 'Ciénaga de Mallorquín', mediana_ha: 816.9 },
    { cienaga: 'Ciénaga de Balboa', mediana_ha: 146.8 }, { cienaga: 'Ciénaga Manatíes', mediana_ha: 30.9 }, { cienaga: 'Ciénaga El Salado', mediana_ha: 1.8 },
  ],
  audio: {},
};

export interface CifrasWorkflow {
  manglar_probable_ha: number; prob_alta_ha: number; prob_media_ha: number; por_revisar_ha: number;
  perdida_ha: number; ganancia_ha: number; perdida_ha_2016_2025: number; dosel_seco_2026_ha: number;
  altura_mediana_m: number; riesgo_muy_alto_ha: number; carbono_total_t: number; carbono_t_c_ha: number;
  carbono_suelo_pct: number; invemar_ha: number; invemar_poligonos: number;
}

export interface PestanaWorkflow {
  id: string; etiqueta: string; titulo: string; resumen: string;
  cifras: { valor: string; unidad: string; etiqueta: string }[];
  puntos: string[];
  capa: 'invemar' | 'sectores' | 'pendiente';
  color?: 'capa-manglar' | 'capa-dosel' | 'capa-agua' | 'capa-recuperacion' | 'capa-riesgo';
  fuente: string;
  audio?: AudioCRA;
}

export interface Workflow { cifras: CifrasWorkflow; sectores: SectorWorkflow[]; pestanas: PestanaWorkflow[] }

const suma = (s: SectorCRA[], k: keyof SectorCRA) => s.reduce((t, x) => t + Number(x[k]), 0);
const r1 = (n: number) => Math.round(n * 10) / 10;
const es = (n: number, decimales = 0) => n.toLocaleString('es-CO', { maximumFractionDigits: decimales }).replace('-', '−');
const cifra = (valor: number, unidad: string, etiqueta: string, decimales = 0) => ({ valor: es(valor, decimales), unidad, etiqueta });
const miles = (t: number) => `${es(Math.round(t / 1000))} mil`;

/** Arma cifras, sectores y pestañas a partir del resumen de la C.R.A. */
export function construirWorkflow(c: ResumenCRA): Workflow {
  const s = c.sectores;
  const sectores: SectorWorkflow[] = s.map((x) => ({
    ...SECTOR_POR_ZONA[x.zona], nombre_cra: x.sector,
    total_ha: Math.round(x.referencia_ha + x.intermedia_ha), probable_ha: Math.round(x.referencia_ha),
    prob_alta_ha: r1(x.segura_ha), por_revisar_ha: Math.round(x.intermedia_ha), dosel_seco_ha: Math.round(x.dosel_seco_ha),
    riesgo_medio: Math.round(x.riesgo_medio * 100) / 100, riesgo_muy_alto_ha: r1(x.riesgo_muy_alto_ha),
    perdida_ha: r1(x.perdida_ha), ganancia_ha: r1(x.ganancia_ha), altura_mediana_m: x.altura_mediana_m, carbono_t: x.carbono_t,
  }));
  const perdida = suma(s, 'perdida_ha');
  const ganancia = suma(s, 'ganancia_ha');
  const cifras: CifrasWorkflow = {
    manglar_probable_ha: Math.round(suma(s, 'referencia_ha')), prob_alta_ha: Math.round(suma(s, 'segura_ha')),
    prob_media_ha: Math.round(suma(s, 'media_ha')), por_revisar_ha: Math.round(suma(s, 'intermedia_ha')),
    perdida_ha: r1(perdida), ganancia_ha: r1(ganancia), perdida_ha_2016_2025: r1(ganancia - perdida),
    dosel_seco_2026_ha: Math.round(suma(s, 'dosel_seco_ha')),
    altura_mediana_m: Number.isFinite(c.altura_mediana_m) ? c.altura_mediana_m : RESPALDO_CRA.altura_mediana_m,
    riesgo_muy_alto_ha: Math.round(suma(s, 'riesgo_muy_alto_ha')), carbono_total_t: c.carbono_t, carbono_t_c_ha: c.carbono_t_ha,
    carbono_suelo_pct: Math.round(c.carbono_suelo_t_ha / c.carbono_t_ha * 100), invemar_ha: 533, invemar_poligonos: 144,
  };
  const total = sectores.reduce((t, x) => t + x.total_ha, 0);
  const lista = (f: (x: SectorWorkflow) => string) => sectores.map(f).join('; ') + '.';
  const primerAnio = c.area_anual[0];
  const ultimoAnio = c.area_anual.at(-1);
  const audio = (clave: string) => c.audio[clave];

  const pestanas: PestanaWorkflow[] = [
    {
      id: 'sintesis', etiqueta: 'Síntesis', titulo: 'El manglar en cifras',
      resumen: `Se estiman ${es(cifras.manglar_probable_ha)} ha de manglar probable y ${es(cifras.por_revisar_ha)} ha por revisar en cuatro sectores del Atlántico.`,
      cifras: [cifra(cifras.manglar_probable_ha, 'ha', 'Manglar probable'), cifra(cifras.por_revisar_ha, 'ha', 'Por revisar'), cifra(cifras.perdida_ha_2016_2025, 'ha', 'Cambio neto · 2016–2025', 1), cifra(cifras.dosel_seco_2026_ha, 'ha', 'Dosel más seco · 2026'), cifra(cifras.riesgo_muy_alto_ha, 'ha', 'Riesgo muy alto'), { valor: miles(cifras.carbono_total_t), unidad: 't de carbono', etiqueta: 'Carbono total' }],
      puntos: [`Manglar probable: ${es(cifras.prob_alta_ha)} ha con probabilidad alta y ${es(cifras.prob_media_ha)} ha con probabilidad media.`, `Los cuatro sectores suman ${es(total)} ha: ${es(cifras.manglar_probable_ha)} ha probables + ${es(cifras.por_revisar_ha)} ha por revisar.`, 'Los límites sectoriales son aproximados; la correspondencia de Manatíes (Tubará – Juan de Acosta) requiere confirmación de la C.R.A.'],
      capa: 'sectores', color: 'capa-manglar', fuente: FUENTE_WORKFLOW, audio: audio('sin'),
    },
    {
      id: 'extension', etiqueta: 'Extensión', titulo: 'Extensión probable',
      resumen: 'La estimación distingue probabilidad alta y media de las superficies que todavía requieren revisión.',
      cifras: [cifra(cifras.prob_alta_ha, 'ha', 'Probabilidad alta'), cifra(cifras.prob_media_ha, 'ha', 'Probabilidad media'), cifra(cifras.por_revisar_ha, 'ha', 'Por revisar'), cifra(cifras.invemar_ha, 'ha', 'Referencia INVEMAR · 2020'), cifra(cifras.invemar_poligonos, 'polígonos', 'Referencia INVEMAR')],
      puntos: [`Probable y por revisar, por sector: ${lista((x) => `${x.nombre} ${es(x.probable_ha)} ha y ${es(x.por_revisar_ha)} ha`)}`, 'INVEMAR 2020: escala 1:25.000. Sus 533 ha difieren de las ha probables por la fecha y el método; no son capas equivalentes.', 'La capa de manglar probable de la C.R.A. se cargará desde su KMZ.'],
      capa: 'invemar', color: 'capa-manglar', fuente: `${FUENTE_WORKFLOW}; Capa Nacional de Manglares INVEMAR 2020`, audio: audio('ext'),
    },
    {
      id: 'cambios', etiqueta: 'Cambios', titulo: 'Cambios que persisten',
      resumen: `Entre 2016 y 2025 se confirmaron ${es(cifras.perdida_ha, 1)} ha de pérdida y ${es(cifras.ganancia_ha, 1)} ha de ganancia: un cambio neto de ${es(cifras.perdida_ha_2016_2025, 1)} ha.`,
      cifras: [cifra(cifras.perdida_ha_2016_2025, 'ha', 'Cambio neto · 2016–2025', 1), cifra(cifras.perdida_ha, 'ha', 'Pérdida confirmada', 1), cifra(cifras.ganancia_ha, 'ha', 'Ganancia confirmada', 1)],
      puntos: [
        `Por sector (pérdida / ganancia): ${lista((x) => `${x.nombre} ${es(x.perdida_ha, 1)} / ${es(x.ganancia_ha, 1)} ha`)}`,
        ...(primerAnio && ultimoAnio && primerAnio !== ultimoAnio ? [`Área de referencia anual: ${es(primerAnio[1], 1)} ha en ${primerAnio[0]} y ${es(ultimoAnio[1], 1)} ha en ${ultimoAnio[0]}.`] : []),
        'Los cambios se confirman mediante una regla de persistencia.', 'Cada actualización trimestral es provisional hasta confirmarse.',
      ],
      capa: 'pendiente', color: 'capa-recuperacion', fuente: FUENTE_WORKFLOW, audio: audio('cam'),
    },
    {
      id: 'dosel', etiqueta: 'Dosel 2026', titulo: 'Un dosel más seco',
      resumen: `El workflow identifica ${es(cifras.dosel_seco_2026_ha)} ha con el dosel claramente más seco en 2026 que en 2024 y 2025.`,
      cifras: [cifra(cifras.dosel_seco_2026_ha, 'ha', 'Dosel más seco · 2026'), ...sectores.map((x) => cifra(x.dosel_seco_ha, 'ha', x.nombre))],
      puntos: ['La señal de dosel seco requiere interpretación y verificación en campo; no equivale por sí sola a pérdida de manglar.'],
      capa: 'pendiente', color: 'capa-dosel', fuente: FUENTE_WORKFLOW, audio: audio('dos'),
    },
    {
      id: 'altura', etiqueta: 'Altura', titulo: 'La estructura del dosel',
      resumen: `La altura mediana estimada del dosel es de ${es(cifras.altura_mediana_m, 1)} m.`,
      cifras: [cifra(cifras.altura_mediana_m, 'm', 'Altura mediana', 1), ...sectores.map((x) => cifra(x.altura_mediana_m, 'm', x.nombre, 1))],
      puntos: ['Mapa global de altura de dosel 2020: Sentinel-2 calibrado con láser espacial, resolución de 10 m.', 'TanDEM-X 2015 (12 m) y NASADEM (30 m) complementan los insumos.', 'Biomasa = 1,4179 × (0,6337 × altura)^1,6038 (Simard y colaboradores, 2019).'],
      capa: 'pendiente', color: 'capa-dosel', fuente: `${FUENTE_WORKFLOW}; mapa global de altura de dosel 2020; TanDEM-X 2015; NASADEM; Simard et al. 2019`, audio: audio('alt'),
    },
    {
      id: 'agua', etiqueta: 'Agua', titulo: 'El agua conecta el manglar',
      resumen: 'Espejo de agua mediano de cada ciénaga en la serie trimestral de Sentinel-2 (2015–2026).',
      cifras: c.agua.slice(0, 4).map((a) => cifra(a.mediana_ha, 'ha', a.cienaga.replace(/^Ciénaga (de |del )?/, ''))),
      puntos: ['Un píxel cuenta como agua cuando el índice de agua de Sentinel-2 es mayor que cero.', 'La conexión hídrica de los caños ayuda a comprender el estado del manglar.'],
      capa: 'pendiente', color: 'capa-agua', fuente: FUENTE_WORKFLOW, audio: audio('agu'),
    },
    {
      id: 'presion', etiqueta: 'Presión', titulo: 'Presión y riesgo',
      resumen: `El workflow estima ${es(cifras.riesgo_muy_alto_ha)} ha en riesgo muy alto.`,
      cifras: [cifra(cifras.riesgo_muy_alto_ha, 'ha', 'Riesgo muy alto'), ...sectores.map((x) => cifra(x.riesgo_medio, 'índice 0–1', `Riesgo medio · ${x.nombre}`, 2))],
      puntos: ['La presión antrópica incluye rellenos, expansión urbana, vías y vertimientos.', `Riesgo muy alto por sector: ${lista((x) => `${x.nombre} ${es(x.riesgo_muy_alto_ha, 1)} ha`)}`, 'El riesgo orienta la revisión y las prioridades de conservación.'],
      capa: 'pendiente', color: 'capa-riesgo', fuente: FUENTE_WORKFLOW, audio: audio('pre'),
    },
    {
      id: 'carbono', etiqueta: 'Carbono', titulo: 'El carbono también está en el suelo',
      resumen: `Se estiman ${miles(cifras.carbono_total_t)} toneladas de carbono, con un valor central de ${es(cifras.carbono_t_c_ha)} t C/ha.`,
      cifras: [{ valor: miles(cifras.carbono_total_t), unidad: 't de carbono', etiqueta: 'Carbono total' }, cifra(cifras.carbono_t_c_ha, 't C/ha', 'Valor central'), cifra(cifras.carbono_suelo_pct, '%', 'En el suelo')],
      puntos: [`El ${es(cifras.carbono_suelo_pct)} % del carbono está en el suelo: conservar el suelo del manglar importa tanto como conservar los árboles.`, `Por sector: ${lista((x) => `${x.nombre} ${miles(x.carbono_t)} t`)}`],
      capa: 'pendiente', fuente: FUENTE_WORKFLOW, audio: audio('car'),
    },
    {
      id: 'metodo', etiqueta: 'Método', titulo: 'Del insumo a la revisión',
      resumen: 'El monitoreo integra 9 capas y 18 pasos, con actualización trimestral mediante nuevas imágenes Sentinel-2.',
      cifras: [cifra(9, 'capas', 'Monitoreo'), cifra(18, 'pasos', 'Proceso metodológico')],
      puntos: ['Literatura e insumos; versiones 1–3; muestra, clasificador y umbrales.', 'Delimitación, cambios, dosel, altura y agua.', 'Presión y riesgo, carbono, equivalencias, revisión crítica y pendientes.', 'Las actualizaciones trimestrales son provisionales hasta confirmar la persistencia de los cambios.'],
      capa: 'sectores', fuente: FUENTE_WORKFLOW, audio: audio('met'),
    },
    {
      id: 'fuentes', etiqueta: 'Fuentes', titulo: 'Datos y referencias',
      resumen: 'El workflow combina observación satelital, inventarios y planificación territorial.',
      cifras: [], puntos: ['Sentinel-2 (programa Copernicus) y radar.', 'Mapa global de altura de dosel 2020; TanDEM-X 2015; NASADEM.', 'Simard et al. 2019 e inventario IDEAM 2021.', 'Plan de manejo de la C.R.A. y Capa Nacional de Manglares INVEMAR 2020.', 'OpenStreetMap: cartografía base.'],
      capa: 'invemar', fuente: FUENTE_WORKFLOW, audio: audio('fue'),
    },
  ];
  return { cifras, sectores, pestanas };
}

export const RESPALDO_WORKFLOW = construirWorkflow(RESPALDO_CRA);
// Valores fijos para lo que se calcula fuera de React (plantillas, alertas del panel).
export const CIFRAS = RESPALDO_WORKFLOW.cifras;
export const SECTORES_WORKFLOW = RESPALDO_WORKFLOW.sectores;
export const PESTANAS_WORKFLOW = RESPALDO_WORKFLOW.pestanas;
