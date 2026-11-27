// Reporte de monitoreo de una acción con fotografías ubicadas.
// Se monta con client:only="react" (usa Leaflet y APIs del navegador).
import 'leaflet/dist/leaflet.css';
import '../../lib/popupsQueCaben';
import '../../styles/mapa.css';
import { useEffect, useMemo, useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { divIcon, latLngBounds } from 'leaflet';
import { CircleMarker, MapContainer, Marker, Popup, TileLayer, useMap, useMapEvents } from 'react-leaflet';
import exifr from 'exifr';
import { Camera, Crosshair, ImagePlus, LocateFixed, MapPin, Send, Trash2, TriangleAlert } from 'lucide-react';
import type { Accion, FotoUbicada, ReporteMonitoreo as Monitoreo } from '../../types/plataforma';
import { useAcciones, useMonitoreos, registrarMonitoreo } from '../../lib/plataforma/estado';
import { SECTORES } from '../../lib/plataforma/catalogos';
import { cn } from '../../lib/utils';
import { LIMITES_MANGLAR } from '../../lib/areaReporte';
import AvisoZanky from '../marca/AvisoZanky';

interface Props { acciones: Accion[]; monitoreos: Monitoreo[] }

type Origen = 'exif' | 'dispositivo' | 'mapa';
interface FotoBorrador {
  id: string;
  nombre: string;
  miniatura: string | null;
  lat: number | null;
  lon: number | null;
  tomada_en: string;
  origen: Origen | null;
  estado: 'procesando' | 'lista' | 'error';
  aviso?: string;
}

const MAX_FOTOS = 6;
const LADO_MINIATURA = 480;
const DISTANCIA_AVISO_M = 500;

const hoyBogota = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Bogota' });
const fechaCorta = (iso: string) => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso.length === 10 ? `${iso}T12:00:00-05:00` : iso));

function distanciaM(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(h));
}

// Redibujar en canvas deja la imagen sin EXIF: así ni la ubicación original ni
// el modelo del teléfono viajan con la miniatura.
async function miniaturaSinMetadatos(archivo: File): Promise<string> {
  const imagen = await createImageBitmap(archivo);
  const escala = Math.min(1, LADO_MINIATURA / Math.max(imagen.width, imagen.height));
  const lienzo = document.createElement('canvas');
  lienzo.width = Math.round(imagen.width * escala);
  lienzo.height = Math.round(imagen.height * escala);
  const contexto = lienzo.getContext('2d');
  if (!contexto) throw new Error('Sin lienzo');
  contexto.drawImage(imagen, 0, 0, lienzo.width, lienzo.height);
  imagen.close();
  return lienzo.toDataURL('image/jpeg', 0.7);
}

