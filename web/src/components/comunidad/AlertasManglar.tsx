// Alertas del manglar: el servidor de Zanky cruza cada 10 minutos las estaciones del IDEAM, el pronóstico y las
// mareas de DIMAR, los focos de calor de la C.R.A. y los reportes de la comunidad, y dice qué calamidad se
// presenta o viene (mar de leva, pleamar con oleaje, aguaceros, viento fuerte, riesgo de incendio, fuego cerca
// del manglar o varios reportes de la misma amenaza), dónde, cuándo y qué hacer.
// modo="aviso" es la píldora del inicio; sin modo es la sección completa (#alertas).
import { useEffect, useState } from 'react';
import '../../styles/alertas.css';

type Nivel = 'amarilla' | 'naranja' | 'roja';
type TipoAlerta = 'mar_de_leva' | 'inundacion_costera' | 'lluvia_fuerte' | 'vendaval' | 'riesgo_incendio' | 'foco_calor' | 'amenaza_ciudadana';

interface Alerta {
  id: string; tipo: TipoAlerta; nivel: Nivel; titulo: string; detalle: string; recomendacion: string;
  lugar: string; lat: number; lon: number; desde: string; hasta: string; medido: boolean;
  valor?: number; unidad?: string; umbral?: number; fuentes: string[];
}
interface Fuente { id: string; nombre: string; url: string; ok: boolean; error?: string }
interface Resultado {
  generado: string; simulacro: boolean; nivel_maximo: Nivel | null; alertas: Alerta[]; fuentes: Fuente[]; nota: string;
  ahora: {
    lluvia_hora_mm: number | null; lluvia_24h_mm: number | null; lluvia_estacion: string | null;
    viento_ms: number | null; viento_estacion: string | null; temperatura_c: number | null;
    ola_max_m: number | null; ola_cuando: string | null; ola_lugar: string | null;
    proxima_pleamar: { t: string; m: number } | null; temp_max_pronostico_c: number | null; reportes_72h: number | null;
  };
}

const URL_ALERTAS = String(import.meta.env.PUBLIC_ALERTAS_URL ?? 'https://zanqui.sentralabs.co/alertas');
const NUMERO = String(import.meta.env.PUBLIC_ZANKY_WHATSAPP ?? '573104432501');

const NIVEL_TEXTO: Record<Nivel, string> = { amarilla: 'Alerta amarilla', naranja: 'Alerta naranja', roja: 'Alerta roja' };
const ICONO: Record<TipoAlerta, string> = {
  mar_de_leva: '🌊', inundacion_costera: '🌕', lluvia_fuerte: '🌧️', vendaval: '💨', riesgo_incendio: '🔥', foco_calor: '🛰️', amenaza_ciudadana: '📣',
};
const NOMBRE_FUENTE: Record<string, string> = { ideam: 'IDEAM', dimar: 'DIMAR', mareas: 'DIMAR · CIOH', cra: 'C.R.A.', comunidad: 'Comunidad' };

// Una sola petición para la píldora y la sección, aunque se monten por separado.
const pedidos = new Map<string, { cuando: number; p: Promise<Resultado> }>();
function pedir(simulacro: boolean, forzar = false): Promise<Resultado> {
  const clave = simulacro ? 'simulacro' : 'real';
  const previo = pedidos.get(clave);
  if (previo && !forzar && Date.now() - previo.cuando < 60_000) return previo.p;
  const p = fetch(`${URL_ALERTAS}${simulacro ? '?simulacro=1' : ''}`, { cache: 'no-store' }).then(async (r) => {
    if (!r.ok) throw new Error(`alertas ${r.status}`);
    return (await r.json()) as Resultado;
  });
  pedidos.set(clave, { cuando: Date.now(), p });
  p.catch(() => pedidos.delete(clave));
  return p;
}

