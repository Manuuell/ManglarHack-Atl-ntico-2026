// Visor de página completa para las capas oficiales de la C.R.A.:
// - «riesgo»: puntos críticos de riesgo y focos de calor cerca del manglar;
// - «agua»: calidad del agua (ICA) de las ciénagas con manglar.
// Mapa a la izquierda y lista a la derecha (debajo en el teléfono); al tocar un
// elemento de la lista, el mapa vuela hasta él y abre su ventana.
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import '../../lib/popupsQueCaben';
import L from 'leaflet';
import { GeoJSON, MapContainer, Pane, TileLayer, ZoomControl, useMap } from 'react-leaflet';
import { Flame } from 'lucide-react';
import type { CapaManglarCRA } from '../../types/manglar';
import { FUENTE_MANGLAR_CRA, obtenerCapaManglarCRA } from '../../lib/datos';
import { LIMITES_MANGLAR } from '../../lib/areaReporte';
import {
  COLOR_SIN_DATO, PAGINA_CALIDAD_AGUA, VISOR_GEOVISOR_CRA, VISOR_PUNTOS_CRITICOS, categoriaICA, formatoFechaCRA,
  type CalidadAguaCRA, type FocoIncendioCRA, type PuntoCriticoCRA,
} from '../../lib/craApi';
import {
  COLOR_FOCO, CapasCRAEnMapa, InterruptoresCRA, LeyendaCRA, claveMarcador, tinta, useCapasCRA,
  type ClaveCapaCRA, type ConDistancia, type RegistrarMarcador,
} from '../mapa/CapasOficialesCRA';
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';

type Modo = 'riesgo' | 'agua';
const CAPAS: Record<Modo, ClaveCapaCRA[]> = { riesgo: ['puntos', 'incendios'], agua: ['agua'] };

const tarjeta = 'w-full rounded-2xl bg-white/5 p-3 text-left ring-1 ring-linea transition-colors hover:bg-white/10 focus-visible:bg-white/10';
const cifra = (v: number | null) => (v === null ? '—' : v.toLocaleString('es-CO', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));

/** Encuadra el mapa en la cobertura de manglar la primera vez que llega. */
function AjustarAlManglar({ manglar }: { manglar: CapaManglarCRA | null }) {
  const mapa = useMap();
  const listo = useRef(false);
  useEffect(() => {
    if (!manglar || listo.current) return;
    listo.current = true;
    mapa.fitBounds(L.geoJSON(manglar).getBounds(), { padding: [24, 24] });
  }, [mapa, manglar]);
  return null;
}

