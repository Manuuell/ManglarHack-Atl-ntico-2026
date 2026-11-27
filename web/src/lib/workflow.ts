export type SectorWorkflowId = 'mallorquin' | 'balboa' | 'manaties' | 'totumo';

export interface SectorWorkflow {
  id: SectorWorkflowId;
  nombre: string;
  total_ha: number;
  probable_ha: number | null;
  por_revisar_ha: number | null;
  dosel_seco_ha: number | null;
  riesgo_medio: number | null;
}

export const FUENTE_WORKFLOW = 'Workflow de monitoreo del manglar de la C.R.A. (manglarcra.netlify.app), actualización 2025–2026';

// Total sectorial = manglar probable + superficie por revisar; no es manglar confirmado.
export const SECTORES_WORKFLOW: SectorWorkflow[] = [
  { id: 'mallorquin', nombre: 'Mallorquín', total_ha: 516, probable_ha: 348, por_revisar_ha: 168, dosel_seco_ha: 106, riesgo_medio: 0.38 },
  { id: 'balboa', nombre: 'Balboa', total_ha: 197, probable_ha: null, por_revisar_ha: null, dosel_seco_ha: null, riesgo_medio: null },
  { id: 'totumo', nombre: 'Totumo', total_ha: 148, probable_ha: null, por_revisar_ha: null, dosel_seco_ha: null, riesgo_medio: null },
  { id: 'manaties', nombre: 'Manatíes', total_ha: 742, probable_ha: null, por_revisar_ha: null, dosel_seco_ha: null, riesgo_medio: null },
];

export const CIFRAS = {
  manglar_probable_ha: 775, prob_alta_ha: 465, prob_media_ha: 310,
  por_revisar_ha: 828, perdida_ha_2016_2025: -34.7, dosel_seco_2026_ha: 262,
  altura_mediana_m: 10.7, riesgo_muy_alto_ha: 194, carbono_total_t: 125000,
  carbono_t_c_ha: 270, carbono_suelo_pct: 92, invemar_ha: 533, invemar_poligonos: 144,
} as const;

interface PestanaWorkflow {
  id: string; etiqueta: string; titulo: string; resumen: string;
  cifras: { valor: string; unidad: string; etiqueta: string }[];
  puntos: string[];
  capa: 'invemar' | 'sectores' | 'pendiente';
  color?: 'capa-manglar' | 'capa-dosel' | 'capa-agua' | 'capa-recuperacion' | 'capa-riesgo';
  fuente: string;
}

const cifra = (valor: number, unidad: string, etiqueta: string) => ({
  valor: valor.toLocaleString('es-CO').replace('-', '−'), unidad, etiqueta,
});