function useAlertas(simulacro: boolean) {
  const [datos, setDatos] = useState<Resultado | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let activo = true;
    const cargar = (forzar: boolean) => pedir(simulacro, forzar)
      .then((r) => { if (activo) { setDatos(r); setError(false); } })
      .catch(() => { if (activo) setError(true); });
    setDatos(null);
    void cargar(false);
    const t = window.setInterval(() => void cargar(true), 5 * 60_000);
    return () => { activo = false; window.clearInterval(t); };
  }, [simulacro]);
  return { datos, error };
}

const ZONA = 'America/Bogota';
const n1 = (v: number) => v.toLocaleString('es-CO', { maximumFractionDigits: 1 });
const n2 = (v: number) => v.toLocaleString('es-CO', { maximumFractionDigits: 2 });
const dia = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: ZONA }).format(d);
function cuando(iso: string): string {
  const d = new Date(iso);
  const hora = new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, hour: 'numeric', minute: '2-digit' }).format(d).replace(/\s/g, ' ');
  if (dia(d) === dia(new Date())) return `hoy, ${hora}`;
  if (dia(d) === dia(new Date(Date.now() + 86_400_000))) return `mañana, ${hora}`;
  if (dia(d) === dia(new Date(Date.now() - 86_400_000))) return `ayer, ${hora}`;
  return `${new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, weekday: 'short', day: 'numeric' }).format(d).replace('.', '')}, ${hora}`;
}
function haceCuanto(iso: string): string {
  const min = Math.max(0, Math.round((Date.now() - Date.parse(iso)) / 60_000));
  return min < 1 ? 'hace un momento' : min < 60 ? `hace ${min} min` : `hace ${Math.round(min / 60)} h`;
}

const MAX_TARJETAS = 6;
type AlertaVista = Alerta & { simulado: boolean };

/** Lo que se publica: de las alertas de la comunidad queda una sola, rotulada SIMULADO (los reportes de la
 *  demostración las generan); las de IDEAM, DIMAR y la C.R.A. van todas. Solo las 6 más recientes. */
function publicadas(alertas: Alerta[]): AlertaVista[] {
  const comunidad = alertas.filter((a) => a.tipo === 'amenaza_ciudadana').slice(0, 1).map((a) => ({ ...a, simulado: true }));
  const reales = alertas.filter((a) => a.tipo !== 'amenaza_ciudadana').map((a) => ({ ...a, simulado: false }));
  return [...reales, ...comunidad].sort((x, y) => Date.parse(y.desde) - Date.parse(x.desde)).slice(0, MAX_TARJETAS);
}

/** Imagen del sector donde pasa la alerta: las vistas satelitales del workflow de la C.R.A. (copia en /cra/img,
 *  z1 a z4). `lugar` a veces es una estación del IDEAM, así que se elige el sector más cercano al punto. */
const SECTORES_IMAGEN: [number, number, number][] = [[1, 11.025, -74.86], [2, 10.99, -74.955], [3, 10.93, -75.05], [4, 10.74, -75.23]];
function imagenDe(a: Alerta): string {
  const k = Math.cos((a.lat * Math.PI) / 180);
  const [zona] = SECTORES_IMAGEN.reduce((mejor, z) => (Math.hypot(z[1] - a.lat, (z[2] - a.lon) * k) < Math.hypot(mejor[1] - a.lat, (mejor[2] - a.lon) * k) ? z : mejor));
  return `/cra/img/z${zona}_img.jpg`;
}

/** La primera frase del detalle: la tarjeta va con poco texto. */
function resumen(texto: string): string {
  // Corta donde termina una oración (punto y mayúscula), no en «a. m.» ni «p. m.».
  const frase = texto.match(/^.*?[.!?](?=\s+[A-ZÁÉÍÓÚÑ¿¡]|\s*$)/)?.[0]?.trim() ?? texto;
  return frase.length > 150 ? `${frase.slice(0, 147).trimEnd()}…` : frase;
}

