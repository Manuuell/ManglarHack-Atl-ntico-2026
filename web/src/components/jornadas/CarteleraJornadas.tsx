// Cartelera de jornadas comunitarias: tarjetas con banner, ficha de invitación con inscripción,
// formas de compartir (WhatsApp, enlace, calendario), QR y cartel imprimible, y alta de jornadas.
import { useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react';
import QRCode from 'qrcode';
import { CalendarPlus, Check, Clock, Copy, Download, MapPin, MessageCircle, Navigation, Plus, Printer, Share2, Users, X } from 'lucide-react';
import type { Accion, Jornada, TipoJornada } from '../../types/plataforma';
import { inscribirseEnJornada, useAcciones, useInscripciones, useJornadas } from '../../lib/plataforma/estado';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { copiarEnlace, descargarICS, enlaceInvitacionWhatsApp } from '../../lib/plataforma/calendario';
import { crearJornada, enlaceComoLlegar, enlaceGoogleCalendar, fmt, urlInvitacion, type DatosJornada } from '../../lib/plataforma/jornadas';
import { cn } from '../../lib/utils';

interface Props { jornadas: Jornada[]; acciones: Accion[]; aviso: string }

const BANNER: Record<TipoJornada, string> = {
  siembra: 'from-emerald-500 via-emerald-700 to-cra-900',
  limpieza: 'from-cra-500 via-cra-700 to-cra-950',
  recorrido_vigias: 'from-dorado-400 via-amber-600 to-cra-900',
  monitoreo: 'from-sky-400 via-cra-600 to-cra-950',
};
const TIPOS = Object.keys(TIPOS_JORNADA) as TipoJornada[];
const capital = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function estadoDe(j: Jornada) {
  const libres = Math.max(0, j.cupos - j.inscritos);
  const pasada = Date.parse(j.fin) < Date.now();
  return { libres, pasada, lleno: libres === 0 };
}

function Banner({ j, className, grande = false }: { j: Jornada; className?: string; grande?: boolean }) {
  const Icono = TIPOS_JORNADA[j.tipo].icono;
  const { libres, pasada, lleno } = estadoDe(j);
  return (
    <div className={cn('relative isolate overflow-hidden bg-linear-to-br', BANNER[j.tipo], className)}>
      <svg aria-hidden="true" viewBox="0 0 400 225" preserveAspectRatio="none" className="absolute inset-0 -z-10 h-full w-full fill-none stroke-white/15">
        {[0, 1, 2, 3, 4].map((i) => <path key={i} d={`M-20 ${150 + i * 14} C 80 ${110 + i * 14}, 180 ${190 + i * 14}, 420 ${130 + i * 14}`} strokeWidth="1.2" />)}
      </svg>
      <Icono aria-hidden="true" strokeWidth={1.2} className={cn('absolute -right-5 -bottom-6 text-white/20 transition-transform duration-500 group-hover:scale-110', grande ? 'size-56' : 'size-36')} />
      <div className="absolute top-3 left-3 rounded-2xl bg-white px-3 py-1.5 text-center text-cra-950 shadow-lg">
        <span className="block font-[family-name:var(--font-titulo)] text-2xl leading-none font-extrabold">{fmt.dia(j.inicio)}</span>
        <span className="text-[11px] font-bold tracking-wider uppercase">{fmt.mes(j.inicio)}</span>
      </div>
      <span className={cn('absolute rounded-full px-3 py-1 text-xs font-bold', grande ? 'bottom-4 left-4' : 'top-3 right-3', pasada ? 'bg-black/40 text-white' : lleno ? 'bg-alta text-white' : 'bg-white/90 text-cra-950')}>
        {pasada ? 'Realizada' : lleno ? 'Sin cupos' : `${libres} ${libres === 1 ? 'cupo libre' : 'cupos libres'}`}
      </span>
    </div>
  );
}

function Cupos({ j }: { j: Jornada }) {
  const pct = Math.min(100, (j.inscritos / Math.max(1, j.cupos)) * 100);
  return (
    <div className="mt-3">
      <div className="flex items-center justify-between text-xs text-suave">
        <span className="flex items-center gap-1"><Users className="size-3.5" aria-hidden="true" />{j.inscritos} de {j.cupos} inscritos</span>
        <span>{Math.round(pct)} %</span>
      </div>
      <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-white/10" role="meter" aria-valuemin={0} aria-valuemax={j.cupos} aria-valuenow={j.inscritos} aria-label="Cupos ocupados">
        <div className="h-full rounded-full bg-dorado-400 transition-[width] duration-700" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

/** Hoja adaptable: abajo en el teléfono, centrada en escritorio. Se cierra con Esc o tocando fuera. */
function Hoja({ titulo, onCerrar, children }: { titulo: string; onCerrar: () => void; children: ReactNode }) {
  const cerrar = useRef<HTMLButtonElement>(null);
  // La función para cerrar cambia en cada render; se guarda en una referencia para que el efecto
  // corra una sola vez (si no, el foco saltaría al botón de cerrar mientras se escribe).
  const alCerrar = useRef(onCerrar);
  alCerrar.current = onCerrar;
  useEffect(() => {
    const previo = document.activeElement as HTMLElement | null;
    cerrar.current?.focus();
    const tecla = (e: KeyboardEvent) => { if (e.key === 'Escape') alCerrar.current(); };
    document.addEventListener('keydown', tecla);
    const anterior = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.removeEventListener('keydown', tecla); document.body.style.overflow = anterior; previo?.focus?.(); };
  }, []);
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm sm:items-center sm:p-6 print:hidden" onMouseDown={(e) => { if (e.target === e.currentTarget) onCerrar(); }}>
      <div role="dialog" aria-modal="true" aria-label={titulo} className="relative max-h-[92dvh] w-full max-w-3xl overflow-y-auto rounded-t-[2rem] border border-linea-suave bg-fondo shadow-[var(--c-sombra-alta)] sm:rounded-[2rem]">
        <button ref={cerrar} type="button" onClick={onCerrar} aria-label="Cerrar" className="absolute top-4 right-4 z-10 grid size-11 place-items-center rounded-full bg-black/40 text-white backdrop-blur hover:bg-black/60"><X className="size-5" aria-hidden="true" /></button>
        {children}
      </div>
    </div>
  );
}

function BotonCompartir({ onClick, href, icono, children, externo }: { onClick?: () => void; href?: string; icono: ReactNode; children: ReactNode; externo?: boolean }) {
  const clase = 'inline-flex min-h-11 items-center justify-center gap-2 rounded-full border border-white/20 bg-white/5 px-4 text-sm font-semibold text-texto transition-colors hover:border-dorado-300 hover:text-dorado-300';
  return href
    ? <a href={href} className={clase} {...(externo ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>{icono}{children}</a>
    : <button type="button" onClick={onClick} className={clase}>{icono}{children}</button>;
}

function Invitacion({ j, accion, inscrito, aviso, onCerrar }: { j: Jornada; accion?: Accion; inscrito: boolean; aviso: string; onCerrar: () => void }) {
  const T = TIPOS_JORNADA[j.tipo];
  const { pasada, lleno } = estadoDe(j);
  const url = urlInvitacion(j.id);
  const [nombre, setNombre] = useState('');
  const [acepta, setAcepta] = useState(false);
  const [mensaje, setMensaje] = useState<{ ok: boolean; texto: string } | null>(null);
  const [copiado, setCopiado] = useState(false);
  const [qr, setQr] = useState('');
  const puedeCompartir = typeof navigator !== 'undefined' && typeof navigator.share === 'function';

  useEffect(() => {
    QRCode.toString(url, { type: 'svg', margin: 1, errorCorrectionLevel: 'M', color: { dark: '#05243a', light: '#ffffff' } }).then(setQr).catch(() => setQr(''));
  }, [url]);

  function confirmar(e: FormEvent) {
    e.preventDefault();
    if (nombre.trim().length < 2) { setMensaje({ ok: false, texto: 'Escribe tu nombre para la lista.' }); return; }
    if (!acepta) { setMensaje({ ok: false, texto: 'Para inscribirte, acepta el tratamiento de tu nombre (Ley 1581).' }); return; }
    const r = inscribirseEnJornada(j.id, nombre);
    if (!r.ok) { setMensaje({ ok: false, texto: Object.values(r.errores)[0] ?? 'No se pudo inscribir.' }); return; }
    setMensaje({ ok: true, texto: '¡Listo! Quedaste en la lista. Te esperamos.' });
  }

  async function copiar() {
    setCopiado(await copiarEnlace(url));
    setTimeout(() => setCopiado(false), 2200);
  }

  return (
    <Hoja titulo={`Invitación: ${j.titulo}`} onCerrar={onCerrar}>
      <Banner j={j} grande className="aspect-[2/1] sm:aspect-[21/9]" />
      <div className="space-y-7 p-6 sm:p-9">
        <header>
          <p className={cn('rotulo flex items-center gap-1.5', T.clase)}><T.icono className="size-3.5" aria-hidden="true" />{T.etiqueta}</p>
          <h2 className="titular mt-2 text-3xl sm:text-4xl">{j.titulo}</h2>
          <p className="mt-3 rounded-2xl border border-white/15 bg-white/5 px-4 py-2 text-xs text-suave">{aviso}</p>
        </header>

        <dl className="grid gap-4 sm:grid-cols-2">
          <div className="rounded-2xl bg-superficie p-4">
            <dt className="rotulo text-tenue">Cuándo</dt>
            <dd className="mt-1.5 font-semibold">{capital(fmt.larga(j.inicio))}</dd>
            <dd className="mt-0.5 flex items-center gap-1 text-sm text-suave"><Clock className="size-3.5" aria-hidden="true" />{fmt.hora(j.inicio)} – {fmt.hora(j.fin)} (hora de Colombia)</dd>
          </div>
          <div className="rounded-2xl bg-superficie p-4">
            <dt className="rotulo text-tenue">Dónde</dt>
            <dd className="mt-1.5 flex items-start gap-1 font-semibold"><MapPin className="mt-1 size-3.5 shrink-0" aria-hidden="true" />{j.punto_encuentro}</dd>
            <dd className="mt-1"><a href={enlaceComoLlegar(j)} target="_blank" rel="noopener noreferrer" className="inline-flex min-h-11 items-center gap-1 text-sm font-semibold text-dorado-300 hover:underline"><Navigation className="size-3.5" aria-hidden="true" />Cómo llegar</a></dd>
          </div>
          <div className="rounded-2xl bg-superficie p-4 sm:col-span-2">
            <dt className="rotulo text-tenue">Cupos</dt>
            <dd><Cupos j={j} /></dd>
            {accion && <dd className="mt-3 text-sm text-suave">Hace parte de la acción <a href={`/plataforma/seguimiento?accion=${accion.id}`} className="font-semibold text-texto underline decoration-white/30 underline-offset-4 hover:text-dorado-300">{accion.nombre}</a>.</dd>}
          </div>
        </dl>

        {j.que_llevar.length > 0 && (
          <section aria-labelledby={`llevar-${j.id}`}>
            <h3 id={`llevar-${j.id}`} className="rotulo text-dorado-300">Qué llevar</h3>
            <ul className="mt-3 flex flex-wrap gap-2">{j.que_llevar.map((x) => <li key={x} className="rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-sm text-suave">{x}</li>)}</ul>
          </section>
        )}
        <p className="leading-relaxed text-suave">{j.descripcion}</p>

        {/* Inscripción */}
        <section aria-labelledby={`inscripcion-${j.id}`} className="rounded-3xl border border-dorado-500/40 bg-dorado-500/10 p-5 sm:p-6">
          <h3 id={`inscripcion-${j.id}`} className="titular text-2xl">¿Vas a ir?</h3>
          {inscrito || mensaje?.ok ? (
            <p className="mt-3 flex items-center gap-2 font-semibold text-emerald-200"><Check className="size-5" aria-hidden="true" />{mensaje?.texto ?? 'Ya estás inscrito en esta jornada desde este navegador.'}</p>
          ) : pasada || lleno ? (
            <p className="mt-3 text-suave">{pasada ? 'Esta jornada ya se realizó.' : 'Esta jornada ya no tiene cupos. Comparte la invitación: pueden abrir más cupos.'}</p>
          ) : (
            <form onSubmit={confirmar} className="mt-4 grid gap-3" noValidate>
              <label className="grid gap-1.5">
                <span className="text-sm font-semibold text-suave">Tu nombre</span>
                <input value={nombre} onChange={(e) => setNombre(e.target.value)} autoComplete="name" maxLength={80} placeholder="Como quieres aparecer en la lista" className="min-h-12 rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none" />
              </label>
              <label className="flex items-start gap-3 text-sm text-suave">
                <input type="checkbox" checked={acepta} onChange={(e) => setAcepta(e.target.checked)} className="mt-0.5 size-5 shrink-0 accent-dorado-500" />
                <span>Acepto que la organización use mi nombre solo para la lista de esta jornada, según la Ley 1581 de 2012. No se publica.</span>
              </label>
              <button type="submit" className="inline-flex min-h-12 items-center justify-center rounded-full bg-dorado-500 px-6 font-bold text-cra-950 transition-colors hover:bg-dorado-300">Confirmar asistencia</button>
              {mensaje && !mensaje.ok && <p role="alert" className="text-sm font-semibold text-alta-texto">{mensaje.texto}</p>}
              <p className="text-xs text-tenue">Modo demostración: la inscripción se guarda en este navegador.</p>
            </form>
          )}
        </section>

        {/* Compartir */}
        <section aria-labelledby={`compartir-${j.id}`}>
          <h3 id={`compartir-${j.id}`} className="rotulo text-dorado-300">Invita a tu gente</h3>
          <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
            <BotonCompartir href={enlaceInvitacionWhatsApp(j, url)} externo icono={<MessageCircle className="size-4" aria-hidden="true" />}>WhatsApp</BotonCompartir>
            {puedeCompartir && <BotonCompartir onClick={() => navigator.share({ title: j.titulo, text: `Te invito: ${j.titulo}`, url }).catch(() => {})} icono={<Share2 className="size-4" aria-hidden="true" />}>Compartir</BotonCompartir>}
            <BotonCompartir onClick={copiar} icono={copiado ? <Check className="size-4" aria-hidden="true" /> : <Copy className="size-4" aria-hidden="true" />}>{copiado ? '¡Copiado!' : 'Copiar enlace'}</BotonCompartir>
            <BotonCompartir href={enlaceGoogleCalendar(j, url)} externo icono={<CalendarPlus className="size-4" aria-hidden="true" />}>Google Calendar</BotonCompartir>
            <BotonCompartir onClick={() => descargarICS(j, url)} icono={<Download className="size-4" aria-hidden="true" />}>Calendario (.ics)</BotonCompartir>
          </div>
          <div className="mt-5 flex flex-col items-center gap-5 rounded-3xl bg-white p-5 text-cra-950 sm:flex-row">
            <div className="size-36 shrink-0" aria-label="Código QR de la invitación" role="img" dangerouslySetInnerHTML={{ __html: qr }} />
            <div className="text-center sm:text-left">
              <p className="font-[family-name:var(--font-titulo)] text-lg font-extrabold">Código QR de la invitación</p>
              <p className="mt-1 text-sm text-cra-900/80">Para carteles en el colegio, la junta o el punto de encuentro: quien lo escanea abre esta invitación.</p>
              <button type="button" onClick={() => window.print()} className="mt-3 inline-flex min-h-11 items-center gap-2 rounded-full bg-cra-950 px-5 text-sm font-bold text-white hover:bg-cra-800"><Printer className="size-4" aria-hidden="true" />Imprimir cartel</button>
            </div>
          </div>
        </section>
      </div>

      {/* Cartel imprimible: solo aparece al imprimir. */}
      <div id="cartel-jornada" className="hidden">
        <p className="cartel-rotulo">{T.etiqueta} · Jornada comunitaria del manglar</p>
        <h1 className="cartel-titulo">{j.titulo}</h1>
        <p className="cartel-dato">{capital(fmt.larga(j.inicio))} · {fmt.hora(j.inicio)} – {fmt.hora(j.fin)}</p>
        <p className="cartel-dato">Punto de encuentro: {j.punto_encuentro}</p>
        {j.que_llevar.length > 0 && <p className="cartel-dato">Qué llevar: {j.que_llevar.join(', ')}</p>}
        <div className="cartel-qr" dangerouslySetInnerHTML={{ __html: qr }} />
        <p className="cartel-pie">Escanea para inscribirte · Cupos: {j.cupos}</p>
        <p className="cartel-pie">Corporación Autónoma Regional del Atlántico · Monitoreo comunitario con Zanky</p>
      </div>
    </Hoja>
  );
}

function FormularioJornada({ acciones, onCreada, onCerrar }: { acciones: Accion[]; onCreada: (j: Jornada) => void; onCerrar: () => void }) {
  const elegibles = acciones.filter((a) => a.estado === 'aprobada' || a.estado === 'en_ejecucion');
  const manana = new Date(Date.now() + 86_400_000).toISOString().slice(0, 10);
  const [d, setD] = useState<DatosJornada>({ titulo: '', tipo: 'siembra', accion_id: elegibles[0]?.id ?? '', fecha: manana, hora_inicio: '07:00', hora_fin: '11:00', punto_encuentro: '', cupos: 30, que_llevar: 'Agua potable, gorra, bloqueador solar', descripcion: '' });
  const [errores, setErrores] = useState<Record<string, string>>({});
  const cambiar = <K extends keyof DatosJornada>(k: K, v: DatosJornada[K]) => setD((p) => ({ ...p, [k]: v }));
  const campo = 'min-h-12 w-full rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none';
  const Error = ({ k }: { k: string }) => (errores[k] ? <span role="alert" className="text-sm font-semibold text-alta-texto">{errores[k]}</span> : null);

  function enviar(e: FormEvent) {
    e.preventDefault();
    const r = crearJornada(d, elegibles);
    if (!r.ok) { setErrores(r.errores); return; }
    onCreada(r.jornada);
  }

  return (
    <Hoja titulo="Crear una jornada" onCerrar={onCerrar}>
      <form onSubmit={enviar} noValidate className="grid gap-5 p-6 sm:p-9">
        <header className="pr-12">
          <p className="rotulo text-dorado-300">Nueva jornada</p>
          <h2 className="titular mt-2 text-3xl">Convoca a tu comunidad</h2>
          <p className="mt-2 text-sm text-suave">La jornada se liga a una acción aprobada o en ejecución, y toma su punto en el mapa.</p>
        </header>
        {elegibles.length === 0 ? (
          <p className="rounded-2xl bg-superficie p-4 text-suave">Todavía no hay acciones aprobadas o en ejecución. Propón una en <a href="/plataforma/proponer" className="font-semibold text-dorado-300 underline">Proponer acción</a>.</p>
        ) : (
          <>
            <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Nombre de la jornada</span><input className={campo} value={d.titulo} onChange={(e) => cambiar('titulo', e.target.value)} maxLength={90} placeholder="Ej.: Siembra de mangle rojo en el caño" /><Error k="titulo" /></label>
            <div className="grid gap-5 sm:grid-cols-2">
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Tipo</span>
                <select className={campo} value={d.tipo} onChange={(e) => cambiar('tipo', e.target.value as TipoJornada)}>{TIPOS.map((t) => <option key={t} value={t}>{TIPOS_JORNADA[t].etiqueta}</option>)}</select></label>
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Acción</span>
                <select className={campo} value={d.accion_id} onChange={(e) => cambiar('accion_id', e.target.value)}>{elegibles.map((a) => <option key={a.id} value={a.id}>{a.nombre}</option>)}</select><Error k="accion_id" /></label>
            </div>
            <div className="grid gap-5 sm:grid-cols-3">
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Fecha</span><input type="date" className={campo} value={d.fecha} min={new Date().toISOString().slice(0, 10)} onChange={(e) => cambiar('fecha', e.target.value)} /><Error k="fecha" /></label>
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Empieza</span><input type="time" className={campo} value={d.hora_inicio} onChange={(e) => cambiar('hora_inicio', e.target.value)} /><Error k="hora_inicio" /></label>
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Termina</span><input type="time" className={campo} value={d.hora_fin} onChange={(e) => cambiar('hora_fin', e.target.value)} /><Error k="hora_fin" /></label>
            </div>
            <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Punto de encuentro</span><input className={campo} value={d.punto_encuentro} onChange={(e) => cambiar('punto_encuentro', e.target.value)} maxLength={140} placeholder="Ej.: Ecoparque Ciénaga de Mallorquín, entrada principal" /><Error k="punto_encuentro" /></label>
            <div className="grid gap-5 sm:grid-cols-[10rem_1fr]">
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Cupos</span><input type="number" inputMode="numeric" min={1} max={500} className={campo} value={d.cupos} onChange={(e) => cambiar('cupos', Number(e.target.value))} /><Error k="cupos" /></label>
              <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Qué llevar (separado por comas)</span><input className={campo} value={d.que_llevar} onChange={(e) => cambiar('que_llevar', e.target.value)} maxLength={300} /></label>
            </div>
            <label className="grid gap-1.5"><span className="text-sm font-semibold text-suave">Descripción</span><textarea rows={3} className={cn(campo, 'py-3')} value={d.descripcion} onChange={(e) => cambiar('descripcion', e.target.value)} maxLength={600} placeholder="Qué se va a hacer, quién acompaña, recomendaciones" /><Error k="descripcion" /></label>
            <button type="submit" className="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-dorado-500 px-6 font-bold text-cra-950 hover:bg-dorado-300"><Plus className="size-5" aria-hidden="true" />Crear y compartir</button>
            <p className="text-xs text-tenue">Modo demostración: la jornada se guarda en este navegador. En producción la crea el servidor con tu cuenta de actor.</p>
          </>
        )}
      </form>
    </Hoja>
  );
}

export default function CarteleraJornadas(props: Props) {
  const lista = useJornadas(props.jornadas);
  const acciones = useAcciones(props.acciones);
  const inscripciones = useInscripciones();
  const [tipo, setTipo] = useState<TipoJornada | 'todas'>('todas');
  const [cuando, setCuando] = useState<'proximas' | 'realizadas'>('proximas');
  const [abierta, setAbierta] = useState<string | null>(null);
  const [creando, setCreando] = useState(false);

  // Enlace de invitación: ?jornada=<id> abre la ficha.
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('jornada');
    if (id) setAbierta(id);
  }, []);
  function abrir(id: string | null) {
    setAbierta(id);
    const url = new URL(window.location.href);
    if (id) url.searchParams.set('jornada', id); else url.searchParams.delete('jornada');
    window.history.replaceState(null, '', url);
  }

  const visibles = useMemo(() => lista
    .filter((j) => (tipo === 'todas' || j.tipo === tipo) && (cuando === 'proximas' ? !estadoDe(j).pasada : estadoDe(j).pasada))
    .sort((a, b) => (cuando === 'proximas' ? a.inicio.localeCompare(b.inicio) : b.inicio.localeCompare(a.inicio))), [lista, tipo, cuando]);
  const actual = lista.find((j) => j.id === abierta);
  const inscrito = (id: string) => inscripciones.some((i) => i.jornada_id === id);
  const chip = (activo: boolean) => cn('inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full border px-4 text-sm font-semibold transition-colors', activo ? 'border-dorado-500 bg-dorado-500 text-cra-950' : 'border-linea bg-white/5 text-suave hover:border-dorado-300 hover:text-texto');

  return (
    <div className="grid gap-8">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="rotulo text-dorado-300">Jornadas comunitarias</p>
          <h2 className="titular mt-2 text-3xl sm:text-4xl">Siembras, limpiezas y recorridos para cuidar el manglar</h2>
          <p className="mt-3 max-w-2xl text-suave">Cada jornada tiene su invitación: se comparte por WhatsApp, se agenda en el calendario y se imprime con un QR para el punto de encuentro.</p>
        </div>
        <button type="button" onClick={() => setCreando(true)} className="inline-flex min-h-12 shrink-0 items-center gap-2 self-start rounded-full bg-dorado-500 px-6 font-bold text-cra-950 shadow-[0_12px_34px_-14px_rgb(237_181_18/0.8)] hover:bg-dorado-300 sm:self-auto"><Plus className="size-5" aria-hidden="true" />Crear jornada</button>
      </div>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Filtrar por tipo">
          <button type="button" className={chip(tipo === 'todas')} aria-pressed={tipo === 'todas'} onClick={() => setTipo('todas')}>Todas</button>
          {TIPOS.map((t) => { const I = TIPOS_JORNADA[t].icono; return <button key={t} type="button" className={chip(tipo === t)} aria-pressed={tipo === t} onClick={() => setTipo(t)}><I className="size-4" aria-hidden="true" />{TIPOS_JORNADA[t].etiqueta}</button>; })}
        </div>
        <div className="inline-flex shrink-0 self-start rounded-full border border-linea bg-white/5 p-1" role="group" aria-label="Próximas o realizadas">
          {(['proximas', 'realizadas'] as const).map((c) => <button key={c} type="button" aria-pressed={cuando === c} onClick={() => setCuando(c)} className={cn('min-h-10 rounded-full px-4 text-sm font-semibold', cuando === c ? 'bg-white text-cra-950' : 'text-suave hover:text-texto')}>{c === 'proximas' ? 'Próximas' : 'Realizadas'}</button>)}
        </div>
      </div>

      <p className="text-xs text-tenue">{props.aviso}</p>

      {visibles.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-linea p-10 text-center">
          <p className="titular text-2xl">{cuando === 'proximas' ? 'No hay jornadas próximas con este filtro' : 'Todavía no hay jornadas realizadas'}</p>
          <p className="mt-2 text-suave">{cuando === 'proximas' ? 'Crea una y comparte la invitación con tu comunidad.' : 'Aquí aparecerán las jornadas cuando pasen.'}</p>
        </div>
      ) : (
        <ul className="grid gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
          {visibles.map((j) => {
            const T = TIPOS_JORNADA[j.tipo];
            return (
              <li key={j.id}>
                <article className="group">
                  <button type="button" onClick={() => abrir(j.id)} className="block w-full text-left" aria-label={`Ver la invitación: ${j.titulo}`}>
                    <Banner j={j} className="aspect-[16/9] rounded-2xl shadow-[var(--c-sombra)]" />
                    <div className="mt-3 px-1">
                      <p className={cn('rotulo flex items-center gap-1.5', T.clase)}><T.icono className="size-3.5" aria-hidden="true" />{T.etiqueta}</p>
                      <h3 className="mt-1.5 font-[family-name:var(--font-titulo)] text-xl leading-snug font-bold transition-colors group-hover:text-dorado-300">{j.titulo}</h3>
                      <p className="mt-1 text-sm text-suave">{capital(fmt.diaSemana(j.inicio))} · {fmt.hora(j.inicio)} – {fmt.hora(j.fin)}</p>
                      <p className="mt-0.5 flex items-start gap-1 text-sm text-suave"><MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />{j.punto_encuentro}</p>
                      <Cupos j={j} />
                      {inscrito(j.id) && <p className="mt-2 inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-3 py-1 text-xs font-bold text-emerald-200"><Check className="size-3.5" aria-hidden="true" />Vas a ir</p>}
                    </div>
                  </button>
                </article>
              </li>
            );
          })}
        </ul>
      )}

      {actual && <Invitacion j={actual} accion={acciones.find((a) => a.id === actual.accion_id)} inscrito={inscrito(actual.id)} aviso={props.aviso} onCerrar={() => abrir(null)} />}
      {creando && <FormularioJornada acciones={acciones} onCerrar={() => setCreando(false)} onCreada={(j) => { setCreando(false); setCuando('proximas'); setTipo('todas'); abrir(j.id); }} />}
    </div>
  );
}
