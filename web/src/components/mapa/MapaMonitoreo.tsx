import { useEffect, useMemo, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import L from 'leaflet';
import { GeoJSON, Pane, MapContainer, Marker, Polygon, Popup, TileLayer, Tooltip, ZoomControl, useMap } from 'react-leaflet';
import type { NivelPrioridad, ReportePublico, CapaManglarCRA, TipoReporte, ZonasManglar } from '../../types/manglar';
import { LISTA_PRIORIDADES, LISTA_PRIORIDADES_ZONA, LISTA_TIPOS, PRIORIDADES, PRIORIDADES_ZONA, TIPOS, formatearFecha, nivelPrioridad } from '../../lib/catalogos';
import { useReportesPublicos } from '../../lib/reportesStore';
import { LIMITES_MANGLAR, RADIO_INFLUENCIA_M, enAreaDeReporte } from '../../lib/areaReporte';
import { cn } from '../../lib/utils';
import BarraConfianza from '../ui/react/BarraConfianza';
import ChipPrioridad from '../ui/react/ChipPrioridad';
import ChipPrioridadZona from '../ui/react/ChipPrioridadZona';
import ChipEstado from '../ui/react/ChipEstado';
import { FUENTE_MANGLAR_CRA, obtenerCapaManglarCRA } from '../../lib/datos';
import type { FeatureCollection, Polygon as PoligonoGeo } from 'geojson';
import { exportarCSV, exportarGeoJSON, exportarKML } from '../../lib/exportar';
import ChipCanal from '../ui/react/ChipCanal';
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';

interface Props { reportes: ReportePublico[]; poligonos: ZonasManglar; }


const iconos = new Map<string, { normal: L.DivIcon; pulso: L.DivIcon }>();

function iconoReporte(reporte: ReportePublico): L.DivIcon {
  const clave = `${reporte.tipo}-${reporte.prioridad}`;
  let variantes = iconos.get(clave);
  if (!variantes) {
    const Icono = TIPOS[reporte.tipo].icono;
    const html = renderToStaticMarkup(
      <span className="pin-reporte__cuerpo" style={{ backgroundColor: PRIORIDADES[nivelPrioridad(reporte.prioridad)].color }}>
        <span className="pin-reporte__icono"><Icono size={16} strokeWidth={2.25} color="white" aria-hidden="true" /></span>
      </span>,
    );
    const crear = (pulso: boolean) => L.divIcon({
      className: cn('pin-reporte', pulso && 'pin-reporte--pulso'),
      html, iconSize: [34, 42], iconAnchor: [17, 40], popupAnchor: [0, -36],
    });
    variantes = { normal: crear(false), pulso: crear(true) };
    iconos.set(clave, variantes);
  }
  return reporte.estado === 'recibido' && nivelPrioridad(reporte.prioridad) === 'alta' ? variantes.pulso : variantes.normal;
}

function AjustarMapa({ poligonos }: Pick<Props, 'poligonos'>) {
  const mapa = useMap();
  useEffect(() => {
    const puntos: L.LatLngTuple[] = poligonos.features.flatMap((zona) =>
      zona.geometry.coordinates.flatMap((anillo) => anillo.map(([lon, lat]): L.LatLngTuple => [lat, lon])),
    );
    if (puntos.length) mapa.fitBounds(L.latLngBounds(puntos), { padding: [32, 32] });
  }, [mapa, poligonos]);
  useEffect(() => {
    const traducirCierre = (evento: L.PopupEvent) => {
      const boton = evento.popup.getElement()?.querySelector('.leaflet-popup-close-button');
      boton?.setAttribute('aria-label', 'Cerrar ventana');
      boton?.setAttribute('title', 'Cerrar ventana');
    };
    mapa.on('popupopen', traducirCierre);
    return () => { mapa.off('popupopen', traducirCierre); };
  }, [mapa]);
  return null;
}

function alternar<T,>(seleccion: T[], valor: T): T[] {
  return seleccion.includes(valor) ? seleccion.filter((item) => item !== valor) : [...seleccion, valor];
}

export default function MapaMonitoreo({ reportes, poligonos }: Props) {
  const todosVivos = useReportesPublicos(reportes);
  // Solo se publican denuncias dentro del manglar o de su área de influencia.
  const reportesVivos = useMemo(() => todosVivos.filter(enAreaDeReporte), [todosVivos]);
  const fueraDeArea = todosVivos.length - reportesVivos.length;
  const [tipos, setTipos] = useState<TipoReporte[]>([]);
  const [prioridades, setPrioridades] = useState<NivelPrioridad[]>([]);
  const [mostrarZonas, setMostrarZonas] = useState(true);
  const filtrados = useMemo(() => reportesVivos.filter((reporte) =>
    (!tipos.length || tipos.includes(reporte.tipo)) && (!prioridades.length || prioridades.includes(nivelPrioridad(reporte.prioridad))),
  ), [reportesVivos, tipos, prioridades]);
  const [capa, setCapa] = useState<CapaManglarCRA | null>(null);
  const [errorCapa, setErrorCapa] = useState(false);
  const [mostrarCapa, setMostrarCapa] = useState(true);
  useEffect(() => {
    let activo = true;
    obtenerCapaManglarCRA().then((datos) => { if (activo) setCapa(datos); }).catch(() => { if (activo) setErrorCapa(true); });
    return () => { activo = false; };
  }, []);
  const areaInvemar = capa?.features.reduce((total, f) => total + f.properties.area_ha, 0);
  const hayFiltros = tipos.length > 0 || prioridades.length > 0;

  return (
    <div className="relative z-0">
      <div className="mb-3 rounded-sm bg-superficie/95 p-4 shadow-[var(--c-sombra-alta)] backdrop-blur ">
        <div className="mb-1 flex items-center gap-2 text-sm font-semibold text-dorado-300">Datos de ejemplo</div>
        <div role="status" aria-live="polite" className="text-sm text-suave">
          Mostrando {filtrados.length} de {reportesVivos.length} reportes{fueraDeArea > 0 ? ` · ${fueraDeArea} fuera del área de reporte no se publica${fueraDeArea === 1 ? "" : "n"}` : ""}
          {filtrados.length === 0 && <span className="mt-2 block text-texto">Ningún reporte coincide con los filtros</span>}
        </div>
        <fieldset className="mt-3">
          <legend className="mb-2 text-xs font-semibold text-suave">Tipo</legend>
          <div className="flex flex-wrap gap-2">{LISTA_TIPOS.map((tipo) => {
            const Icono = TIPOS[tipo].icono;
            return <button key={tipo} type="button" aria-pressed={tipos.includes(tipo)} onClick={() => setTipos((actuales) => alternar(actuales, tipo))}
              className={cn('inline-flex min-h-11 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors', tipos.includes(tipo) ? 'bg-dorado-500 text-cra-950' : 'bg-fondo-alt text-suave hover:bg-white/10')}>
              <Icono size={14} aria-hidden="true" />{TIPOS[tipo].etiqueta}
            </button>;
          })}</div>
        </fieldset>
        <fieldset className="mt-3">
          <legend className="mb-2 text-xs font-semibold text-suave">Prioridad</legend>
          <div className="flex flex-wrap gap-2">{LISTA_PRIORIDADES.map((prioridad) => (
            <button key={prioridad} type="button" aria-pressed={prioridades.includes(prioridad)} onClick={() => setPrioridades((actuales) => alternar(actuales, prioridad))}
              className={cn('inline-flex min-h-11 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors', prioridades.includes(prioridad) ? PRIORIDADES[prioridad].chip : 'bg-fondo-alt text-suave hover:bg-white/10')}>
              <span className={cn('size-2 rounded-full', PRIORIDADES[prioridad].punto)} aria-hidden="true" />{PRIORIDADES[prioridad].etiqueta}
            </button>
          ))}</div>
        </fieldset>
        <label className="mt-3 flex min-h-11 cursor-pointer items-center gap-2 text-xs font-medium text-texto">
          <input type="checkbox" role="switch" checked={mostrarZonas} onChange={(evento) => setMostrarZonas(evento.target.checked)} className="size-4 accent-dorado-500" />Zonas de trabajo (aproximadas)
        </label>
        <label className="mt-2 flex min-h-11 items-center gap-2 text-xs font-medium"><input type="checkbox" role="switch" checked={mostrarCapa} onChange={(e) => setMostrarCapa(e.target.checked)} />Cobertura de manglar (C.R.A. 1:5.000)</label>
        {!capa && <p role="status" className="text-xs text-suave">{errorCapa ? 'No se pudo cargar la cobertura de manglar de la C.R.A.' : 'Cargando cobertura de manglar…'}</p>}
        {hayFiltros && <button type="button" onClick={() => { setTipos([]); setPrioridades([]); }} className="mt-2 min-h-11 text-xs font-semibold text-dorado-300 underline underline-offset-4">Limpiar filtros</button>}
      </div>

      <div role="region" aria-label="Mapa de monitoreo de manglares del Atlántico" className="h-[520px] overflow-hidden rounded-sm shadow-[var(--c-sombra)] ring-1 ring-linea sm:h-[600px]">
        <MapContainer maxBounds={LIMITES_MANGLAR} maxBoundsViscosity={1} minZoom={9} center={[10.93, -74.99]} zoom={11} scrollWheelZoom={false} zoomControl={false} className="h-full w-full">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
          <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
          <AjustarMapa poligonos={poligonos} />
          <Pane name="cobertura-invemar" style={{ zIndex: 350 }}>{mostrarCapa && capa && <GeoJSON data={capa} style={{ fillColor: '#d946ef', fillOpacity: 0.5, color: '#f0abfc', weight: 0.8 }} />}</Pane>
          {mostrarZonas && poligonos.features.map((zona) => {
            const datos = zona.properties;
            const prioridad = PRIORIDADES_ZONA[datos.prioridad];
            const estilo: L.PathOptions = { color: prioridad.color, weight: datos.prioridad === 'critica' ? 2.5 : 2, fillColor: prioridad.relleno, dashArray: '6 4', fillOpacity: 0.06 };
            const posiciones: L.LatLngTuple[][] = zona.geometry.coordinates.map((anillo) => anillo.map(([lon, lat]): L.LatLngTuple => [lat, lon]));
            return <Polygon key={datos.id} positions={posiciones} pathOptions={estilo} eventHandlers={{
              mouseover: (evento) => (evento.target as L.Polygon).setStyle({ weight: 4, fillOpacity: 0.12 }),
              mouseout: (evento) => (evento.target as L.Polygon).setStyle(estilo),
            }}>
              <Tooltip sticky>{datos.nombre} · Zona de trabajo aproximada</Tooltip>
              <Popup minWidth={260} maxWidth={280}>
                <div className="space-y-3 text-texto">
                  <h3 className="pr-4 text-base font-bold">{datos.nombre}</h3>
                  <div className="text-sm text-suave">{datos.municipio}</div>
                  <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-suave">Prioridad de conservación propuesta</span><ChipPrioridadZona prioridad={datos.prioridad} /></div>
                  <div><strong>Área:</strong> {datos.area_ha === null ? 'Sin cifra oficial · KMZ C.R.A. pendiente' : `${datos.area_ha.toLocaleString('es-CO')} ha`}</div>
                  <div><strong>Especies</strong><ul className="mt-1 list-disc pl-4">{datos.especies.slice(0, 4).map((especie) => <li key={especie}>{especie}</li>)}</ul></div>
                  <div><strong>Presiones principales</strong><ul className="mt-1 list-disc pl-4">{datos.amenazas.slice(0, 3).map((presion) => <li key={presion}>{presion}</li>)}</ul></div>
                  <p className="text-xs text-suave">{datos.fuente}</p><div className="font-semibold text-dorado-300">{reportesVivos.filter((reporte) => reporte.zona === datos.nombre).length} reportes en esta zona</div>
                </div>
              </Popup>
            </Polygon>;
          })}
          {filtrados.map((reporte) => (
            <Marker key={reporte.id} position={[reporte.lat, reporte.lon]} icon={iconoReporte(reporte)} title={TIPOS[reporte.tipo].etiquetaLarga} alt={TIPOS[reporte.tipo].etiquetaLarga} eventHandlers={{
              add: (evento) => (evento.target as L.Marker).getElement()?.setAttribute('aria-label', TIPOS[reporte.tipo].etiquetaLarga),
            }}>
              <Popup minWidth={260} maxWidth={280}>
                <div className="space-y-3 text-texto">
                  <h3 className="flex items-center gap-2 text-base font-bold">{(() => { const Icono = TIPOS[reporte.tipo].icono; return <Icono size={20} aria-hidden="true" />; })()}{TIPOS[reporte.tipo].etiquetaLarga}</h3>
                  <div className="flex flex-wrap gap-2"><ChipPrioridad prioridad={reporte.prioridad} /></div>
                  <dl className="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-3 gap-y-2 text-xs [&_dt]:text-suave [&_dd]:min-w-0 [&_dd]:break-words">
                    <dt>Zona</dt><dd>{reporte.dentro_poligono ? reporte.zona : `Fuera de zona · a ${reporte.distancia_m ?? "—"} m`} · {reporte.municipio}</dd>
                    <dt>Confianza IA</dt><dd><BarraConfianza valor={reporte.confianza} compacta /></dd>
                    <dt>Canal</dt><dd><ChipCanal canal={reporte.canal} /></dd>
                    <dt>Estado</dt><dd><ChipEstado estado={reporte.estado} /></dd>
                    <dt>Captura</dt><dd>{formatearFecha(reporte.capturado_en)}</dd>
                  </dl>
                  <p className="text-xs text-suave">Ubicación aproximada para proteger a quien reporta</p>
                  <a href="#panel" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">Ver en el panel C.R.A.</a>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      <div aria-label="Leyenda del mapa" className="mt-3 space-y-3 rounded-sm bg-superficie/95 p-4 text-xs shadow-[var(--c-sombra-alta)] backdrop-blur ">
        <div><h3 className="font-semibold">Cobertura de manglar · C.R.A. 1:5.000</h3>
          {capa && <p>{capa.features.length.toLocaleString('es-CO')} polígonos · {areaInvemar?.toLocaleString('es-CO', { maximumFractionDigits: 0 })} ha</p>}
          <p>{FUENTE_MANGLAR_CRA}.</p>
        </div>
        <div><h3 className="mb-2 font-semibold text-texto">Zonas de trabajo (aproximadas)</h3><ul className="flex flex-wrap gap-3">{LISTA_PRIORIDADES_ZONA.map((valor) => {
          const prioridad = PRIORIDADES_ZONA[valor];
          return <li key={valor} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className="relative h-3 w-4 overflow-hidden rounded-sm border-2" style={{ borderColor: prioridad.color }}><span className="absolute inset-0" style={{ backgroundColor: prioridad.relleno, opacity: prioridad.opacidadRelleno }} /></span>{prioridad.etiqueta}</li>;
        })}</ul></div>
        <div><h3 className="mb-2 font-semibold text-texto">Reportes por prioridad</h3><ul className="flex flex-wrap gap-3">{LISTA_PRIORIDADES.map((prioridad) => (
          <li key={prioridad} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className={cn('size-2 rounded-full', PRIORIDADES[prioridad].punto)} />{PRIORIDADES[prioridad].etiqueta}</li>
        ))}</ul></div>
        <div className="flex flex-wrap gap-2" aria-label="Descargar datos públicos">{[{ etiqueta: 'CSV', descargar: exportarCSV }, { etiqueta: 'GeoJSON', descargar: exportarGeoJSON }, { etiqueta: 'KML', descargar: exportarKML }].map(({ etiqueta, descargar }) => <button key={etiqueta} disabled={!filtrados.length} onClick={() => descargar(filtrados)} className="min-h-11 rounded-xl px-3 ring-1 ring-linea disabled:opacity-40">Exportar {etiqueta}</button>)}</div>
        <p>Solo denuncias dentro del manglar o a menos de {RADIO_INFLUENCIA_M} m · vista filtrada · ubicaciones aproximadas · CC BY 4.0 · Datos de ejemplo</p>
      </div>
    </div>
  );
}
