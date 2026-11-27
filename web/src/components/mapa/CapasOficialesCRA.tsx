// Capas oficiales de la C.R.A. sobre el mapa de monitoreo, leídas en vivo de su API:
// puntos críticos de riesgo, focos de calor detectados por satélite y calidad del agua
// de las ciénagas. Sirven para dar contexto a los reportes de la comunidad: un reporte
// cerca de un punto crítico o de un foco de calor oficial pesa más.
//
// Se usa desde MapaMonitoreo y desde los visores (/visores/riesgo y /visores/agua):
// useCapasCRA() da el estado; InterruptoresCRA va en el panel de filtros, CapasCRAEnMapa
// dentro del MapContainer y LeyendaCRA en la leyenda. `claves` elige qué capas se ofrecen.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import L from 'leaflet';
import { GeoJSON, Marker, Popup, Tooltip } from 'react-leaflet';
import type { FeatureCollection, MultiPolygon, Polygon } from 'geojson';
import { Droplet, Flame, TriangleAlert, type LucideIcon } from 'lucide-react';
import type { CapaManglarCRA } from '../../types/manglar';
import { evaluarUbicacion } from '../../lib/areaReporte';
import {
  CIENAGAS_CON_MANGLAR, COLOR_SIN_DATO, ESCALA_ICA, PAGINA_CALIDAD_AGUA, VISOR_GEOVISOR_CRA, VISOR_PUNTOS_CRITICOS, categoriaICA, formatoFechaCRA, obtenerCapasCRA,
  type CalidadAguaCRA, type CapasCRA, type FocoIncendioCRA, type PuntoCriticoCRA,
} from '../../lib/craApi';
import '../../styles/capas-cra.css';

export type ClaveCapaCRA = 'puntos' | 'incendios' | 'agua';

/** Solo se muestra lo que queda a esta distancia de la cobertura de manglar o menos:
 *  el resto (por ejemplo, las inundaciones del casco urbano) no es contexto del manglar. */
export const RADIO_CONTEXTO_M = 2000;

export type ConDistancia<T> = T & { distancia: string | null; distancia_m: number | null };
export const TODAS_LAS_CAPAS: ClaveCapaCRA[] = ['puntos', 'incendios', 'agua'];
/** Para abrir la ventana de un marcador desde fuera del mapa (las listas de los visores). */
export type RegistrarMarcador = (clave: string, marcador: L.Marker | null) => void;
export const claveMarcador = (capa: ClaveCapaCRA, id: number) => `${capa}-${id}`;
export interface CapasCercanas {
  puntos: ConDistancia<PuntoCriticoCRA>[];
  incendios: ConDistancia<FocoIncendioCRA>[];
  agua: ConDistancia<CalidadAguaCRA>[];
  tipos: CapasCRA['tipos'];
  /** false si no se pudo cargar la cobertura de manglar: entonces se muestra toda la franja costera. */
  filtradas: boolean;
}

export interface EstadoCapasCRA {
  datos: CapasCercanas | null;
  error: boolean;
  visibles: Record<ClaveCapaCRA, boolean>;
  alternar: (clave: ClaveCapaCRA) => void;
  reintentar: () => void;
}

/** @param manglar cobertura de manglar de la C.R.A. (null mientras carga)
 *  @param sinManglar true si la cobertura no se pudo cargar: se muestra todo sin filtrar
 *  @param iniciales qué capas arrancan encendidas (por omisión, todas) */