export default function VisorCapasCRA({ modo }: { modo: Modo }) {
  const [manglar, setManglar] = useState<CapaManglarCRA | null>(null);
  const [errorManglar, setErrorManglar] = useState(false);
  useEffect(() => {
    let activo = true;
    obtenerCapaManglarCRA().then((c) => { if (activo) setManglar(c); }).catch(() => { if (activo) setErrorManglar(true); });
    return () => { activo = false; };
  }, []);
  const claves = CAPAS[modo];
  const capas = useCapasCRA(manglar, errorManglar, { puntos: claves.includes('puntos'), incendios: claves.includes('incendios'), agua: claves.includes('agua') });
  const { datos } = capas;

  const [mapa, setMapa] = useState<L.Map | null>(null);
  const contenedorMapa = useRef<HTMLDivElement>(null);
  const marcadores = useRef(new Map<string, L.Marker>());
  const registrar = useCallback<RegistrarMarcador>((clave, marcador) => {
    if (marcador) marcadores.current.set(clave, marcador); else marcadores.current.delete(clave);
  }, []);

  const enfocar = useCallback((capa: ClaveCapaCRA, id: number, lat: number, lon: number) => {
    if (!mapa) return;
    if (!capas.visibles[capa]) capas.alternar(capa);
    const reducido = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (window.matchMedia('(max-width: 1023px)').matches) contenedorMapa.current?.scrollIntoView({ behavior: reducido ? 'auto' : 'smooth', block: 'center' });
    mapa.once('moveend', () => marcadores.current.get(claveMarcador(capa, id))?.openPopup());
    mapa.flyTo([lat, lon], Math.max(mapa.getZoom(), 14), { duration: reducido ? 0 : 0.8 });
  }, [mapa, capas]);

  const verVarios = useCallback((puntos: { lat: number; lon: number }[]) => {
    if (!mapa || !puntos.length) return;
    if (window.matchMedia('(max-width: 1023px)').matches) contenedorMapa.current?.scrollIntoView({ block: 'center' });
    mapa.flyToBounds(L.latLngBounds(puntos.map((p): L.LatLngTuple => [p.lat, p.lon])), { padding: [48, 48], maxZoom: 15, duration: 0.8 });
  }, [mapa]);

  const etiquetaMapa = modo === 'riesgo' ? 'Mapa de puntos críticos y focos de calor cerca del manglar' : 'Mapa de la calidad del agua de las ciénagas con manglar';

  return (
    <div className="relative isolate grid gap-4 lg:grid-cols-[minmax(0,1fr)_380px]">
      <div className="min-w-0 space-y-3">
        <div className="rounded-sm bg-superficie/95 px-4 pb-1 pt-1 shadow-[var(--c-sombra-alta)]">
          <InterruptoresCRA capas={capas} claves={claves} />
        </div>
        <div ref={contenedorMapa} role="region" aria-label={etiquetaMapa}
          className="h-[60vh] min-h-[420px] overflow-hidden rounded-sm shadow-[var(--c-sombra)] ring-1 ring-linea lg:h-[calc(100dvh-15rem)]">
          <MapContainer ref={setMapa} maxBounds={LIMITES_MANGLAR} maxBoundsViscosity={1} minZoom={9} center={[10.93, -74.99]} zoom={11} scrollWheelZoom zoomControl={false} className="h-full w-full">
            <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
            <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
            <Pane name="cobertura-manglar" style={{ zIndex: 350 }}>
              {manglar && <GeoJSON data={manglar} interactive={false} style={{ fillColor: '#d946ef', fillOpacity: 0.45, color: '#f0abfc', weight: 0.8 }} />}
            </Pane>
            <AjustarAlManglar manglar={manglar} />
            <CapasCRAEnMapa capas={capas} registrar={registrar} />
          </MapContainer>
        </div>
        <div aria-label="Leyenda del mapa" className="space-y-3 rounded-sm bg-superficie/95 p-4 text-xs shadow-[var(--c-sombra-alta)]">
          <div>
            <h3 className="font-semibold text-texto">Cobertura de manglar · C.R.A. 1:5.000</h3>
            <p className="text-suave">{manglar ? `${FUENTE_MANGLAR_CRA}.` : errorManglar ? 'No se pudo cargar la cobertura de manglar de la C.R.A.' : 'Cargando la cobertura de manglar…'}</p>
          </div>
          <LeyendaCRA capas={capas} claves={claves} />
        </div>
      </div>

      <aside className="min-w-0 lg:sticky lg:top-24 lg:max-h-[calc(100dvh-7rem)] lg:overflow-y-auto lg:pr-1" aria-label={modo === 'riesgo' ? 'Lista de riesgos' : 'Lista de ciénagas'}>
        {!datos && <p role="status" className="rounded-2xl bg-white/5 p-4 text-sm text-suave ring-1 ring-linea">{capas.error ? 'La C.R.A. no respondió. Prueba de nuevo en un momento.' : 'Consultando la C.R.A.…'}</p>}
        {datos && modo === 'riesgo' && <ListaRiesgo puntos={datos.puntos} focos={datos.incendios} enfocar={enfocar} />}
        {datos && modo === 'agua' && <ListaAgua agua={datos.agua} enfocar={enfocar} verVarios={verVarios} />}
      </aside>
    </div>
  );
}

