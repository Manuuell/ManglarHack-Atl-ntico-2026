// Panel de administración (/admin), en una sola página con barra de secciones: métricas de los últimos
// 30 días, personas registradas, jornadas (crear, editar, cancelar, inscritos), invitaciones por WhatsApp
// con la plantilla aprobada, historial de envíos y el bot. Todo vive en el servidor de Zanky; cada petición
// lleva el token de la cuenta y el servidor comprueba el rol de administrador. Los reportes de las
// métricas salen de la vista pública del servidor común (sin datos personales).
import { useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { CalendarDays, Check, Download, Image as Imagen, MapPin, MessageCircle, Pencil, Plus, RefreshCw, Search, Send, ShieldCheck, Users, X } from 'lucide-react';
import type { TipoJornada } from '../../types/plataforma';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { normalizarCelular, renovarSesion, useSesion } from '../../lib/cuenta';
import { ErrorBot, pedirBot, pedirBotCrudo } from '../../lib/bot';
import { sincronizarJornadas } from '../../lib/plataforma/jornadasApi';
import { backendActivo, leerReportesPublicos, type FilaPublica } from '../../lib/backend/supabase';
import MapaReportesAdmin from './MapaReportesAdmin';
import PorConfirmar from './PorConfirmar';
import { cn } from '../../lib/utils';

// --- Tipos del contrato con el servidor -----------------------------------------------------------
interface JornadaAdmin {
  id: string; accion_id: string; titulo: string; tipo: TipoJornada; inicio: string; fin: string;
  punto_encuentro: string; lat: number; lon: number; cupos: number; inscritos: number;
  que_llevar: string[]; descripcion: string; imagen_url: string | null; ejemplo: boolean;
  estado: 'publicada' | 'cancelada'; inscripciones_activas?: number;
}
type Conteo = Record<string, number>;
interface Resumen {
  bot: { simulacion: boolean; ia: boolean; vigias: number; vigias_por_municipio: Conteo; vigias_por_rol: Conteo; reportes: { total: number; por_estado: Conteo; por_tipo: Conteo; pendientes_envio: number } };
  cuentas: { con_whatsapp: number; total_sincronizadas: number };
  jornadas: { publicadas: number; proximas: number; inscripciones: number };
  envios: { total: number; enviados: number; fallidos: number };
  plantilla: { nombre: string; idioma: string; imagen_por_defecto: string };
}
interface Inscrito { id: string; nombre: string; telefono_mascara: string | null; acepta_whatsapp: boolean; cuenta: boolean; fecha: string; estado: string }
interface Contacto { cuenta_id: string; nombre: string; telefono_mascara: string | null; whatsapp_ok: boolean; actualizado_en: string }
interface Envio { fecha: string; jornada_id: string; jornada_titulo: string; nombre: string; telefono_mascara: string | null; estado: string; error?: string; por: string }
interface ResultadoEnvio { enviados: number; fallidos: number; resultados: { nombre: string; telefono_mascara: string | null; estado: string; error?: string }[] }

/** Una persona de la lista: una cuenta de la web o alguien que se inscribió a una jornada sin cuenta. */
interface Persona { clave: string; nombre: string; telefono: string | null; whatsapp: boolean; origen: 'cuenta' | 'inscripcion'; detalle: string; fecha: string; cuenta_id?: string }

type Seccion = 'metricas' | 'mapa' | 'confirmar' | 'personas' | 'jornadas' | 'invitar' | 'envios' | 'bot';
const SECCIONES: { id: Seccion; texto: string }[] = [
  { id: 'metricas', texto: 'Últimos 30 días' }, { id: 'mapa', texto: 'Mapa' }, { id: 'confirmar', texto: 'Por confirmar' }, { id: 'personas', texto: 'Personas' }, { id: 'jornadas', texto: 'Jornadas' },
  { id: 'invitar', texto: 'Invitar por WhatsApp' }, { id: 'envios', texto: 'Envíos' }, { id: 'bot', texto: 'Zanky BOT' },
];
const DIAS = 30;
const TIPOS = Object.keys(TIPOS_JORNADA) as TipoJornada[];
const PUNTOS = [
  { nombre: 'Ecoparque Ciénaga de Mallorquín', lat: 11.03217, lon: -74.85755 },
  { nombre: 'Caño Balboa (Puerto Colombia)', lat: 11.03878, lon: -74.91318 },
  { nombre: 'Muelle de pescadores del Totumo', lat: 10.73029, lon: -75.22261 },
];

// --- Formatos ----------------------------------------------------------------------------------------
const zona = { timeZone: 'America/Bogota' } as const;
const capital = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
// Sin la coma que pone Intl tras el día: «sábado 28 de noviembre», como en la plantilla.
const fechaLarga = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', day: 'numeric', month: 'long' }).format(new Date(iso)).replace(/^(\p{L}+),\s/u, '$1 ');
const hora = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
const fechaCorta = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
const diaBogota = (iso: string | number) => new Date(iso).toLocaleDateString('en-CA', zona);
const horaBogota = (iso: string) => new Date(iso).toLocaleTimeString('en-GB', { ...zona, hour: '2-digit', minute: '2-digit' });
const etiquetaConteo = (k: string) => capital(k.replace(/_/g, ' '));
/** Fecha como va en la plantilla: «sábado 28 de noviembre, 8:00 a. m.». */
const fechaPlantilla = (iso: string) => `${fechaLarga(iso)}, ${hora(iso)}`;
/** «27 nov.» a partir de la clave de un día (AAAA-MM-DD en Bogotá). */
const diaCorto = (clave: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric', month: 'short' }).format(new Date(`${clave}T12:00:00-05:00`));
const desplazar = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });

// --- Piezas -----------------------------------------------------------------------------------------
function Tarjeta({ titulo, valor, detalle, icono }: { titulo: string; valor: ReactNode; detalle?: ReactNode; icono?: ReactNode }) {
  return <div className="min-w-0 rounded-3xl border border-linea-suave bg-superficie p-5">
    <p className="rotulo flex items-center gap-2 text-dorado-300">{icono}{titulo}</p>
    <p className="titular mt-3 text-4xl tabular-nums">{valor}</p>
    {detalle && <div className="mt-2 text-sm text-suave">{detalle}</div>}
  </div>;
}

function Barras({ titulo, datos, vacio }: { titulo: string; datos: Conteo; vacio: string }) {
  const filas = Object.entries(datos ?? {}).sort((a, b) => b[1] - a[1]);
  const max = Math.max(1, ...filas.map(([, n]) => n));
  return <div className="min-w-0 rounded-3xl border border-linea-suave bg-superficie p-5">
    <h3 className="rotulo text-dorado-300">{titulo}</h3>
    {filas.length === 0 ? <p className="mt-3 text-sm text-tenue">{vacio}</p> : <ul className="mt-3 space-y-2.5">
      {filas.map(([k, n]) => <li key={k} className="text-sm">
        <div className="flex justify-between gap-3"><span className="min-w-0 truncate text-suave">{etiquetaConteo(k)}</span><span className="tabular-nums font-semibold">{n}</span></div>
        <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-white/10"><div className="h-full rounded-full bg-dorado-400" style={{ width: `${(n / max) * 100}%` }} /></div>
      </li>)}
    </ul>}
  </div>;
}