export function useCapasCRA(manglar: CapaManglarCRA | null, sinManglar = false, iniciales: Partial<Record<ClaveCapaCRA, boolean>> = {}): EstadoCapasCRA {
  const [crudas, setCrudas] = useState<CapasCRA | null>(null);
  const [error, setError] = useState(false);
  const [intento, setIntento] = useState(0);
  const [visibles, setVisibles] = useState<Record<ClaveCapaCRA, boolean>>(() => ({ puntos: true, incendios: true, agua: true, ...iniciales }));
  useEffect(() => {
    let activo = true;
    setError(false);
    obtenerCapasCRA().then((capas) => { if (activo) setCrudas(capas); }).catch(() => { if (activo) setError(true); });
    return () => { activo = false; };
  }, [intento]);
  const datos = useMemo<CapasCercanas | null>(() => {
    if (!crudas || (!manglar && !sinManglar)) return null;
    const cerca = <T extends { lat: number; lon: number }>(lista: T[], siempre: (item: T) => boolean = () => false): ConDistancia<T>[] =>
      lista.flatMap((item) => {
        if (!manglar) return [{ ...item, distancia: null, distancia_m: null }];
        const { dentro_poligono, distancia_m } = evaluarUbicacion(item.lat, item.lon, manglar);
        if (dentro_poligono) return [{ ...item, distancia: 'Dentro del manglar', distancia_m: 0 }];
        const cercano = distancia_m <= RADIO_CONTEXTO_M;
        if (!cercano && !siempre(item)) return [];
        return [{ ...item, distancia: cercano ? `A ${distancia_m.toLocaleString('es-CO')} m del manglar` : null, distancia_m: Number.isFinite(distancia_m) ? distancia_m : null }];
      });
    return {
      puntos: cerca(crudas.puntos),
      incendios: cerca(crudas.incendios),
      agua: cerca(crudas.agua, (p) => CIENAGAS_CON_MANGLAR.includes(p.cuerpo_id)),
      tipos: crudas.tipos,
      filtradas: Boolean(manglar),
    };
  }, [crudas, manglar, sinManglar]);
  const alternar = useCallback((clave: ClaveCapaCRA) => setVisibles((v) => ({ ...v, [clave]: !v[clave] })), []);
  const reintentar = useCallback(() => setIntento((n) => n + 1), []);
  return { datos, error, visibles, alternar, reintentar };
}

// ---- Íconos ----
const TINTA_OSCURA = 'var(--color-cra-950)';
/** Ícono blanco sobre colores oscuros y azul profundo sobre colores claros (amarillos, verdes). */
export function tinta(hex: string): string {
  const n = Number.parseInt(hex.replace('#', '').slice(0, 6), 16);
  if (Number.isNaN(n)) return '#fff';
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => { const s = c / 255; return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4; });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.35 ? TINTA_OSCURA : '#fff';
}

const iconos = new Map<string, L.DivIcon>();
function iconoCRA(forma: 'rombo' | 'circulo', color: string, Icono: LucideIcon): L.DivIcon {
  const clave = `${forma}-${color}-${Icono.displayName ?? ''}`;
  let icono = iconos.get(clave);
  if (!icono) {
    const html = renderToStaticMarkup(
      <span className={forma === 'rombo' ? 'pin-cra pin-cra--rombo' : 'pin-cra'} style={{ backgroundColor: color }}>
        <Icono size={13} strokeWidth={2.5} color={tinta(color)} aria-hidden="true" />
      </span>,
    );
    icono = L.divIcon({ className: 'pin-cra-envoltura', html, iconSize: [26, 26], iconAnchor: [13, 13], popupAnchor: [0, -12] });
    iconos.set(clave, icono);
  }
  return icono;
}

export const COLOR_FOCO = '#f97316';
const CONFIANZA: Record<string, string> = { very_high: 'muy alta', high: 'alta', nominal: 'nominal', medium: 'media', low: 'baja' };

function Fuente({ texto, enlace, etiqueta }: { texto: string; enlace: string; etiqueta: string }) {
  return <p className="text-xs text-suave">{texto} · <a href={enlace} target="_blank" rel="noopener noreferrer" className="underline underline-offset-4">{etiqueta}</a></p>;
}

const filaDatos = 'grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-3 gap-y-2 text-xs [&_dt]:text-suave [&_dd]:min-w-0 [&_dd]:break-words';