const iconoAccion = divIcon({
  className: 'pin-reporte',
  html: '<span style="display:block;width:18px;height:18px;background:#edb512;border:2px solid #05243a;transform:rotate(45deg)"></span>',
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

function Encuadre({ puntos }: { puntos: [number, number][] }) {
  const mapa = useMap();
  const clave = puntos.map((p) => p.join(',')).join('|');
  useEffect(() => {
    if (!puntos.length) return;
    const { x, y } = mapa.getSize();
    if (!x || !y) return;
    if (puntos.length === 1) mapa.setView(puntos[0], 15);
    else mapa.fitBounds(latLngBounds(puntos), { padding: [30, 30], maxZoom: 15 });
    // Solo cuando cambian los puntos (la clave), no en cada render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapa, clave]);
  return null;
}

function AlHacerClic({ activo, alMarcar }: { activo: boolean; alMarcar: (lat: number, lon: number) => void }) {
  useMapEvents({ click: (evento) => { if (activo) alMarcar(evento.latlng.lat, evento.latlng.lng); } });
  return null;
}

export default function ReporteMonitoreo({ acciones: accionesIniciales, monitoreos: monitoreosIniciales }: Props) {
  const acciones = useAcciones(accionesIniciales);
  const monitoreos = useMonitoreos(monitoreosIniciales);
  const elegibles = useMemo(() => acciones.filter((a) => a.estado === 'en_ejecucion' || a.estado === 'cerrada'), [acciones]);

  const [accionId, setAccionId] = useState(elegibles[0]?.id ?? '');
  const [fecha, setFecha] = useState(hoyBogota());
  const [vivas, setVivas] = useState('');
  const [altura, setAltura] = useState('');
  const [observaciones, setObservaciones] = useState('');
  const [fotos, setFotos] = useState<FotoBorrador[]>([]);
  const [marcando, setMarcando] = useState<string | null>(null);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [mensaje, setMensaje] = useState<{ tipo: 'ok' | 'error'; texto: string } | null>(null);
  const entradaArchivos = useRef<HTMLInputElement>(null);

  const accion = acciones.find((a) => a.id === accionId) ?? null;
  const actualizarFoto = (id: string, cambio: Partial<FotoBorrador>) => setFotos((previas) => previas.map((f) => (f.id === id ? { ...f, ...cambio } : f)));

  async function alElegirArchivos(evento: ChangeEvent<HTMLInputElement>) {
    const archivos = Array.from(evento.target.files ?? []);
    evento.target.value = '';
    const disponibles = MAX_FOTOS - fotos.length;
    if (archivos.length > disponibles) setMensaje({ tipo: 'error', texto: `Se admiten hasta ${MAX_FOTOS} fotografías por reporte; se tomaron las primeras ${Math.max(0, disponibles)}.` });
    for (const archivo of archivos.slice(0, Math.max(0, disponibles))) {
      const id = crypto.randomUUID();
      setFotos((previas) => [...previas, { id, nombre: archivo.name, miniatura: null, lat: null, lon: null, tomada_en: new Date().toISOString(), origen: null, estado: 'procesando' }]);
      try {
        const [gps, meta, miniatura] = await Promise.all([
          exifr.gps(archivo).catch(() => undefined),
          exifr.parse(archivo, ['DateTimeOriginal']).catch(() => undefined) as Promise<{ DateTimeOriginal?: Date } | undefined>,
          miniaturaSinMetadatos(archivo),
        ]);
        const conGps = gps && Number.isFinite(gps.latitude) && Number.isFinite(gps.longitude);
        const tomada = meta?.DateTimeOriginal instanceof Date && !Number.isNaN(meta.DateTimeOriginal.getTime()) ? meta.DateTimeOriginal.toISOString() : new Date().toISOString();
        actualizarFoto(id, {
          miniatura,
          tomada_en: tomada,
          estado: 'lista',
          lat: conGps ? gps.latitude : null,
          lon: conGps ? gps.longitude : null,
          origen: conGps ? 'exif' : null,
          aviso: conGps ? undefined : 'La foto no trae ubicación: use su ubicación actual o márquela en el mapa.',
        });
      } catch {
        actualizarFoto(id, { estado: 'error', aviso: 'No se pudo leer esta imagen (formato no compatible). Pruebe con JPG o PNG.' });
      }
    }
  }

  function usarMiUbicacion(id: string) {
    if (!('geolocation' in navigator)) {
      actualizarFoto(id, { aviso: 'Este navegador no permite obtener la ubicación. Márquela en el mapa.' });
      return;
    }
    actualizarFoto(id, { aviso: 'Obteniendo su ubicación…' });
    navigator.geolocation.getCurrentPosition(
      (posicion) => actualizarFoto(id, { lat: posicion.coords.latitude, lon: posicion.coords.longitude, origen: 'dispositivo', aviso: undefined }),
      (error) => actualizarFoto(id, {
        aviso: error.code === error.PERMISSION_DENIED
          ? 'Permiso de ubicación negado. Márquela en el mapa.'
          : 'No se obtuvo la ubicación a tiempo. Inténtelo de nuevo o márquela en el mapa.',
      }),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
    );
  }

  function marcarEnMapa(lat: number, lon: number) {
    if (!marcando) return;
    actualizarFoto(marcando, { lat, lon, origen: 'mapa', aviso: undefined });
    setMarcando(null);
  }

  function enviar(evento: FormEvent) {
    evento.preventDefault();
    setMensaje(null);
    if (fotos.some((f) => f.estado === 'procesando')) {
      setErrores({ fotos: 'Espere a que terminen de procesarse las fotografías.' });
      return;
    }
    const validas = fotos.filter((f) => f.estado === 'lista');
    if (validas.some((f) => f.lat === null || f.lon === null)) {
      setErrores({ fotos: 'Ubique todas las fotografías (ubicación actual o mapa) o quite las que no tengan ubicación.' });
      return;
    }
    const fotosUbicadas: FotoUbicada[] = validas.map((f) => ({ url: f.miniatura ?? '', lat: f.lat as number, lon: f.lon as number, tomada_en: f.tomada_en }));
    const resultado = registrarMonitoreo({
      accion_id: accionId,
      fecha,
      vivas_pct: vivas === '' ? Number.NaN : Number(vivas),
      altura_cm: altura === '' ? Number.NaN : Number(altura),
      fotos: fotosUbicadas,
      observaciones,
      autor_id: 'comunidad-demo',
    });
    if (!resultado.ok) {
      setErrores(resultado.errores);
      const primero = Object.keys(resultado.errores)[0];
      document.getElementById(`monitoreo-${primero}`)?.focus();
      return;
    }
    setErrores({});
    setVivas('');
    setAltura('');
    setObservaciones('');
    setFotos([]);
    setMensaje({ tipo: 'ok', texto: 'Reporte guardado en este navegador (demostración). En la versión conectada llega a la Corporación con sus fotografías ubicadas.' });
  }

  const recibidos = useMemo(() => [...monitoreos].sort((a, b) => b.fecha.localeCompare(a.fecha)), [monitoreos]);
  const puntosMapa = useMemo(() => {
    const p: [number, number][] = [];
    if (accion) p.push([accion.lat, accion.lon]);
    for (const f of fotos) if (f.lat !== null && f.lon !== null) p.push([f.lat, f.lon]);
    if (!p.length) for (const a of elegibles) p.push([a.lat, a.lon]);
    return p;
  }, [accion, fotos, elegibles]);
  const fotosRecibidas = recibidos.flatMap((m) => m.fotos.map((f, i) => ({ ...f, clave: `${m.id}-${i}`, accion: acciones.find((a) => a.id === m.accion_id)?.nombre ?? 'Acción', fecha: m.fecha })));

  const campo = 'mt-1 w-full min-h-11 border-0 border-b border-white/60 bg-white/5 px-3 text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none';
  const error = (clave: string) => errores[clave] && <p id={`error-${clave}`} className="mt-1 text-sm text-alta-texto">{errores[clave]}</p>;

  return (
    <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <form onSubmit={enviar} noValidate className="rounded-sm border border-linea-suave bg-superficie p-5 sm:p-6" aria-labelledby="titulo-reporte-monitoreo">
        <h3 id="titulo-reporte-monitoreo" className="rotulo text-dorado-300">Reporte de monitoreo</h3>
        {!elegibles.length ? (
          <AvisoZanky animo="curioso" forma="bloque" titulo="Aún no hay acciones para reportar" className="mt-6 py-4">
            <p>No hay acciones en ejecución o cerradas. Cuando la Corporación apruebe e inicie una acción, aparecerá aquí.</p>
          </AvisoZanky>
        ) : (
          <div className="mt-4 grid gap-4">
            <label className="block">
              <span className="etiqueta-campo">Acción</span>
              <select id="monitoreo-accion_id" value={accionId} onChange={(e) => setAccionId(e.target.value)} className={campo} aria-invalid={!!errores.accion_id} aria-describedby={errores.accion_id ? 'error-accion_id' : undefined}>
                {elegibles.map((a) => <option key={a.id} value={a.id} className="bg-cra-900">{a.nombre} · {a.sector ? SECTORES[a.sector].nombre : 'Sin sector confirmado'}</option>)}
              </select>
              {error('accion_id')}
            </label>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="block">
                <span className="etiqueta-campo">Fecha</span>
                <input id="monitoreo-fecha" type="date" max={hoyBogota()} value={fecha} onChange={(e) => setFecha(e.target.value)} className={campo} aria-invalid={!!errores.fecha} aria-describedby={errores.fecha ? 'error-fecha' : undefined} />
                {error('fecha')}
              </label>
              <label className="block">
                <span className="etiqueta-campo">Plántulas vivas, %</span>
                <input id="monitoreo-vivas_pct" type="number" inputMode="decimal" min={0} max={100} value={vivas} onChange={(e) => setVivas(e.target.value)} className={campo} aria-invalid={!!errores.vivas_pct} aria-describedby={errores.vivas_pct ? 'error-vivas_pct' : undefined} />
                {error('vivas_pct')}
              </label>
              <label className="block">
                <span className="etiqueta-campo">Altura media, cm</span>
                <input id="monitoreo-altura_cm" type="number" inputMode="decimal" min={0} value={altura} onChange={(e) => setAltura(e.target.value)} className={campo} aria-invalid={!!errores.altura_cm} aria-describedby={errores.altura_cm ? 'error-altura_cm' : undefined} />
                {error('altura_cm')}
              </label>
            </div>

            <fieldset>
              <legend className="etiqueta-campo">Fotografías ubicadas ({fotos.length} de {MAX_FOTOS})</legend>
              <input ref={entradaArchivos} id="monitoreo-fotos" type="file" accept="image/*" capture="environment" multiple className="sr-only" onChange={alElegirArchivos} />
              <button type="button" onClick={() => entradaArchivos.current?.click()} disabled={fotos.length >= MAX_FOTOS} className="mt-2 inline-flex min-h-11 items-center gap-2 border border-white/60 px-4 text-sm font-bold uppercase tracking-wider hover:border-dorado-300 hover:text-dorado-300 disabled:opacity-50">
                <ImagePlus className="size-4" aria-hidden="true" />Tomar o elegir fotos
              </button>
              <p className="mt-2 text-xs text-tenue">Se lee la ubicación guardada en la foto (EXIF). La miniatura se vuelve a dibujar sin metadatos antes de guardarse.</p>
              {error('fotos')}
              {fotos.length > 0 && (
                <ul className="mt-3 grid gap-3" aria-live="polite">
                  {fotos.map((f) => {
                    const lejos = accion && f.lat !== null && f.lon !== null ? distanciaM({ lat: f.lat, lon: f.lon }, accion) : 0;
                    return (
                      <li key={f.id} className={cn('flex gap-3 border border-linea-suave bg-white/5 p-2', marcando === f.id && 'ring-2 ring-dorado-300')}>
                        <div className="grid size-20 shrink-0 place-items-center overflow-hidden bg-cra-950">
                          {f.miniatura ? <img src={f.miniatura} alt={`Fotografía ${f.nombre}`} className="h-full w-full object-cover" /> : <Camera className="size-6 text-tenue" aria-hidden="true" />}
                        </div>
                        <div className="min-w-0 flex-1 text-sm">
                          <p className="truncate font-bold">{f.nombre}</p>
                          {f.estado === 'procesando' && <p className="text-tenue">Leyendo la fotografía…</p>}
                          {f.lat !== null && f.lon !== null && (
                            <p className="text-suave">
                              <MapPin className="mr-1 inline size-3.5 text-dorado-300" aria-hidden="true" />
                              {f.lat.toFixed(5)}, {f.lon.toFixed(5)} · {f.origen === 'exif' ? 'de la foto' : f.origen === 'dispositivo' ? 'del dispositivo' : 'marcada en el mapa'}
                            </p>
                          )}
                          {lejos > DISTANCIA_AVISO_M && <p className="text-media-texto"><TriangleAlert className="mr-1 inline size-3.5" aria-hidden="true" />A {Math.round(lejos).toLocaleString('es-CO')} m del sitio de la acción.</p>}
                          {f.aviso && <p className={f.estado === 'error' ? 'text-alta-texto' : 'text-media-texto'}>{f.aviso}</p>}
                          <div className="mt-1 flex flex-wrap gap-1">
                            {f.estado === 'lista' && f.lat === null && (
                              <>
                                <button type="button" onClick={() => usarMiUbicacion(f.id)} className="inline-flex min-h-11 items-center gap-1 px-2 text-xs font-bold uppercase text-dorado-300 hover:underline"><LocateFixed className="size-3.5" aria-hidden="true" />Usar mi ubicación</button>
                                <button type="button" onClick={() => setMarcando(marcando === f.id ? null : f.id)} aria-pressed={marcando === f.id} className="inline-flex min-h-11 items-center gap-1 px-2 text-xs font-bold uppercase text-dorado-300 hover:underline"><Crosshair className="size-3.5" aria-hidden="true" />{marcando === f.id ? 'Cancelar' : 'Marcar en el mapa'}</button>
                              </>
                            )}
                            <button type="button" onClick={() => { setFotos((p) => p.filter((x) => x.id !== f.id)); if (marcando === f.id) setMarcando(null); }} className="inline-flex min-h-11 items-center gap-1 px-2 text-xs font-bold uppercase text-suave hover:text-alta-texto" aria-label={`Quitar ${f.nombre}`}><Trash2 className="size-3.5" aria-hidden="true" />Quitar</button>
                          </div>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
            </fieldset>

            <label className="block">
              <span className="etiqueta-campo">Observaciones</span>
              <textarea value={observaciones} onChange={(e) => setObservaciones(e.target.value)} rows={3} className={cn(campo, 'py-2')} placeholder="Estado de las plántulas, marea, residuos, presencia de fauna…" />
            </label>
            <button type="submit" className="inline-flex min-h-11 items-center justify-center gap-2 bg-dorado-500 px-5 text-xs font-black uppercase tracking-[0.08em] text-cra-950 hover:bg-dorado-300">
              <Send className="size-4" aria-hidden="true" />Enviar reporte
            </button>
          </div>
        )}
        <div aria-live="polite">
          {mensaje && (mensaje.tipo === 'ok'
            ? <AvisoZanky animo="celebrando" titulo="¡Reporte enviado!" className="mt-4 rounded-3xl border border-dorado-500/40 bg-dorado-500/10 p-4 text-sm"><p className="text-suave">{mensaje.texto}</p></AvisoZanky>
            : <p className="mt-4 border-l-4 border-alta bg-alta-suave p-3 text-sm">{mensaje.texto}</p>)}
        </div>
      </form>

      <div className="grid content-start gap-6">
        <div>
          <p className="rotulo text-dorado-300">{marcando ? 'Haga clic en el mapa para ubicar la foto' : 'Sitio de la acción y fotografías ubicadas'}</p>
          <div className={cn('relative z-0 mt-3 h-80 overflow-hidden border border-linea', marcando && 'cursor-crosshair ring-2 ring-dorado-300')}>
            <MapContainer maxBounds={LIMITES_MANGLAR} maxBoundsViscosity={1} minZoom={9} center={[10.95, -75.0]} zoom={10} scrollWheelZoom={false} className="h-full w-full" aria-label="Mapa de fotografías ubicadas">
              <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
              <Encuadre puntos={puntosMapa} />
              <AlHacerClic activo={marcando !== null} alMarcar={marcarEnMapa} />
              {elegibles.map((a) => (
                <Marker key={a.id} position={[a.lat, a.lon]} icon={iconoAccion} title={a.nombre}>
                  <Popup><strong>{a.nombre}</strong><br />{a.sector ? SECTORES[a.sector].largo : 'Sin sector confirmado'}</Popup>
                </Marker>
              ))}
              {fotos.filter((f) => f.lat !== null && f.lon !== null).map((f) => (
                <CircleMarker key={f.id} center={[f.lat as number, f.lon as number]} radius={7} pathOptions={{ color: '#f8d86f', fillColor: '#d946ef', fillOpacity: 0.9, weight: 2 }}>
                  <Popup>{f.miniatura && <img src={f.miniatura} alt="" className="mb-1 w-44" />}Foto por enviar</Popup>
                </CircleMarker>
              ))}
              {fotosRecibidas.map((f) => (
                <CircleMarker key={f.clave} center={[f.lat, f.lon]} radius={5} pathOptions={{ color: '#ffffff', fillColor: '#d946ef', fillOpacity: 0.7, weight: 1 }}>
                  <Popup><img src={f.url} alt="" className="mb-1 w-44" loading="lazy" /><strong>{f.accion}</strong><br />{fechaCorta(f.tomada_en)}</Popup>
                </CircleMarker>
              ))}
            </MapContainer>
          </div>
          <p className="mt-2 text-xs text-tenue">Rombo dorado: sitio de la acción · punto magenta: fotografía ubicada.</p>
        </div>

        <div>
          <p className="rotulo text-dorado-300">Reportes recibidos</p>
          {recibidos.length === 0 ? (
            <AvisoZanky animo="curioso" className="mt-3 text-suave"><p>Aún no hay reportes de monitoreo. El primero que llegue aparecerá aquí.</p></AvisoZanky>
          ) : (
            <div className="mt-3 overflow-x-auto">
              <table className="w-full min-w-[480px] text-left text-sm">
                <thead>
                  <tr className="border-b border-white text-[11px] font-bold uppercase tracking-[0.06em] text-suave">
                    <th scope="col" className="py-2 pr-3">Fecha</th><th scope="col" className="py-2 pr-3">Acción</th><th scope="col" className="py-2 pr-3 text-right">Vivas</th><th scope="col" className="py-2 pr-3 text-right">Altura</th><th scope="col" className="py-2 text-right">Fotos</th>
                  </tr>
                </thead>
                <tbody>
                  {recibidos.map((m) => (
                    <tr key={m.id} className="border-b border-white/25">
                      <td className="py-2 pr-3 whitespace-nowrap">{fechaCorta(m.fecha)}</td>
                      <td className="py-2 pr-3">{acciones.find((a) => a.id === m.accion_id)?.nombre ?? 'Acción no disponible'}</td>
                      <td className="py-2 pr-3 text-right tabular-nums">{m.vivas_pct.toLocaleString('es-CO')} %</td>
                      <td className="py-2 pr-3 text-right tabular-nums">{m.altura_cm.toLocaleString('es-CO')} cm</td>
                      <td className="py-2 text-right tabular-nums">{m.fotos.length}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <p className="mt-3 text-xs text-tenue">Cada fotografía ubicada se convierte en una etiqueta independiente para reentrenar el modelo del workflow.</p>
        </div>
      </div>
    </div>
  );
}
