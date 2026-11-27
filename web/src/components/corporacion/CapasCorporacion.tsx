// Capas de la Corporación: KMZ/KML → GeoJSON en el navegador, con vista previa
// y guardado para que el workflow las dibuje. Solo cliente (Leaflet, DOMParser).
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';
import { useEffect, useState, type ChangeEvent } from 'react';
import { geoJSON } from 'leaflet';
import { GeoJSON, MapContainer, TileLayer, useMap } from 'react-leaflet';
import { kml as kmlAGeoJSON } from '@tmcw/togeojson';
import { strFromU8, unzipSync } from 'fflate';
import type { FeatureCollection } from 'geojson';
import { Download, FileUp, Layers, Save, Trash2 } from 'lucide-react';
import { useRolDemo } from '../../lib/plataforma/estado';
import { puede } from '../../lib/plataforma/catalogos';
import { descargarArchivo } from '../../lib/exportar';
import { FUENTE_MANGLAR_CRA, URL_CAPA_MANGLAR_CRA, URL_CAPA_PRIORIDADES } from '../../lib/datos';

interface CapaGuardada { id: string; nombre: string; cargada_en: string; geojson: FeatureCollection }
const CLAVE = 'zanky-web:v1:capas-cra';
const LIMITE_GUARDADO = 4 * 1024 * 1024;
const LIMITE_KML = 40 * 1024 * 1024;

function leerGuardadas(): CapaGuardada[] {
  try {
    const v: unknown = JSON.parse(localStorage.getItem(CLAVE) ?? '[]');
    return Array.isArray(v) ? (v as CapaGuardada[]) : [];
  } catch { return []; }
}

function Encuadre({ capa }: { capa: FeatureCollection | null }) {
  const mapa = useMap();
  useEffect(() => {
    if (!capa) return;
    const limites = geoJSON(capa).getBounds();
    if (limites.isValid()) mapa.fitBounds(limites, { padding: [20, 20] });
  }, [mapa, capa]);
  return null;
}

function resumen(capa: FeatureCollection) {
  const tipos: Record<string, number> = {};
  const campos = new Set<string>();
  for (const f of capa.features) {
    const t = f.geometry?.type ?? 'Sin geometría';
    tipos[t] = (tipos[t] ?? 0) + 1;
    for (const k of Object.keys(f.properties ?? {})) campos.add(k);
  }
  return { tipos, campos: [...campos].slice(0, 24) };
}

