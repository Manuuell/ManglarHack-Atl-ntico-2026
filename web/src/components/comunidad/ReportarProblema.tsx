// Reportar un problema desde la portada: qué pasa, dónde (GPS o tocando el mapa), foto y detalles.
// La ubicación se evalúa contra la cobertura de manglar de la C.R.A. (1:5.000) y su área de
// influencia; lo de fuera no se admite. Con el backend conectado, el reporte (y su foto) va al servidor
// común con la RPC crear_reporte, que recalcula zona, prioridad y confianza; sin él, queda en este
// navegador (modo demostración). En los dos casos aparece al instante en el mapa en vivo.
import { useEffect, useRef, useState, type FormEvent } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Camera, Check, Crosshair, ImagePlus, LoaderCircle, MapPin, X } from 'lucide-react';
import type { CapaManglarCRA, Prioridad, Reporte, TipoReporte, ZonasManglar } from '../../types/manglar';
import { LISTA_TIPOS, TIPOS } from '../../lib/catalogos';
import { LIMITES_MANGLAR, RADIO_INFLUENCIA_M, evaluarUbicacion } from '../../lib/areaReporte';
import { obtenerCapaManglarCRA } from '../../lib/datos';
import { agregarReporteLocal, numeroDeCaso } from '../../lib/comunidad/reportesLocales';
import { backendActivo, crearReporte, estadoDeReportes, idDeEsteNavegador, prepararFoto, subirFoto } from '../../lib/backend/supabase';
import { cn } from '../../lib/utils';

interface Props { sectores: ZonasManglar }
type Momento = 'ahora' | 'hoy' | 'antes';
type Magnitud = 'pequena' | 'mediana' | 'grande';
interface Punto { lat: number; lon: number; metodo: 'gps' | 'mapa'; precision: number | null }

const MOMENTOS: [Momento, string][] = [['ahora', 'Ahora mismo'], ['hoy', 'Hoy, más temprano'], ['antes', 'Antes de hoy']];
const MAGNITUDES: [Magnitud, string, string][] = [['pequena', 'Pequeña', 'Unos metros'], ['mediana', 'Mediana', 'Como una cancha'], ['grande', 'Grande', 'Más que una cancha']];

function dentroDeAnillo(lon: number, lat: number, anillo: number[][]): boolean {
  let d = false;
  for (let i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
    const [xi, yi] = anillo[i], [xj, yj] = anillo[j];
    if ((yi > lat) !== (yj > lat) && lon < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) d = !d;
  }
  return d;
}

/** El sector del manglar donde cae el punto, o el más cercano. */
function sectorDe(sectores: ZonasManglar, lat: number, lon: number) {
  let mejor = sectores.features[0];
  let dist = Infinity;
  for (const f of sectores.features) {
    const anillo = f.geometry.coordinates[0];
    if (dentroDeAnillo(lon, lat, anillo)) return f.properties;
    for (const [x, y] of anillo) {
      const d = Math.hypot(x - lon, y - lat);
      if (d < dist) { dist = d; mejor = f; }
    }
  }
  return mejor.properties;
}