// ---- Capas dentro del mapa ----
function PuntoCritico({ punto, registrar }: { punto: ConDistancia<PuntoCriticoCRA>; registrar?: RegistrarMarcador }) {
  const { distancia } = punto;
  const titulo = `${punto.tipo.nombre} · punto crítico de la C.R.A.`;
  return (
    <Marker ref={(m) => registrar?.(claveMarcador('puntos', punto.id), m)} position={[punto.lat, punto.lon]} icon={iconoCRA('rombo', punto.tipo.color, TriangleAlert)} zIndexOffset={-200} title={titulo} alt={titulo}
      eventHandlers={{ add: (e) => (e.target as L.Marker).getElement()?.setAttribute('aria-label', titulo) }}>
      <Tooltip>{punto.tipo.nombre} · C.R.A.</Tooltip>
      <Popup minWidth={260} maxWidth={290}>
        <div className="space-y-3 text-texto">
          <p className="text-xs font-semibold uppercase tracking-wide text-dorado-300">Punto crítico · C.R.A.</p>
          <h3 className="flex items-center gap-2 pr-6 text-base font-bold"><span aria-hidden="true" className="size-3 shrink-0 rotate-45 rounded-[2px]" style={{ backgroundColor: punto.tipo.color }} />{punto.tipo.nombre}</h3>
          {punto.descripcion && <p className="text-sm">{punto.descripcion}</p>}
          <dl className={filaDatos}>
            <dt>Lugar</dt><dd>{[punto.municipio, punto.zona && `zona ${punto.zona.toLowerCase()}`].filter(Boolean).join(' · ')}</dd>
            {distancia && <><dt>Manglar</dt><dd>{distancia}</dd></>}
            <dt>Registro</dt><dd>{formatoFechaCRA(punto.registrado_en)}</dd>
            <dt>Estado</dt><dd>{punto.confirmado ? 'Confirmado por la C.R.A.' : 'Sin confirmar'}</dd>
          </dl>
          <Fuente texto="Puntos críticos de riesgo de la C.R.A." enlace={VISOR_PUNTOS_CRITICOS} etiqueta="Ver su visor" />
        </div>
      </Popup>
    </Marker>
  );
}

function FocoIncendio({ foco, registrar }: { foco: ConDistancia<FocoIncendioCRA>; registrar?: RegistrarMarcador }) {
  const { distancia } = foco;
  const titulo = `Focos de calor por satélite · ${formatoFechaCRA(foco.hasta)}`;
  return (
    <Marker ref={(m) => registrar?.(claveMarcador('incendios', foco.id), m)} position={[foco.lat, foco.lon]} icon={iconoCRA('circulo', COLOR_FOCO, Flame)} zIndexOffset={-100} title={titulo} alt={titulo}
      eventHandlers={{ add: (e) => (e.target as L.Marker).getElement()?.setAttribute('aria-label', titulo) }}>
      <Tooltip>Focos de calor · {formatoFechaCRA(foco.hasta, false)}</Tooltip>
      <Popup minWidth={260} maxWidth={290}>
        <div className="space-y-3 text-texto">
          <p className="text-xs font-semibold uppercase tracking-wide text-dorado-300">Satélite · C.R.A.</p>
          <h3 className="flex items-center gap-2 pr-6 text-base font-bold"><Flame size={18} color={COLOR_FOCO} aria-hidden="true" />Focos de calor (posible quema)</h3>
          <dl className={filaDatos}>
            <dt>Focos</dt><dd>{foco.focos.toLocaleString('es-CO')}</dd>
            <dt>Fechas</dt><dd>{formatoFechaCRA(foco.desde)} a {formatoFechaCRA(foco.hasta)}</dd>
            <dt>Lugar</dt><dd>{foco.municipio || '—'}</dd>
            {distancia && <><dt>Manglar</dt><dd>{distancia}</dd></>}
            <dt>Satélites</dt><dd>{foco.satelites}</dd>
            <dt>Confianza</dt><dd>{CONFIANZA[foco.confianza] ?? foco.confianza}</dd>
          </dl>
          <p className="text-xs text-suave">Un foco de calor no siempre es un incendio: hay que verificarlo en campo.</p>
          <Fuente texto="Focos de calor agrupados por la C.R.A." enlace={VISOR_GEOVISOR_CRA} etiqueta="Ver su geovisor" />
        </div>
      </Popup>
    </Marker>
  );
}