export const PESTANAS_WORKFLOW: PestanaWorkflow[] = [
  {
    id: 'sintesis', etiqueta: 'Síntesis', titulo: 'El manglar en cifras',
    resumen: 'En 2025 se estiman 775 ha de manglar probable y 828 ha por revisar en cuatro sectores del Atlántico.',
    cifras: [cifra(CIFRAS.manglar_probable_ha, 'ha', 'Manglar probable · 2025'), cifra(CIFRAS.por_revisar_ha, 'ha', 'Por revisar'), cifra(CIFRAS.perdida_ha_2016_2025, 'ha', 'Pérdida neta · 2016–2025'), cifra(CIFRAS.dosel_seco_2026_ha, 'ha', 'Dosel más seco · 2026'), cifra(CIFRAS.riesgo_muy_alto_ha, 'ha', 'Riesgo muy alto'), { valor: '125 mil', unidad: 't de carbono', etiqueta: 'Carbono total' }],
    puntos: ['Manglar probable: 465 ha con probabilidad alta y 310 ha con probabilidad media.', 'Mallorquín, Balboa, Totumo y Manatíes suman 1.603 ha: 775 ha probables + 828 ha por revisar.', 'Los límites sectoriales son aproximados; la correspondencia de Manatíes requiere confirmación de la C.R.A.'],
    capa: 'sectores', color: 'capa-manglar', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'extension', etiqueta: 'Extensión', titulo: 'Extensión probable en 2025',
    resumen: 'La estimación distingue probabilidad alta y media de las superficies que todavía requieren revisión.',
    cifras: [cifra(CIFRAS.prob_alta_ha, 'ha', 'Probabilidad alta'), cifra(CIFRAS.prob_media_ha, 'ha', 'Probabilidad media'), cifra(CIFRAS.por_revisar_ha, 'ha', 'Por revisar'), cifra(CIFRAS.invemar_ha, 'ha', 'Referencia INVEMAR · 2020'), cifra(CIFRAS.invemar_poligonos, 'polígonos', 'Referencia INVEMAR')],
    puntos: ['Total probable + por revisar: Mallorquín 516 ha, Balboa 197 ha, Totumo 148 ha y Manatíes 742 ha.', 'Mallorquín: 348 ha probables y 168 ha por revisar. No se publica aquí el desglose de los demás sectores.', 'INVEMAR 2020: escala 1:25.000. Sus 533 ha difieren de las 775 ha probables por la fecha y el método; no son capas equivalentes.', 'La capa de manglar probable de la C.R.A. se cargará desde su KMZ.'],
    capa: 'invemar', color: 'capa-manglar', fuente: `${FUENTE_WORKFLOW}; Capa Nacional de Manglares INVEMAR 2020`,
  },
  {
    id: 'cambios', etiqueta: 'Cambios', titulo: 'Cambios que persisten',
    resumen: 'La pérdida neta entre 2016 y 2025 es de −34,7 ha.',
    cifras: [cifra(CIFRAS.perdida_ha_2016_2025, 'ha', 'Cambio neto · 2016–2025')],
    puntos: ['Los cambios se confirman mediante una regla de persistencia.', 'Cada actualización trimestral es provisional hasta confirmarse.'],
    capa: 'pendiente', color: 'capa-recuperacion', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'dosel', etiqueta: 'Dosel 2026', titulo: 'Un dosel más seco',
    resumen: 'El workflow identifica 262 ha con dosel más seco en 2026, año El Niño.',
    cifras: [cifra(CIFRAS.dosel_seco_2026_ha, 'ha', 'Dosel más seco · 2026'), cifra(106, 'ha', 'Dosel más seco · Mallorquín')],
    puntos: ['La señal de dosel seco requiere interpretación y verificación en campo; no equivale por sí sola a pérdida de manglar.'],
    capa: 'pendiente', color: 'capa-dosel', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'altura', etiqueta: 'Altura', titulo: 'La estructura del dosel',
    resumen: 'La altura mediana estimada del dosel es de 10,7 m.',
    cifras: [cifra(CIFRAS.altura_mediana_m, 'm', 'Altura mediana')],
    puntos: ['Mapa global de altura de dosel 2020: Sentinel-2 calibrado con láser espacial, resolución de 10 m.', 'TanDEM-X 2015 (12 m) y NASADEM (30 m) complementan los insumos.', 'Biomasa = 1,4179 × (0,6337 × altura)^1,6038 (Simard y colaboradores, 2019).'],
    capa: 'pendiente', color: 'capa-dosel', fuente: `${FUENTE_WORKFLOW}; mapa global de altura de dosel 2020; TanDEM-X 2015; NASADEM; Simard et al. 2019`,
  },
  {
    id: 'agua', etiqueta: 'Agua', titulo: 'El agua conecta el manglar',
    resumen: 'La conexión hídrica de los caños y la frecuencia de agua superficial ayudan a comprender el estado del manglar.',
    cifras: [], puntos: ['No hay una cifra publicada aquí.', 'Capa espacial pendiente del GeoJSON de la C.R.A.'],
    capa: 'pendiente', color: 'capa-agua', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'presion', etiqueta: 'Presión', titulo: 'Presión y riesgo',
    resumen: 'El workflow estima 194 ha en riesgo muy alto.',
    cifras: [cifra(CIFRAS.riesgo_muy_alto_ha, 'ha', 'Riesgo muy alto'), cifra(0.38, 'índice', 'Riesgo medio · Mallorquín')],
    puntos: ['La presión antrópica incluye rellenos, expansión urbana, vías y vertimientos.', 'El riesgo orienta la revisión y las prioridades de conservación.'],
    capa: 'pendiente', color: 'capa-riesgo', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'carbono', etiqueta: 'Carbono', titulo: 'El carbono también está en el suelo',
    resumen: 'Se estiman 125 mil toneladas de carbono, con un valor central de 270 t C/ha.',
    cifras: [{ valor: '125 mil', unidad: 't de carbono', etiqueta: 'Carbono total' }, cifra(CIFRAS.carbono_t_c_ha, 't C/ha', 'Valor central'), cifra(CIFRAS.carbono_suelo_pct, '%', 'En el suelo')],
    puntos: ['El 92 % del carbono está en el suelo: conservar el suelo del manglar importa tanto como conservar los árboles.'],
    capa: 'pendiente', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'metodo', etiqueta: 'Método', titulo: 'Del insumo a la revisión',
    resumen: 'El monitoreo integra 9 capas y 18 pasos, con actualización trimestral mediante nuevas imágenes Sentinel-2.',
    cifras: [cifra(9, 'capas', 'Monitoreo'), cifra(18, 'pasos', 'Proceso metodológico')],
    puntos: ['Literatura e insumos; versiones 1–3; muestra, clasificador y umbrales.', 'Delimitación, cambios, dosel, altura y agua.', 'Presión y riesgo, carbono, equivalencias, revisión crítica y pendientes.', 'Las actualizaciones trimestrales son provisionales hasta confirmar la persistencia de los cambios.'],
    capa: 'sectores', fuente: FUENTE_WORKFLOW,
  },
  {
    id: 'fuentes', etiqueta: 'Fuentes', titulo: 'Datos y referencias',
    resumen: 'El workflow combina observación satelital, inventarios y planificación territorial.',
    cifras: [], puntos: ['Sentinel-2 (programa Copernicus) y radar.', 'Mapa global de altura de dosel 2020; TanDEM-X 2015; NASADEM.', 'Simard et al. 2019 e inventario IDEAM 2021.', 'Plan de manejo de la C.R.A. y Capa Nacional de Manglares INVEMAR 2020.', 'OpenStreetMap: cartografía base.'],
    capa: 'invemar', fuente: FUENTE_WORKFLOW,
  },
];
