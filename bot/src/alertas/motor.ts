import { ubicar } from '../geo/zonas';
import {
  comunidadActiva, estacionesIdeam, EventoMarea, FocoCalor, focosCra, FUENTES, HoraPronostico, IdFuente, lecturasIdeam,
  Lectura, mareasDimar, pronosticoDimar, ReportePublico, reportesRecientes,
} from './fuentes';

/**
 * Motor de alertas del manglar. Cada 10 minutos lee las fuentes públicas, cruza lo que miden las estaciones,
 * lo que pronostica DIMAR y lo que reporta la comunidad, y dice qué calamidad se está presentando o viene,
 * dónde, cuándo y qué hacer. Los umbrales están todos en UMBRALES: son de trabajo y se ajustan con la C.R.A.
 */

export type Nivel = 'amarilla' | 'naranja' | 'roja';
export type TipoAlerta =
  | 'mar_de_leva' | 'inundacion_costera' | 'lluvia_fuerte' | 'vendaval' | 'riesgo_incendio' | 'foco_calor' | 'amenaza_ciudadana';

export interface Alerta {
  id: string;
  tipo: TipoAlerta;
  nivel: Nivel;
  titulo: string;
  /** Qué pasa, con las cifras. */
  detalle: string;
  /** Qué hacer. */
  recomendacion: string;
  lugar: string;
  lat: number;
  lon: number;
  desde: string;
  hasta: string;
  /** true si lo midió una estación o un satélite; false si es pronóstico. */
  medido: boolean;
  valor?: number;
  unidad?: string;
  umbral?: number;
  fuentes: IdFuente[];
}

export interface EstadoFuente {
  id: IdFuente;
  nombre: string;
  url: string;
  ok: boolean;
  error?: string;
}

export interface ResultadoAlertas {
  generado: string;
  simulacro: boolean;
  nivel_maximo: Nivel | null;
  alertas: Alerta[];
  /** Lo que se está midiendo y pronosticando ahora, haya alerta o no. */
  ahora: {
    lluvia_hora_mm: number | null;
    lluvia_24h_mm: number | null;
    lluvia_estacion: string | null;
    viento_ms: number | null;
    viento_estacion: string | null;
    temperatura_c: number | null;
    ola_max_m: number | null;
    ola_cuando: string | null;
    ola_lugar: string | null;
    proxima_pleamar: { t: string; m: number } | null;
    temp_max_pronostico_c: number | null;
    reportes_72h: number | null;
  };
  fuentes: EstadoFuente[];
  umbrales: typeof UMBRALES;
  nota: string;
}

export const UMBRALES = {
  /** Altura de ola pronosticada frente a la costa (m): amarilla, naranja, roja. */
  ola_m: [2.0, 2.5, 3.0],
  /** Pleamar que, junto con oleaje de alerta en ±3 h, se suma a la inundación de la orilla. */
  pleamar_m: 0.9,
  ventana_marea_h: 3,
  /** Lluvia medida en una hora y en 24 h (mm). */
  lluvia_1h_mm: [15, 30, 50],
  lluvia_24h_mm: [40, 70, 100],
  /** Lluvia pronosticada en 24 h (mm). */
  lluvia_pronostico_24h_mm: [30, 50, 80],
  /** Viento medido (m/s, Beaufort 6, 7 y 8). */
  viento_ms: [10.8, 13.9, 17.2],
  /** Viento pronosticado (m/s): un escalón más alto, porque el modelo suele exagerar en tierra. */
  viento_pronostico_ms: [13.9, 17.2, 20.8],
  /** Horas de calor seco con brisa que vuelven fácil que una quema se salga de control. */
  incendio: { temperatura_c: 32, humedad_max_pct: 60, viento_ms: 6, horas_minimas: 3, lluvia_72h_max_mm: 1 },
  /** Reportes de la misma amenaza en la misma zona en 72 h. */
  reportes_misma_zona: [2, 4, 6],
  horas_reportes: 72,
  /** Focos de calor por satélite a esta distancia del manglar y de estos días. */
  foco_distancia_m: 2000,
  foco_dias: 7,
};

const ORDEN: Record<Nivel, number> = { amarilla: 1, naranja: 2, roja: 3 };
const NIVELES: Nivel[] = ['amarilla', 'naranja', 'roja'];

function nivelPor(valor: number, cortes: number[]): Nivel | null {
  let n: Nivel | null = null;
  cortes.forEach((c, i) => { if (valor >= c) n = NIVELES[i]; });
  return n;
}
const peor = (a: Nivel | null, b: Nivel | null): Nivel | null => (!a ? b : !b ? a : ORDEN[b] > ORDEN[a] ? b : a);
const subir = (n: Nivel): Nivel => NIVELES[Math.min(2, ORDEN[n])];

/** Sectores de manglar: un punto en tierra (lluvia, viento, calor) y uno en el mar frente a la costa (oleaje). */
const SECTORES = [
  { id: 'mallorquin', nombre: 'Ciénaga de Mallorquín', tierra: [11.025, -74.86], mar: [11.1, -74.9] },
  { id: 'puerto_colombia', nombre: 'Puerto Colombia y Balboa', tierra: [10.99, -74.955], mar: [11.06, -74.97] },
  { id: 'tubara', nombre: 'Costa de Tubará y Juan de Acosta', tierra: [10.93, -75.05], mar: [11.0, -75.05] },
  { id: 'totumo', nombre: 'Ciénaga del Totumo y Galerazamba', tierra: [10.74, -75.23], mar: [10.8, -75.3] },
] as const;