function compartir(a: Alerta): string {
  const texto = `${a.nivel === 'roja' ? '🔴' : a.nivel === 'naranja' ? '🟠' : '🟡'} ${a.titulo}\n${a.detalle}\n👉 ${a.recomendacion}\n\nMás en https://mimanglar.sentralabs.co/#alertas`;
  return `https://wa.me/?text=${encodeURIComponent(texto)}`;
}

// --- Píldora del inicio ----------------------------------------------------------

function Aviso() {
  const { datos } = useAlertas(false);
  if (!datos) return null;
  const lista = publicadas(datos.alertas);
  const n = lista.length;
  if (!n) {
    return <a className="al-pildora" data-nivel="calma" href="#alertas"><span aria-hidden="true">✅</span> Sin alertas en el manglar ahora</a>;
  }
  const a = lista[0];
  return (
    <a className="al-pildora" data-nivel={a.nivel} href="#alertas">
      <span className="al-punto" aria-hidden="true" />
      <span><strong>{NIVEL_TEXTO[a.nivel]}{a.simulado ? ' (simulado)' : ''}:</strong> {a.titulo}{n > 1 ? ` · y ${n - 1} más` : ''}</span>
      <span aria-hidden="true">→</span>
    </a>
  );
}

// --- Sección completa --------------------------------------------------------------

function Ahora({ a }: { a: Resultado['ahora'] }) {
  const datos: { icono: string; titulo: string; valor: string; pie: string }[] = [];
  if (a.viento_ms !== null) datos.push({ icono: '💨', titulo: 'Viento ahora', valor: `${n1(a.viento_ms)} m/s`, pie: `${n1(a.viento_ms * 3.6)} km/h · ${a.viento_estacion ?? 'IDEAM'}` });
  if (a.lluvia_24h_mm !== null) datos.push({ icono: '🌧️', titulo: 'Lluvia en 24 h', valor: `${n1(a.lluvia_24h_mm)} mm`, pie: `La más alta, en ${a.lluvia_estacion ?? 'IDEAM'}` });
  if (a.ola_max_m !== null) datos.push({ icono: '🌊', titulo: 'Ola más alta (3 días)', valor: `${n1(a.ola_max_m)} m`, pie: `${a.ola_cuando ? cuando(a.ola_cuando) : ''}${a.ola_lugar ? ` · ${a.ola_lugar}` : ''}` });
  if (a.proxima_pleamar) datos.push({ icono: '🌕', titulo: 'Próxima pleamar', valor: `${n2(a.proxima_pleamar.m)} m`, pie: `${cuando(a.proxima_pleamar.t)} · Barranquilla` });
  if (a.temp_max_pronostico_c !== null) datos.push({ icono: '🌡️', titulo: 'Calor máximo (24 h)', valor: `${n1(a.temp_max_pronostico_c)} °C`, pie: 'Pronóstico DIMAR en la costa' });
  if (!datos.length) return null;
  return (
    <ul className="al-ahora" aria-label="Lo que se mide y pronostica ahora">
      {datos.map((d) => (
        <li key={d.titulo}>
          <span className="al-ahora-titulo"><span aria-hidden="true">{d.icono}</span> {d.titulo}</span>
          <strong className="al-ahora-valor">{d.valor}</strong>
          <span className="al-ahora-pie">{d.pie}</span>
        </li>
      ))}
    </ul>
  );
}