type Enfocar = (capa: ClaveCapaCRA, id: number, lat: number, lon: number) => void;
const porDistancia = (a: { distancia_m: number | null }, b: { distancia_m: number | null }) => (a.distancia_m ?? Infinity) - (b.distancia_m ?? Infinity);

function ListaRiesgo({ puntos, focos, enfocar }: {
  puntos: ConDistancia<PuntoCriticoCRA>[];
  focos: ConDistancia<FocoIncendioCRA>[];
  enfocar: Enfocar;
}) {
  const ordenados = useMemo(() => [...puntos].sort(porDistancia), [puntos]);
  const focosOrdenados = useMemo(() => [...focos].sort(porDistancia), [focos]);
  return (
    <div className="space-y-6">
      <section aria-labelledby="titulo-lista-puntos">
        <h2 id="titulo-lista-puntos" className="text-lg font-bold">Puntos críticos <span className="font-normal text-suave">({ordenados.length})</span></h2>
        <p className="mt-1 text-xs text-suave">Del más cercano al manglar al más lejano. Toca uno para verlo en el mapa. <a href={VISOR_PUNTOS_CRITICOS} target="_blank" rel="noopener noreferrer" className="underline underline-offset-4">Visor de la C.R.A.</a></p>
        {ordenados.length === 0 && <p className="mt-3 text-sm text-suave">No hay puntos críticos registrados cerca del manglar.</p>}
        <ul className="mt-3 space-y-2">
          {ordenados.map((p) => (
            <li key={p.id}>
              <button type="button" className={tarjeta} onClick={() => enfocar('puntos', p.id, p.lat, p.lon)}>
                <span className="flex items-center gap-2 text-sm font-semibold"><span aria-hidden="true" className="size-2.5 shrink-0 rotate-45 rounded-[2px]" style={{ backgroundColor: p.tipo.color }} />{p.tipo.nombre}</span>
                <span className="mt-1 block text-xs text-suave">{[p.municipio, p.distancia, formatoFechaCRA(p.registrado_en)].filter(Boolean).join(' · ')}</span>
                {p.descripcion && <span className="mt-1.5 line-clamp-2 text-sm text-texto">{p.descripcion}</span>}
              </button>
            </li>
          ))}
        </ul>
      </section>
      <section aria-labelledby="titulo-lista-focos">
        <h2 id="titulo-lista-focos" className="text-lg font-bold">Focos de calor <span className="font-normal text-suave">({focosOrdenados.length})</span></h2>
        <p className="mt-1 text-xs text-suave">Detectados por satélite y agrupados por la C.R.A. Un foco de calor no siempre es un incendio. <a href={VISOR_GEOVISOR_CRA} target="_blank" rel="noopener noreferrer" className="underline underline-offset-4">Geovisor de la C.R.A.</a></p>
        {focosOrdenados.length === 0 && <p className="mt-3 text-sm text-suave">No hay focos de calor recientes cerca del manglar.</p>}
        <ul className="mt-3 space-y-2">
          {focosOrdenados.map((f) => (
            <li key={f.id}>
              <button type="button" className={tarjeta} onClick={() => enfocar('incendios', f.id, f.lat, f.lon)}>
                <span className="flex items-center gap-2 text-sm font-semibold"><Flame size={16} color={COLOR_FOCO} aria-hidden="true" />{f.focos.toLocaleString('es-CO')} focos en {f.municipio || 'la costa'}</span>
                <span className="mt-1 block text-xs text-suave">{[`${formatoFechaCRA(f.desde)} a ${formatoFechaCRA(f.hasta)}`, f.distancia].filter(Boolean).join(' · ')}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

interface Cienaga { nombre: string; puntos: CalidadAguaCRA[]; media: number | null; min: number | null; max: number | null; fecha: string | null }

function ListaAgua({ agua, enfocar, verVarios }: { agua: CalidadAguaCRA[]; enfocar: Enfocar; verVarios: (p: { lat: number; lon: number }[]) => void }) {
  const cienagas = useMemo<Cienaga[]>(() => {
    const grupos = new Map<string, CalidadAguaCRA[]>();
    for (const p of agua) grupos.set(p.cuerpo, [...(grupos.get(p.cuerpo) ?? []), p]);
    return [...grupos].map(([nombre, puntos]) => {
      const icas = puntos.flatMap((p) => (p.ica === null ? [] : [p.ica]));
      return {
        nombre, puntos: [...puntos].sort((a, b) => a.codigo.localeCompare(b.codigo, 'es', { numeric: true })),
        media: icas.length ? icas.reduce((s, v) => s + v, 0) / icas.length : null,
        min: icas.length ? Math.min(...icas) : null, max: icas.length ? Math.max(...icas) : null,
        fecha: puntos.map((p) => p.muestreado_en).filter(Boolean).sort().at(-1) ?? null,
      };
    }).sort((a, b) => (a.media ?? Infinity) - (b.media ?? Infinity));
  }, [agua]);
  return (
    <section aria-labelledby="titulo-lista-agua">
      <h2 id="titulo-lista-agua" className="text-lg font-bold">Ciénagas y cuerpos de agua <span className="font-normal text-suave">({cienagas.length})</span></h2>
      <p className="mt-1 text-xs text-suave">Índice de calidad del agua (ICA) del IDEAM, de 0 (muy mala) a 1 (buena): promedio de los puntos de muestreo de la C.R.A., de la peor a la mejor. <a href={PAGINA_CALIDAD_AGUA} target="_blank" rel="noopener noreferrer" className="underline underline-offset-4">Informes de la C.R.A.</a></p>
      {cienagas.length === 0 && <p className="mt-3 text-sm text-suave">No hay mediciones de calidad del agua cerca del manglar.</p>}
      <ul className="mt-3 space-y-3">
        {cienagas.map((c) => {
          const categoria = categoriaICA(c.media);
          return (
            <li key={c.nombre} className="rounded-2xl bg-white/5 p-4 ring-1 ring-linea">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="font-semibold">{c.nombre}</h3>
                  <p className="text-xs text-suave">{c.puntos.length} {c.puntos.length === 1 ? 'punto' : 'puntos'} · {c.min === c.max ? `ICA ${cifra(c.min)}` : `ICA de ${cifra(c.min)} a ${cifra(c.max)}`} · {formatoFechaCRA(c.fecha)}</p>
                </div>
                <div className="shrink-0 text-right">
                  <p className="text-2xl font-extrabold leading-none">{cifra(c.media)}</p>
                  {categoria && <span className="mt-1 inline-block rounded-full px-2 py-0.5 text-xs font-semibold" style={{ backgroundColor: categoria.color, color: tinta(categoria.color) }}>{categoria.etiqueta}</span>}
                </div>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                <button type="button" onClick={() => verVarios(c.puntos)} className="min-h-11 rounded-full px-3 text-xs font-semibold text-dorado-300 underline underline-offset-4">Ver en el mapa</button>
                {c.puntos.map((p) => {
                  const cat = categoriaICA(p.ica);
                  return (
                    <button key={p.id} type="button" onClick={() => enfocar('agua', p.id, p.lat, p.lon)} aria-label={`Punto ${p.codigo}, ICA ${cifra(p.ica)}${cat ? `, ${cat.etiqueta.toLowerCase()}` : ''}`}
                      className="inline-flex min-h-11 items-center gap-1.5 rounded-full bg-white/5 px-3 text-xs ring-1 ring-linea hover:bg-white/10">
                      <span aria-hidden="true" className="size-2.5 rounded-full" style={{ backgroundColor: cat?.color ?? COLOR_SIN_DATO }} />{p.codigo} · {cifra(p.ica)}
                    </button>
                  );
                })}
              </div>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