function PuntoAgua({ punto, registrar }: { punto: CalidadAguaCRA; registrar?: RegistrarMarcador }) {
  const categoria = categoriaICA(punto.ica);
  const color = categoria?.color ?? COLOR_SIN_DATO;
  const titulo = `Calidad del agua · ${punto.cuerpo} (${punto.codigo})`;
  const cifra = (v: number | null, unidad = '') => (v === null ? '—' : `${v.toLocaleString('es-CO', { maximumFractionDigits: 2 })}${unidad}`);
  return (
    <Marker ref={(m) => registrar?.(claveMarcador('agua', punto.id), m)} position={[punto.lat, punto.lon]} icon={iconoCRA('circulo', color, Droplet)} zIndexOffset={-300} title={titulo} alt={titulo}
      eventHandlers={{ add: (e) => (e.target as L.Marker).getElement()?.setAttribute('aria-label', titulo) }}>
      <Tooltip>{punto.cuerpo} · ICA {cifra(punto.ica)}</Tooltip>
      <Popup minWidth={260} maxWidth={290}>
        <div className="space-y-3 text-texto">
          <p className="text-xs font-semibold uppercase tracking-wide text-dorado-300">Calidad del agua · C.R.A.</p>
          <h3 className="pr-6 text-base font-bold">{punto.cuerpo}</h3>
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <span className="text-suave">Índice de calidad (ICA)</span>
            <strong>{cifra(punto.ica)}</strong>
            {categoria && <span className="rounded-full px-2 py-0.5 text-xs font-semibold" style={{ backgroundColor: color, color: tinta(color) }}>{categoria.etiqueta}</span>}
          </div>
          <dl className={filaDatos}>
            <dt>Punto</dt><dd>{punto.codigo}</dd>
            <dt>Oxígeno disuelto</dt><dd>{cifra(punto.od_mg_l, ' mg/L')}</dd>
            <dt>pH</dt><dd>{cifra(punto.ph)}</dd>
            <dt>Temperatura</dt><dd>{cifra(punto.temperatura_c, ' °C')}</dd>
            <dt>Coliformes</dt><dd>{cifra(punto.coliformes_nmp_100ml, ' NMP/100 mL')}</dd>
            <dt>Muestreo</dt><dd>{formatoFechaCRA(punto.muestreado_en)}</dd>
          </dl>
          <Fuente texto="Monitoreo de calidad del agua de la C.R.A. (escala ICA del IDEAM)" enlace={PAGINA_CALIDAD_AGUA} etiqueta="Ver informes" />
        </div>
      </Popup>
    </Marker>
  );
}

export function CapasCRAEnMapa({ capas, registrar }: { capas: EstadoCapasCRA; registrar?: RegistrarMarcador }) {
  const { datos, visibles } = capas;
  const areasFocos = useMemo<FeatureCollection<Polygon | MultiPolygon> | null>(() => datos && datos.incendios.length
    ? { type: 'FeatureCollection', features: datos.incendios.map((f) => ({ type: 'Feature', id: f.id, properties: {}, geometry: f.geometria })) }
    : null, [datos]);
  if (!datos) return null;
  return (
    <>
      {visibles.incendios && areasFocos && <GeoJSON key={`focos-${datos.incendios.length}`} data={areasFocos} interactive={false}
        style={{ color: COLOR_FOCO, weight: 1.5, fillColor: COLOR_FOCO, fillOpacity: 0.35 }} />}
      {visibles.agua && datos.agua.map((p) => <PuntoAgua key={`agua-${p.id}`} punto={p} registrar={registrar} />)}
      {visibles.incendios && datos.incendios.map((f) => <FocoIncendio key={`foco-${f.id}`} foco={f} registrar={registrar} />)}
      {visibles.puntos && datos.puntos.map((p) => <PuntoCritico key={`punto-${p.id}`} punto={p} registrar={registrar} />)}
    </>
  );
}