const TIPOS_REPORTE: Record<string, string> = {
  tala: 'tala', quema: 'quema', relleno: 'relleno', vertimiento: 'vertimiento', basuras: 'basuras',
  cano_taponado: 'caño taponado', fauna: 'fauna afectada', otro: 'otras amenazas',
};

// --- Formato -----------------------------------------------------------------

const ZONA = 'America/Bogota';
const n1 = (v: number) => v.toLocaleString('es-CO', { maximumFractionDigits: 1 });
/** Las mareas del Caribe varían por centímetros: se muestran con dos decimales. */
const n2 = (v: number) => v.toLocaleString('es-CO', { maximumFractionDigits: 2 });
const diaBogota = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(d);

const horaDe = (iso: string) =>
  new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, hour: 'numeric', minute: '2-digit' }).format(new Date(iso)).replace(/\s/g, ' ');

export function cuando(iso: string): string {
  const d = new Date(iso);
  const hora = horaDe(iso);
  const hoy = diaBogota(new Date());
  const manana = diaBogota(new Date(Date.now() + 86_400_000));
  const ayer = diaBogota(new Date(Date.now() - 86_400_000));
  const dia = diaBogota(d);
  if (dia === hoy) return `hoy a las ${hora}`;
  if (dia === manana) return `mañana a las ${hora}`;
  if (dia === ayer) return `ayer a las ${hora}`;
  const fecha = new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, weekday: 'long', day: 'numeric', month: 'short' }).format(d).replace('.', '');
  return `el ${fecha} a las ${hora}`;
}

// --- Datos de entrada ----------------------------------------------------------

interface Entrada {
  lecturas: Lectura[] | null;
  estaciones: Map<string, { nombre: string; lat: number; lon: number }> | null;
  tierra: Map<string, HoraPronostico[]>;
  mar: Map<string, HoraPronostico[]>;
  mareas: EventoMarea[] | null;
  focos: FocoCalor[] | null;
  reportes: ReportePublico[] | null;
}

async function leerFuentes(): Promise<{ entrada: Entrada; fuentes: EstadoFuente[] }> {
  const fallos: Partial<Record<IdFuente, string>> = {};
  const atrapar = async <T>(id: IdFuente, p: Promise<T>): Promise<T | null> => {
    try {
      return await p;
    } catch (err) {
      fallos[id] = (err as Error).message.slice(0, 160);
      console.warn(`[alertas] ${id}: ${fallos[id]}`);
      return null;
    }
  };
  const pronosticos = (cual: 'tierra' | 'mar') =>
    Promise.all(SECTORES.map(async s => [s.id, await atrapar('dimar', pronosticoDimar(s[cual][0], s[cual][1]))] as const));

  const [lecturas, estaciones, tierra, mar, mareas, focos, reportes] = await Promise.all([
    atrapar('ideam', lecturasIdeam(74)),
    atrapar('ideam', estacionesIdeam()),
    pronosticos('tierra'),
    pronosticos('mar'),
    atrapar('mareas', mareasDimar('BQA', 4)),
    atrapar('cra', focosCra()),
    comunidadActiva() ? atrapar('comunidad', reportesRecientes(UMBRALES.horas_reportes)) : Promise.resolve(null),
  ]);
  if (!comunidadActiva()) fallos.comunidad = 'sin conexión al backend común';

  const aMapa = (pares: readonly (readonly [string, HoraPronostico[] | null])[]) =>
    new Map(pares.filter((p): p is readonly [string, HoraPronostico[]] => Array.isArray(p[1]) && p[1].length > 0));

  const fuentes = (Object.keys(FUENTES) as IdFuente[]).map(id => ({
    id, nombre: FUENTES[id].nombre, url: FUENTES[id].url, ok: !fallos[id], ...(fallos[id] ? { error: fallos[id] } : {}),
  }));
  return { entrada: { lecturas, estaciones, tierra: aMapa(tierra), mar: aMapa(mar), mareas, focos, reportes }, fuentes };
}

// --- Reglas ------------------------------------------------------------------

const sector = (id: string) => SECTORES.find(s => s.id === id)!;
const proximas = (horas: HoraPronostico[], h: number) => {
  const ahora = Date.now() - 3600_000;
  return horas.filter(x => { const t = Date.parse(x.hora); return t >= ahora && t <= Date.now() + h * 3600_000; });
};

function reglaOleaje(e: Entrada): Alerta | null {
  let mejor: { s: string; h: HoraPronostico } | null = null;
  const afectados: string[] = [];
  let desde = '', hasta = '';
  for (const [id, horas] of e.mar) {
    const futuras = proximas(horas, 72).filter(h => h.ola !== null);
    const altas = futuras.filter(h => (h.ola ?? 0) >= UMBRALES.ola_m[0]);
    if (altas.length) {
      afectados.push(sector(id).nombre);
      if (!desde || altas[0].hora < desde) desde = altas[0].hora;
      if (!hasta || altas[altas.length - 1].hora > hasta) hasta = altas[altas.length - 1].hora;
    }
    for (const h of futuras) if (!mejor || (h.ola ?? 0) > (mejor.h.ola ?? 0)) mejor = { s: id, h };
  }
  if (!mejor || mejor.h.ola === null) return null;
  const nivel = nivelPor(mejor.h.ola, UMBRALES.ola_m);
  if (!nivel) return null;
  const s = sector(mejor.s);
  return {
    id: `mar_de_leva-${mejor.h.hora.slice(0, 10)}`,
    tipo: 'mar_de_leva', nivel,
    titulo: `Mar de leva frente a ${s.nombre}`,
    detalle: `DIMAR pronostica olas de hasta ${n1(mejor.h.ola)} m ${cuando(mejor.h.hora)}. `
      + `Habrá oleaje de ${n1(UMBRALES.ola_m[0])} m o más desde ${cuando(desde)} hasta ${cuando(hasta)}`
      + (afectados.length > 1 ? ` en ${afectados.join(', ')}.` : '.'),
    recomendacion: 'No entres al mar ni a las bocas de las ciénagas en lancha o kayak. Aleja de la orilla los viveros de plántulas y las jornadas de siembra en playa. Después del oleaje, revisa y reporta si hay erosión o basura arrastrada en el manglar.',
    lugar: s.nombre, lat: s.mar[0], lon: s.mar[1], desde, hasta,
    medido: false, valor: mejor.h.ola, unidad: 'm', umbral: UMBRALES.ola_m[0], fuentes: ['dimar'],
  };
}

