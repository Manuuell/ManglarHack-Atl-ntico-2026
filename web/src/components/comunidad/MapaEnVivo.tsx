// Mapa en vivo de la portada: cobertura de manglar de la C.R.A., sectores, reportes de la comunidad
// y jornadas, con la lista de lo que está pasando. Lo nuevo llega en tiempo real (otras pestañas
// incluidas) y el mapa vuela hasta allá.
import { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { CalendarDays, MapPin, Radio } from 'lucide-react';
import type { ReportePublico, ZonasManglar } from '../../types/manglar';
import type { Jornada } from '../../types/plataforma';
import { ESTADOS, PRIORIDADES, TIPOS, nivelPrioridad } from '../../lib/catalogos';
import { useReportesPublicos } from '../../lib/reportesStore';
import { useJornadas } from '../../lib/plataforma/estado';
import { LIMITES_MANGLAR, enAreaDeReporte } from '../../lib/areaReporte';
import { obtenerCapaManglarCRA } from '../../lib/datos';
import { numeroDeCaso } from '../../lib/comunidad/reportesLocales';
import { cn } from '../../lib/utils';

interface Props { reportes: ReportePublico[]; sectores: ZonasManglar; jornadas: Jornada[] }

const zona = { timeZone: 'America/Bogota' } as const;
function hace(iso: string, ahora: number): string {
  const min = Math.max(0, Math.round((ahora - Date.parse(iso)) / 60000));
  if (min < 1) return 'ahora mismo';
  if (min < 60) return `hace ${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `hace ${h} h`;
  const d = Math.round(h / 24);
  return `hace ${d} ${d === 1 ? 'día' : 'días'}`;
}
const fechaJornada = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));

export default function MapaEnVivo({ reportes: iniciales, sectores, jornadas: jornadasIniciales }: Props) {
  const reportes = useReportesPublicos(iniciales);
  const jornadas = useJornadas(jornadasIniciales);
  const caja = useRef<HTMLDivElement>(null);
  const mapa = useRef<L.Map | null>(null);
  const capaPuntos = useRef<L.LayerGroup | null>(null);
  const marcadores = useRef(new Map<string, L.Marker>());
  const conocidos = useRef<Set<string> | null>(null);
  const [nuevos, setNuevos] = useState<Set<string>>(new Set());
  const [ahora, setAhora] = useState(() => Date.now());

  const visibles = useMemo(
    () => reportes.filter((r) => r.estado !== 'descartado' && enAreaDeReporte(r)).sort((a, b) => b.capturado_en.localeCompare(a.capturado_en)),
    [reportes],
  );
  const proximas = useMemo(() => jornadas.filter((j) => Date.parse(j.fin) > ahora).sort((a, b) => a.inicio.localeCompare(b.inicio)).slice(0, 2), [jornadas, ahora]);

  // Mapa: se crea una vez.
  useEffect(() => {
    if (!caja.current || mapa.current) return;
    const m = L.map(caja.current, { zoomControl: false, scrollWheelZoom: false, maxBounds: L.latLngBounds(LIMITES_MANGLAR).pad(0.6) });
    L.control.zoom({ position: 'bottomright' }).addTo(m);
    L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 18, attribution: 'Imágenes © Esri, Maxar, Earthstar Geographics',
    }).addTo(m);
    L.geoJSON(sectores, {
      style: () => ({ color: '#f8d86f', weight: 1.6, fill: false, dashArray: '5 5' }),
      onEachFeature: (f, capa) => capa.bindTooltip(`Sector ${f.properties?.nombre ?? ''}`, { sticky: true }),
    }).addTo(m);
    capaPuntos.current = L.layerGroup().addTo(m);
    m.fitBounds(L.latLngBounds(LIMITES_MANGLAR), { padding: [20, 20] });
    mapa.current = m;
    // La cobertura real de manglar (C.R.A., 1:5.000) llega después, sin frenar la portada.
    obtenerCapaManglarCRA().then((capa) => {
      L.geoJSON(capa as GeoJSON.GeoJsonObject, { style: () => ({ color: '#22c55e', weight: 0.6, fillColor: '#4ade80', fillOpacity: 0.35 }), interactive: false }).addTo(m).bringToBack();
    }).catch(() => { /* sin la capa queda el mapa con los sectores */ });
    const ro = new ResizeObserver(() => m.invalidateSize());
    ro.observe(caja.current);
    const volar = (e: Event) => {
      const id = (e as CustomEvent<string>).detail;
      const marcador = marcadores.current.get(id);
      if (marcador) { m.flyTo(marcador.getLatLng(), 15, { duration: 1.2 }); setTimeout(() => marcador.openPopup(), 1300); }
    };
    window.addEventListener('zanky:ver-reporte', volar);
    const reloj = window.setInterval(() => setAhora(Date.now()), 30_000);
    return () => { ro.disconnect(); window.removeEventListener('zanky:ver-reporte', volar); clearInterval(reloj); m.remove(); mapa.current = null; };
  }, [sectores]);

  // Puntos: se repintan cuando cambia la lista; lo nuevo late y el mapa vuela hasta allá.
  useEffect(() => {
    const m = mapa.current;
    const capa = capaPuntos.current;
    if (!m || !capa) return;
    const primera = conocidos.current === null;
    const recien = primera ? [] : visibles.filter((r) => !conocidos.current!.has(r.id));
    conocidos.current = new Set(visibles.map((r) => r.id));
    capa.clearLayers();
    marcadores.current.clear();
    for (const r of visibles) {
      const abierto = ESTADOS[r.estado].abierto;
      const color = PRIORIDADES[nivelPrioridad(r.prioridad)].color;
      const late = recien.some((x) => x.id === r.id) || (abierto && r.prioridad >= 4);
      const icono = L.divIcon({ className: cn('pin-reporte', late && 'ahora'), html: `<span style="--c:${color}"></span>`, iconSize: [16, 16] });
      const mk = L.marker([r.lat, r.lon], { icon: icono, keyboard: false })
        .bindPopup(`<b>${numeroDeCaso(r.id)} · ${TIPOS[r.tipo].etiquetaLarga}</b><br>${r.zona ?? ''} · ${ESTADOS[r.estado].etiqueta}<br><small>Ubicación aproximada</small>`)
        .addTo(capa);
      marcadores.current.set(r.id, mk);
    }
    for (const j of proximas) {
      const icono = L.divIcon({ className: 'pin-jornada', html: '<span>🌱</span>', iconSize: [28, 28] });
      L.marker([j.lat, j.lon], { icon: icono, keyboard: false }).bindPopup(`<b>${j.titulo}</b><br>${fechaJornada(j.inicio)}<br><a href="/plataforma/jornadas?jornada=${j.id}">Ver la invitación</a>`).addTo(capa);
    }
    if (recien.length) {
      setNuevos((prev) => new Set([...prev, ...recien.map((r) => r.id)]));
      const ultimo = recien[recien.length - 1];
      m.flyTo([ultimo.lat, ultimo.lon], 14, { duration: 1.2 });
      setTimeout(() => setNuevos((prev) => { const s = new Set(prev); recien.forEach((r) => s.delete(r.id)); return s; }), 12_000);
    }
  }, [visibles, proximas]);

  const ver = (id: string) => window.dispatchEvent(new CustomEvent('zanky:ver-reporte', { detail: id }));

  return (
    <div className="envivo">
      <div className="envivo-mapa">
        <div ref={caja} className="absolute inset-0" />
        <div className="visor-barra">
          <span className="visor-chip"><span className="punto" aria-hidden="true" />En vivo</span>
          <span className="visor-chip leyenda"><i style={{ background: '#4ade80' }} />Manglar</span>
          <span className="visor-chip leyenda"><i style={{ background: '#dc2626' }} />Reportes</span>
        </div>
      </div>
      <aside className="envivo-lista" aria-label="Lo que está pasando en el manglar" aria-live="polite">
        <p className="envivo-titulo"><Radio className="size-4" aria-hidden="true" />Ahora en el manglar</p>
        <ul>
          {visibles.slice(0, 7).map((r) => {
            const Icono = TIPOS[r.tipo].icono;
            const color = PRIORIDADES[nivelPrioridad(r.prioridad)].color;
            return (
              <li key={r.id} className={cn(nuevos.has(r.id) && 'nuevo')}>
                <button type="button" onClick={() => ver(r.id)}>
                  <span className="icono" style={{ background: color }}><Icono className="size-4" aria-hidden="true" /></span>
                  <span className="texto">
                    <b>{TIPOS[r.tipo].etiquetaLarga}</b>
                    <small><MapPin className="inline size-3" aria-hidden="true" /> {r.zona ?? 'Atlántico'} · {hace(r.capturado_en, ahora)}</small>
                  </span>
                  <span className="estado">{nuevos.has(r.id) ? 'Nuevo' : ESTADOS[r.estado].etiqueta}</span>
                </button>
              </li>
            );
          })}
        </ul>
        {proximas.length > 0 && (
          <div className="envivo-jornadas">
            {proximas.map((j) => (
              <a key={j.id} href={`/plataforma/jornadas?jornada=${j.id}`}>
                <CalendarDays className="size-4 shrink-0" aria-hidden="true" />
                <span><b>{j.titulo}</b><small>{fechaJornada(j.inicio)} · {j.inscritos}/{j.cupos} inscritos</small></span>
              </a>
            ))}
          </div>
        )}
        <p className="envivo-pie">Datos de ejemplo y lo que reportes desde este navegador.</p>
      </aside>
    </div>
  );
}
