// Mapa de /admin: de dónde salen los reportes de la comunidad (app, WhatsApp y web), leídos en vivo del
// servidor común (vista pública: ubicación difuminada, sin quién reporta). Color por prioridad, filtro por
// canal y por período, y a la derecha cuántos llegan de cada sector y de cada canal.
import { useEffect, useMemo, useState } from 'react';
import L from 'leaflet';
import { CircleMarker, GeoJSON, MapContainer, Pane, Popup, TileLayer, ZoomControl, useMap } from 'react-leaflet';
import type { CapaManglarCRA, Canal, ReportePublico } from '../../types/manglar';
import { CANALES, ESTADOS, LISTA_CANALES, LISTA_PRIORIDADES, PRIORIDADES, TIPOS, formatearFecha, nivelPrioridad } from '../../lib/catalogos';
import { useReportesPublicos, estadoDelServidor } from '../../lib/reportesStore';
import { obtenerCapaManglarCRA } from '../../lib/datos';
import { LIMITES_MANGLAR } from '../../lib/areaReporte';
import { cn } from '../../lib/utils';
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';

type Periodo = 7 | 30 | 0;
const SIN_REPORTES: ReportePublico[] = [];
const chip = (activo: boolean) => cn('inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full border px-4 text-sm font-semibold transition-colors',
  activo ? 'border-dorado-500 bg-dorado-500 text-cra-950' : 'border-linea bg-white/5 text-suave hover:border-dorado-300 hover:text-texto');

/** Encuadra los reportes visibles (o la franja del manglar si no hay). */
function Encuadrar({ puntos }: { puntos: [number, number][] }) {
  const mapa = useMap();
  const clave = puntos.length;
  useEffect(() => {
    if (puntos.length > 1) mapa.fitBounds(L.latLngBounds(puntos), { padding: [40, 40], maxZoom: 13 });
    else if (puntos.length === 1) mapa.setView(puntos[0], 13);
    else mapa.fitBounds(LIMITES_MANGLAR);
  }, [mapa, clave]); // eslint-disable-line react-hooks/exhaustive-deps
  return null;
}