function reglaInundacionCostera(e: Entrada): Alerta | null {
  if (!e.mareas?.length || !e.mar.size) return null;
  const ventana = UMBRALES.ventana_marea_h * 3600_000;
  const casos: { p: EventoMarea; ola: number; s: string }[] = [];
  for (const p of e.mareas) {
    const t = Date.parse(p.t);
    if (p.tipo !== 'PLEAMAR' || p.m < UMBRALES.pleamar_m || t < Date.now() - 2 * 3600_000 || t > Date.now() + 72 * 3600_000) continue;
    let ola = 0, s = '';
    for (const [id, horas] of e.mar) for (const h of horas) {
      if (h.ola !== null && Math.abs(Date.parse(h.hora) - t) <= ventana && h.ola > ola) { ola = h.ola; s = id; }
    }
    if (ola >= UMBRALES.ola_m[0]) casos.push({ p, ola, s });
  }
  if (!casos.length) return null;
  casos.sort((a, b) => b.ola - a.ola || Date.parse(a.p.t) - Date.parse(b.p.t));
  const c = casos[0];
  const nivel = nivelPor(c.ola, UMBRALES.ola_m)!;
  const s = sector(c.s);
  const t = Date.parse(c.p.t);
  const otras = casos.length - 1;
  return {
    id: `inundacion_costera-${c.p.t.slice(0, 13)}`,
    tipo: 'inundacion_costera', nivel,
    titulo: `Pleamar con oleaje: la orilla se puede inundar en ${s.nombre}`,
    detalle: `La pleamar de ${n2(c.p.m)} m ${cuando(c.p.t)} coincide con olas de ${n1(c.ola)} m. `
      + 'El agua puede pasar la línea de playa, mojar las raíces y llevarse arena del borde del manglar'
      + (otras > 0 ? `. Pasa ${otras === 1 ? 'una vez más' : `${otras} veces más`} en los próximos 3 días.` : '.'),
    recomendacion: `Evita la franja de playa y los caños de desagüe desde ${cuando(new Date(t - 2 * 3600_000).toISOString())} hasta las ${horaDe(new Date(t + 2 * 3600_000).toISOString())}. Si vives en la orilla, sube lo que se pueda mojar. Al bajar el agua, toma una foto del borde y repórtala para medir la erosión.`,
    lugar: s.nombre, lat: s.tierra[0], lon: s.tierra[1],
    desde: new Date(t - 2 * 3600_000).toISOString(), hasta: new Date(t + 2 * 3600_000).toISOString(),
    medido: false, valor: c.ola, unidad: 'm', umbral: UMBRALES.ola_m[0], fuentes: ['mareas', 'dimar'],
  };
}

/** Lluvia por estación: la hora más lluviosa de las últimas 3 y el total de 24 h y de 72 h. */
function lluviaPorEstacion(lecturas: Lectura[]) {
  const porEstacion = new Map<string, Map<string, { mm: number; fin: string }>>();
  for (const l of lecturas) {
    if (!l.variable.startsWith('total_precipitation')) continue;
    // Una sola lectura por hora acumulada y por estación (se publican varias veces).
    const horas = porEstacion.get(l.estacion) ?? new Map();
    horas.set(`${l.inicio}/${l.fin}`, { mm: l.valor, fin: l.fin });
    porEstacion.set(l.estacion, horas);
  }
  const ahora = Date.now();
  const res = new Map<string, { max1h: number; cuando1h: string; mm24: number; mm72: number }>();
  for (const [est, horas] of porEstacion) {
    let max1h = 0, cuando1h = '', mm24 = 0, mm72 = 0;
    for (const { mm, fin } of horas.values()) {
      const edad = ahora - Date.parse(fin);
      if (mm < 0 || mm > 300) continue; // lecturas imposibles
      if (edad <= 3 * 3600_000 && mm >= max1h) { max1h = mm; cuando1h = fin; }
      if (edad <= 24 * 3600_000) mm24 += mm;
      if (edad <= 72 * 3600_000) mm72 += mm;
    }
    res.set(est, { max1h, cuando1h, mm24, mm72 });
  }
  return res;
}

function nombreEstacion(e: Entrada, id: string): string {
  return e.estaciones?.get(id)?.nombre ?? id;
}

