import { useEffect, useRef, useState } from 'react';
import type { KeyboardEvent } from 'react';
import { geoJSON, circleMarker } from 'leaflet';
import type { FeatureCollection, Geometry } from 'geojson';
import { GeoJSON, MapContainer, Pane, Popup, TileLayer, Tooltip, ZoomControl, useMap, useMapEvents } from 'react-leaflet';
import { obtenerCapaManglarCRA } from '../../lib/datos';
import { LIMITES_MANGLAR } from '../../lib/areaReporte';
import { FUENTE_WORKFLOW, PESTANAS_WORKFLOW, SECTORES_WORKFLOW, URL_WORKFLOW_CRA, VERSION_WORKFLOW } from '../../lib/workflow';
import { BloqueWorkflow } from './BloquesWorkflow';
import { useWorkflowCRA } from '../../lib/useWorkflowCRA';
import { fechaCRA } from '../../lib/cra';
import type { PropiedadesZona, ZonasManglar } from '../../types/manglar';
import ZankyImg from '../marca/ZankyImg';
import 'leaflet/dist/leaflet.css';
import '../../styles/workflow.css';

interface CapaCRA { id: string; nombre: string; cargada_en: string; geojson: FeatureCollection }
const numero = (n: number) => n.toLocaleString('es-CO');
const claveCapas = 'zanky-web:v1:capas-cra';
const objeto = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null;
const posicion = (v: unknown): boolean => Array.isArray(v) && v.length >= 2 && v.every(n => typeof n === 'number' && Number.isFinite(n));
function coordenadas(v: unknown, profundidad: number): boolean {
  return profundidad === 0 ? posicion(v) : Array.isArray(v) && v.length > 0 && v.every(p => coordenadas(p, profundidad - 1));
}
function geometria(v: unknown): v is Geometry {
  if (!objeto(v)) return false;
  if (v.type === 'GeometryCollection') return Array.isArray(v.geometries) && v.geometries.every(geometria);
  const niveles: Record<string, number> = { Point: 0, MultiPoint: 1, LineString: 1, MultiLineString: 2, Polygon: 2, MultiPolygon: 3 };
  return typeof v.type === 'string' && Object.hasOwn(niveles, v.type) && coordenadas(v.coordinates, niveles[v.type]!);
}
function esCapaCRA(v: unknown): v is CapaCRA {
  if (!objeto(v) || typeof v.id !== 'string' || typeof v.nombre !== 'string' || typeof v.cargada_en !== 'string' || !objeto(v.geojson)) return false;
  return v.geojson.type === 'FeatureCollection' && Array.isArray(v.geojson.features) && v.geojson.features.every((f: unknown) => objeto(f) && f.type === 'Feature' && (f.geometry === null || geometria(f.geometry)) && (f.properties === null || objeto(f.properties)));
}

function AjustarMapa({ zonas, activar }: { zonas: ZonasManglar; activar: () => void }) {
  const mapa = useMap();
  useMapEvents({ click: () => { mapa.scrollWheelZoom.enable(); activar(); } });
  useEffect(() => {
    const limites = geoJSON(zonas).getBounds();
    // El contenedor flexible puede medir 0 px al montar: encuadrar entonces
    // lleva a zoom 18. Se encuadra la primera vez que el mapa tiene tamaño.
    let encuadrado = false;
    const encuadrar = () => {
      const { x, y } = mapa.getSize();
      if (encuadrado || !x || !y || !limites.isValid()) return;
      mapa.fitBounds(limites, { padding: [35, 35] });
      encuadrado = true;
    };
    encuadrar();
    const observador = new ResizeObserver(() => { mapa.invalidateSize(); encuadrar(); });
    observador.observe(mapa.getContainer());
    mapa.getContainer().setAttribute('aria-label', 'Mapa del manglar del Atlántico');
    return () => observador.disconnect();
  }, [mapa, zonas]);
  return null;
}

function datoInvemar(p: PropiedadesZona, clave: 'area_invemar_ha' | 'poligonos_invemar') {
  const valor: unknown = (p as PropiedadesZona & Record<string, unknown>)[clave];
  return typeof valor === 'number' && Number.isFinite(valor) ? numero(valor) : 'No publicado';
}