/** Barras de los últimos 30 días (un día por barra, en hora de Bogotá), con el total y los datos debajo. */
function GraficoDias({ titulo, unidad, fechas, error, detalle }: { titulo: string; unidad: [string, string]; fechas: string[] | null; error?: string; detalle?: ReactNode }) {
  const serie = useMemo(() => {
    const hoy = Date.now();
    const dias = Array.from({ length: DIAS }, (_, i) => diaBogota(hoy - (DIAS - 1 - i) * 86_400_000));
    const conteo = new Map(dias.map((d) => [d, 0]));
    for (const f of fechas ?? []) { const d = diaBogota(f); const n = conteo.get(d); if (n !== undefined) conteo.set(d, n + 1); }
    return dias.map((dia) => ({ dia, n: conteo.get(dia) ?? 0 }));
  }, [fechas]);
  const total = serie.reduce((t, p) => t + p.n, 0);
  const max = Math.max(1, ...serie.map((p) => p.n));
  const pico = serie.reduce((a, b) => (b.n > a.n ? b : a), serie[0]);
  const conDatos = serie.filter((p) => p.n > 0).reverse();
  return <div className="flex min-w-0 flex-col rounded-3xl border border-linea-suave bg-superficie p-5 sm:p-6">
    <p className="text-sm font-semibold text-suave">{titulo}</p>
    {fechas === null && !error ? <p className="mt-3 text-sm text-tenue" role="status">Cargando…</p> : error ? <p className="mt-3 text-sm text-alta-texto">{error}</p> : <>
      <p className="mt-1 flex items-baseline gap-2"><span className="titular text-4xl tabular-nums">{total.toLocaleString('es-CO')}</span><span className="text-suave">{total === 1 ? unidad[0] : unidad[1]}</span></p>
      {detalle && <div className="mt-1 text-sm text-tenue">{detalle}</div>}
      <div className="mt-auto pt-5">
        <div role="img" aria-label={`${titulo}: ${total} ${total === 1 ? unidad[0] : unidad[1]} en los últimos ${DIAS} días${pico.n ? `; el día con más fue el ${diaCorto(pico.dia)}, con ${pico.n}` : ''}.`}
          className="flex h-24 items-end gap-[3px] border-b border-linea-suave">
          {serie.map((p) => <div key={p.dia} title={`${diaCorto(p.dia)}: ${p.n}`} className={cn('min-w-0 flex-1 rounded-t-[3px]', p.n ? 'bg-dorado-500' : 'bg-white/10')}
            style={{ height: p.n ? `${Math.max(8, (p.n / max) * 100)}%` : '3px' }} />)}
        </div>
        <div className="mt-1.5 flex justify-between text-[11px] text-tenue" aria-hidden="true"><span>{diaCorto(serie[0].dia)}</span><span>hoy</span></div>
        <details className="mt-2 text-sm">
          <summary className="inline-flex min-h-11 cursor-pointer items-center gap-1 font-semibold text-suave hover:text-texto">Ver los datos</summary>
          {conDatos.length === 0 ? <p className="pb-1 text-tenue">Sin registros en estos {DIAS} días.</p> :
            <table className="w-full text-left"><thead className="text-xs text-tenue"><tr><th className="py-1 font-semibold">Día</th><th className="py-1 text-right font-semibold">Cantidad</th></tr></thead>
              <tbody>{conDatos.map((p) => <tr key={p.dia} className="border-t border-linea-suave"><td className="py-1.5">{diaCorto(p.dia)}</td><td className="py-1.5 text-right tabular-nums">{p.n}</td></tr>)}</tbody></table>}
        </details>
      </div>
    </>}
  </div>;
}

function SeccionAdmin({ id, titulo, descripcion, accion, children }: { id: Seccion; titulo: string; descripcion?: ReactNode; accion?: ReactNode; children: ReactNode }) {
  return <section id={id} aria-labelledby={`${id}-titulo`} className="grid scroll-mt-40 gap-5">
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div className="min-w-0"><h2 id={`${id}-titulo`} className="titular text-2xl sm:text-3xl">{titulo}</h2>
        {descripcion && <p className="mt-1 max-w-3xl text-suave">{descripcion}</p>}</div>
      {accion}
    </div>
    {children}
  </section>;
}

const boton = (tono: 'dorado' | 'claro' | 'peligro' = 'claro') => cn(
  'inline-flex min-h-11 items-center justify-center gap-2 rounded-full px-5 text-sm font-bold transition-colors disabled:cursor-not-allowed disabled:opacity-55',
  tono === 'dorado' && 'bg-dorado-500 text-cra-950 hover:bg-dorado-300',
  tono === 'claro' && 'border border-linea bg-white/5 text-texto hover:border-dorado-300 hover:text-dorado-300',
  tono === 'peligro' && 'border border-alta/50 bg-alta/10 text-alta-texto hover:bg-alta/20',
);
const campo = 'min-h-11 w-full rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none';

function Aviso({ tipo, children }: { tipo: 'ok' | 'error' | 'info'; children: ReactNode }) {
  return <p role={tipo === 'error' ? 'alert' : 'status'} className={cn('rounded-2xl px-4 py-3 text-sm',
    tipo === 'ok' && 'bg-baja/15 text-baja-texto', tipo === 'error' && 'bg-alta/15 text-alta-texto', tipo === 'info' && 'border border-linea-suave bg-white/5 text-suave')}>{children}</p>;
}

// --- Formulario de jornada ---------------------------------------------------------------------------
interface Borrador {
  titulo: string; tipo: TipoJornada; fecha: string; hora_inicio: string; hora_fin: string; punto_encuentro: string;
  lat: string; lon: string; cupos: string; que_llevar: string; descripcion: string; imagen_url: string;
}
function borradorDe(j?: JornadaAdmin): Borrador {
  if (j) return {
    titulo: j.titulo, tipo: j.tipo, fecha: diaBogota(j.inicio), hora_inicio: horaBogota(j.inicio), hora_fin: horaBogota(j.fin),
    punto_encuentro: j.punto_encuentro, lat: String(j.lat), lon: String(j.lon), cupos: String(j.cupos),
    que_llevar: j.que_llevar.join(', '), descripcion: j.descripcion, imagen_url: j.imagen_url ?? '',
  };
  return {
    titulo: '', tipo: 'limpieza', fecha: diaBogota(Date.now() + 86_400_000), hora_inicio: '08:00', hora_fin: '11:00',
    punto_encuentro: PUNTOS[0].nombre, lat: String(PUNTOS[0].lat), lon: String(PUNTOS[0].lon), cupos: '40',
    que_llevar: 'Agua potable, gorra, bloqueador solar, guantes', descripcion: '', imagen_url: '',
  };
}

