// Mapa de la plataforma abierta: plan de manejo de la C.R.A., manglar de
// referencia, sectores, acciones y reportes ciudadanos. Solo cliente
// (client:only="react"): importa Leaflet.
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';
import { useEffect, useMemo, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { divIcon, geoJSON, type Layer, type LeafletMouseEvent, type PathOptions } from 'leaflet';
import { CircleMarker, GeoJSON, MapContainer, Marker, Pane, Popup, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet';
import type { Feature, Geometry } from 'geojson';
import type { CapaPrioridades, PropiedadesPrioridad, ReportePublico, ZonasManglar } from '../../types/manglar';
import type { Accion } from '../../types/plataforma';
import { obtenerCapaManglarCRA, obtenerCapaPrioridades } from '../../lib/datos';
import { ACCIONES_PLAN, ESTADOS_ACCION, SECTORES, TIPOS_ACCION } from '../../lib/plataforma/catalogos';
import { ESTADOS, PRIORIDADES, TIPOS, nivelPrioridad } from '../../lib/catalogos';
import { cn } from '../../lib/utils';

export interface PuntoMapa { lat: number; lon: number }
interface Props {
  zonas: ZonasManglar;
  acciones?: Accion[];
  reportes?: ReportePublico[];
  modo?: 'ver' | 'marcar';
  punto?: PuntoMapa | null;
  alMarcar?: (p: PuntoMapa) => void;
  alCargarPrioridades?: (capa: CapaPrioridades | null) => void;
  alto?: string;
}

const OPACIDAD_PRIORIDAD: Record<PropiedadesPrioridad['prioridad'], number> = { alta: 0.6, media: 0.42, baja: 0.25 };
const iconos = new Map<string, ReturnType<typeof divIcon>>();
function iconoAccion(tipo: Accion['tipo']) {
  if (!iconos.has(tipo)) {
    const Icono = TIPOS_ACCION[tipo].icono;
    const svg = renderToStaticMarkup(<Icono size={14} color="#05243a" strokeWidth={2.5} aria-hidden="true" />);
    iconos.set(tipo, divIcon({ className: 'pin-reporte', html: `<span style="display:grid;place-items:center;width:26px;height:26px;background:#edb512;border:2px solid #05243a;box-shadow:0 2px 6px rgb(0 0 0/.45)">${svg}</span>`, iconSize: [26, 26], iconAnchor: [13, 13], popupAnchor: [0, -14] }));
  }
  return iconos.get(tipo)!;
}
const iconoPunto = divIcon({ className: 'pin-reporte', html: '<span style="display:block;width:22px;height:22px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:#f8d86f;border:3px solid #05243a;box-shadow:0 2px 8px rgb(0 0 0/.5)"></span>', iconSize: [22, 22], iconAnchor: [11, 22] });

function Encuadre({ zonas }: { zonas: ZonasManglar }) {
  const mapa = useMap();
  useEffect(() => {
    const limites = geoJSON(zonas).getBounds();
    let hecho = false;
    const encuadrar = () => {
      const { x, y } = mapa.getSize();
      if (hecho || !x || !y || !limites.isValid()) return;
      mapa.fitBounds(limites, { padding: [24, 24] });
      hecho = true;
    };
    encuadrar();
    const observador = new ResizeObserver(() => { mapa.invalidateSize(); encuadrar(); });
    observador.observe(mapa.getContainer());
    return () => observador.disconnect();
  }, [mapa, zonas]);
  return null;
}

function Marcador({ activo, alMarcar }: { activo: boolean; alMarcar?: (p: PuntoMapa) => void }) {
  const mapa = useMap();
  useEffect(() => { mapa.getContainer().style.cursor = activo ? 'crosshair' : ''; }, [mapa, activo]);
  useMapEvents({ click: (e: LeafletMouseEvent) => { if (activo && alMarcar) alMarcar({ lat: e.latlng.lat, lon: e.latlng.lng }); } });
  return null;
}

type EstadoCapa<T> = { estado: 'cargando' } | { estado: 'lista'; capa: T } | { estado: 'error' };

export default function MapaPlataforma({ zonas, acciones = [], reportes = [], modo = 'ver', punto = null, alMarcar, alCargarPrioridades, alto = '560px' }: Props) {
  const marcar = modo === 'marcar';
  const [plan, setPlan] = useState<EstadoCapa<CapaPrioridades>>({ estado: 'cargando' });
  const [manglar, setManglar] = useState<EstadoCapa<Awaited<ReturnType<typeof obtenerCapaManglarCRA>>>>({ estado: 'cargando' });
  const [ver, setVer] = useState({ plan: true, manglar: true, sectores: true, acciones: true, reportes: true });

  useEffect(() => {
    let vivo = true;
    obtenerCapaPrioridades()
      .then((capa) => { if (vivo) { setPlan({ estado: 'lista', capa }); alCargarPrioridades?.(capa); } })
      .catch(() => { if (vivo) { setPlan({ estado: 'error' }); alCargarPrioridades?.(null); } });
    obtenerCapaManglarCRA()
      .then((capa) => { if (vivo) setManglar({ estado: 'lista', capa }); })
      .catch(() => { if (vivo) setManglar({ estado: 'error' }); });
    return () => { vivo = false; };
    // Las capas se piden una sola vez.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const estiloPlan = useMemo(() => (f?: Feature<Geometry, PropiedadesPrioridad>): PathOptions => {
    const p = f?.properties;
    const color = p ? ACCIONES_PLAN[p.accion].color : '#9ca3af';
    return { color, weight: 0.4, opacity: 0.8, fillColor: color, fillOpacity: p ? OPACIDAD_PRIORIDAD[p.prioridad] : 0.3 };
  }, []);
  const popupPlan = (f: Feature<Geometry, PropiedadesPrioridad>, capa: Layer) => {
    const p = f.properties;
    const filas = [
      ['Acción del plan', ACCIONES_PLAN[p.accion].etiqueta],
      ['Prioridad', p.prioridad === 'alta' ? 'Alta' : p.prioridad === 'media' ? 'Media' : 'Baja'],
      ['Unidad hidrográfica', p.unidad],
      ['Escenario', p.escenario],
      ['Figura', p.figura],
      ['Área protegida', p.area_protegida],
    ].filter(([, v]) => v);
    const div = document.createElement('div');
    div.innerHTML = `<p style="font-weight:900;text-transform:uppercase;letter-spacing:.08em;font-size:11px;color:#f8d86f;margin:0 0 6px">Prioridades de conservación · C.R.A.</p>`;
    for (const [k, v] of filas) {
      const fila = document.createElement('p');
      fila.style.margin = '2px 0';
      const b = document.createElement('strong'); b.textContent = `${k}: `;
      fila.append(b, document.createTextNode(String(v)));
      div.append(fila);
    }
    capa.bindPopup(div);
  };

  const conmutador = (clave: keyof typeof ver, texto: string, muestra: string, deshabilitado = false) => (
    <label className={cn('flex min-h-9 items-center gap-2 text-xs', deshabilitado && 'opacity-50')}>
      <input type="checkbox" className="size-4 accent-dorado-500" checked={ver[clave]} disabled={deshabilitado} onChange={(e) => setVer((v) => ({ ...v, [clave]: e.target.checked }))} />
      <span aria-hidden="true" className={cn('inline-block h-3 w-4 border', muestra)} />
      {texto}
    </label>
  );

  return (
    <div className="mapa-plataforma relative z-0">
      <div className="relative overflow-hidden border border-linea" style={{ height: alto }}>
        <MapContainer center={[10.93, -75.02]} zoom={10} preferCanvas scrollWheelZoom={false} zoomControl className="h-full w-full" aria-label="Mapa del manglar y de las acciones">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
          <Encuadre zonas={zonas} />
          <Marcador activo={marcar} alMarcar={alMarcar} />
          <Pane name="plan" style={{ zIndex: 340 }}>
            {ver.plan && plan.estado === 'lista' && (
              <GeoJSON data={plan.capa} style={estiloPlan as (f?: Feature) => PathOptions} interactive={!marcar} onEachFeature={marcar ? undefined : (popupPlan as (f: Feature, l: Layer) => void)} />
            )}
          </Pane>
          <Pane name="manglar" style={{ zIndex: 350 }}>
            {ver.manglar && manglar.estado === 'lista' && (
              <GeoJSON data={manglar.capa} interactive={false} style={{ color: '#f0abfc', weight: 0.8, fillColor: '#d946ef', fillOpacity: 0.55 }} />
            )}
          </Pane>
          <Pane name="sectores" style={{ zIndex: 360 }}>
            {ver.sectores && zonas.features.map((z) => (
              <GeoJSON key={z.properties.id} data={z} interactive={!marcar} style={{ color: '#ffffff', weight: 1.5, dashArray: '6 4', fillOpacity: 0 }}>
                {!marcar && <Tooltip sticky>{SECTORES[z.properties.id as keyof typeof SECTORES]?.largo ?? z.properties.nombre}</Tooltip>}
              </GeoJSON>
            ))}
          </Pane>
          {ver.reportes && reportes.map((r) => (
            <CircleMarker key={r.id} center={[r.lat, r.lon]} radius={6} interactive={!marcar} pathOptions={{ color: '#ffffff', weight: 1.5, fillColor: PRIORIDADES[nivelPrioridad(r.prioridad)].color, fillOpacity: 0.95 }}>
              <Popup>
                <strong>{TIPOS[r.tipo].etiquetaLarga}</strong><br />
                {r.zona ?? 'Fuera de sector'} · {ESTADOS[r.estado].etiqueta}<br />
                <span style={{ opacity: 0.75 }}>Reporte ciudadano · ubicación aproximada</span>
              </Popup>
            </CircleMarker>
          ))}
          {ver.acciones && acciones.map((a) => (
            <Marker key={a.id} position={[a.lat, a.lon]} icon={iconoAccion(a.tipo)} title={a.nombre} interactive={!marcar}>
              <Popup>
                <strong>{a.nombre}</strong><br />
                {TIPOS_ACCION[a.tipo].etiqueta} · {SECTORES[a.sector].nombre} · {a.hectareas.toLocaleString('es-CO')} ha<br />
                Plan: {ACCIONES_PLAN[a.accion_plan].etiqueta}{a.prioridad_plan ? ` · prioridad ${a.prioridad_plan}` : ''}<br />
                <span style={{ color: '#f8d86f', fontWeight: 900, fontSize: 11 }}>{ESTADOS_ACCION[a.estado].etiqueta}</span><br />
                <a href={`/plataforma/seguimiento?accion=${a.id}`}>Ver seguimiento</a>
              </Popup>
            </Marker>
          ))}
          {punto && (
            <Marker position={[punto.lat, punto.lon]} icon={iconoPunto} draggable eventHandlers={{ dragend: (e) => { const ll = e.target.getLatLng(); alMarcar?.({ lat: ll.lat, lon: ll.lng }); } }} title="Sitio marcado" />
          )}
        </MapContainer>
        <div className="pointer-events-none absolute left-3 top-3 z-[500] flex flex-col gap-1 text-xs" aria-live="polite">
          {marcar && <span className="bg-cra-950/90 px-2 py-1 font-bold text-dorado-300">Haga clic en el mapa para marcar el sitio</span>}
          {(plan.estado === 'cargando' || manglar.estado === 'cargando') && <span className="bg-cra-950/90 px-2 py-1 text-suave">Cargando capas…</span>}
          {plan.estado === 'error' && <span className="bg-cra-950/90 px-2 py-1 text-alta-texto">No se pudo cargar el plan de la C.R.A.</span>}
          {manglar.estado === 'error' && <span className="bg-cra-950/90 px-2 py-1 text-alta-texto">No se pudo cargar la cobertura de manglar</span>}
        </div>
      </div>

      <details className="mt-2 border border-linea-suave bg-fondo-alt p-3" open>
        <summary className="rotulo inline-flex min-h-9 cursor-pointer items-center text-dorado-300">Capas y convenciones</summary>
        <div className="mt-2 grid gap-x-6 gap-y-1 sm:grid-cols-2">
          <div>
            {conmutador('plan', 'Plan de manejo C.R.A. (prioridades de conservación)', 'border-white/50 bg-gradient-to-r from-plan-preservacion via-plan-restauracion to-plan-recuperacion', plan.estado !== 'lista')}
            <ul className="ml-6 flex flex-wrap gap-x-3 gap-y-1 text-[11px] text-suave">
              {(['preservacion', 'restauracion', 'recuperacion', 'rehabilitacion'] as const).map((k) => (
                <li key={k} className="flex items-center gap-1"><span aria-hidden="true" className="inline-block size-2.5" style={{ background: ACCIONES_PLAN[k].color }} />{ACCIONES_PLAN[k].etiqueta}</li>
              ))}
              <li>· más intenso = prioridad más alta</li>
            </ul>
            {conmutador('manglar', 'Cobertura de manglar C.R.A. · 1:5.000 (649,7 ha)', 'border-[#f0abfc] bg-capa-manglar/60', manglar.estado !== 'lista')}
            {conmutador('sectores', 'Sectores del manglar (aproximados)', 'border-dashed border-white')}
          </div>
          <div>
            {conmutador('acciones', `Acciones (${acciones.length})`, 'border-cra-950 bg-dorado-500')}
            {conmutador('reportes', `Reportes de Zanqui (${reportes.length})`, 'rounded-full border-white bg-alta')}
            <p className="mt-1 text-[11px] text-tenue">Fuentes: capa «Prioridades de conservación» entregada por la C.R.A. (KMZ) · cobertura de manglar de la C.R.A. a 1:5.000 (Maxar 2021–2022, verificada en campo) · reportes y acciones de ejemplo.</p>
          </div>
        </div>
      </details>
    </div>
  );
}