function reglaLluvia(e: Entrada): Alerta | null {
  // Medido por el IDEAM
  let medida: { nivel: Nivel; est: string; texto: string; valor: number; umbral: number; desde: string; hasta: string } | null = null;
  if (e.lecturas) {
    for (const [est, l] of lluviaPorEstacion(e.lecturas)) {
      const n1h = nivelPor(l.max1h, UMBRALES.lluvia_1h_mm);
      const n24 = nivelPor(l.mm24, UMBRALES.lluvia_24h_mm);
      const n = peor(n1h, n24);
      if (!n || (medida && ORDEN[n] <= ORDEN[medida.nivel])) continue;
      const por1h = n1h && (!n24 || ORDEN[n1h] >= ORDEN[n24]);
      medida = {
        nivel: n, est,
        texto: por1h
          ? `La estación ${nombreEstacion(e, est)} del IDEAM midió ${n1(l.max1h)} mm de lluvia en una hora (${cuando(l.cuando1h)}).`
          : `La estación ${nombreEstacion(e, est)} del IDEAM lleva ${n1(l.mm24)} mm de lluvia en 24 horas.`,
        valor: por1h ? l.max1h : l.mm24,
        umbral: por1h ? UMBRALES.lluvia_1h_mm[0] : UMBRALES.lluvia_24h_mm[0],
        desde: new Date(Date.now() - (por1h ? 3 : 24) * 3600_000).toISOString(),
        hasta: new Date().toISOString(),
      };
    }
  }
  // Pronóstico de DIMAR: el peor acumulado de 24 h que viene en cada sector
  let pron: { nivel: Nivel; s: string; mm: number; desde: string; hasta: string } | null = null;
  for (const [id, horas] of e.tierra) {
    const futuras = proximas(horas, 72);
    for (let i = 0; i < futuras.length; i++) {
      const tramo = futuras.slice(i, i + 24);
      const mm = tramo.reduce((s, h) => s + (Number.isFinite(h.lluvia) ? h.lluvia : 0), 0);
      const n = nivelPor(mm, UMBRALES.lluvia_pronostico_24h_mm);
      if (n && (!pron || mm > pron.mm)) pron = { nivel: n, s: id, mm, desde: tramo[0].hora, hasta: tramo[tramo.length - 1].hora };
    }
  }
  if (!medida && !pron) return null;
  const usarMedida = medida && (!pron || ORDEN[medida.nivel] >= ORDEN[pron.nivel]);
  const recomendacion = 'No cruces arroyos ni caños crecidos. La lluvia arrastra basura hacia los caños y las ciénagas: si ves un caño taponado o agua estancada en el manglar, repórtalo con foto.';
  if (usarMedida && medida) {
    const est = e.estaciones?.get(medida.est);
    const extra = pron ? ` Además DIMAR pronostica ${n1(pron.mm)} mm en 24 h en ${sector(pron.s).nombre}.` : '';
    return {
      id: `lluvia_fuerte-medida-${medida.est}-${medida.hasta.slice(0, 13)}`,
      tipo: 'lluvia_fuerte', nivel: medida.nivel,
      titulo: `Lluvia fuerte en ${est?.nombre ?? 'el Atlántico'}`,
      detalle: medida.texto + extra,
      recomendacion,
      lugar: est?.nombre ?? 'Atlántico', lat: est?.lat ?? 10.95, lon: est?.lon ?? -74.85, desde: medida.desde, hasta: medida.hasta,
      medido: true, valor: medida.valor, unidad: 'mm', umbral: medida.umbral, fuentes: pron ? ['ideam', 'dimar'] : ['ideam'],
    };
  }
  const p = pron!;
  const s = sector(p.s);
  return {
    id: `lluvia_fuerte-pronostico-${p.desde.slice(0, 10)}`,
    tipo: 'lluvia_fuerte', nivel: p.nivel,
    titulo: `Se esperan aguaceros en ${s.nombre}`,
    detalle: `DIMAR pronostica ${n1(p.mm)} mm de lluvia en 24 horas, desde ${cuando(p.desde)}.`,
    recomendacion,
    lugar: s.nombre, lat: s.tierra[0], lon: s.tierra[1], desde: p.desde, hasta: p.hasta,
    medido: false, valor: p.mm, unidad: 'mm', umbral: UMBRALES.lluvia_pronostico_24h_mm[0], fuentes: ['dimar'],
  };
}

/** Último valor de cada variable por estación (de las últimas 2 horas). */
function ultimas(lecturas: Lectura[], variable: string) {
  const res = new Map<string, Lectura>();
  for (const l of lecturas) {
    if (l.variable !== variable || Date.now() - Date.parse(l.fin) > 2 * 3600_000) continue;
    const prev = res.get(l.estacion);
    if (!prev || l.fin > prev.fin) res.set(l.estacion, l);
  }
  return res;
}