function FormularioJornada({ jornada, onGuardar, onCerrar }: { jornada?: JornadaAdmin; onGuardar: (cuerpo: Record<string, unknown>) => Promise<void>; onCerrar: () => void }) {
  const [d, setD] = useState<Borrador>(() => borradorDe(jornada));
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [ocupado, setOcupado] = useState(false);
  const [fallo, setFallo] = useState('');
  const cambiar = <K extends keyof Borrador>(k: K, v: Borrador[K]) => setD((p) => ({ ...p, [k]: v }));
  const Falta = ({ k }: { k: string }) => (errores[k] ? <span role="alert" className="text-sm font-semibold text-alta-texto">{errores[k]}</span> : null);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    const er: Record<string, string> = {};
    const titulo = d.titulo.trim();
    if (titulo.length < 5 || titulo.length > 90) er.titulo = 'El nombre va de 5 a 90 letras.';
    if (!/^\d{4}-\d{2}-\d{2}$/.test(d.fecha)) er.fecha = 'Elige la fecha.';
    const inicio = `${d.fecha}T${d.hora_inicio}:00-05:00`;
    const fin = `${d.fecha}T${d.hora_fin}:00-05:00`;
    if (!er.fecha && !(Date.parse(fin) > Date.parse(inicio))) er.hora_fin = 'La hora de fin debe ser después de la de inicio.';
    if (d.punto_encuentro.trim().length < 5) er.punto_encuentro = 'Indica el punto de encuentro (al menos 5 letras).';
    const lat = Number(d.lat), lon = Number(d.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) er.lat = 'Latitud y longitud no válidas.';
    const cupos = Number(d.cupos);
    if (!Number.isInteger(cupos) || cupos < 1 || cupos > 1000) er.cupos = 'Los cupos van de 1 a 1000.';
    const imagen = d.imagen_url.trim();
    if (imagen && !/^https:\/\/\S+$/.test(imagen)) er.imagen_url = 'La imagen debe ser un enlace https (JPG o PNG) público.';
    setErrores(er);
    if (Object.keys(er).length) return;
    setOcupado(true); setFallo('');
    try {
      await onGuardar({
        titulo, tipo: d.tipo, inicio, fin, punto_encuentro: d.punto_encuentro.trim(), lat, lon, cupos,
        que_llevar: d.que_llevar.split(/[,\n]/).map((x) => x.trim()).filter(Boolean).slice(0, 12),
        descripcion: d.descripcion.trim(), imagen_url: imagen || null,
      });
    } catch (err) {
      setFallo(err instanceof Error ? err.message : 'No se pudo guardar la jornada.');
    } finally { setOcupado(false); }
  }

  return <form onSubmit={enviar} noValidate className="grid gap-5 rounded-3xl border border-dorado-500/40 bg-dorado-500/5 p-5 sm:p-7">
    <div className="flex items-start justify-between gap-3">
      <div><p className="rotulo text-dorado-300">{jornada ? 'Editar jornada' : 'Nueva jornada'}</p>
        <h3 className="titular mt-1 text-2xl">{jornada ? jornada.titulo : 'Convoca a la comunidad'}</h3></div>
      <button type="button" onClick={onCerrar} aria-label="Cerrar el formulario" className="grid size-11 shrink-0 place-items-center rounded-full hover:bg-white/10"><X className="size-5" aria-hidden="true" /></button>
    </div>
    <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Nombre de la jornada</span>
      <input className={campo} value={d.titulo} onChange={(e) => cambiar('titulo', e.target.value)} maxLength={90} placeholder="Ej.: Recolección de basura en el manglar de Mallorquín" /><Falta k="titulo" /></label>
    <div className="grid gap-5 sm:grid-cols-2">
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Tipo</span>
        <select className={campo} value={d.tipo} onChange={(e) => cambiar('tipo', e.target.value as TipoJornada)}>{TIPOS.map((t) => <option key={t} value={t}>{TIPOS_JORNADA[t].etiqueta}</option>)}</select></label>
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Cupos</span>
        <input type="number" inputMode="numeric" min={1} max={1000} className={campo} value={d.cupos} onChange={(e) => cambiar('cupos', e.target.value)} /><Falta k="cupos" /></label>
    </div>
    <div className="grid gap-5 sm:grid-cols-3">
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Fecha</span><input type="date" className={campo} value={d.fecha} onChange={(e) => cambiar('fecha', e.target.value)} /><Falta k="fecha" /></label>
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Empieza</span><input type="time" className={campo} value={d.hora_inicio} onChange={(e) => cambiar('hora_inicio', e.target.value)} /></label>
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Termina</span><input type="time" className={campo} value={d.hora_fin} onChange={(e) => cambiar('hora_fin', e.target.value)} /><Falta k="hora_fin" /></label>
    </div>
    <div className="grid gap-2">
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Punto de encuentro</span>
        <input className={campo} value={d.punto_encuentro} onChange={(e) => cambiar('punto_encuentro', e.target.value)} maxLength={140} /><Falta k="punto_encuentro" /></label>
      <div className="flex flex-wrap gap-2" role="group" aria-label="Puntos frecuentes">
        {PUNTOS.map((p) => <button key={p.nombre} type="button" onClick={() => setD((x) => ({ ...x, punto_encuentro: p.nombre, lat: String(p.lat), lon: String(p.lon) }))}
          className="inline-flex min-h-11 items-center gap-1.5 rounded-full border border-linea bg-white/5 px-3 text-xs font-semibold text-suave hover:border-dorado-300 hover:text-texto"><MapPin className="size-3.5" aria-hidden="true" />{p.nombre}</button>)}
      </div>
    </div>
    <div className="grid gap-5 sm:grid-cols-2">
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Latitud</span><input inputMode="decimal" className={campo} value={d.lat} onChange={(e) => cambiar('lat', e.target.value)} /></label>
      <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Longitud</span><input inputMode="decimal" className={campo} value={d.lon} onChange={(e) => cambiar('lon', e.target.value)} /><Falta k="lat" /></label>
    </div>
    <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Qué llevar (separado por comas)</span><input className={campo} value={d.que_llevar} onChange={(e) => cambiar('que_llevar', e.target.value)} maxLength={300} /></label>
    <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Descripción</span><textarea rows={3} className={cn(campo, 'py-3')} value={d.descripcion} onChange={(e) => cambiar('descripcion', e.target.value)} maxLength={600} placeholder="Qué se va a hacer, quién acompaña, recomendaciones" /></label>
    <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Imagen de la invitación (opcional)</span>
      <input className={campo} value={d.imagen_url} onChange={(e) => cambiar('imagen_url', e.target.value)} inputMode="url" placeholder="https://… (JPG o PNG público; si no, va la imagen por defecto)" /><Falta k="imagen_url" />
      <span className="text-xs text-tenue">Es la foto que llega en el WhatsApp de la invitación y la que se ve en la cartelera.</span></label>
    {/^https:\/\/\S+$/.test(d.imagen_url.trim()) && <img src={d.imagen_url.trim()} alt="Vista previa de la imagen de la invitación" className="max-h-56 w-full rounded-2xl object-cover" />}
    {fallo && <Aviso tipo="error">{fallo}</Aviso>}
    <div className="flex flex-wrap gap-3">
      <button type="submit" disabled={ocupado} className={boton('dorado')}><Check className="size-4" aria-hidden="true" />{ocupado ? 'Guardando…' : jornada ? 'Guardar cambios' : 'Publicar jornada'}</button>
      <button type="button" onClick={onCerrar} className={boton()}>Cancelar</button>
    </div>
  </form>;
}

// --- Panel -----------------------------------------------------------------------------------------
type Estado = 'sin_sesion' | 'cargando' | 'sin_rol' | 'error' | 'listo';