export default function CapasCorporacion() {
  const rol = useRolDemo();
  const autorizado = puede(rol, 'cargar_capas');
  const [guardadas, setGuardadas] = useState<CapaGuardada[]>([]);
  const [vista, setVista] = useState<{ nombre: string; capa: FeatureCollection } | null>(null);
  const [estado, setEstado] = useState<{ tipo: 'info' | 'error'; texto: string } | null>(null);
  const [procesando, setProcesando] = useState(false);

  useEffect(() => { setGuardadas(leerGuardadas()); }, []);

  async function alElegir(evento: ChangeEvent<HTMLInputElement>) {
    const archivo = evento.target.files?.[0];
    evento.target.value = '';
    if (!archivo) return;
    setProcesando(true);
    setEstado({ tipo: 'info', texto: `Leyendo ${archivo.name}…` });
    try {
      const bytes = new Uint8Array(await archivo.arrayBuffer());
      let texto: string;
      if (/\.kmz$/i.test(archivo.name)) {
        const zip = unzipSync(bytes);
        const nombres = Object.keys(zip).filter((n) => /\.kml$/i.test(n));
        const elegido = nombres.find((n) => /(^|\/)doc\.kml$/i.test(n)) ?? nombres[0];
        if (!elegido) throw new Error('El KMZ no contiene ningún archivo .kml.');
        if (zip[elegido].length > LIMITE_KML) throw new Error(`El KML pesa ${(zip[elegido].length / 1048576).toFixed(0)} MB: demasiado para el navegador. Conviértalo con «npm run capas:prioridades» o mapshaper.`);
        texto = strFromU8(zip[elegido]);
      } else if (/\.kml$/i.test(archivo.name)) {
        if (bytes.length > LIMITE_KML) throw new Error('El KML es demasiado grande para convertirlo en el navegador.');
        texto = new TextDecoder().decode(bytes);
      } else {
        throw new Error('Use un archivo .kmz o .kml.');
      }
      const documento = new DOMParser().parseFromString(texto, 'text/xml');
      if (documento.getElementsByTagName('parsererror').length) throw new Error('El archivo no es un KML válido.');
      const capa = kmlAGeoJSON(documento) as FeatureCollection;
      const conGeometria = capa.features.filter((f) => f.geometry);
      if (!conGeometria.length) throw new Error('El KML no trae geometrías: no se generó ninguna capa.');
      capa.features = conGeometria;
      setVista({ nombre: archivo.name.replace(/\.(kmz|kml)$/i, ''), capa });
      setEstado({ tipo: 'info', texto: `Convertido: ${conGeometria.length.toLocaleString('es-CO')} elementos.` });
    } catch (e) {
      setVista(null);
      setEstado({ tipo: 'error', texto: e instanceof Error ? e.message : 'No se pudo convertir el archivo.' });
    } finally {
      setProcesando(false);
    }
  }

  function guardar() {
    if (!vista) return;
    const nueva: CapaGuardada = { id: crypto.randomUUID(), nombre: vista.nombre, cargada_en: new Date().toISOString(), geojson: vista.capa };
    const todas = [...guardadas, nueva];
    const texto = JSON.stringify(todas);
    if (texto.length > LIMITE_GUARDADO) {
      setEstado({ tipo: 'error', texto: 'La capa supera el espacio del navegador (~4 MB). Descárguela como GeoJSON y súbala al repositorio en datos/cra/.' });
      return;
    }
    try {
      localStorage.setItem(CLAVE, texto);
      setGuardadas(todas);
      setEstado({ tipo: 'info', texto: `«${nueva.nombre}» guardada en este navegador; el visor del workflow ya la dibuja.` });
    } catch {
      setEstado({ tipo: 'error', texto: 'El navegador no permitió guardar la capa.' });
    }
  }

  function quitar(id: string) {
    const todas = guardadas.filter((c) => c.id !== id);
    localStorage.setItem(CLAVE, JSON.stringify(todas));
    setGuardadas(todas);
  }

  const info = vista ? resumen(vista.capa) : null;
  const boton = 'inline-flex min-h-11 items-center gap-2 px-4 text-xs font-black uppercase tracking-[0.06em]';

  return (
    <section id="capas" aria-labelledby="titulo-capas" className="grid scroll-mt-6 gap-6">
      <h2 id="titulo-capas" className="rotulo border-b border-white pb-2">Capas de la Corporación (KMZ/KML → GeoJSON)</h2>

      <div className="grid gap-3 md:grid-cols-2">
        {[
          { titulo: 'Prioridades de conservación', texto: 'Zonificación del plan de manejo (acción, prioridad, escenario, figura legal), recortada a los cuatro sectores del manglar.', url: URL_CAPA_PRIORIDADES, archivo: 'prioridades-cra.geojson' },
          { titulo: 'Cobertura de manglar 1:5.000', texto: `${FUENTE_MANGLAR_CRA}. 886 polígonos, 649,7 ha.`, url: URL_CAPA_MANGLAR_CRA, archivo: 'manglar-cra.geojson' },
        ].map((c) => (
          <article key={c.titulo} className="border border-linea-suave bg-superficie p-4 text-sm">
            <p className="rotulo flex items-center gap-2 text-dorado-300"><Layers className="size-4" aria-hidden="true" />Integrada · {c.titulo}</p>
            <p className="mt-2 text-suave">{c.texto}</p>
            <a href={c.url} download={c.archivo} className="mt-2 inline-flex min-h-11 items-center gap-1 text-xs font-bold uppercase text-dorado-300 hover:underline"><Download className="size-3.5" aria-hidden="true" />Descargar GeoJSON</a>
          </article>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]">
        <div className="grid content-start gap-4 text-sm">
          <p className="text-suave">Cargue una capa nueva de la Corporación para verla aquí y en el visor del workflow. El KMZ oficial reemplaza a los sectores aproximados; para el repositorio existen <code className="text-dorado-300">npm run capas:prioridades</code> y <code className="text-dorado-300">npm run capas:manglar</code>.</p>
          <label className={`${boton} w-fit cursor-pointer border border-white/60 hover:border-dorado-300 hover:text-dorado-300 ${!autorizado || procesando ? 'pointer-events-none opacity-40' : ''}`}>
            <FileUp className="size-4" aria-hidden="true" />{procesando ? 'Convirtiendo…' : 'Elegir KMZ o KML'}
            <input type="file" accept=".kmz,.kml,application/vnd.google-earth.kmz,application/vnd.google-earth.kml+xml" className="sr-only" disabled={!autorizado || procesando} onChange={alElegir} />
          </label>
          {!autorizado && <p className="text-xs text-media-texto">Solo el administrador carga capas. Cambie el rol en «Ver como».</p>}
          <div aria-live="polite">{estado && <p className={`border-l-4 p-3 ${estado.tipo === 'error' ? 'border-alta bg-alta-suave' : 'border-dorado-300 bg-white/5'}`}>{estado.texto}</p>}</div>
          {vista && info && (
            <div className="border border-linea-suave bg-white/5 p-3">
              <p className="font-bold">{vista.nombre}</p>
              <p className="text-xs text-suave">{Object.entries(info.tipos).map(([t, n]) => `${n.toLocaleString('es-CO')} ${t}`).join(' · ')}</p>
              {info.campos.length > 0 && <p className="mt-1 text-xs text-tenue">Campos: {info.campos.join(', ')}</p>}
              <div className="mt-3 flex flex-wrap gap-2">
                <button type="button" onClick={guardar} disabled={!autorizado} className={`${boton} bg-dorado-500 text-cra-950 hover:bg-dorado-300 disabled:opacity-40`}><Save className="size-4" aria-hidden="true" />Guardar en la plataforma</button>
                <button type="button" onClick={() => descargarArchivo(JSON.stringify(vista.capa), `${vista.nombre}.geojson`, 'application/geo+json')} className={`${boton} border border-white/60 hover:border-dorado-300`}><Download className="size-4" aria-hidden="true" />Descargar GeoJSON</button>
                <button type="button" onClick={() => { setVista(null); setEstado(null); }} className={`${boton} text-suave hover:text-texto`}>Descartar</button>
              </div>
            </div>
          )}
          <div>
            <p className="etiqueta-campo text-suave">Capas guardadas en este navegador</p>
            {guardadas.length === 0 ? <p className="mt-1 text-xs text-tenue">Ninguna todavía.</p> : (
              <ul className="mt-2 grid gap-1">
                {guardadas.map((c) => (
                  <li key={c.id} className="flex items-center justify-between gap-2 border-b border-white/25 py-1 text-sm">
                    <button type="button" className="text-left hover:text-dorado-300" onClick={() => setVista({ nombre: c.nombre, capa: c.geojson })}>{c.nombre} <span className="text-xs text-tenue">· {c.geojson.features.length.toLocaleString('es-CO')} elementos</span></button>
                    <button type="button" disabled={!autorizado} onClick={() => quitar(c.id)} aria-label={`Quitar ${c.nombre}`} className="inline-flex min-h-11 items-center px-2 text-suave hover:text-alta-texto disabled:opacity-40"><Trash2 className="size-4" aria-hidden="true" /></button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        <div className="relative z-0 h-[380px] overflow-hidden border border-linea">
          <MapContainer center={[10.93, -75.02]} zoom={10} preferCanvas scrollWheelZoom={false} className="h-full w-full" aria-label="Vista previa de la capa cargada">
            <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
            {vista && <GeoJSON key={vista.nombre + vista.capa.features.length} data={vista.capa} style={{ color: '#f8d86f', weight: 1.2, fillColor: '#edb512', fillOpacity: 0.25 }} />}
            <Encuadre capa={vista?.capa ?? null} />
          </MapContainer>
          {!vista && <p className="pointer-events-none absolute inset-x-0 bottom-3 z-[500] mx-auto w-fit bg-cra-950/90 px-3 py-1 text-xs text-suave">La vista previa aparece al cargar una capa</p>}
        </div>
      </div>
    </section>
  );
}