function reglaViento(e: Entrada): Alerta | null {
  let medida: { nivel: Nivel; l: Lectura } | null = null;
  if (e.lecturas) {
    for (const l of ultimas(e.lecturas, 'wind_speed').values()) {
      const n = nivelPor(l.valor, UMBRALES.viento_ms);
      if (n && (!medida || l.valor > medida.l.valor)) medida = { nivel: n, l };
    }
  }
  let pron: { nivel: Nivel; s: string; h: HoraPronostico } | null = null;
  for (const [id, horas] of e.tierra) for (const h of proximas(horas, 48)) {
    const n = nivelPor(h.viento, UMBRALES.viento_pronostico_ms);
    if (n && (!pron || h.viento > pron.h.viento)) pron = { nivel: n, s: id, h };
  }
  const recomendacion = 'Asegura techos, carpas y viveros. No hagas quemas ni fogatas: con este viento el fuego se sale de control y llega al manglar. Si ves humo, repórtalo de inmediato.';
  if (medida && (!pron || ORDEN[medida.nivel] >= ORDEN[pron.nivel])) {
    const est = e.estaciones?.get(medida.l.estacion);
    return {
      id: `vendaval-medido-${medida.l.estacion}-${medida.l.fin.slice(0, 13)}`,
      tipo: 'vendaval', nivel: medida.nivel,
      titulo: `Viento fuerte en ${est?.nombre ?? 'el Atlántico'}`,
      detalle: `La estación ${est?.nombre ?? medida.l.estacion} del IDEAM midió viento de ${n1(medida.l.valor)} m/s (${n1(medida.l.valor * 3.6)} km/h) ${cuando(medida.l.fin)}.`,
      recomendacion,
      lugar: est?.nombre ?? 'Atlántico', lat: est?.lat ?? 10.95, lon: est?.lon ?? -74.85,
      desde: medida.l.inicio, hasta: medida.l.fin,
      medido: true, valor: medida.l.valor, unidad: 'm/s', umbral: UMBRALES.viento_ms[0], fuentes: ['ideam'],
    };
  }
  if (!pron) return null;
  const s = sector(pron.s);
  return {
    id: `vendaval-pronostico-${pron.h.hora.slice(0, 13)}`,
    tipo: 'vendaval', nivel: pron.nivel,
    titulo: `Se esperan vientos fuertes en ${s.nombre}`,
    detalle: `DIMAR pronostica viento de ${n1(pron.h.viento)} m/s (${n1(pron.h.viento * 3.6)} km/h) ${cuando(pron.h.hora)}.`,
    recomendacion,
    lugar: s.nombre, lat: s.tierra[0], lon: s.tierra[1], desde: pron.h.hora, hasta: pron.h.hora,
    medido: false, valor: pron.h.viento, unidad: 'm/s', umbral: UMBRALES.viento_pronostico_ms[0], fuentes: ['dimar'],
  };
}

function reglaIncendio(e: Entrada): Alerta | null {
  const u = UMBRALES.incendio;
  // ¿Ha llovido en los últimos 3 días? Se toma la estación más lluviosa: si alguna midió lluvia, no está tan seco.
  let lluvia72: number | null = null;
  if (e.lecturas) for (const l of lluviaPorEstacion(e.lecturas).values()) lluvia72 = Math.max(lluvia72 ?? 0, l.mm72);
  if (lluvia72 !== null && lluvia72 > u.lluvia_72h_max_mm) return null;

  let mejor: { s: string; horas: HoraPronostico[]; extremas: number } | null = null;
  for (const [id, horas] of e.tierra) {
    const peligrosas = proximas(horas, 48).filter(h => h.temperatura >= u.temperatura_c && h.humedad <= u.humedad_max_pct && h.viento >= u.viento_ms);
    const extremas = peligrosas.filter(h => h.temperatura >= u.temperatura_c + 2 && h.humedad <= u.humedad_max_pct - 10).length;
    if (peligrosas.length >= u.horas_minimas && (!mejor || peligrosas.length + extremas > mejor.horas.length + mejor.extremas)) {
      mejor = { s: id, horas: peligrosas, extremas };
    }
  }
  const quemas = (e.reportes ?? []).filter(r => r.tipo === 'quema');
  if (!mejor && !quemas.length) return null;

  let nivel: Nivel = mejor && mejor.extremas >= u.horas_minimas ? 'naranja' : 'amarilla';
  if (quemas.length) nivel = subir(nivel);
  if (quemas.length >= 3) nivel = 'roja';
  const s = sector(mejor?.s ?? 'mallorquin');
  const tmax = mejor ? Math.max(...mejor.horas.map(h => h.temperatura)) : null;
  const hmin = mejor ? Math.min(...mejor.horas.map(h => h.humedad)) : null;
  const partes: string[] = [];
  if (mejor && tmax !== null && hmin !== null) {
    const seco = lluvia72 === null ? '' : lluvia72 > 0 ? `, y casi no ha llovido en 3 días (${n1(lluvia72)} mm)` : ', y no ha llovido en 3 días en las estaciones del IDEAM';
    partes.push(`DIMAR pronostica ${mejor.horas.length} horas de calor seco con brisa (hasta ${n1(tmax)} °C y ${Math.round(hmin)} % de humedad), desde ${cuando(mejor.horas[0].hora)}${seco}`);
  }
  if (quemas.length) partes.push(`La comunidad reportó ${quemas.length === 1 ? 'una quema' : `${quemas.length} quemas`} en las últimas ${UMBRALES.horas_reportes} horas`);
  return {
    id: `riesgo_incendio-${(mejor?.horas[0].hora ?? new Date().toISOString()).slice(0, 10)}`,
    tipo: 'riesgo_incendio', nivel,
    titulo: `Riesgo de que una quema se vuelva incendio en ${s.nombre}`,
    detalle: partes.join('. ') + '.',
    recomendacion: 'No quemes basura ni maleza cerca del manglar. Si ves humo o fuego, aléjate, llama al 119 (bomberos) y repórtalo en Zanky con la ubicación: la C.R.A. lo ve en el panel.',
    lugar: s.nombre, lat: s.tierra[0], lon: s.tierra[1],
    desde: mejor?.horas[0].hora ?? new Date().toISOString(), hasta: mejor?.horas[mejor.horas.length - 1].hora ?? new Date().toISOString(),
    medido: false, unidad: '°C', valor: tmax ?? undefined, umbral: u.temperatura_c,
    fuentes: [...(mejor ? (['dimar', 'ideam'] as IdFuente[]) : []), ...(quemas.length ? (['comunidad'] as IdFuente[]) : [])],
  };
}

