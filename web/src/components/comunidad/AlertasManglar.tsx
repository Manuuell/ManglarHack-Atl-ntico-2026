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

function compartir(a: Alerta): string {
  const texto = `${a.nivel === 'roja' ? '🔴' : a.nivel === 'naranja' ? '🟠' : '🟡'} ${a.titulo}\n${a.detalle}\n👉 ${a.recomendacion}\n\nMás en https://mimanglar.sentralabs.co/#alertas`;
  return `https://wa.me/?text=${encodeURIComponent(texto)}`;
}

// --- Píldora del inicio ----------------------------------------------------------

function Aviso() {
  const { datos } = useAlertas(false);
  if (!datos) return null;
  const n = datos.alertas.length;
  if (!n) {
    return <a className="al-pildora" data-nivel="calma" href="#alertas"><span aria-hidden="true">✅</span> Sin alertas en el manglar ahora</a>;
  }
  const a = datos.alertas[0];
  return (
    <a className="al-pildora" data-nivel={a.nivel} href="#alertas">
      <span className="al-punto" aria-hidden="true" />
      <span><strong>{NIVEL_TEXTO[a.nivel]}:</strong> {a.titulo}{n > 1 ? ` · y ${n - 1} más` : ''}</span>
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

function Tarjeta({ a }: { a: Alerta }) {
  return (
    <li className="al-tarjeta" data-nivel={a.nivel}>
      <div className="al-tarjeta-cab">
        <span className="al-etiqueta" data-nivel={a.nivel}>{NIVEL_TEXTO[a.nivel]}</span>
        <span className="al-tipo">{a.medido ? 'Medido' : 'Pronóstico'}</span>
      </div>
      <h3 className="al-titulo"><span aria-hidden="true">{ICONO[a.tipo]}</span> {a.titulo}</h3>
      <p className="al-detalle">{a.detalle}</p>
      <p className="al-hacer"><strong>Qué hacer:</strong> {a.recomendacion}</p>
      <dl className="al-meta">
        <div><dt>Dónde</dt><dd>{a.lugar}</dd></div>
        <div><dt>Cuándo</dt><dd>{a.desde === a.hasta ? cuando(a.desde) : `${cuando(a.desde)} → ${cuando(a.hasta)}`}</dd></div>
        <div><dt>Fuente</dt><dd>{a.fuentes.map((f) => NOMBRE_FUENTE[f] ?? f).join(' + ')}</dd></div>
      </dl>
      <div className="al-acciones">
        <a className="al-boton" href={compartir(a)} target="_blank" rel="noopener noreferrer">Avisar por WhatsApp</a>
        <a className="al-boton al-boton-claro" href="#reportar" data-cuenta-reportar>Reportar lo que veas</a>
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
              {datos.alertas.map((a) => <Tarjeta key={a.id} a={a} />)}
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