function Tarjeta({ a, simulacro }: { a: AlertaVista; simulacro: boolean }) {
  const origen = simulacro ? 'Simulacro' : a.simulado ? 'Simulado' : a.medido ? 'Medido' : 'Pronóstico';
  return (
    <li className="al-tarjeta" data-nivel={a.nivel}>
      <div className="al-foto">
        <img src={imagenDe(a)} alt="" loading="lazy" decoding="async" />
        <span className="al-etiqueta" data-nivel={a.nivel}>{NIVEL_TEXTO[a.nivel]}</span>
        {(a.simulado || simulacro) && <span className="al-sello">{simulacro ? 'Simulacro' : 'Simulado'}</span>}
        <span className="al-icono" aria-hidden="true">{ICONO[a.tipo]}</span>
      </div>
      <div className="al-cuerpo">
        <p className="al-tipo">{origen} · {a.fuentes.map((f) => NOMBRE_FUENTE[f] ?? f).join(' + ')}</p>
        <h3 className="al-titulo">{a.titulo}</h3>
        <p className="al-detalle">{resumen(a.detalle)}</p>
        <p className="al-donde">{a.lugar} · {a.desde === a.hasta ? cuando(a.desde) : `${cuando(a.desde)} → ${cuando(a.hasta)}`}</p>
        <a className="al-enlace" href={compartir(a)} target="_blank" rel="noopener noreferrer">Avisar por WhatsApp <span aria-hidden="true">→</span></a>
      </div>
    </li>
  );
}

function Seccion() {
  const [simulacro, setSimulacro] = useState(false);
  const { datos, error } = useAlertas(simulacro);
  return (
    <div className="al">
      <div className="al-cab">
        <div>
          <p className="kicker">Alertas</p>
          <h2>¿Qué viene para el manglar? <span className="tono">Te avisamos.</span></h2>
          <p className="al-intro">
            Cada 10 minutos cruzamos las estaciones del IDEAM, el pronóstico y las mareas de DIMAR, los focos de calor de la C.R.A.
            y lo que reporta la comunidad. Si viene mar de leva, un aguacero, viento fuerte o riesgo de incendio, aparece aquí.
          </p>
        </div>
        <div className="al-controles">
          <button type="button" className="al-boton al-boton-claro" aria-pressed={simulacro} onClick={() => setSimulacro((s) => !s)}>
            {simulacro ? 'Volver a las alertas reales' : 'Ver un simulacro'}
          </button>
          <a className="al-boton" href={`https://wa.me/${NUMERO}?text=${encodeURIComponent('alertas')}`} target="_blank" rel="noopener noreferrer">
            Pedirlas por WhatsApp
          </a>
        </div>
      </div>

      {simulacro && <p className="al-simulacro" role="status">🧪 Simulacro: así se ven las alertas cuando hay mar de leva y quemas. Las cifras de «Ahora» sí son reales.</p>}

      {!datos && !error && <div className="al-cargando" aria-busy="true">Leyendo las estaciones y el pronóstico…</div>}
      {error && !datos && (
        <p className="al-vacio" role="status">No pudimos leer las fuentes en este momento. Vuelve a intentarlo en unos minutos.</p>
      )}

      {datos && (
        <>
          <Ahora a={datos.ahora} />
          {datos.alertas.length === 0 ? (
            <div className="al-vacio al-calma">
              <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width="96" height="96" loading="lazy" />
              <div>
                <strong>Todo en calma.</strong> No hay mar de leva, aguaceros, vientos fuertes ni riesgo de incendio a la vista,
                y la comunidad no ha reportado amenazas repetidas.
              </div>
            </div>
          ) : (
            <ul className="al-lista" aria-live="polite">
              {publicadas(datos.alertas).map((a) => <Tarjeta key={a.id} a={a} simulacro={simulacro} />)}
            </ul>
          )}
          <div className="al-pie">
            <p>
              Actualizado {haceCuanto(datos.generado)} ·{' '}
              {datos.fuentes.map((f, i) => (
                <span key={f.id}>
                  {i > 0 && ' · '}
                  <a href={f.url} target="_blank" rel="noopener noreferrer" title={f.error ?? 'Respondió bien'}>
                    {f.ok ? '●' : '○'} {f.nombre}
                  </a>
                </span>
              ))}
            </p>
            <p>{datos.nota} Si hay peligro para las personas, llama al 123.</p>
          </div>
        </>
      )}
    </div>
  );
}

export default function AlertasManglar({ modo }: { modo?: 'aviso' }) {
  return modo === 'aviso' ? <Aviso /> : <Seccion />;
}