export default function MapaReportesAdmin() {
  const reportes = useReportesPublicos(SIN_REPORTES);
  const [canal, setCanal] = useState<Canal | 'todos'>('todos');
  const [periodo, setPeriodo] = useState<Periodo>(30);
  const [manglar, setManglar] = useState<CapaManglarCRA | null>(null);
  useEffect(() => { let activo = true; obtenerCapaManglarCRA().then((c) => { if (activo) setManglar(c); }).catch(() => {}); return () => { activo = false; }; }, []);

  const enPeriodo = useMemo(() => reportes.filter((r) => periodo === 0 || Date.now() - Date.parse(r.capturado_en) <= periodo * 86_400_000), [reportes, periodo]);
  const visibles = useMemo(() => enPeriodo.filter((r) => canal === 'todos' || r.canal === canal), [enPeriodo, canal]);
  const porCanal = useMemo(() => Object.fromEntries(LISTA_CANALES.map((c) => [c, enPeriodo.filter((r) => r.canal === c).length])) as Record<Canal, number>, [enPeriodo]);
  const porSector = useMemo(() => {
    const m = new Map<string, number>();
    for (const r of visibles) { const k = r.dentro_poligono || r.zona ? (r.zona ?? 'Sin sector') : 'Fuera de los sectores'; m.set(k, (m.get(k) ?? 0) + 1); }
    return [...m].sort((a, b) => b[1] - a[1]);
  }, [visibles]);
  const estado = estadoDelServidor();

  return (
    <div className="grid gap-4">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Canal">
          <button type="button" aria-pressed={canal === 'todos'} onClick={() => setCanal('todos')} className={chip(canal === 'todos')}>Todos <span className="tabular-nums opacity-80">({enPeriodo.length})</span></button>
          {LISTA_CANALES.map((c) => { const I = CANALES[c].icono; return (
            <button key={c} type="button" aria-pressed={canal === c} onClick={() => setCanal(c)} className={chip(canal === c)}><I className="size-4" aria-hidden="true" />{CANALES[c].etiqueta} <span className="tabular-nums opacity-80">({porCanal[c]})</span></button>
          ); })}
        </div>
        <div className="inline-flex shrink-0 self-start rounded-full border border-linea bg-white/5 p-1" role="group" aria-label="Período">
          {([[7, '7 días'], [30, '30 días'], [0, 'Todo']] as const).map(([v, t]) => (
            <button key={v} type="button" aria-pressed={periodo === v} onClick={() => setPeriodo(v)} className={cn('min-h-10 rounded-full px-4 text-sm font-semibold', periodo === v ? 'bg-white text-cra-950' : 'text-suave hover:text-texto')}>{t}</button>
          ))}
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_18rem]">
        <div role="region" aria-label="Mapa de los reportes de la comunidad" className="relative isolate h-[440px] overflow-hidden rounded-3xl ring-1 ring-linea sm:h-[520px]">
          <MapContainer maxBounds={LIMITES_MANGLAR} maxBoundsViscosity={1} minZoom={9} center={[10.93, -74.99]} zoom={10} scrollWheelZoom={false} zoomControl={false} className="h-full w-full">
            <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
            <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
            <Pane name="manglar-admin" style={{ zIndex: 350 }}>
              {manglar && <GeoJSON data={manglar} interactive={false} style={{ fillColor: '#d946ef', fillOpacity: 0.35, color: '#f0abfc', weight: 0.6 }} />}
            </Pane>
            <Encuadrar puntos={visibles.map((r): [number, number] => [r.lat, r.lon])} />
            {visibles.map((r) => {
              const nivel = nivelPrioridad(r.prioridad);
              return (
                <CircleMarker key={r.id} center={[r.lat, r.lon]} radius={9} pathOptions={{ color: '#ffffff', weight: 2, fillColor: PRIORIDADES[nivel].color, fillOpacity: 0.95 }}>
                  <Popup minWidth={230}>
                    <div className="space-y-1.5 text-texto">
                      <p className="font-bold">{TIPOS[r.tipo].etiquetaLarga}</p>
                      <p className="text-xs text-suave">{CANALES[r.canal].etiqueta} · {ESTADOS[r.estado].etiqueta} · prioridad {PRIORIDADES[nivel].etiqueta.toLowerCase()}</p>
                      <p className="text-xs text-suave">{r.zona ?? 'Fuera de los sectores'}{r.municipio ? ` · ${r.municipio}` : ''}</p>
                      <p className="text-xs text-tenue">{formatearFecha(r.capturado_en)} · ubicación aproximada</p>
                    </div>
                  </Popup>
                </CircleMarker>
              );
            })}
          </MapContainer>
          {visibles.length === 0 && <p role="status" className="pointer-events-none absolute inset-x-4 top-4 z-[500] rounded-2xl bg-fondo-alt/95 px-4 py-2 text-sm text-suave">
            {estado === 'cargando' ? 'Leyendo los reportes del servidor…' : estado === 'error' ? 'No se pudo leer el servidor de reportes.' : 'No hay reportes con estos filtros.'}
          </p>}
        </div>

        <aside className="grid content-start gap-4 rounded-3xl border border-linea bg-white/5 p-5" aria-label="Resumen de los reportes del mapa">
          <div>
            <p className="titular text-4xl tabular-nums">{visibles.length}</p>
            <p className="text-sm text-suave">{visibles.length === 1 ? 'reporte' : 'reportes'} {periodo ? `en ${periodo} días` : 'en total'}{canal !== 'todos' ? ` por ${CANALES[canal].etiqueta}` : ''}</p>
          </div>
          <div>
            <h3 className="rotulo text-dorado-300">Por sector</h3>
            {porSector.length === 0 ? <p className="mt-2 text-sm text-tenue">Sin reportes.</p> : (
              <ul className="mt-2 grid gap-1.5">
                {porSector.map(([s, n]) => (
                  <li key={s} className="flex items-center justify-between gap-3 text-sm"><span className="min-w-0 truncate text-suave">{s}</span><span className="font-bold tabular-nums">{n}</span></li>
                ))}
              </ul>
            )}
          </div>
          <div>
            <h3 className="rotulo text-dorado-300">Prioridad</h3>
            <ul className="mt-2 flex flex-wrap gap-3 text-sm text-suave">
              {LISTA_PRIORIDADES.map((p) => <li key={p} className="flex items-center gap-1.5"><span aria-hidden="true" className="size-2.5 rounded-full" style={{ backgroundColor: PRIORIDADES[p].color }} />{PRIORIDADES[p].etiqueta}</li>)}
            </ul>
          </div>
          <p className="text-xs text-tenue">Reportes del servidor común (app, WhatsApp y web), sin los descartados. La ubicación es aproximada para proteger a quien reporta. La mancha rosada es la cobertura de manglar de la C.R.A.</p>
        </aside>
      </div>
    </div>
  );
}