function reglaFocos(e: Entrada): Alerta | null {
  if (!e.focos?.length) return null;
  const limite = Date.now() - UMBRALES.foco_dias * 86_400_000;
  const cerca = e.focos
    .filter(f => Date.parse(f.hasta) >= limite)
    .map(f => ({ f, u: ubicar(f.lat, f.lon) }))
    .filter(x => x.u.distanciaM <= UMBRALES.foco_distancia_m)
    .sort((a, b) => a.u.distanciaM - b.u.distanciaM);
  if (!cerca.length) return null;
  const { f, u } = cerca[0];
  return {
    id: `foco_calor-${f.hasta.slice(0, 13)}-${f.lat.toFixed(3)}`,
    tipo: 'foco_calor', nivel: u.dentro ? 'roja' : 'naranja',
    titulo: u.dentro ? `Fuego detectado dentro del manglar${u.zona ? ` (${u.zona})` : ''}` : `Fuego detectado a ${u.distanciaM} m del manglar`,
    detalle: `El satélite ${f.satelites} vio ${f.focos} ${f.focos === 1 ? 'foco' : 'focos'} de calor ${cuando(f.hasta)} (confianza ${f.confianza.replace('_', ' ')})`
      + (cerca.length > 1 ? `. Hay ${cerca.length - 1} más cerca del manglar esta semana.` : '.'),
    recomendacion: 'Si estás cerca y es seguro, toma una foto y repórtala en Zanky para confirmar el fuego. Llama al 119 si sigue activo.',
    lugar: u.zona ?? 'Manglar del Atlántico', lat: f.lat, lon: f.lon, desde: f.desde, hasta: f.hasta,
    medido: true, valor: u.distanciaM, unidad: 'm', umbral: UMBRALES.foco_distancia_m, fuentes: ['cra'],
  };
}

function reglasComunidad(e: Entrada): Alerta[] {
  if (!e.reportes?.length) return [];
  const grupos = new Map<string, ReportePublico[]>();
  for (const r of e.reportes) {
    const clave = `${r.tipo}|${r.zona ?? r.municipio ?? 'sin_zona'}`;
    grupos.set(clave, [...(grupos.get(clave) ?? []), r]);
  }
  const alertas: Alerta[] = [];
  for (const [clave, rs] of grupos) {
    const [tipo] = clave.split('|');
    const oficial = rs.some(r => r.estado === 'alerta_oficial');
    let nivel = nivelPor(rs.length, UMBRALES.reportes_misma_zona);
    if (oficial) nivel = peor(nivel, 'naranja');
    if (!nivel) continue;
    const lugar = nombreZona(rs[0]);
    const lat = rs.reduce((s, r) => s + r.lat, 0) / rs.length;
    const lon = rs.reduce((s, r) => s + r.lon, 0) / rs.length;
    const fechas = rs.map(r => r.capturado_en).sort();
    const nombre = TIPOS_REPORTE[tipo] ?? tipo;
    alertas.push({
      id: `amenaza_ciudadana-${clave}`,
      tipo: 'amenaza_ciudadana', nivel,
      titulo: `${rs.length > 1 ? `${rs.length} reportes` : 'Un reporte'} de ${nombre} en ${lugar}`,
      detalle: (rs.length > 1
        ? `La comunidad reportó ${nombre} ${rs.length} veces en ${lugar} desde ${cuando(fechas[0])}: varias personas vieron lo mismo.`
        : `La comunidad reportó ${nombre} en ${lugar} ${cuando(fechas[0])}.`)
        + (oficial ? ' La C.R.A. ya lo declaró alerta oficial.' : ' La C.R.A. lo está verificando.'),
      recomendacion: tipo === 'quema'
        ? 'Si ves fuego, aléjate y llama al 119. Suma tu foto al reporte en Zanky para que la C.R.A. lo confirme rápido.'
        : 'Si pasas por ahí, suma tu foto en Zanky: cada reporte que coincide sube la confianza y acelera la visita de la C.R.A.',
      lugar, lat, lon, desde: fechas[0], hasta: fechas[fechas.length - 1],
      medido: true, valor: rs.length, unidad: 'reportes', umbral: UMBRALES.reportes_misma_zona[0], fuentes: ['comunidad'],
    });
  }
  return alertas;
}

function nombreZona(r: ReportePublico): string {
  const z = (r.zona ?? '').toLowerCase();
  const conocidas: Record<string, string> = { mallorquin: 'Ciénaga de Mallorquín', tubara: 'Tubará', juan_de_acosta: 'Juan de Acosta', piojo: 'Piojó' };
  return conocidas[z] ?? r.zona ?? r.municipio ?? 'el manglar';
}

// --- Resumen de lo que se mide ahora ------------------------------------------