// ---- Panel de filtros y leyenda ----
export function InterruptoresCRA({ capas, claves = TODAS_LAS_CAPAS }: { capas: EstadoCapasCRA; claves?: ClaveCapaCRA[] }) {
  const { datos, error, visibles, alternar, reintentar } = capas;
  const opciones = ([
    { clave: 'puntos', etiqueta: 'Puntos críticos de riesgo', cantidad: datos?.puntos.length },
    { clave: 'incendios', etiqueta: 'Focos de calor por satélite', cantidad: datos?.incendios.length },
    { clave: 'agua', etiqueta: 'Calidad del agua (ICA)', cantidad: datos?.agua.length },
  ] as { clave: ClaveCapaCRA; etiqueta: string; cantidad?: number }[]).filter((o) => claves.includes(o.clave));
  return (
    <fieldset className="mt-3">
      <legend className="mb-1 text-xs font-semibold text-suave">Capas oficiales de la C.R.A. · en vivo</legend>
      {!datos && (error
        ? <p role="status" className="text-xs text-suave">La C.R.A. no respondió; el mapa sigue sin sus capas. <button type="button" onClick={reintentar} className="min-h-11 font-semibold text-dorado-300 underline underline-offset-4">Reintentar</button></p>
        : <p role="status" className="text-xs text-suave">Consultando la C.R.A.…</p>)}
      {datos && <div className="flex flex-wrap gap-x-4">{opciones.map(({ clave, etiqueta, cantidad }) => (
        <label key={clave} className="flex min-h-11 cursor-pointer items-center gap-2 text-xs font-medium text-texto">
          <input type="checkbox" role="switch" checked={visibles[clave]} onChange={() => alternar(clave)} className="size-4 accent-dorado-500" />
          {etiqueta}{cantidad !== undefined && <span className="text-suave">({cantidad})</span>}
        </label>
      ))}</div>}
    </fieldset>
  );
}

export function LeyendaCRA({ capas, claves = TODAS_LAS_CAPAS }: { capas: EstadoCapasCRA; claves?: ClaveCapaCRA[] }) {
  const { datos } = capas;
  const resumen = useMemo(() => {
    if (!datos) return null;
    const fechas = (lista: string[]) => (lista.length ? [lista.reduce((a, b) => (a < b ? a : b)), lista.reduce((a, b) => (a > b ? a : b))] : null);
    const tiposPresentes = datos.tipos.filter((t) => datos.puntos.some((p) => p.tipo.id === t.id));
    return {
      tiposPresentes,
      puntos: fechas(datos.puntos.map((p) => p.registrado_en)),
      focos: fechas(datos.incendios.flatMap((f) => [f.desde, f.hasta])),
      agua: fechas(datos.agua.flatMap((p) => (p.muestreado_en ? [p.muestreado_en] : []))),
    };
  }, [datos]);
  if (!datos || !resumen) return null;
  const rango = (r: string[] | null) => (r ? (r[0].slice(0, 10) === r[1].slice(0, 10) ? formatoFechaCRA(r[0]) : `${formatoFechaCRA(r[0])} a ${formatoFechaCRA(r[1])}`) : 'sin datos');
  return (
    <div>
      <h3 className="mb-2 font-semibold text-texto">Capas oficiales de la C.R.A. · en vivo</h3>
      {(claves.includes('puntos') || claves.includes('incendios')) && <ul className="flex flex-wrap gap-3">
        {claves.includes('puntos') && resumen.tiposPresentes.map((t) => <li key={t.id} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className="size-2.5 rotate-45 rounded-[2px]" style={{ backgroundColor: t.color }} />{t.nombre}</li>)}
        {claves.includes('incendios') && <li className="flex items-center gap-1.5 text-suave"><Flame size={14} color={COLOR_FOCO} aria-hidden="true" />Focos de calor</li>}
      </ul>}
      {claves.includes('agua') && <ul className="mt-2 flex flex-wrap gap-3" aria-label="Escala del índice de calidad del agua">
        {ESCALA_ICA.map((c) => <li key={c.etiqueta} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className="size-2.5 rounded-full" style={{ backgroundColor: c.color }} />Agua {c.etiqueta.toLowerCase()}</li>)}
      </ul>}
      <p className="mt-2 text-suave">
        {datos.filtradas ? `Solo lo que está a ${(RADIO_CONTEXTO_M / 1000).toLocaleString('es-CO')} km o menos del manglar${claves.includes('agua') ? ' (y el agua de las ciénagas con manglar)' : ''}. ` : 'Sin la cobertura de manglar no se pudo filtrar: se muestra toda la franja costera. '}
        {[
          claves.includes('puntos') && `puntos críticos: ${rango(resumen.puntos)}`,
          claves.includes('incendios') && `focos de calor: ${rango(resumen.focos)}`,
          claves.includes('agua') && `calidad del agua: muestreo del ${rango(resumen.agua)}`,
        ].filter(Boolean).join(' · ').replace(/^./, (c) => c.toUpperCase())}. Fuente: API de gestión del riesgo de la C.R.A., leída al abrir esta página.
      </p>
    </div>
  );
}