const indiceDeHash = () => {
  if (typeof window === 'undefined') return 0;
  const i = PESTANAS_WORKFLOW.findIndex(p => `#${p.id}` === window.location.hash);
  return i < 0 ? 0 : i;
};

export default function VisorWorkflow({ zonas }: { zonas: ZonasManglar }) {
  const [indice, setIndice] = useState(indiceDeHash);
  // En pantallas estrechas la leyenda empieza plegada para no tapar el mapa.
  const [leyendaAbierta] = useState(() => window.matchMedia('(min-width: 640px)').matches);
  const [capa, setCapa] = useState<Awaited<ReturnType<typeof obtenerCapaManglarCRA>> | null>(null);
  const [estadoCapa, setEstadoCapa] = useState<'cargando' | 'lista' | 'error'>('cargando');
  const [intento, setIntento] = useState(0);
  const [rueda, setRueda] = useState(false);
  const [capasCRA, setCapasCRA] = useState<CapaCRA[]>([]);
  const [mostrarCRA, setMostrarCRA] = useState(true);
  const [errorCRA, setErrorCRA] = useState(false);
  const [errorTeselas, setErrorTeselas] = useState(false);
  const raiz = useRef<HTMLDivElement>(null);
  const contenido = useRef<HTMLDivElement>(null);
  const botones = useRef<(HTMLButtonElement | null)[]>([]);
  const pestana = PESTANAS_WORKFLOW[indice]!;
  const etiquetas = Boolean(pestana.rotuloSector);
  const pendiente = pestana.bloques.find(b => b.tipo === 'pendiente');
  // Copia en vivo de los datos de la C.R.A.: fecha de revisión y audio de cada pestaña.
  const { workflow: vivo, espejo, estado: estadoDatos } = useWorkflowCRA();
  const audio = vivo.pestanas.find(p => p.id === pestana.id)?.audio;

  useEffect(() => {
    let vigente = true;
    setEstadoCapa('cargando');
    obtenerCapaManglarCRA().then(datos => { if (vigente) { setCapa(datos); setEstadoCapa('lista'); } })
      .catch(() => { if (vigente) setEstadoCapa('error'); });
    return () => { vigente = false; };
  }, [intento]);

  useEffect(() => {
    const leer = () => {
      try {
        const valor: unknown = JSON.parse(localStorage.getItem(claveCapas) ?? '[]');
        if (!Array.isArray(valor) || !valor.every(esCapaCRA)) throw new Error('Capas inválidas');
        setCapasCRA(valor); setErrorCRA(false);
      } catch { setCapasCRA([]); setErrorCRA(true); }
    };
    const actualizar = (evento: StorageEvent) => { if (evento.key === claveCapas || evento.key === null) leer(); };
    leer();
    window.addEventListener('storage', actualizar);
    window.addEventListener('focus', leer);
    return () => { window.removeEventListener('storage', actualizar); window.removeEventListener('focus', leer); };
  }, []);

  useEffect(() => {
    // Con #pestaña en la URL, mostrar esa pestaña en la barra sin mover la página.
    const boton = botones.current[indice];
    const barra = boton?.parentElement;
    // Posición del botón medida desde la barra (offsetLeft cuenta desde el visor entero, mapa incluido,
    // y en pantallas anchas dejaba la pestaña activa fuera de la vista).
    if (boton && barra) barra.scrollLeft = boton.getBoundingClientRect().left - barra.getBoundingClientRect().left + barra.scrollLeft - (barra.clientWidth - boton.clientWidth) / 2;
    // Un enlace a otra pestaña del mismo visor (#carbono) cambia de pestaña.
    const alCambiarHash = () => setIndice(indiceDeHash());
    window.addEventListener('hashchange', alCambiarHash);
    return () => window.removeEventListener('hashchange', alCambiarHash);
    // Solo al montar.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const ajustar = () => {
      if (raiz.current) raiz.current.style.setProperty('--workflow-offset', `${raiz.current.getBoundingClientRect().top + window.scrollY}px`);
    };
    ajustar();
    const observador = new ResizeObserver(ajustar);
    document.querySelectorAll('header, .workflow-franja').forEach(elemento => observador.observe(elemento));
    window.addEventListener('resize', ajustar);
    return () => { observador.disconnect(); window.removeEventListener('resize', ajustar); };
  }, []);

  function seleccionar(nuevo: number, enfocar = false) {
    const siguiente = (nuevo + PESTANAS_WORKFLOW.length) % PESTANAS_WORKFLOW.length;
    setIndice(siguiente);
    try { history.replaceState(null, '', `#${PESTANAS_WORKFLOW[siguiente]!.id}`); } catch { /* sin historial: no pasa nada */ }
    contenido.current?.scrollTo({ top: 0 });
    if (enfocar) botones.current[siguiente]?.focus({ preventScroll: true });
    botones.current[siguiente]?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }
  function teclado(evento: KeyboardEvent<HTMLButtonElement>, actual: number) {
    const siguiente = evento.key === 'ArrowRight' ? actual + 1 : evento.key === 'ArrowLeft' ? actual - 1 : evento.key === 'Home' ? 0 : evento.key === 'End' ? PESTANAS_WORKFLOW.length - 1 : null;
    if (siguiente !== null) { evento.preventDefault(); seleccionar(siguiente, true); }
  }

  return <div ref={raiz} className="visor-workflow relative z-0 flex flex-col text-texto lg:flex-row">
    <section className="workflow-mapa relative isolate min-w-0 flex-none lg:flex-1" aria-label="Visor cartográfico">
      <MapContainer maxBounds={LIMITES_MANGLAR} maxBoundsViscosity={1} minZoom={9} center={[10.95, -75.03]} zoom={10} zoomControl={false} scrollWheelZoom={false} className="h-full w-full">
        <Pane name="teselas-workflow" className="workflow-teselas" style={{ zIndex: 200 }}>
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution="© colaboradores de OpenStreetMap" eventHandlers={{ tileerror: () => setErrorTeselas(true) }} />
        </Pane>
        <AjustarMapa zonas={zonas} activar={() => setRueda(true)} />
        <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
        <Pane name="referencia-workflow" style={{ zIndex: 350 }}>
          {capa && <GeoJSON data={capa} style={{ fillColor: '#d946ef', fillOpacity: pestana.capa === 'cra' ? 0.55 : 0.18, color: '#f0abfc', weight: 0.8, opacity: pestana.capa === 'cra' ? 1 : 0.4 }} />}
        </Pane>
        <Pane name="sectores-workflow" style={{ zIndex: 400 }}>
          {zonas.features.map(zona => {
            const sector = SECTORES_WORKFLOW.find(s => s.id === zona.properties.id);
            return <GeoJSON key={zona.properties.id} data={zona} style={{ color: 'white', dashArray: '6 5', weight: 1.3, fillColor: 'white', fillOpacity: 0.04, opacity: pestana.capa === 'sectores' || etiquetas ? 1 : 0.35 }}>
              {etiquetas && <Tooltip permanent direction="center" className="workflow-sector">{sector ? `${sector.nombre.toLocaleUpperCase('es-CO')} · ${numero(pestana.rotuloSector === 'total' ? sector.total_ha : sector.probable_ha)} ha` : zona.properties.nombre}</Tooltip>}
              <Popup><strong>{sector?.nombre_largo ?? zona.properties.nombre}</strong>
                {sector && <><p>Manglar probable: {numero(sector.probable_ha)} ha ({numero(sector.alta_ha)} con probabilidad alta y {numero(sector.media_ha)} media).</p>
                  <p>Por revisar: {numero(sector.por_revisar_ha)} ha. Total probable + por revisar: {numero(sector.total_ha)} ha.</p>
                  <p>Dosel claramente más seco en 2026: {numero(sector.dosel_seco_ha)} ha · riesgo medio {sector.riesgo_medio.toLocaleString('es-CO')} (0 a 1) · altura mediana {sector.altura_mediana_m.toLocaleString('es-CO')} m.</p></>}
                <p>Polígonos INVEMAR: {datoInvemar(zona.properties, 'poligonos_invemar')}.<br />Área INVEMAR: {datoInvemar(zona.properties, 'area_invemar_ha')} ha.</p>
                <p>Límite sectorial aproximado. Manglar probable, no confirmado: requiere verificación en campo.</p>
                <p>Fuente: {FUENTE_WORKFLOW}; {zona.properties.fuente}.</p>
              </Popup>
            </GeoJSON>;
          })}
        </Pane>
        <Pane name="cra-workflow" style={{ zIndex: 450 }}>
          {mostrarCRA && capasCRA.map((c, i) => <GeoJSON key={`${c.id}-${c.cargada_en}-${i}`} data={c.geojson}
            style={{ color: 'var(--color-dorado-500)', weight: 2, fillOpacity: 0.12 }}
            pointToLayer={(_, latlng) => circleMarker(latlng, { color: 'var(--color-dorado-500)', radius: 6, fillOpacity: 0.5 })}>
            <Popup><strong>{c.nombre}</strong><p>Capa C.R.A. cargada en este navegador.</p></Popup>
          </GeoJSON>)}
        </Pane>
      </MapContainer>
      <div className="pointer-events-none absolute left-3 top-3 z-[500] max-w-[calc(100%-1.5rem)] space-y-2 text-sm" aria-live="polite">
        {!rueda && <p className="bg-fondo-alt/95 px-3 py-2">Haz clic para usar la rueda del ratón</p>}
        {estadoCapa === 'cargando' && <p className="bg-fondo-alt/95 px-3 py-2">Cargando la cobertura de manglar de la C.R.A.…</p>}
        {estadoCapa === 'error' && <div className="pointer-events-auto flex items-start gap-2 bg-fondo-alt/95 px-3 py-2"><ZankyImg animo="preocupado" decorativo sizes="28px" className="mt-1 size-8 shrink-0 drop-shadow-none" /><p>No se pudo cargar la cobertura de manglar de la C.R.A. Los sectores siguen disponibles. <button className="min-h-11 underline text-dorado-300" onClick={() => setIntento(n => n + 1)}>Reintentar</button></p></div>}
        {errorTeselas && <p className="bg-fondo-alt/95 px-3 py-2">No se pudieron cargar algunas teselas de OpenStreetMap.</p>}
        {errorCRA && <p className="bg-fondo-alt/95 px-3 py-2">No se pudieron leer las capas C.R.A. de este navegador.</p>}
        {capasCRA.length > 0 && <label className="pointer-events-auto flex min-h-11 items-center gap-2 bg-fondo-alt/95 px-3 py-2"><input type="checkbox" checked={mostrarCRA} onChange={e => setMostrarCRA(e.target.checked)} />Capas C.R.A. cargadas</label>}
      </div>
      <details open={leyendaAbierta} className="workflow-leyenda absolute bottom-6 left-3 z-[500] max-h-[45%] w-[min(360px,calc(100%-4.5rem))] overflow-auto border border-linea bg-fondo-alt/90 p-3 text-xs">
        <summary className="rotulo min-h-11 cursor-pointer text-dorado-300">Convenciones del workflow</summary>
        <ul className="space-y-2">
          {pendiente?.tipo === 'pendiente' && <li className="space-y-1 border-b border-linea-suave pb-2"><p className="font-semibold">{pendiente.capas[0]}: capa de la C.R.A. pendiente de entrega</p>{pendiente.convenciones && <p className="text-tenue">{pendiente.convenciones.join(' · ')}</p>}</li>}
          <li className="flex items-center gap-2"><span aria-hidden="true" className="h-2.5 w-5 shrink-0 border border-dashed border-white" />Sectores de la C.R.A. (límites aproximados)</li>
          <li className="flex items-start gap-2"><span aria-hidden="true" className="mt-1 h-2.5 w-2.5 shrink-0 bg-capa-manglar" /><span>Cobertura de manglar C.R.A. 1:5.000 (649,7 ha; Maxar 2021–2022, verificada en campo). La capa de manglar probable del workflow (775 ha) es otra: se cargará cuando la C.R.A. la entregue</span></li>
          {capasCRA.length > 0 && <li className="flex items-center gap-2"><span className="h-2.5 w-5 border border-dorado-500" />Capas C.R.A. cargadas</li>}
        </ul>
      </details>
    </section>
    <aside className="workflow-panel flex min-w-0 flex-col border-l border-linea bg-fondo-alt lg:w-[480px] lg:shrink-0 xl:w-[560px]" aria-label="Análisis del workflow">
      <div className="shrink-0 border-b border-linea bg-fondo-alt p-4">
        <p className="rotulo text-dorado-300">Manglar probable, no confirmado</p>
        <p className="mt-1 text-sm text-suave">Requiere verificación en campo. {VERSION_WORKFLOW}.</p>
        <p className="mt-2 flex items-center gap-2 text-xs text-tenue" aria-live="polite">
          <span aria-hidden="true" className={`h-2 w-2 shrink-0 rounded-full ${estadoDatos === 'en_vivo' ? 'bg-baja' : estadoDatos === 'respaldo' ? 'bg-dorado-500' : 'bg-white/40'}`} />
          {estadoDatos === 'cargando' && 'Leyendo los datos de la C.R.A.…'}
          {estadoDatos === 'en_vivo' && <>Copia en vivo de los datos de la C.R.A.{espejo ? ` (revisados el ${fechaCRA(espejo.revisado_en)})` : ''}; las pestañas muestran lo transcrito de su visor el 27-11-2026.</>}
          {estadoDatos === 'respaldo' && 'No se pudo leer la copia de los datos de la C.R.A.: se muestra lo transcrito de su visor el 27-11-2026.'}
        </p>
      </div>
      <div role="tablist" aria-label="Temas del workflow" className="flex shrink-0 overflow-x-auto border-b border-linea">
        {PESTANAS_WORKFLOW.map((p, i) => <button key={p.id} ref={el => { botones.current[i] = el; }} id={`tab-${p.id}`} role="tab" aria-selected={i === indice} aria-controls={`panel-${p.id}`} tabIndex={i === indice ? 0 : -1} onClick={() => seleccionar(i)} onKeyDown={e => teclado(e, i)} className={`rotulo min-h-11 shrink-0 border-b-[3px] px-4 py-3 text-white ${i === indice ? 'border-dorado-500' : 'border-transparent hover:bg-white/5'}`}>{p.etiqueta}</button>)}
      </div>
      <div ref={contenido} className="min-h-0 flex-1 overflow-y-auto">
        <section key={pestana.id} role="tabpanel" id={`panel-${pestana.id}`} aria-labelledby={`tab-${pestana.id}`} tabIndex={0} className="space-y-6 p-5">
          <h2 className="titular text-2xl">{pestana.titulo}</h2>
          {audio && <div className="space-y-2">
            <p className="rotulo text-dorado-300">Escuchar esta sección · {Math.round(audio.dur)} s</p>
            <audio key={audio.src} controls preload="none" src={audio.src} className="w-full" aria-label={`Audio de la sección ${pestana.etiqueta}`} />
          </div>}
          <details className="rounded-sm border border-linea-suave">
            <summary className="flex min-h-11 cursor-pointer items-center px-3 text-sm text-dorado-300">Resumen de la sección (texto del audio de la C.R.A.)</summary>
            <p className="px-3 pb-3 text-sm leading-relaxed text-suave">{pestana.narracion}</p>
          </details>
          {pestana.bloques.map((b, i) => <BloqueWorkflow key={`${pestana.id}-${i}`} bloque={b} />)}
          <p className="border-l-2 border-dorado-500 pl-3 text-sm">Capa en el mapa de esta web: {pestana.capa === 'cra' ? 'cobertura de manglar de la C.R.A. (1:5.000) resaltada' : 'sectores de la C.R.A. con límites aproximados'}.</p>
          <p className="text-xs leading-relaxed text-tenue">Fuente: {pestana.fuente}.</p>
          <a href={`${URL_WORKFLOW_CRA}`} target="_blank" rel="noopener" className="inline-flex min-h-11 items-center text-sm text-dorado-300 underline">Ver esta sección en el workflow original de la C.R.A. ↗</a>
        </section>
      </div>
      <nav aria-label="Recorrer pestañas" className="grid shrink-0 grid-cols-2 border-t border-linea">
        <button onClick={() => seleccionar(indice - 1)} className="rotulo min-h-14 p-3 text-left text-dorado-300 hover:bg-white/5">◀ Pestaña anterior</button>
        <button onClick={() => seleccionar(indice + 1)} className="rotulo min-h-14 border-l border-linea p-3 text-right text-dorado-300 hover:bg-white/5">Pestaña siguiente ▶</button>
      </nav>
    </aside>
  </div>;
}
