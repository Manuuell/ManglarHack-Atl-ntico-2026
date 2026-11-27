// Datos del workflow de la C.R.A. (manglarcra.netlify.app), leídos de la copia
// que la web sirve en /cra/. La copia la mantiene scripts/copiar-cra.mjs: en el
// build (public/cra) y en el VPS cada 15 minutos (/var/www/mimanglar/cra), así
// que cuando la C.R.A. actualiza su workflow, esta web se actualiza sola.
// Si la copia no responde, la web usa las cifras de respaldo de workflow.ts.

export const RUTA_CRA = '/cra/';
export const ORIGEN_CRA = 'https://manglarcra.netlify.app/';

export interface AudioCRA { src: string; dur: number; txt: string }

/** Lo que la web usa del core.json de la C.R.A., ya resumido. */
export interface SectorCRA {
  zona: 1 | 2 | 3 | 4;
  sector: string;
  referencia_ha: number; // manglar probable
  segura_ha: number; // probabilidad alta
  media_ha: number; // probabilidad media
  intermedia_ha: number; // por revisar
  perdida_ha: number;
  ganancia_ha: number;
  altura_mediana_m: number;
  dosel_seco_ha: number;
  riesgo_medio: number;
  riesgo_muy_alto_ha: number;
  carbono_t: number;
}

export interface ResumenCRA {
  sectores: SectorCRA[];
  altura_mediana_m: number;
  carbono_t: number;
  carbono_t_ha: number;
  carbono_suelo_t_ha: number;
  area_anual: [number, number][];
  agua: { cienaga: string; mediana_ha: number }[];
  audio: Record<string, AudioCRA>;
}

export interface EspejoCRA { origen: string; revisado_en: string; actualizado_en: string }

const numero = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);
const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;
const RUTA_AUDIO = /^audio\/[a-z0-9_-]+\.mp3$/i;

function porZona(lista: unknown, zona: number): Record<string, unknown> {
  const fila = Array.isArray(lista) ? lista.find((s) => objeto(s) && Number(s.zona ?? s.k) === zona) : undefined;
  if (!objeto(fila)) throw new Error(`Falta la zona ${zona}`);
  return fila;
}
function num(fila: Record<string, unknown>, clave: string): number {
  const v = fila[clave];
  if (!numero(v)) throw new Error(`Falta ${clave}`);
  return v;
}
function mediana(valores: number[]): number {
  const v = [...valores].sort((a, b) => a - b);
  const m = Math.floor(v.length / 2);
  return v.length % 2 ? v[m]! : (v[m - 1]! + v[m]!) / 2;
}

/** Convierte el core.json de la C.R.A. en el resumen que usa la web. Lanza si cambió de forma. */
export function resumirCore(core: unknown): ResumenCRA {
  if (!objeto(core) || !Array.isArray(core.resumen) || !objeto(core.seco) || !objeto(core.riesgo) || !objeto(core.carb)) throw new Error('core.json con otra forma');
  const carb = core.carb;
  const sectores = ([1, 2, 3, 4] as const).map((zona): SectorCRA => {
    const r = porZona(core.resumen, zona);
    const s = porZona((core.seco as Record<string, unknown>).sect, zona);
    const q = porZona((core.riesgo as Record<string, unknown>).sect, zona);
    const c = porZona(carb.sect, zona);
    return {
      zona, sector: String(r.sector ?? ''),
      referencia_ha: num(r, 'referencia_ha'), segura_ha: num(r, 'segura_ha'), media_ha: num(r, 'media_ha'),
      intermedia_ha: num(r, 'intermedia_ha'), perdida_ha: num(r, 'perdida_ha'), ganancia_ha: num(r, 'ganancia_ha'),
      altura_mediana_m: num(r, 'altura_mediana_m'), dosel_seco_ha: num(s, 'ha_seco_010'),
      riesgo_medio: num(q, 'riesgo_medio'), riesgo_muy_alto_ha: num(q, 'ha_muy_alto'), carbono_t: num(c, 'tC'),
    };
  });

  const audio: Record<string, AudioCRA> = {};
  if (objeto(core.audio)) for (const [clave, a] of Object.entries(core.audio)) {
    if (objeto(a) && typeof a.src === 'string' && RUTA_AUDIO.test(a.src) && numero(a.dur) && typeof a.txt === 'string') audio[clave] = { src: RUTA_CRA + a.src, dur: a.dur, txt: a.txt };
  }

  // Espejo de agua: mediana de la serie trimestral por ciénaga ([trimestre, ciénaga, ha, …]).
  const porCienaga = new Map<string, number[]>();
  if (Array.isArray(core.t_agua)) for (const fila of core.t_agua) {
    if (Array.isArray(fila) && typeof fila[1] === 'string' && numero(fila[2])) porCienaga.set(fila[1], [...(porCienaga.get(fila[1]) ?? []), fila[2]]);
  }
  const agua = [...porCienaga].map(([cienaga, v]) => ({ cienaga, mediana_ha: mediana(v) })).sort((a, b) => b.mediana_ha - a.mediana_ha);

  const area_anual = Array.isArray(core.t_area) ? core.t_area.filter((f): f is [number, number] => Array.isArray(f) && numero(f[0]) && numero(f[1])) : [];
  // La altura del conjunto solo viene en el texto de la pestaña; si no aparece, se usa la del respaldo.
  const altura = /altura mediana del dosel es de ([\d]+(?:,\d+)?) metros/i.exec(audio.alt?.txt ?? '')?.[1];
  const comp = objeto(carb.comp) ? carb.comp : {};

  return {
    sectores,
    altura_mediana_m: altura ? Number(altura.replace(',', '.')) : NaN,
    carbono_t: num(carb, 'reserva_tC'),
    carbono_t_ha: num(carb, 'c_ha'),
    carbono_suelo_t_ha: num(comp, 'suelo'),
    area_anual,
    agua,
    audio,
  };
}

let carga: Promise<{ resumen: ResumenCRA; espejo: EspejoCRA | null }> | null = null;

/** Lee la copia de /cra/ una sola vez por página. */
export function cargarCRA() {
  carga ??= (async () => {
    const [respuesta, espejo] = await Promise.all([
      fetch(`${RUTA_CRA}data/core.json`),
      fetch(`${RUTA_CRA}espejo.json`).then((r) => (r.ok ? r.json() : null)).catch(() => null),
    ]);
    if (!respuesta.ok) throw new Error(`HTTP ${respuesta.status}`);
    const resumen = resumirCore(await respuesta.json());
    const valido = objeto(espejo) && typeof espejo.revisado_en === 'string' && typeof espejo.actualizado_en === 'string';
    return { resumen, espejo: valido ? (espejo as unknown as EspejoCRA) : null };
  })();
  carga.catch(() => { carga = null; });
  return carga;
}

export function fechaCRA(iso: string) {
  return new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
}