export default function PanelAdmin() {
  const sesion = useSesion();
  const [estado, setEstado] = useState<Estado>('cargando');
  const [error, setError] = useState('');
  const [yo, setYo] = useState<{ correo: string; rol: string } | null>(null);
  const [resumen, setResumen] = useState<Resumen | null>(null);
  const [jornadas, setJornadas] = useState<JornadaAdmin[]>([]);
  const [contactos, setContactos] = useState<Contacto[]>([]);
  const [envios, setEnvios] = useState<Envio[]>([]);
  const [activa, setActiva] = useState<Seccion>('metricas');
  const [reportes, setReportes] = useState<FilaPublica[] | null>(null);
  const [errorReportes, setErrorReportes] = useState('');
  const [inscritosListos, setInscritosListos] = useState(false);
  const [filtro, setFiltro] = useState('');
  const [editando, setEditando] = useState<JornadaAdmin | 'nueva' | null>(null);
  const [abiertaInscritos, setAbiertaInscritos] = useState<string | null>(null);
  const [inscritos, setInscritos] = useState<Record<string, Inscrito[]>>({});
  const [aviso, setAviso] = useState<{ tipo: 'ok' | 'error'; texto: string } | null>(null);
  // Invitar
  const [jornadaInvitar, setJornadaInvitar] = useState('');
  const [destino, setDestino] = useState<'cuentas' | 'inscritos' | 'uno' | 'numero'>('cuentas');
  const [cuentaUna, setCuentaUna] = useState('');
  // «Un número»: quien administra escribe el celular (para probar o para alguien que pidió la invitación).
  const [numero, setNumero] = useState('');
  const [nombreNumero, setNombreNumero] = useState('');
  const [confirmando, setConfirmando] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [resultado, setResultado] = useState<ResultadoEnvio | null>(null);

  const api = useCallback(async <T,>(ruta: string, o: { metodo?: 'GET' | 'POST' | 'PATCH' | 'DELETE'; cuerpo?: unknown } = {}): Promise<T> => {
    const s = await renovarSesion().catch(() => null);
    if (!s) throw new ErrorBot('Tu sesión venció. Vuelve a iniciar sesión.', 401);
    return pedirBot<T>(ruta, { ...o, token: s.access_token });
  }, []);

  const cargar = useCallback(async () => {
    if (!sesion) { setEstado('sin_sesion'); return; }
    setEstado((e) => (e === 'listo' ? e : 'cargando'));
    try {
      const quien = await api<{ correo: string; rol: string }>('/api/admin/yo');
      const [r, j, c, e] = await Promise.all([
        api<Resumen>('/api/admin/resumen'),
        api<{ jornadas: JornadaAdmin[] }>('/api/admin/jornadas'),
        api<{ contactos: Contacto[] }>('/api/admin/contactos'),
        api<{ envios: Envio[] }>('/api/admin/envios'),
      ]);
      const lista = j?.jornadas ?? [];
      setYo(quien); setResumen(r); setJornadas(lista); setContactos(c?.contactos ?? []); setEnvios(e?.envios ?? []);
      setEstado('listo');
      // Los inscritos de todas las jornadas alimentan las métricas y la lista de personas.
      void Promise.allSettled(lista.map((x) => api<{ inscritos: Inscrito[] }>(`/api/admin/jornadas/${encodeURIComponent(x.id)}/inscritos`).then((res) => [x.id, res?.inscritos ?? []] as const)))
        .then((rs) => {
          setInscritos((p) => { const n = { ...p }; for (const x of rs) if (x.status === 'fulfilled') n[x.value[0]] = x.value[1]; return n; });
          setInscritosListos(true);
        });
      if (!backendActivo) setErrorReportes('La web no está conectada al servidor de reportes.');
      else void leerReportesPublicos().then((f) => { setReportes(f); setErrorReportes(''); })
        .catch((err: unknown) => setErrorReportes(err instanceof Error ? err.message : 'No se pudieron leer los reportes.'));
    } catch (err) {
      const status = err instanceof ErrorBot ? err.status : -1;
      if (status === 401) setEstado('sin_sesion');
      else if (status === 403) setEstado('sin_rol');
      else { setError(err instanceof Error ? err.message : 'No se pudo cargar el panel.'); setEstado('error'); }
    }
  }, [api, sesion]);

  useEffect(() => { void cargar(); }, [sesion?.usuario.id]); // eslint-disable-line react-hooks/exhaustive-deps

  // La sección va en el enlace (#jornadas, #invitar…) para poder compartirla: al cargar el panel se baja a ella,
  // y la barra marca la sección que se está leyendo.
  useEffect(() => {
    if (estado !== 'listo') return;
    const h = location.hash.slice(1);
    if (SECCIONES.some((x) => x.id === h)) requestAnimationFrame(() => document.getElementById(h)?.scrollIntoView({ block: 'start' }));
    const obs = new IntersectionObserver((entradas) => {
      for (const en of entradas) if (en.isIntersecting) setActiva(en.target.id as Seccion);
    }, { rootMargin: '-30% 0px -65% 0px' });
    for (const x of SECCIONES) { const el = document.getElementById(x.id); if (el) obs.observe(el); }
    return () => obs.disconnect();
  }, [estado]);
  function irA(s: Seccion) { history.replaceState(null, '', `#${s}`); setAviso(null); setActiva(s); desplazar(s); }

  const publicadas = useMemo(() => jornadas.filter((j) => j.estado === 'publicada').sort((a, b) => a.inicio.localeCompare(b.inicio)), [jornadas]);
  const proximas = useMemo(() => publicadas.filter((j) => Date.parse(j.fin) > Date.now()), [publicadas]);
  useEffect(() => { if (!jornadaInvitar && proximas[0]) setJornadaInvitar(proximas[0].id); }, [proximas, jornadaInvitar]);
  const conWhatsapp = useMemo(() => contactos.filter((c) => c.whatsapp_ok), [contactos]);
  useEffect(() => { if (!cuentaUna && conWhatsapp[0]) setCuentaUna(conWhatsapp[0].cuenta_id); }, [conWhatsapp, cuentaUna]);

  // Personas: las cuentas de la web y, aparte, quienes se inscribieron sin cuenta (una fila por persona).
  const personas = useMemo<Persona[]>(() => {
    const lista: Persona[] = contactos.map((c) => ({ clave: `c-${c.cuenta_id}`, nombre: c.nombre, telefono: c.telefono_mascara, whatsapp: c.whatsapp_ok, origen: 'cuenta', detalle: 'Cuenta de la web', fecha: c.actualizado_en, cuenta_id: c.cuenta_id }));
    const sinCuenta = new Map<string, Persona & { jornadas: string[] }>();
    for (const j of jornadas) for (const i of inscritos[j.id] ?? []) {
      if (i.cuenta) continue;
      const k = `${i.nombre.trim().toLocaleLowerCase('es-CO')}|${i.telefono_mascara ?? ''}`;
      const previa = sinCuenta.get(k);
      if (previa) { previa.jornadas.push(j.titulo); if (i.fecha > previa.fecha) previa.fecha = i.fecha; previa.whatsapp ||= i.acepta_whatsapp; }
      else sinCuenta.set(k, { clave: `i-${i.id}`, nombre: i.nombre, telefono: i.telefono_mascara, whatsapp: i.acepta_whatsapp, origen: 'inscripcion', detalle: '', fecha: i.fecha, jornadas: [j.titulo] });
    }
    for (const x of sinCuenta.values()) lista.push({ ...x, detalle: x.jornadas.length === 1 ? `Inscripción sin cuenta en «${x.jornadas[0]}»` : `Inscripción sin cuenta en ${x.jornadas.length} jornadas` });
    return lista.sort((a, b) => b.fecha.localeCompare(a.fecha));
  }, [contactos, inscritos, jornadas]);
  const personasVisibles = useMemo(() => {
    const q = filtro.trim().toLocaleLowerCase('es-CO');
    return q ? personas.filter((x) => x.nombre.toLocaleLowerCase('es-CO').includes(q) || (x.telefono ?? '').replace(/\s/g, '').includes(q.replace(/\s/g, ''))) : personas;
  }, [personas, filtro]);

  // Series de las métricas.
  const fechasReportes = useMemo(() => reportes?.map((r) => r.capturado_en) ?? null, [reportes]);
  const reportesPorCanal = useMemo(() => {
    const desde = Date.now() - DIAS * 86_400_000;
    const c: Conteo = {};
    for (const r of reportes ?? []) if (Date.parse(r.capturado_en) >= desde) c[r.canal] = (c[r.canal] ?? 0) + 1;
    return c;
  }, [reportes]);
  const fechasInscripciones = useMemo(() => (inscritosListos ? Object.values(inscritos).flat().filter((i) => i.estado !== 'cancelada').map((i) => i.fecha) : null), [inscritos, inscritosListos]);
  const fechasInvitaciones = useMemo(() => envios.filter((e) => e.estado === 'enviado').map((e) => e.fecha), [envios]);
  const fallidasMes = useMemo(() => envios.filter((e) => e.estado !== 'enviado' && Date.parse(e.fecha) >= Date.now() - DIAS * 86_400_000).length, [envios]);

  function invitarA(cuenta: string) { setDestino('uno'); setCuentaUna(cuenta); setConfirmando(false); setResultado(null); irA('invitar'); }

  async function verInscritos(id: string, forzar = false) {
    if (abiertaInscritos === id && !forzar) { setAbiertaInscritos(null); return; }
    setAbiertaInscritos(id);
    try {
      const r = await api<{ inscritos: Inscrito[] }>(`/api/admin/jornadas/${encodeURIComponent(id)}/inscritos`);
      setInscritos((p) => ({ ...p, [id]: r?.inscritos ?? [] }));
    } catch (err) {
      // Sin respuesta no se deja la caja en «Cargando…»: se cierra y se explica arriba.
      setAbiertaInscritos((actual) => (actual === id ? null : actual));
      setAviso({ tipo: 'error', texto: `No se pudieron leer los inscritos: ${err instanceof Error ? err.message : 'error del servidor'}` });
    }
  }

  async function descargarCSV(j: JornadaAdmin) {
    try {
      const s = await renovarSesion().catch(() => null);
      const res = await pedirBotCrudo(`/api/admin/jornadas/${encodeURIComponent(j.id)}/inscritos?formato=csv`, { token: s?.access_token });
      const url = URL.createObjectURL(await res.blob());
      const a = Object.assign(document.createElement('a'), { href: url, download: `inscritos-${j.id}.csv` });
      document.body.append(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 5000);
    } catch (err) { setAviso({ tipo: 'error', texto: err instanceof Error ? err.message : 'No se pudo descargar la lista.' }); }
  }

  async function guardarJornada(cuerpo: Record<string, unknown>) {
    const actual = editando !== 'nueva' ? editando : null;
    if (actual) await api(`/api/admin/jornadas/${encodeURIComponent(actual.id)}`, { metodo: 'PATCH', cuerpo });
    else await api('/api/admin/jornadas', { metodo: 'POST', cuerpo });
    setEditando(null);
    setAviso({ tipo: 'ok', texto: actual ? 'Jornada actualizada.' : 'Jornada publicada: ya aparece en la cartelera y en Zanky BOT.' });
    await cargar();
    void sincronizarJornadas(true);
  }

  async function cancelarJornada(j: JornadaAdmin) {
    if (!window.confirm(`¿Cancelar «${j.titulo}»? Deja de aparecer en la cartelera y en el bot.`)) return;
    try {
      await api(`/api/admin/jornadas/${encodeURIComponent(j.id)}`, { metodo: 'DELETE' });
      setAviso({ tipo: 'ok', texto: 'Jornada cancelada.' });
      await cargar();
      void sincronizarJornadas(true);
    } catch (err) { setAviso({ tipo: 'error', texto: err instanceof Error ? err.message : 'No se pudo cancelar.' }); }
  }

  // Invitar: destinatarios y vista previa
  const jInvitar = publicadas.find((j) => j.id === jornadaInvitar) ?? null;
  useEffect(() => { if (destino === 'inscritos' && jInvitar && !inscritos[jInvitar.id]) void verInscritos(jInvitar.id, true); }, [destino, jInvitar?.id]); // eslint-disable-line react-hooks/exhaustive-deps
  const inscritosWhatsapp = jInvitar ? (inscritos[jInvitar.id] ?? []).filter((i) => i.acepta_whatsapp && i.estado !== 'cancelada' && i.telefono_mascara) : [];
  const numeroNormal = normalizarCelular(numero);
  const numeroOk = numeroNormal !== null && numeroNormal !== 'invalido';
  const cuantos = destino === 'cuentas' ? conWhatsapp.length : destino === 'inscritos' ? inscritosWhatsapp.length : destino === 'numero' ? (numeroOk ? 1 : 0) : cuentaUna ? 1 : 0;
  const nombreEjemplo = destino === 'numero' ? (nombreNumero.trim() || 'amigo del manglar') : destino === 'uno' ? (conWhatsapp.find((c) => c.cuenta_id === cuentaUna)?.nombre ?? 'María') : destino === 'inscritos' ? (inscritosWhatsapp[0]?.nombre ?? 'María') : (conWhatsapp[0]?.nombre ?? 'María');
  const esManana = jInvitar ? diaBogota(jInvitar.inicio) === diaBogota(Date.now() + 86_400_000) : false;
  const imagenInvitacion = jInvitar?.imagen_url || resumen?.plantilla.imagen_por_defecto || '';

  async function enviarInvitacion() {
    if (!jInvitar) return;
    setEnviando(true); setResultado(null);
    try {
      const r = await api<ResultadoEnvio>('/api/admin/invitaciones', { metodo: 'POST', cuerpo: { jornada_id: jInvitar.id, destino, ...(destino === 'uno' ? { cuenta_id: cuentaUna } : {}), ...(destino === 'numero' ? { telefono: numero, nombre: nombreNumero } : {}) } });
      setResultado(r);
      setAviso({ tipo: r.fallidos ? 'error' : 'ok', texto: `Enviadas: ${r.enviados}. Fallidas: ${r.fallidos}.` });
      void api<{ envios: Envio[] }>('/api/admin/envios').then((e) => setEnvios(e?.envios ?? [])).catch(() => undefined);
    } catch (err) {
      setAviso({ tipo: 'error', texto: err instanceof Error ? err.message : 'No se pudo enviar la invitación.' });
    } finally { setEnviando(false); setConfirmando(false); }
  }

  // --- Estados sin panel ---
  const pedirSesion = () => window.dispatchEvent(new Event('zanky-cuenta:abrir'));
  const encabezado = <header className="flex min-w-0 items-start gap-4">
    <span className="mt-1 grid size-12 shrink-0 place-items-center rounded-2xl bg-dorado-500/15 text-dorado-500 sm:size-14"><ShieldCheck className="size-7 sm:size-8" aria-hidden="true" /></span>
    <div className="min-w-0">
      <h1 className="titular text-4xl sm:text-5xl">Administración</h1>
      <p className="mt-2 max-w-3xl text-suave">Métricas, personas, jornadas, invitaciones por WhatsApp y el bot. Todo se guarda en el servidor de Zanky, el mismo del bot.</p>
    </div>
  </header>;

  if (estado !== 'listo') {
    return <div className="grid gap-8">
      {encabezado}
      <div className="grid max-w-2xl gap-4 rounded-3xl border border-linea-suave bg-superficie p-6 sm:p-8">
        {estado === 'cargando' && <p className="text-suave" role="status">Cargando el panel…</p>}
        {estado === 'sin_sesion' && <>
          <p className="titular text-2xl">Inicia sesión con tu cuenta de administración</p>
          <p className="text-suave">El panel es solo para cuentas con rol de administrador de la plataforma.</p>
          <button type="button" onClick={pedirSesion} className={cn(boton('dorado'), 'justify-self-start')}>Iniciar sesión</button>
        </>}
        {estado === 'sin_rol' && <>
          <p className="titular text-2xl">Tu cuenta no tiene rol de administrador</p>
          <p className="text-suave">Entraste como {sesion?.usuario.correo}. Pide a la C.R.A. que le asigne el rol a tu cuenta y vuelve a intentarlo.</p>
          <div className="flex flex-wrap gap-3"><button type="button" onClick={() => void cargar()} className={boton()}><RefreshCw className="size-4" aria-hidden="true" />Reintentar</button><a href="/" className={boton()}>Ir a la portada</a></div>
        </>}
        {estado === 'error' && <>
          <p className="titular text-2xl">No se pudo cargar el panel</p>
          <Aviso tipo="error">{error}</Aviso>
          <button type="button" onClick={() => void cargar()} className={cn(boton(), 'justify-self-start')}><RefreshCw className="size-4" aria-hidden="true" />Reintentar</button>
        </>}
      </div>
    </div>;
  }

  const bot = resumen?.bot;
  return <div className="grid gap-10">
    <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      {encabezado}
      <div className="flex flex-wrap items-center gap-3 text-sm text-suave">
        <span className="inline-flex min-h-11 items-center gap-1.5 rounded-full border border-linea px-3 py-2"><ShieldCheck className="size-4 text-dorado-300" aria-hidden="true" />{yo?.correo} · {yo?.rol.replace(/_/g, ' ')}</span>
        <button type="button" onClick={() => void cargar()} className={boton()}><RefreshCw className="size-4" aria-hidden="true" />Actualizar</button>
      </div>
    </div>

    <nav aria-label="Secciones del panel" className="sticky top-[4.75rem] z-30 -mx-4 bg-fondo/95 px-4 py-2 shadow-[0_10px_24px_-18px_rgb(0_0_0/0.8)] backdrop-blur-md sm:mx-0 sm:rounded-full sm:px-2">
      <ul className="flex gap-2 overflow-x-auto">
        {SECCIONES.map((x) => <li key={x.id} className="shrink-0"><a href={`#${x.id}`} aria-current={activa === x.id ? 'true' : undefined}
          onClick={(e) => { e.preventDefault(); irA(x.id); }}
          className={cn('inline-flex min-h-11 items-center rounded-full border px-5 text-sm font-semibold transition-colors', activa === x.id ? 'border-dorado-500 bg-dorado-500 text-cra-950' : 'border-linea bg-white/5 text-suave hover:border-dorado-300 hover:text-texto')}>{x.texto}</a></li>)}
      </ul>
    </nav>

    {aviso && <Aviso tipo={aviso.tipo}>{aviso.texto}</Aviso>}

    <SeccionAdmin id="metricas" titulo={`Últimos ${DIAS} días`} descripcion="Reportes de la comunidad (app, web y WhatsApp, sin los descartados), inscripciones a jornadas e invitaciones enviadas, día por día.">
      <div className="grid gap-4 md:grid-cols-3">
        <GraficoDias titulo="Reportes de la comunidad" unidad={['reporte', 'reportes']} fechas={fechasReportes} error={errorReportes || undefined}
          detalle={Object.keys(reportesPorCanal).length ? Object.entries(reportesPorCanal).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${n} ${k === 'whatsapp' ? 'WhatsApp' : k}`).join(' · ') : undefined} />
        <GraficoDias titulo="Inscripciones a jornadas" unidad={['inscripción', 'inscripciones']} fechas={fechasInscripciones} detalle={`En ${publicadas.length} ${publicadas.length === 1 ? 'jornada publicada' : 'jornadas publicadas'}`} />
        <GraficoDias titulo="Invitaciones por WhatsApp" unidad={['enviada', 'enviadas']} fechas={fechasInvitaciones} detalle={fallidasMes ? `${fallidasMes} ${fallidasMes === 1 ? 'fallida' : 'fallidas'} en estos días` : 'Ninguna fallida en estos días'} />
      </div>
      {resumen && bot && <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Tarjeta titulo="Vigías en Zanky BOT" icono={<MessageCircle className="size-4" aria-hidden="true" />} valor={bot.vigias} detalle="Personas registradas por WhatsApp" />
        <Tarjeta titulo="Cuentas con WhatsApp" icono={<Users className="size-4" aria-hidden="true" />} valor={resumen.cuentas.con_whatsapp} detalle={`de ${resumen.cuentas.total_sincronizadas} cuentas sincronizadas aceptaron invitaciones`} />
        <Tarjeta titulo="Jornadas próximas" icono={<CalendarDays className="size-4" aria-hidden="true" />} valor={resumen.jornadas.proximas} detalle={`de ${resumen.jornadas.publicadas} publicadas · ${resumen.jornadas.inscripciones} inscripciones`} />
        <Tarjeta titulo="Reportes por WhatsApp" valor={bot.reportes.total} detalle={bot.reportes.pendientes_envio > 0 ? `${bot.reportes.pendientes_envio} esperando llegar al servidor común` : 'Todos llegaron al servidor común'} />
      </div>}
    </SeccionAdmin>

    <SeccionAdmin id="mapa" titulo="Mapa de reportes" descripcion="De dónde salen los reportes de la comunidad: color por prioridad, filtro por canal y período, y cuántos llegan de cada sector.">
      <MapaReportesAdmin />
    </SeccionAdmin>

    <SeccionAdmin id="confirmar" titulo="Por confirmar" descripcion="Publicaciones de la comunidad que invitan a actividades y reportes ciudadanos: confírmalos para que se publiquen o recházalos.">
      <PorConfirmar />
    </SeccionAdmin>

    <SeccionAdmin id="personas" titulo="Personas registradas"
      descripcion={<>Las cuentas de la web y quienes se inscribieron a una jornada sin cuenta: {personas.length} en total{bot ? `, más ${bot.vigias} ${bot.vigias === 1 ? 'vigía' : 'vigías'} de Zanky BOT` : ''}. Los celulares nunca se muestran completos.</>}>
      <label className="relative block max-w-md">
        <span className="sr-only">Filtrar personas por nombre o celular</span>
        <Search className="pointer-events-none absolute top-1/2 left-4 size-4 -translate-y-1/2 text-tenue" aria-hidden="true" />
        <input type="search" value={filtro} onChange={(e) => setFiltro(e.target.value)} placeholder="Filtrar por nombre o celular" className={cn(campo, 'pl-11')} />
      </label>
      {personas.length === 0 ? <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">{inscritosListos ? 'Todavía no hay personas registradas.' : 'Cargando…'}</p> :
        <div className="overflow-x-auto rounded-3xl border border-linea-suave bg-superficie"><table className="w-full min-w-[680px] text-left text-sm">
          <thead className="bg-white/[0.04] text-xs tracking-wide text-tenue uppercase"><tr>
            <th scope="col" className="px-5 py-3 font-semibold">Persona</th><th scope="col" className="pr-4 font-semibold">Celular</th><th scope="col" className="pr-4 font-semibold">WhatsApp</th>
            <th scope="col" className="pr-4 font-semibold">Fecha</th><th scope="col" className="pr-5 text-right font-semibold">Acción</th></tr></thead>
          <tbody>{personasVisibles.map((x) => <tr key={x.clave} className="border-t border-linea-suave align-top">
            <td className="px-5 py-3"><span className="block font-semibold">{x.nombre}</span><span className="block text-xs text-tenue">{x.detalle}</span></td>
            <td className="pr-4 py-3 tabular-nums">{x.telefono ?? '—'}</td>
            <td className="pr-4 py-3"><span className={cn('inline-flex rounded-full px-2.5 py-1 text-xs font-bold', x.whatsapp ? 'bg-baja/20 text-baja-texto' : 'bg-white/10 text-tenue')}>{x.whatsapp ? 'Acepta' : 'No'}</span></td>
            <td className="pr-4 py-3 whitespace-nowrap text-suave">{fechaCorta(x.fecha)}</td>
            <td className="pr-5 py-2 text-right">{x.origen === 'cuenta' && x.whatsapp && x.cuenta_id && proximas.length > 0
              ? <button type="button" onClick={() => invitarA(x.cuenta_id!)} className={boton()}><Send className="size-4" aria-hidden="true" />Invitar</button>
              : <span className="text-tenue">—</span>}</td>
          </tr>)}
          {personasVisibles.length === 0 && <tr><td colSpan={5} className="px-5 py-6 text-center text-suave">Nadie coincide con «{filtro}».</td></tr>}
          </tbody>
        </table></div>}
    </SeccionAdmin>

    <SeccionAdmin id="jornadas" titulo="Jornadas" descripcion="Las jornadas publicadas aparecen en la cartelera, en la portada y en Zanky BOT."
      accion={editando === null ? <button type="button" onClick={() => setEditando('nueva')} className={boton('dorado')}><Plus className="size-4" aria-hidden="true" />Nueva jornada</button> : undefined}>
      {editando !== null && <FormularioJornada key={editando === 'nueva' ? 'nueva' : editando.id} jornada={editando === 'nueva' ? undefined : editando} onGuardar={guardarJornada} onCerrar={() => setEditando(null)} />}
      {jornadas.length === 0 ? <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">Todavía no hay jornadas. Publica la primera.</p> : <ul className="grid gap-4">
        {[...jornadas].sort((a, b) => b.inicio.localeCompare(a.inicio)).map((j) => {
          const lista = inscritos[j.id];
          const cancelada = j.estado === 'cancelada';
          const pasada = Date.parse(j.fin) < Date.now();
          return <li key={j.id} className={cn('min-w-0 rounded-3xl border bg-superficie p-5', cancelada ? 'border-linea-suave opacity-70' : 'border-linea-suave')}>
            <div className="flex flex-col gap-4 sm:flex-row">
              {j.imagen_url ? <img src={j.imagen_url} alt="" className="h-28 w-full shrink-0 rounded-2xl object-cover sm:w-44" /> : <div className="grid h-28 w-full shrink-0 place-items-center rounded-2xl bg-white/5 text-tenue sm:w-44"><Imagen className="size-8" aria-hidden="true" /></div>}
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap gap-2 text-xs font-bold">
                  <span className="rounded-full bg-white/10 px-2.5 py-1">{TIPOS_JORNADA[j.tipo]?.etiqueta ?? j.tipo}</span>
                  <span className={cn('rounded-full px-2.5 py-1', cancelada ? 'bg-alta/20 text-alta-texto' : pasada ? 'bg-white/10 text-tenue' : 'bg-baja/20 text-baja-texto')}>{cancelada ? 'Cancelada' : pasada ? 'Realizada' : 'Publicada'}</span>
                  {j.ejemplo && <span className="rounded-full border border-white/15 px-2.5 py-1 text-tenue">Datos de ejemplo</span>}
                </div>
                <h3 className="mt-2 text-lg font-bold leading-snug">{j.titulo}</h3>
                <p className="mt-1 text-sm text-suave">{capital(fechaPlantilla(j.inicio))} – {hora(j.fin)}</p>
                <p className="flex items-start gap-1 text-sm text-suave"><MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />{j.punto_encuentro}</p>
                <p className="mt-1 text-sm text-suave"><Users className="mr-1 inline size-3.5" aria-hidden="true" />{j.inscritos} de {j.cupos} inscritos{typeof j.inscripciones_activas === 'number' ? ` · ${j.inscripciones_activas} en el servidor` : ''}</p>
              </div>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              <button type="button" onClick={() => void verInscritos(j.id)} aria-expanded={abiertaInscritos === j.id} className={boton()}><Users className="size-4" aria-hidden="true" />Inscritos</button>
              {!cancelada && <button type="button" onClick={() => { setEditando(j); desplazar('jornadas'); }} className={boton()}><Pencil className="size-4" aria-hidden="true" />Editar</button>}
              {!cancelada && !pasada && <button type="button" onClick={() => { setJornadaInvitar(j.id); irA('invitar'); }} className={boton()}><Send className="size-4" aria-hidden="true" />Invitar</button>}
              {!cancelada && <button type="button" onClick={() => void cancelarJornada(j)} className={boton('peligro')}><X className="size-4" aria-hidden="true" />Cancelar</button>}
            </div>
            {abiertaInscritos === j.id && <div className="mt-4 rounded-2xl border border-linea-suave bg-fondo-alt p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h4 className="rotulo text-dorado-300">Inscritos en el servidor</h4>
                <button type="button" onClick={() => void descargarCSV(j)} className={boton()}><Download className="size-4" aria-hidden="true" />Descargar CSV</button>
              </div>
              {!lista ? <p className="mt-3 text-sm text-tenue" role="status">Cargando…</p> : lista.length === 0 ? <p className="mt-3 text-sm text-tenue">Nadie se ha inscrito todavía desde la web.</p> :
                <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[520px] text-left text-sm">
                  <thead className="text-xs text-tenue"><tr><th className="py-2 pr-3 font-semibold">Nombre</th><th className="pr-3 font-semibold">Celular</th><th className="pr-3 font-semibold">WhatsApp</th><th className="pr-3 font-semibold">Cuenta</th><th className="font-semibold">Fecha</th></tr></thead>
                  <tbody>{lista.map((i) => <tr key={i.id} className={cn('border-t border-linea-suave', i.estado === 'cancelada' && 'text-tenue line-through')}>
                    <td className="py-2 pr-3">{i.nombre}</td><td className="pr-3 tabular-nums">{i.telefono_mascara ?? '—'}</td><td className="pr-3">{i.acepta_whatsapp ? 'Sí' : 'No'}</td><td className="pr-3">{i.cuenta ? 'Sí' : 'No'}</td><td className="whitespace-nowrap">{fechaCorta(i.fecha)}</td>
                  </tr>)}</tbody>
                </table></div>}
            </div>}
          </li>;
        })}
      </ul>}
    </SeccionAdmin>

    <SeccionAdmin id="invitar" titulo="Invitar por WhatsApp" descripcion="Con la plantilla aprobada por Meta: elige la jornada y a quién le llega.">
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,24rem)]">
      <div className="grid content-start gap-5">
        {proximas.length === 0 ? <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">No hay jornadas próximas para invitar. Publica una en «Jornadas».</p> : <>
          <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Jornada</span>
            <select className={campo} value={jornadaInvitar} onChange={(e) => { setJornadaInvitar(e.target.value); setResultado(null); setConfirmando(false); }}>
              {proximas.map((j) => <option key={j.id} value={j.id}>{j.titulo} · {fechaCorta(j.inicio)}</option>)}
            </select></label>
          <fieldset className="grid gap-2">
            <legend className="mb-1.5 text-sm font-semibold text-suave">A quién</legend>
            {([
              ['cuentas', `Cuentas que aceptaron WhatsApp (${conWhatsapp.length})`],
              ['inscritos', `Inscritos de esta jornada con WhatsApp (${inscritos[jornadaInvitar] ? inscritosWhatsapp.length : '…'})`],
              ['uno', 'Una sola cuenta (para probar)'],
              ['numero', 'Un número que yo escriba'],
            ] as const).map(([v, t]) => <label key={v} className={cn('flex min-h-11 cursor-pointer items-center gap-3 rounded-2xl border px-4 py-2 text-sm', destino === v ? 'border-dorado-500 bg-dorado-500/10' : 'border-linea bg-white/5')}>
              <input type="radio" name="destino" value={v} checked={destino === v} onChange={() => { setDestino(v); setConfirmando(false); setResultado(null); }} className="size-4 accent-dorado-500" />{t}</label>)}
            {destino === 'uno' && (conWhatsapp.length === 0 ? <p className="text-sm text-tenue">Ninguna cuenta ha aceptado WhatsApp todavía. Crea una cuenta con tu celular y marca la casilla.</p> :
              <select className={campo} value={cuentaUna} onChange={(e) => setCuentaUna(e.target.value)} aria-label="Cuenta a la que se envía la prueba">
                {conWhatsapp.map((c) => <option key={c.cuenta_id} value={c.cuenta_id}>{c.nombre} · {c.telefono_mascara}</option>)}
              </select>)}
            {destino === 'numero' && <div className="grid gap-3 sm:grid-cols-2">
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Celular (WhatsApp)</span>
                <input className={campo} type="tel" inputMode="tel" autoComplete="off" maxLength={20} placeholder="300 123 4567" value={numero} onChange={(e) => { setNumero(e.target.value); setConfirmando(false); setResultado(null); }} />
                {numero.trim() && !numeroOk && <span className="text-sm font-semibold text-alta-texto">Revisa el celular: 10 dígitos, por ejemplo 300 123 4567.</span>}</label>
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Nombre (opcional)</span>
                <input className={campo} maxLength={60} placeholder="Para el saludo: «Hola …»" value={nombreNumero} onChange={(e) => setNombreNumero(e.target.value)} /></label>
              <p className="text-xs text-tenue sm:col-span-2">Envía solo a números que te pidieron la invitación o al tuyo para probar (Ley 1581 de 2012 y reglas de WhatsApp).</p>
            </div>}
          </fieldset>
          {jInvitar && !esManana && <Aviso tipo="info">La plantilla dice «mañana es tu evento». Esta jornada es el {fechaLarga(jInvitar.inicio)}: lo ideal es enviarla el día anterior.</Aviso>}
          {!confirmando ? <button type="button" disabled={!jInvitar || cuantos === 0 || enviando} onClick={() => setConfirmando(true)} className={cn(boton('dorado'), 'justify-self-start')}><Send className="size-4" aria-hidden="true" />Enviar invitación</button> :
            <div className="grid gap-3 rounded-2xl border border-dorado-500/40 bg-dorado-500/10 p-4">
              <p className="font-semibold">Se enviará por WhatsApp a {cuantos} {cuantos === 1 ? 'persona' : 'personas'}. ¿Confirmas?</p>
              <div className="flex flex-wrap gap-3">
                <button type="button" disabled={enviando} onClick={() => void enviarInvitacion()} className={boton('dorado')}><Send className="size-4" aria-hidden="true" />{enviando ? 'Enviando…' : 'Sí, enviar'}</button>
                <button type="button" disabled={enviando} onClick={() => setConfirmando(false)} className={boton()}>No, volver</button>
              </div>
            </div>}
          {resultado && <div className="grid gap-2">
            <h3 className="rotulo text-dorado-300">Resultado</h3>
            <ul className="divide-y divide-linea-suave rounded-2xl border border-linea-suave">
              {resultado.resultados.map((r, i) => <li key={i} className="flex flex-wrap items-center justify-between gap-2 px-4 py-2.5 text-sm">
                <span className="min-w-0">{r.nombre} <span className="text-tenue tabular-nums">{r.telefono_mascara}</span></span>
                <span className={r.estado === 'enviado' ? 'font-semibold text-baja-texto' : 'font-semibold text-alta-texto'}>{r.estado === 'enviado' ? 'Enviado' : `Falló${r.error ? `: ${r.error}` : ''}`}</span>
              </li>)}
            </ul>
          </div>}
        </>}
      </div>

      {jInvitar && <aside aria-label="Vista previa del mensaje de WhatsApp" className="min-w-0">
        <p className="rotulo mb-3 text-dorado-300">Así llega por WhatsApp</p>
        <div className="rounded-3xl bg-[#0b141a] p-4">
          <div className="overflow-hidden rounded-2xl bg-[#202c33] text-[15px] text-white shadow-lg">
            {imagenInvitacion ? <img src={imagenInvitacion} alt="Imagen de la invitación" className="aspect-[1.91/1] w-full object-cover" /> : <div className="grid aspect-[1.91/1] place-items-center bg-white/5 text-sm text-tenue">Sin imagen</div>}
            <p className="whitespace-pre-line px-3 pt-2.5 pb-2 leading-snug">
              {`Hola ${nombreEjemplo}, mañana es tu evento.\n\n`}<b>{jInvitar.titulo}</b>{`\n🗓 ${fechaPlantilla(jInvitar.inicio)}\n📍 ${jInvitar.punto_encuentro}\n\nSi ya no puedes ir, retira tu asistencia para dejarle el lugar a alguien más.`}
            </p>
            <div className="border-t border-white/10 py-2.5 text-center font-semibold text-[#53bdeb]">↗ Ver el evento</div>
            <div className="border-t border-white/10 py-2.5 text-center font-semibold text-[#53bdeb]">↩ No podré ir</div>
          </div>
        </div>
        <p className="mt-3 text-xs text-tenue">Plantilla aprobada por Meta: {resumen?.plantilla.nombre}. «Ver el evento» abre la invitación en la plataforma; «No podré ir» libera el cupo.</p>
      </aside>}
      </div>
    </SeccionAdmin>

    <SeccionAdmin id="envios" titulo="Envíos" descripcion="Historial de invitaciones enviadas desde este panel.">
      {envios.length === 0 ? <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">Todavía no se han enviado invitaciones.</p> :
        <div className="overflow-x-auto rounded-3xl border border-linea-suave bg-superficie"><table className="w-full min-w-[640px] text-left text-sm">
          <thead className="text-xs text-tenue"><tr><th className="px-4 py-3 font-semibold">Fecha</th><th className="pr-3 font-semibold">Jornada</th><th className="pr-3 font-semibold">Para</th><th className="pr-3 font-semibold">Estado</th><th className="pr-4 font-semibold">Por</th></tr></thead>
          <tbody>{envios.map((e, i) => <tr key={i} className="border-t border-linea-suave align-top">
            <td className="whitespace-nowrap px-4 py-2.5">{fechaCorta(e.fecha)}</td>
            <td className="pr-3 py-2.5">{e.jornada_titulo}</td>
            <td className="pr-3 py-2.5">{e.nombre} <span className="text-tenue tabular-nums">{e.telefono_mascara}</span></td>
            <td className={cn('pr-3 py-2.5 font-semibold', e.estado === 'enviado' ? 'text-baja-texto' : 'text-alta-texto')}>{e.estado === 'enviado' ? 'Enviado' : 'Falló'}{e.error ? <span className="block text-xs font-normal text-tenue">{e.error}</span> : null}</td>
            <td className="pr-4 py-2.5 text-tenue">{e.por}</td>
          </tr>)}</tbody>
        </table></div>}
    </SeccionAdmin>

    {resumen && bot && <SeccionAdmin id="bot" titulo="Zanky BOT" descripcion="El bot de WhatsApp: vigías registrados y reportes que llegan por ese canal.">
      <div className="grid gap-4 sm:grid-cols-2">
        <Tarjeta titulo="Estado del bot" valor={bot.simulacion ? 'Simulación' : 'En línea'}
          detalle={<>{bot.simulacion ? 'Sin token de WhatsApp: no envía mensajes reales.' : 'Conectado a WhatsApp.'} IA {bot.ia ? 'activa' : 'apagada'}.</>} />
        <Tarjeta titulo="Invitaciones" icono={<Send className="size-4" aria-hidden="true" />} valor={resumen.envios.enviados} detalle={`enviadas en total · ${resumen.envios.fallidos} fallidas`} />
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        <Barras titulo="Vigías por municipio" datos={bot.vigias_por_municipio} vacio="Todavía no hay vigías registrados." />
        <Barras titulo="Vigías por rol" datos={bot.vigias_por_rol} vacio="Todavía no hay vigías registrados." />
        <Barras titulo="Reportes por tipo" datos={bot.reportes.por_tipo} vacio="Todavía no hay reportes por WhatsApp." />
      </div>
      <Barras titulo="Reportes por estado" datos={bot.reportes.por_estado} vacio="Todavía no hay reportes por WhatsApp." />
      <p className="text-xs text-tenue">Plantilla de invitación: {resumen.plantilla.nombre} ({resumen.plantilla.idioma}).</p>
    </SeccionAdmin>}
  </div>;
}