function resumenAhora(e: Entrada): ResultadoAlertas['ahora'] {
  let lluviaHora: number | null = null, lluvia24: number | null = null, lluviaEst: string | null = null;
  let viento: number | null = null, vientoEst: string | null = null, temperatura: number | null = null;
  if (e.lecturas) {
    for (const [est, l] of lluviaPorEstacion(e.lecturas)) {
      if (lluvia24 === null || l.mm24 > lluvia24) { lluvia24 = l.mm24; lluviaEst = nombreEstacion(e, est); }
      lluviaHora = Math.max(lluviaHora ?? 0, l.max1h);
    }
    for (const l of ultimas(e.lecturas, 'wind_speed').values()) if (viento === null || l.valor > viento) { viento = l.valor; vientoEst = nombreEstacion(e, l.estacion); }
    for (const l of ultimas(e.lecturas, 'air_temperature').values()) {
      const c = l.unidad === 'K' || l.valor > 200 ? l.valor - 273.15 : l.valor;
      temperatura = Math.max(temperatura ?? -99, c);
    }
  }
  let ola: { m: number; t: string; s: string } | null = null;
  for (const [id, horas] of e.mar) for (const h of proximas(horas, 72)) if (h.ola !== null && (!ola || h.ola > ola.m)) ola = { m: h.ola, t: h.hora, s: id };
  let tmax: number | null = null;
  for (const horas of e.tierra.values()) for (const h of proximas(horas, 24)) if (Number.isFinite(h.temperatura)) tmax = Math.max(tmax ?? -99, h.temperatura);
  const pleamar = (e.mareas ?? []).find(m => m.tipo === 'PLEAMAR' && Date.parse(m.t) >= Date.now()) ?? null;
  const r = (v: number | null) => (v === null ? null : Math.round(v * 10) / 10);
  return {
    lluvia_hora_mm: r(lluviaHora), lluvia_24h_mm: r(lluvia24), lluvia_estacion: lluviaEst,
    viento_ms: r(viento), viento_estacion: vientoEst, temperatura_c: r(temperatura),
    ola_max_m: r(ola?.m ?? null), ola_cuando: ola?.t ?? null, ola_lugar: ola ? sector(ola.s).nombre : null,
    proxima_pleamar: pleamar ? { t: pleamar.t, m: pleamar.m } : null,
    temp_max_pronostico_c: r(tmax), reportes_72h: e.reportes ? e.reportes.length : null,
  };
}

// --- Motor con caché -----------------------------------------------------------

const NOTA = 'Alertas automáticas de Zanky con datos públicos del IDEAM, DIMAR, la C.R.A. y la comunidad. '
  + 'Son una ayuda para la comunidad, no reemplazan los avisos oficiales de la UNGRD, DIMAR ni la C.R.A. '
  + 'Los umbrales son de trabajo y se ajustan con la C.R.A.';

let cache: { cuando: number; resultado: ResultadoAlertas } | null = null;
let enCurso: Promise<ResultadoAlertas> | null = null;
const VIGENCIA_MS = 10 * 60_000;

function evaluar(e: Entrada, fuentes: EstadoFuente[]): ResultadoAlertas {
  const alertas: Alerta[] = [];
  const intentar = (nombre: string, f: () => Alerta | Alerta[] | null) => {
    try {
      const r = f();
      if (Array.isArray(r)) alertas.push(...r);
      else if (r) alertas.push(r);
    } catch (err) {
      console.warn(`[alertas] regla ${nombre}: ${(err as Error).message}`);
    }
  };
  intentar('oleaje', () => reglaOleaje(e));
  intentar('inundacion', () => reglaInundacionCostera(e));
  intentar('lluvia', () => reglaLluvia(e));
  intentar('viento', () => reglaViento(e));
  intentar('incendio', () => reglaIncendio(e));
  intentar('focos', () => reglaFocos(e));
  intentar('comunidad', () => reglasComunidad(e));
  return ordenar({
    generado: new Date().toISOString(), simulacro: false, nivel_maximo: null, alertas,
    ahora: resumenAhora(e), fuentes, umbrales: UMBRALES, nota: NOTA,
  });
}

/** «a las 1:43 p. m..» → «a las 1:43 p. m.» */
const puntos = (t: string) => t.replace(/\.\.(\s|$)/g, '.$1');

function ordenar(r: ResultadoAlertas): ResultadoAlertas {
  for (const a of r.alertas) { a.detalle = puntos(a.detalle); a.recomendacion = puntos(a.recomendacion); }
  r.alertas.sort((a, b) => ORDEN[b.nivel] - ORDEN[a.nivel] || Number(b.medido) - Number(a.medido) || a.desde.localeCompare(b.desde));
  r.nivel_maximo = r.alertas.reduce<Nivel | null>((n, a) => peor(n, a.nivel), null);
  return r;
}

export async function alertasActuales(): Promise<ResultadoAlertas> {
  if (cache && Date.now() - cache.cuando < VIGENCIA_MS) return cache.resultado;
  if (!enCurso) {
    enCurso = leerFuentes()
      .then(({ entrada, fuentes }) => evaluar(entrada, fuentes))
      .then(resultado => {
        cache = { cuando: Date.now(), resultado };
        console.log(`[alertas] ${resultado.alertas.length} alertas (${resultado.nivel_maximo ?? 'sin alerta'}) · fuentes caídas: ${resultado.fuentes.filter(f => !f.ok).map(f => f.id).join(', ') || 'ninguna'}`);
        return resultado;
      })
      .finally(() => { enCurso = null; });
  }
  // Si hay una versión anterior, se entrega mientras se recalcula; si no, se espera.
  return cache ? cache.resultado : enCurso;
}

/**
 * Simulacro para mostrar cómo se ve una alerta cuando el tiempo está en calma (demo, capacitación de vigías).
 * Usa las cifras reales de «ahora» y cambia solo las alertas, marcadas como SIMULACRO.
 */