export default function ReportarProblema({ sectores }: Props) {
  const [tipo, setTipo] = useState<TipoReporte | null>(null);
  const [punto, setPunto] = useState<Punto | null>(null);
  const [capa, setCapa] = useState<CapaManglarCRA | null>(null);
  const [errorCapa, setErrorCapa] = useState(false);
  const [buscandoGps, setBuscandoGps] = useState(false);
  const [avisoGps, setAvisoGps] = useState('');
  const [foto, setFoto] = useState<{ url: string; nombre: string; archivo: File } | null>(null);
  const [enviando, setEnviando] = useState(false);
  const [idPublico, setIdPublico] = useState<string | null>(null);
  // Un id por reporte, no por intento: si el envío falla y la persona reintenta, el servidor no lo duplica.
  const idEnvio = useRef<string>(crypto.randomUUID());
  const [momento, setMomento] = useState<Momento>('ahora');
  const [magnitud, setMagnitud] = useState<Magnitud>('pequena');
  const [descripcion, setDescripcion] = useState('');
  const [acepta, setAcepta] = useState(false);
  const [error, setError] = useState('');
  const [enviado, setEnviado] = useState<Reporte | null>(null);
  const caja = useRef<HTMLDivElement>(null);
  const mapa = useRef<L.Map | null>(null);
  const marcador = useRef<L.Marker | null>(null);
  const listo = useRef<HTMLDivElement>(null);

  // Al enviar, la tarjeta se encoge: se lleva la confirmación a la vista para que no quede fuera.
  useEffect(() => {
    if (!enviado || !listo.current) return;
    const quieto = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    listo.current.scrollIntoView({ behavior: quieto ? 'auto' : 'smooth', block: 'center' });
  }, [enviado]);

  useEffect(() => {
    obtenerCapaManglarCRA().then(setCapa).catch(() => setErrorCapa(true));
  }, []);

  useEffect(() => {
    if (!caja.current || mapa.current) return;
    const m = L.map(caja.current, { zoomControl: true, maxBounds: L.latLngBounds(LIMITES_MANGLAR).pad(0.3) });
    L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 18, attribution: 'Imágenes © Esri, Maxar',
    }).addTo(m);
    // Los sectores del manglar marcan dónde tocar mientras llega la cobertura detallada.
    const capaSectores = L.geoJSON(sectores, { style: () => ({ color: '#f8d86f', weight: 2, fillColor: '#4ade80', fillOpacity: 0.12, dashArray: '5 5' }), interactive: false }).addTo(m);
    m.fitBounds(capaSectores.getBounds(), { padding: [12, 12] });
    m.on('click', (e: L.LeafletMouseEvent) => setPunto({ lat: e.latlng.lat, lon: e.latlng.lng, metodo: 'mapa', precision: null }));
    mapa.current = m;
    const ro = new ResizeObserver(() => m.invalidateSize());
    ro.observe(caja.current);
    return () => { ro.disconnect(); m.remove(); mapa.current = null; };
  }, [enviado, sectores]);

  useEffect(() => {
    const m = mapa.current;
    if (!m || !capa) return;
    const l = L.geoJSON(capa as GeoJSON.GeoJsonObject, { style: () => ({ color: '#22c55e', weight: 0.6, fillColor: '#4ade80', fillOpacity: 0.35 }), interactive: false }).addTo(m);
    l.bringToBack();
    return () => { l.remove(); };
  }, [capa, enviado]);

  useEffect(() => {
    const m = mapa.current;
    if (!m) return;
    marcador.current?.remove();
    marcador.current = null;
    if (!punto) return;
    const icono = L.divIcon({ className: 'pin-reporte ahora', html: '<span style="--c:#dc2626"></span>', iconSize: [16, 16] });
    marcador.current = L.marker([punto.lat, punto.lon], { icon: icono, draggable: true }).addTo(m);
    marcador.current.on('dragend', () => { const p = marcador.current!.getLatLng(); setPunto({ lat: p.lat, lon: p.lng, metodo: 'mapa', precision: null }); });
    if (m.getZoom() < 13) m.flyTo([punto.lat, punto.lon], 15, { duration: 0.8 });
  }, [punto]);

  const evaluacion = punto && capa ? evaluarUbicacion(punto.lat, punto.lon, capa) : null;
  const metros = (d: number) => (Number.isFinite(d) ? `a ${d.toLocaleString('es-CO')} m del manglar` : 'lejos del manglar');

  function usarGps() {
    setAvisoGps('');
    if (!('geolocation' in navigator)) { setAvisoGps('Este navegador no da la ubicación: toca el sitio en el mapa.'); return; }
    setBuscandoGps(true);
    navigator.geolocation.getCurrentPosition(
      (p) => { setBuscandoGps(false); setPunto({ lat: p.coords.latitude, lon: p.coords.longitude, metodo: 'gps', precision: Math.round(p.coords.accuracy) }); },
      () => { setBuscandoGps(false); setAvisoGps('No pudimos leer tu ubicación. Toca el sitio en el mapa.'); },
      { enableHighAccuracy: true, timeout: 12_000, maximumAge: 30_000 },
    );
  }

  function elegirFoto(archivo: File | undefined) {
    if (!archivo) return;
    if (!archivo.type.startsWith('image/')) { setError('La evidencia debe ser una foto.'); return; }
    if (foto) URL.revokeObjectURL(foto.url);
    setFoto({ url: URL.createObjectURL(archivo), nombre: archivo.name, archivo });
  }

  async function enviar(e: FormEvent) {
    e.preventDefault();
    if (enviando) return;
    setError('');
    if (!tipo) return setError('Elige qué está pasando.');
    if (!punto) return setError('Marca dónde está pasando: usa tu ubicación o toca el mapa.');
    if (!evaluacion) return setError('Espera a que cargue la capa del manglar para revisar la ubicación.');
    if (!evaluacion.admitido) return setError(`Ese punto está fuera del manglar y de su área de influencia (${RADIO_INFLUENCIA_M} m). Toca dentro de las zonas marcadas o mueve el punto.`);
    if (!acepta) return setError('Para enviar, acepta el tratamiento de datos (Ley 1581).');
    const sector = sectorDe(sectores, punto.lat, punto.lon);
    // Misma regla que la app y el servidor; el servidor la recalcula al recibir.
    let p: number = TIPOS[tipo].gravedad;
    if (evaluacion.dentro_poligono && sector.prioridad === 'critica') p += 1;
    if (momento === 'antes') p -= 1;
    if (magnitud === 'grande') p += 1;
    let confianza = 20 + (foto ? 25 : 0) + (punto.metodo === 'gps' ? 20 : 10) + (evaluacion.dentro_poligono ? 15 : 10) + (momento === 'ahora' ? 10 : momento === 'hoy' ? 5 : 0) + (descripcion.trim().length >= 15 ? 5 : 0);
    confianza = Math.min(80, confianza);
    const ahora = new Date().toISOString();
    const reporte: Reporte = {
      id: idEnvio.current, canal: 'web', tipo, descripcion: descripcion.trim().slice(0, 1000),
      lat: punto.lat, lon: punto.lon, precision_m: punto.precision, capturado_en: ahora, recibido_en: ahora,
      zona: sector.nombre, municipio: sector.municipio, dentro_poligono: evaluacion.dentro_poligono, distancia_m: evaluacion.distancia_m,
      prioridad: Math.max(1, Math.min(5, p)) as Prioridad, confianza, estado: 'recibido',
      ia_tipo_detectado: null, ia_confianza: null, foto_url: null, foto_hash: null, reportante_id: null,
    };
    if (!backendActivo) {
      agregarReporteLocal(reporte);
      setEnviado(reporte);
      return;
    }
    setEnviando(true);
    try {
      let fotoUrl: string | null = null;
      let fotoHash: string | null = null;
      if (foto) {
        const preparada = await prepararFoto(foto.archivo);
        await subirFoto(reporte.id, preparada.jpeg);
        fotoUrl = `evidencias/${reporte.id}.jpg`;
        fotoHash = preparada.hash;
      }
      const creado = await crearReporte({
        id: reporte.id, canal: 'web', tipo, descripcion: reporte.descripcion, lat: punto.lat, lon: punto.lon,
        precision_m: punto.precision, metodo_ubicacion: punto.metodo, capturado_en: ahora, momento, magnitud,
        zona: null, municipio: null, // el servidor los calcula con sus zonas
        dentro_poligono: evaluacion.dentro_poligono, distancia_m: evaluacion.distancia_m, confianza,
        foto_hash: fotoHash, foto_de_camara: false, foto_url: fotoUrl, anonimo: false,
        reportante_id: idDeEsteNavegador(), sincronizado_tarde: false,
      });
      // La prioridad y la confianza que valen son las que calculó el servidor.
      let final: Reporte = reporte;
      try {
        const [e] = await estadoDeReportes([reporte.id]);
        if (e) final = { ...reporte, prioridad: e.prioridad, confianza: e.confianza, estado: e.estado };
      } catch { /* el reporte ya quedó guardado; se ve con la prioridad estimada */ }
      // En el mapa va con el id público y la ubicación aproximada, igual que lo publica el servidor.
      agregarReporteLocal({ ...final, id: creado.id_publico, descripcion: '', lat: Number(punto.lat.toFixed(3)), lon: Number(punto.lon.toFixed(3)) });
      setIdPublico(creado.id_publico);
      setEnviado(final);
    } catch (err) {
      setError(`${(err as Error).message || 'No se pudo enviar el reporte.'} Tus datos siguen aquí: vuelve a tocar «Enviar reporte».`);
    } finally {
      setEnviando(false);
    }
  }

  function otro() {
    if (foto) URL.revokeObjectURL(foto.url);
    idEnvio.current = crypto.randomUUID();
    setTipo(null); setPunto(null); setFoto(null); setMomento('ahora'); setMagnitud('pequena'); setDescripcion(''); setAcepta(false); setError(''); setEnviado(null); setIdPublico(null);
  }

  if (enviado) {
    return (
      <div ref={listo} className="reportar-card reportar-listo" role="status">
        <img src="/marca/zanky/zanky-celebrando-256.webp" alt="" width={120} height={120} />
        <p className="rotulo-claro">Reporte enviado</p>
        <h3>¡Gracias! Tu reporte <span>{numeroDeCaso(enviado.id)}</span> ya está en el mapa.</h3>
        <p>{TIPOS[enviado.tipo].etiquetaLarga} · {enviado.zona} · prioridad {enviado.prioridad}. La C.R.A. lo verifica antes de actuar.</p>
        <div className="acciones">
          <a className="boton boton-dorado" href="#mapa" onClick={() => setTimeout(() => window.dispatchEvent(new CustomEvent('zanky:ver-reporte', { detail: idPublico ?? enviado.id })), 500)}><MapPin className="size-4" aria-hidden="true" />Verlo en el mapa</a>
          <button type="button" className="boton boton-claro" onClick={otro}>Reportar otro</button>
        </div>
        <p className="nota">{backendActivo
          ? 'Llegó al servidor de la C.R.A., que lo revisa en su panel. Guarda tu número de caso para cualquier consulta. En el mapa público sale sin datos tuyos y con la ubicación aproximada.'
          : 'Modo demostración: se guarda en este navegador y aparece en el monitoreo y el panel.'}</p>
      </div>
    );
  }

  return (
    <form className="reportar-card" onSubmit={enviar} noValidate>
      <fieldset>
        <legend><span className="paso">1</span>¿Qué está pasando?</legend>
        <div className="tipos">
          {LISTA_TIPOS.map((t) => {
            const Icono = TIPOS[t].icono;
            return (
              <button key={t} type="button" aria-pressed={tipo === t} onClick={() => setTipo(t)} className={cn('tipo', tipo === t && 'activo')}>
                <Icono className="size-5" aria-hidden="true" /><span>{TIPOS[t].etiquetaLarga}</span>
              </button>
            );
          })}
        </div>
      </fieldset>

      <fieldset>
        <legend><span className="paso">2</span>¿Dónde?</legend>
        <div className="ubicar">
          <button type="button" className="boton boton-tinta" onClick={usarGps} disabled={buscandoGps}>
            {buscandoGps ? <LoaderCircle className="size-4 animate-spin" aria-hidden="true" /> : <Crosshair className="size-4" aria-hidden="true" />}
            {buscandoGps ? 'Buscando…' : 'Usar mi ubicación'}
          </button>
          <span>o toca el sitio en el mapa</span>
        </div>
        <div className="mini-mapa"><div ref={caja} className="absolute inset-0" /></div>
        <p className={cn('estado-ubicacion', evaluacion && (evaluacion.admitido ? 'ok' : 'mal'))} aria-live="polite">
          {avisoGps || (!punto ? 'Sin ubicación todavía.' : errorCapa ? 'No se pudo cargar la capa del manglar.' : !capa ? 'Revisando contra la capa del manglar…' : evaluacion!.dentro_poligono ? '✓ Dentro del manglar' : evaluacion!.admitido ? `✓ ${metros(evaluacion!.distancia_m).replace(/^a/, 'A')} (área de influencia)` : `✗ Fuera del área de reporte (${metros(evaluacion!.distancia_m)}). Toca dentro de las zonas marcadas.`)}
          {punto?.metodo === 'gps' && punto.precision !== null && ` · precisión ±${punto.precision} m`}
        </p>
      </fieldset>

      <fieldset>
        <legend><span className="paso">3</span>Foto <small>(si puedes acercarte sin riesgo)</small></legend>
        {foto ? (
          <div className="foto">
            <img src={foto.url} alt="Foto elegida para el reporte" />
            <button type="button" onClick={() => { URL.revokeObjectURL(foto.url); setFoto(null); }} aria-label="Quitar la foto"><X className="size-4" aria-hidden="true" /></button>
          </div>
        ) : (
          <label className="subir">
            <input type="file" accept="image/*" capture="environment" className="sr-only" onChange={(e) => elegirFoto(e.target.files?.[0])} />
            <Camera className="size-5" aria-hidden="true" /> Tomar o elegir una foto <ImagePlus className="size-4 opacity-60" aria-hidden="true" />
          </label>
        )}
      </fieldset>

      <fieldset>
        <legend><span className="paso">4</span>Detalles</legend>
        <div className="opciones" role="group" aria-label="Cuándo">
          {MOMENTOS.map(([v, t]) => <button key={v} type="button" aria-pressed={momento === v} className={cn('opcion', momento === v && 'activo')} onClick={() => setMomento(v)}>{t}</button>)}
        </div>
        <div className="opciones" role="group" aria-label="Qué tan grande">
          {MAGNITUDES.map(([v, t, ej]) => <button key={v} type="button" aria-pressed={magnitud === v} className={cn('opcion', magnitud === v && 'activo')} onClick={() => setMagnitud(v)}>{t}<small>{ej}</small></button>)}
        </div>
        <textarea rows={2} maxLength={500} value={descripcion} onChange={(e) => setDescripcion(e.target.value)} placeholder="Cuéntanos en pocas palabras qué viste (opcional)" />
        <label className="acepto">
          <input type="checkbox" checked={acepta} onChange={(e) => setAcepta(e.target.checked)} />
          <span>Acepto el tratamiento de mis datos según la Ley 1581 de 2012. No se publica quién reporta y la ubicación pública va difuminada.</span>
        </label>
      </fieldset>

      {error && <p className="error" role="alert">{error}</p>}
      <button type="submit" className="boton boton-dorado boton-grande enviar" disabled={enviando} aria-busy={enviando}>
        {enviando ? <><LoaderCircle className="size-5 animate-spin" aria-hidden="true" />Enviando…</> : <><Check className="size-5" aria-hidden="true" />Enviar reporte</>}
      </button>
    </form>
  );
}
