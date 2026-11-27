import { useEffect, useMemo, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import L from 'leaflet';
import { MapContainer, Marker, Polygon, Popup, TileLayer, Tooltip, ZoomControl, useMap } from 'react-leaflet';
import type { PrioridadReporte, PrioridadZona, Reporte, TipoReporte, ZonasManglar } from '../../types/manglar';
import { LISTA_PRIORIDADES, LISTA_TIPOS, PRIORIDADES, PRIORIDADES_ZONA, TIPOS, formatearFecha } from '../../lib/catalogos';
import { useReportes } from '../../lib/reportesStore';
import { cn } from '../../lib/utils';
import BarraConfianza from '../ui/react/BarraConfianza';
import ChipPrioridad from '../ui/react/ChipPrioridad';
import ChipPrioridadZona from '../ui/react/ChipPrioridadZona';
import ChipEstado from '../ui/react/ChipEstado';
import ChipTipo from '../ui/react/ChipTipo';
import ChipOrigen from '../ui/react/ChipOrigen';
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';

interface Props { reportes: Reporte[]; poligonos: ZonasManglar; }

const prioridadesZona: PrioridadZona[] = ['critica', 'alta', 'media', 'baja'];
const iconos = new Map<string, { normal: L.DivIcon; pulso: L.DivIcon }>();

function iconoReporte(reporte: Reporte): L.DivIcon {
  const clave = `${reporte.tipo}-${reporte.prioridad}`;
  let variantes = iconos.get(clave);
  if (!variantes) {
    const Icono = TIPOS[reporte.tipo].icono;
    const html = renderToStaticMarkup(
      <span className="pin-reporte__cuerpo" style={{ backgroundColor: PRIORIDADES[reporte.prioridad].color }}>
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
  return reporte.estado === 'pendiente' && reporte.prioridad === 'alta' ? variantes.pulso : variantes.normal;
}

function AjustarMapa({ poligonos }: Pick<Props, 'poligonos'>) {
  const mapa = useMap();
  useEffect(() => {
    const puntos: L.LatLngTuple[] = poligonos.features.flatMap((zona) =>
      zona.geometry.coordinates.flatMap((anillo) => anillo.map(([lng, lat]): L.LatLngTuple => [lat, lng])),
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
  const reportesVivos = useReportes(reportes);
  const [tipos, setTipos] = useState<TipoReporte[]>([]);
  const [prioridades, setPrioridades] = useState<PrioridadReporte[]>([]);
  const [mostrarZonas, setMostrarZonas] = useState(true);
  const filtrados = useMemo(() => reportesVivos.filter((reporte) =>
    (!tipos.length || tipos.includes(reporte.tipo)) && (!prioridades.length || prioridades.includes(reporte.prioridad)),
  ), [reportesVivos, tipos, prioridades]);
  const hayFiltros = tipos.length > 0 || prioridades.length > 0;

  return (
    <div className="relative z-0">
      <div className="mb-3 rounded-2xl bg-superficie/95 p-4 shadow-[var(--c-sombra-alta)] backdrop-blur lg:absolute lg:left-4 lg:top-4 lg:z-[1000] lg:mb-0 lg:w-80">
        <div className="mb-1 flex items-center gap-2 text-sm font-semibold text-manglar-700"><span className="punto-vivo" aria-hidden="true" />En vivo</div>
        <div role="status" aria-live="polite" className="text-sm text-suave">
          Mostrando {filtrados.length} de {reportesVivos.length} reportes
          {filtrados.length === 0 && <span className="mt-2 block text-texto">Ningún reporte coincide con los filtros</span>}
        </div>
        <fieldset className="mt-3">
          <legend className="mb-2 text-xs font-semibold text-suave">Tipo</legend>
          <div className="flex flex-wrap gap-2">{LISTA_TIPOS.map((tipo) => {
            const Icono = TIPOS[tipo].icono;
            return <button key={tipo} type="button" aria-pressed={tipos.includes(tipo)} onClick={() => setTipos((actuales) => alternar(actuales, tipo))}
              className={cn('inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors', tipos.includes(tipo) ? 'bg-manglar-900 text-white' : 'bg-fondo-alt text-suave hover:bg-manglar-100')}>
              <Icono size={14} aria-hidden="true" />{TIPOS[tipo].etiqueta}
            </button>;
          })}</div>
        </fieldset>
        <fieldset className="mt-3">
          <legend className="mb-2 text-xs font-semibold text-suave">Prioridad</legend>
          <div className="flex flex-wrap gap-2">{LISTA_PRIORIDADES.map((prioridad) => (
            <button key={prioridad} type="button" aria-pressed={prioridades.includes(prioridad)} onClick={() => setPrioridades((actuales) => alternar(actuales, prioridad))}
              className={cn('inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors', prioridades.includes(prioridad) ? PRIORIDADES[prioridad].chip : 'bg-fondo-alt text-suave hover:bg-manglar-100')}>
              <span className={cn('size-2 rounded-full', PRIORIDADES[prioridad].punto)} aria-hidden="true" />{PRIORIDADES[prioridad].etiqueta}
            </button>
          ))}</div>
        </fieldset>
        <label className="mt-3 flex min-h-9 cursor-pointer items-center gap-2 text-xs font-medium text-texto">
          <input type="checkbox" role="switch" checked={mostrarZonas} onChange={(evento) => setMostrarZonas(evento.target.checked)} className="size-4 accent-manglar-900" />Mostrar zonas C.R.A.
        </label>
        {hayFiltros && <button type="button" onClick={() => { setTipos([]); setPrioridades([]); }} className="mt-2 min-h-9 text-xs font-semibold text-manglar-700 underline underline-offset-4">Limpiar filtros</button>}
      </div>

      <div role="region" aria-label="Mapa de monitoreo de manglares del Atlántico" className="h-[520px] overflow-hidden rounded-3xl shadow-[var(--c-sombra)] ring-1 ring-linea sm:h-[600px]">
        <MapContainer center={[10.93, -74.99]} zoom={11} scrollWheelZoom={false} zoomControl={false} className="h-full w-full">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
          <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
          <AjustarMapa poligonos={poligonos} />
          {mostrarZonas && poligonos.features.map((zona) => {
            const datos = zona.properties;
            const prioridad = PRIORIDADES_ZONA[datos.prioridad];
            const estilo: L.PathOptions = { color: prioridad.color, weight: datos.prioridad === 'critica' ? 2.5 : 2, fillColor: prioridad.relleno, fillOpacity: prioridad.opacidadRelleno };
            const posiciones: L.LatLngTuple[][] = zona.geometry.coordinates.map((anillo) => anillo.map(([lng, lat]): L.LatLngTuple => [lat, lng]));
            return <Polygon key={datos.id} positions={posiciones} pathOptions={estilo} eventHandlers={{
              mouseover: (evento) => (evento.target as L.Polygon).setStyle({ weight: 4, fillOpacity: Math.min(prioridad.opacidadRelleno + 0.15, 1) }),
              mouseout: (evento) => (evento.target as L.Polygon).setStyle(estilo),
            }}>
              <Tooltip sticky>{datos.nombre} · {prioridad.etiqueta}</Tooltip>
              <Popup minWidth={260} maxWidth={280}>
                <div className="space-y-3 text-texto">
                  <h3 className="pr-4 text-base font-bold">{datos.nombre}</h3>
                  <div className="text-sm text-suave">{datos.municipio}</div>
                  <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-suave">Prioridad de conservación</span><ChipPrioridadZona prioridad={datos.prioridad} /></div>
                  <div><strong>Área:</strong> {datos.area_ha.toLocaleString('es-CO')} ha</div>
                  <div><strong>Especies</strong><ul className="mt-1 list-disc pl-4">{datos.especies.slice(0, 4).map((especie) => <li key={especie}>{especie}</li>)}</ul></div>
                  <div><strong>Amenazas principales</strong><ul className="mt-1 list-disc pl-4">{datos.amenazas.slice(0, 3).map((amenaza) => <li key={amenaza}>{amenaza}</li>)}</ul></div>
                  <div className="font-semibold text-manglar-700">{reportesVivos.filter((reporte) => reporte.zona === datos.nombre).length} reportes en esta zona</div>
                </div>
              </Popup>
            </Polygon>;
          })}
          {filtrados.map((reporte) => (
            <Marker key={reporte.id} position={[reporte.lat, reporte.lng]} icon={iconoReporte(reporte)} title={reporte.titulo} alt={reporte.titulo} eventHandlers={{
              add: (evento) => (evento.target as L.Marker).getElement()?.setAttribute('aria-label', reporte.titulo),
            }}>
              <Popup minWidth={260} maxWidth={280}>
                <div className="space-y-3 text-texto">
                  <img src={reporte.foto_url} alt={reporte.titulo} loading="lazy" className="h-28 w-full rounded-xl object-cover" />
                  <h3 className="text-base font-bold">{reporte.titulo}</h3>
                  <div className="flex flex-wrap gap-2"><ChipTipo tipo={reporte.tipo} /><ChipPrioridad prioridad={reporte.prioridad} /></div>
                  <dl className="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-x-3 gap-y-2 text-xs [&_dt]:text-suave [&_dd]:min-w-0 [&_dd]:break-words">
                    <dt>Zona</dt><dd>{reporte.zona}</dd>
                    <dt>Confianza IA</dt><dd><BarraConfianza valor={reporte.confianza_ia} compacta /></dd>
                    <dt>Origen</dt><dd><ChipOrigen origen={reporte.origen} /></dd>
                    <dt>Estado</dt><dd><ChipEstado estado={reporte.estado} /></dd>
                    <dt>Fecha</dt><dd>{formatearFecha(reporte.fecha)}</dd>
                    <dt>Autor</dt><dd>{reporte.autor}</dd>
                  </dl>
                  <a href="#panel" className="inline-flex min-h-9 items-center font-semibold underline underline-offset-4">Ver en el panel C.R.A.</a>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      <div aria-label="Leyenda del mapa" className="mt-3 space-y-3 rounded-2xl bg-superficie/95 p-4 text-xs shadow-[var(--c-sombra-alta)] backdrop-blur lg:absolute lg:bottom-4 lg:left-4 lg:z-[1000] lg:mt-0">
        <div><h3 className="mb-2 font-semibold text-texto">Zonas de conservación</h3><ul className="flex flex-wrap gap-3">{prioridadesZona.map((valor) => {
          const prioridad = PRIORIDADES_ZONA[valor];
          return <li key={valor} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className="relative h-3 w-4 overflow-hidden rounded-sm border-2" style={{ borderColor: prioridad.color }}><span className="absolute inset-0" style={{ backgroundColor: prioridad.relleno, opacity: prioridad.opacidadRelleno }} /></span>{prioridad.etiqueta}</li>;
        })}</ul></div>
        <div><h3 className="mb-2 font-semibold text-texto">Reportes por prioridad</h3><ul className="flex flex-wrap gap-3">{LISTA_PRIORIDADES.map((prioridad) => (
          <li key={prioridad} className="flex items-center gap-1.5 text-suave"><span aria-hidden="true" className={cn('size-2 rounded-full', PRIORIDADES[prioridad].punto)} />{PRIORIDADES[prioridad].etiqueta}</li>
        ))}</ul></div>
      </div>
    </div>
  );
}