export async function alertasSimulacro(): Promise<ResultadoAlertas> {
  const real = await alertasActuales();
  const h = (horas: number) => new Date(Date.now() + horas * 3600_000).toISOString();
  const pc = sector('puerto_colombia'), mal = sector('mallorquin');
  const alertas: Alerta[] = [
    {
      id: 'simulacro-mar_de_leva', tipo: 'mar_de_leva', nivel: 'naranja',
      titulo: `SIMULACRO · Mar de leva frente a ${pc.nombre}`,
      detalle: `DIMAR pronostica olas de hasta 2,7 m ${cuando(h(14))}. Habrá oleaje de 2 m o más desde ${cuando(h(6))} hasta ${cuando(h(30))}.`,
      recomendacion: 'No entres al mar ni a las bocas de las ciénagas en lancha o kayak. Aleja de la orilla los viveros y las jornadas de siembra en playa.',
      lugar: pc.nombre, lat: pc.mar[0], lon: pc.mar[1], desde: h(6), hasta: h(30), medido: false, valor: 2.7, unidad: 'm', umbral: 2, fuentes: ['dimar'],
    },
    {
      id: 'simulacro-inundacion', tipo: 'inundacion_costera', nivel: 'naranja',
      titulo: `SIMULACRO · Pleamar con oleaje: la orilla se puede inundar en ${pc.nombre}`,
      detalle: `La pleamar de 0,98 m ${cuando(h(13))} coincide con olas de 2,7 m. El agua puede pasar la línea de playa y llevarse arena del borde del manglar.`,
      recomendacion: 'Evita la franja de playa y los caños de desagüe 2 horas antes y después de la pleamar. Al bajar el agua, toma una foto del borde y repórtala.',
      lugar: pc.nombre, lat: pc.tierra[0], lon: pc.tierra[1], desde: h(11), hasta: h(15), medido: false, valor: 2.7, unidad: 'm', umbral: 2, fuentes: ['mareas', 'dimar'],
    },
    {
      id: 'simulacro-quema', tipo: 'amenaza_ciudadana', nivel: 'naranja',
      titulo: `SIMULACRO · 4 reportes de quema en ${mal.nombre}`,
      detalle: `La comunidad reportó quema 4 veces en ${mal.nombre} desde ${cuando(h(-5))}: varias personas vieron lo mismo. La C.R.A. lo está verificando.`,
      recomendacion: 'Si ves fuego, aléjate y llama al 119. Suma tu foto al reporte en Zanky para que la C.R.A. lo confirme rápido.',
      lugar: mal.nombre, lat: mal.tierra[0], lon: mal.tierra[1], desde: h(-5), hasta: h(-1), medido: true, valor: 4, unidad: 'reportes', umbral: 2, fuentes: ['comunidad'],
    },
    {
      id: 'simulacro-incendio', tipo: 'riesgo_incendio', nivel: 'roja',
      titulo: `SIMULACRO · Riesgo de que una quema se vuelva incendio en ${mal.nombre}`,
      detalle: `DIMAR pronostica 7 horas de calor seco con brisa (hasta 35 °C y 45 % de humedad), desde ${cuando(h(2))}, y no ha llovido en 3 días. La comunidad reportó 4 quemas en las últimas 72 horas.`,
      recomendacion: 'No quemes basura ni maleza cerca del manglar. Si ves humo o fuego, aléjate, llama al 119 y repórtalo en Zanky con la ubicación.',
      lugar: mal.nombre, lat: mal.tierra[0], lon: mal.tierra[1], desde: h(2), hasta: h(9), medido: false, valor: 35, unidad: '°C', umbral: 32, fuentes: ['dimar', 'ideam', 'comunidad'],
    },
  ];
  return ordenar({ ...real, generado: new Date().toISOString(), simulacro: true, alertas });
}

/** Mantiene las alertas al día aunque nadie las pida, para que la web y WhatsApp respondan al instante. */
export function iniciarAlertas(): void {
  const refrescar = () => alertasActuales().catch(err => console.warn(`[alertas] ${(err as Error).message}`));
  void refrescar();
  setInterval(() => { cache = cache && { ...cache, cuando: 0 }; void refrescar(); }, VIGENCIA_MS);
}

// --- Texto para WhatsApp -------------------------------------------------------

const EMOJI: Record<Nivel, string> = { amarilla: '🟡', naranja: '🟠', roja: '🔴' };

export function textoWhatsApp(r: ResultadoAlertas, web: string): string {
  const a = r.ahora;
  const datos: string[] = [];
  if (a.viento_ms !== null) datos.push(`💨 Viento: ${n1(a.viento_ms)} m/s en ${a.viento_estacion}`);
  if (a.lluvia_24h_mm !== null) datos.push(`🌧️ Lluvia 24 h: ${n1(a.lluvia_24h_mm)} mm`);
  if (a.ola_max_m !== null && a.ola_cuando) datos.push(`🌊 Ola más alta: ${n1(a.ola_max_m)} m ${cuando(a.ola_cuando)}`);
  if (a.proxima_pleamar) datos.push(`🌕 Próxima pleamar: ${n2(a.proxima_pleamar.m)} m ${cuando(a.proxima_pleamar.t)}`);
  const pie = `${datos.length ? `\n\n*Ahora en el manglar*\n${datos.join('\n')}` : ''}\n\nMapa y detalle: ${web}/#alertas\n_Fuentes: IDEAM, DIMAR, C.R.A. y la comunidad. No reemplaza los avisos oficiales._`;
  if (!r.alertas.length) return `✅ *Sin alertas para el manglar en este momento.*${pie}`;
  const lineas = r.alertas.slice(0, 4).map(al =>
    puntos(`${EMOJI[al.nivel]} *${al.titulo}* (alerta ${al.nivel}, ${al.medido ? 'medido' : 'pronóstico'})\n${al.detalle}\n👉 ${al.recomendacion}`));
  const mas = r.alertas.length > 4 ? `\n\n…y ${r.alertas.length - 4} más en la web.` : '';
  return `${r.simulacro ? '🧪 *SIMULACRO*\n\n' : ''}⚠️ *Alertas del manglar*\n\n${lineas.join('\n\n')}${mas}${pie}`.slice(0, 4000);
}
