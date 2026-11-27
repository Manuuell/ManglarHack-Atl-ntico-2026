// Seguimiento de las acciones y cartelera de jornadas (base: eventos de Innvita).
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { CalendarPlus, Check, CircleDashed, Copy, MapPin, MessageCircle, Users } from 'lucide-react';
import type { Accion, Actor, CambioAccion, EstadoAccion, Jornada, ReporteMonitoreo } from '../../types/plataforma';
import { inscribirseEnJornada, useAcciones, useActores, useCambiosAccion, useInscripciones, useJornadas, useMonitoreos } from '../../lib/plataforma/estado';
import { ACCIONES_PLAN, ESTADOS_ACCION, LISTA_ESTADOS_ACCION, ROLES, SECTORES, TIPOS_ACCION, TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { copiarEnlace, descargarICS, enlaceInvitacionWhatsApp } from '../../lib/plataforma/calendario';
import { cn } from '../../lib/utils';

interface Props { acciones: Accion[]; actores: Actor[]; cambios: CambioAccion[]; jornadas: Jornada[]; monitoreos: ReporteMonitoreo[] }

const zona = { timeZone: 'America/Bogota' } as const;
const fechaLarga = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
const fechaCorta = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(iso.length === 10 ? `${iso}T12:00:00-05:00` : iso));
const dia = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric' }).format(new Date(iso));
const mes = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, month: 'short' }).format(new Date(iso)).replace('.', '');
const diaSemana = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long' }).format(new Date(iso));
const hora = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
const NIVEL: Record<string, string> = { alta: 'Alta', media: 'Media', baja: 'Baja' };

function Chip({ estado }: { estado: EstadoAccion }) {
  return <span className={cn('inline-block whitespace-nowrap px-2 py-0.5 text-[10px] font-black tracking-[0.1em]', ESTADOS_ACCION[estado].clase)}>{ESTADOS_ACCION[estado].etiqueta}</span>;
}

function TarjetaJornada({ jornada, accion, resaltada, inscrito }: { jornada: Jornada; accion?: Accion; resaltada: boolean; inscrito: boolean }) {
  const [abierto, setAbierto] = useState(false);
  const [nombre, setNombre] = useState('');
  const [mensaje, setMensaje] = useState<{ ok: boolean; texto: string } | null>(null);
  const [copiado, setCopiado] = useState(false);
  const Icono = TIPOS_JORNADA[jornada.tipo].icono;
  const libres = Math.max(0, jornada.cupos - jornada.inscritos);
  const lleno = libres === 0;
  const pasada = Date.parse(jornada.fin) < Date.now();
  const url = typeof window === 'undefined' ? `/plataforma/seguimiento?jornada=${jornada.id}` : `${window.location.origin}/plataforma/seguimiento?jornada=${jornada.id}`;

  function inscribir(e: FormEvent) {
    e.preventDefault();
    const r = inscribirseEnJornada(jornada.id, nombre);
    if (!r.ok) { setMensaje({ ok: false, texto: Object.values(r.errores)[0] ?? 'No se pudo inscribir.' }); return; }
    setMensaje({ ok: true, texto: 'Inscripción guardada en este navegador (demostración). En la versión conectada recibirá la confirmación por WhatsApp.' });
    setNombre(''); setAbierto(false);
  }

  return (
    <article id={`jornada-${jornada.id}`} className={cn('flex scroll-mt-6 flex-col border bg-superficie', resaltada ? 'border-dorado-300 ring-2 ring-dorado-300' : 'border-linea-suave')}>
      <div className="flex gap-4 p-4">
        <div className="flex w-16 shrink-0 flex-col items-center border-r border-white/25 pr-3 text-center">
          <span className="titular text-4xl">{dia(jornada.inicio)}</span>
          <span className="rotulo text-dorado-300">{mes(jornada.inicio)}</span>
          <span className="mt-1 text-[11px] capitalize text-tenue">{diaSemana(jornada.inicio)}</span>
        </div>
        <div className="min-w-0 flex-1 text-sm">
          <p className="rotulo flex items-center gap-1 text-suave"><Icono className="size-3.5" aria-hidden="true" />{TIPOS_JORNADA[jornada.tipo].etiqueta}</p>
          <h3 className="mt-1 text-base font-black leading-snug">{jornada.titulo}</h3>
          <p className="mt-1 text-suave">{hora(jornada.inicio)} – {hora(jornada.fin)}</p>
          <p className="flex items-start gap-1 text-suave"><MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />{jornada.punto_encuentro}</p>
          {accion && <p className="mt-1 text-xs text-tenue">Acción: <a href={`?accion=${accion.id}`} className="underline hover:text-dorado-300">{accion.nombre}</a></p>}
        </div>
      </div>
      <div className="px-4">
        <div className="flex items-center justify-between text-xs text-suave"><span className="flex items-center gap-1"><Users className="size-3.5" aria-hidden="true" />{jornada.inscritos} de {jornada.cupos} inscritos</span><span>{lleno ? 'Cupos agotados' : `${libres} cupos libres`}</span></div>
        <div className="mt-1 h-1.5 bg-white/10" role="meter" aria-valuemin={0} aria-valuemax={jornada.cupos} aria-valuenow={jornada.inscritos} aria-label="Cupos ocupados"><div className="h-full bg-dorado-400" style={{ width: `${Math.min(100, (jornada.inscritos / Math.max(1, jornada.cupos)) * 100)}%` }} /></div>
        {jornada.que_llevar.length > 0 && (
          <details className="mt-2 text-xs text-suave"><summary className="inline-flex min-h-9 cursor-pointer items-center font-bold uppercase tracking-wider hover:text-texto">Qué llevar</summary><ul className="ml-4 list-disc pb-1">{jornada.que_llevar.map((x) => <li key={x}>{x}</li>)}</ul></details>
        )}
      </div>
      <div className="mt-auto grid gap-2 p-4 pt-2">
        {inscrito ? (
          <p className="flex min-h-11 items-center justify-center gap-2 border border-plan-preservacion text-xs font-black uppercase text-emerald-200"><Check className="size-4" aria-hidden="true" />Ya estás inscrito</p>
        ) : abierto ? (
          <form onSubmit={inscribir} className="flex gap-2">
            <label className="sr-only" htmlFor={`nombre-${jornada.id}`}>Su nombre</label>
            <input id={`nombre-${jornada.id}`} autoFocus value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Su nombre" autoComplete="name" className="min-h-11 min-w-0 flex-1 border-0 border-b border-white/60 bg-white/5 px-3 text-sm text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none" />
            <button type="submit" className="min-h-11 bg-dorado-500 px-4 text-xs font-black uppercase text-cra-950 hover:bg-dorado-300">Confirmar</button>
          </form>
        ) : (
          <button type="button" disabled={lleno || pasada} onClick={() => setAbierto(true)} className="min-h-11 bg-dorado-500 text-xs font-black uppercase tracking-[0.08em] text-cra-950 hover:bg-dorado-300 disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-tenue">{pasada ? 'Jornada realizada' : lleno ? 'Sin cupos' : 'Inscribirme'}</button>
        )}
        <div className="grid grid-cols-3 gap-2">
          <a href={enlaceInvitacionWhatsApp(jornada, url)} target="_blank" rel="noopener" className="inline-flex min-h-11 items-center justify-center gap-1 border border-white/40 text-[11px] font-bold uppercase hover:border-dorado-300 hover:text-dorado-300" aria-label={`Invitar por WhatsApp a ${jornada.titulo}`}><MessageCircle className="size-3.5" aria-hidden="true" />Invitar</a>
          <button type="button" onClick={async () => { setCopiado(await copiarEnlace(url)); setTimeout(() => setCopiado(false), 2500); }} className="inline-flex min-h-11 items-center justify-center gap-1 border border-white/40 text-[11px] font-bold uppercase hover:border-dorado-300 hover:text-dorado-300"><Copy className="size-3.5" aria-hidden="true" />{copiado ? 'Copiado' : 'Enlace'}</button>
          <button type="button" onClick={() => descargarICS(jornada, url)} className="inline-flex min-h-11 items-center justify-center gap-1 border border-white/40 text-[11px] font-bold uppercase hover:border-dorado-300 hover:text-dorado-300" aria-label={`Añadir ${jornada.titulo} al calendario`}><CalendarPlus className="size-3.5" aria-hidden="true" />Calendario</button>
        </div>
        <div aria-live="polite">{mensaje && <p className={cn('text-xs', mensaje.ok ? 'text-emerald-200' : 'text-alta-texto')}>{mensaje.texto}</p>}</div>
      </div>
    </article>
  );
}

export default function SeguimientoAcciones(props: Props) {
  const acciones = useAcciones(props.acciones);
  const actores = useActores(props.actores);
  const cambios = useCambiosAccion(props.cambios);
  const jornadas = useJornadas(props.jornadas);
  const monitoreos = useMonitoreos(props.monitoreos);
  const inscripciones = useInscripciones();
  const [filtro, setFiltro] = useState<EstadoAccion | 'todas'>('todas');
  const [seleccion, setSeleccion] = useState<string | null>(null);
  const [resaltada, setResaltada] = useState<string | null>(null);

  // Enlaces profundos: ?accion= abre el detalle; ?jornada= resalta la tarjeta (invitaciones).
  useEffect(() => {
    const p = new URLSearchParams(window.location.search);
    const a = p.get('accion');
    const j = p.get('jornada');
    if (a) { setSeleccion(a); requestAnimationFrame(() => document.getElementById('detalle-accion')?.scrollIntoView({ block: 'start' })); }
    if (j) { setResaltada(j); requestAnimationFrame(() => document.getElementById(`jornada-${j}`)?.scrollIntoView({ block: 'center' })); }
  }, []);

  function ver(id: string) {
    setSeleccion(id);
    const url = new URL(window.location.href);
    url.searchParams.set('accion', id);
    url.searchParams.delete('jornada');
    history.replaceState(null, '', url);
    if (window.matchMedia('(max-width: 1023px)').matches) requestAnimationFrame(() => document.getElementById('detalle-accion')?.scrollIntoView({ behavior: 'smooth' }));
  }

  const filtradas = filtro === 'todas' ? acciones : acciones.filter((a) => a.estado === filtro);
  const accion = acciones.find((a) => a.id === seleccion) ?? null;
  const actorDe = (id: string) => actores.find((a) => a.id === id)?.nombre ?? 'Actor no disponible';
  const linea = useMemo(() => (accion ? cambios.filter((c) => c.accion_id === accion.id).sort((x, y) => x.fecha.localeCompare(y.fecha)) : []), [accion, cambios]);
  const ahora = new Date().toISOString();
  const proximas = [...jornadas].sort((a, b) => a.inicio.localeCompare(b.inicio));

  return (
    <div className="grid gap-14">
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
        <section aria-labelledby="titulo-seguimiento">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b border-white pb-2">
            <h2 id="titulo-seguimiento" className="rotulo">Seguimiento de las acciones</h2>
            <span className="border border-white/50 px-2 py-0.5 text-[10px] font-black uppercase tracking-[0.1em] text-suave">Datos de ejemplo</span>
          </div>
          <div className="mt-3 flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Filtrar por estado">
            {(['todas', ...LISTA_ESTADOS_ACCION] as const).map((e) => {
              const n = e === 'todas' ? acciones.length : acciones.filter((a) => a.estado === e).length;
              return <button key={e} type="button" aria-pressed={filtro === e} onClick={() => setFiltro(e)} className={cn('min-h-11 shrink-0 px-3 text-[11px] font-black uppercase tracking-[0.08em]', filtro === e ? 'bg-dorado-500 text-cra-950' : 'border border-white/40 text-suave hover:text-texto')}>{e === 'todas' ? 'Todas' : ESTADOS_ACCION[e].etiqueta} · {n}</button>;
            })}
          </div>
          {filtradas.length === 0 ? <p className="mt-4 text-suave">No hay acciones en este estado.</p> : (
            <div className="mt-2 overflow-x-auto">
              <table className="w-full min-w-[640px] text-left text-[13px]">
                <thead><tr className="border-b border-white text-[11px] font-bold uppercase tracking-[0.06em] text-suave"><th scope="col" className="py-2 pr-3">Acción</th><th scope="col" className="py-2 pr-3">Actor</th><th scope="col" className="py-2 pr-3">Plan</th><th scope="col" className="py-2 pr-3">Estado</th><th scope="col" className="py-2"><span className="sr-only">Detalle</span></th></tr></thead>
                <tbody>
                  {filtradas.map((a) => (
                    <tr key={a.id} className={cn('border-b border-white/25', seleccion === a.id && 'bg-white/10')}>
                      <td className="py-2 pr-3 font-bold">{a.nombre}</td>
                      <td className="py-2 pr-3 text-suave">{actorDe(a.actor_id)}</td>
                      <td className="py-2 pr-3 text-suave">{ACCIONES_PLAN[a.accion_plan].etiqueta}{a.prioridad_plan ? ` · ${NIVEL[a.prioridad_plan]}` : ''}</td>
                      <td className="py-2 pr-3"><Chip estado={a.estado} /></td>
                      <td className="py-2"><button type="button" onClick={() => ver(a.id)} className="min-h-11 px-3 text-xs font-black uppercase tracking-wider text-dorado-300 hover:underline" aria-label={`Ver detalle de ${a.nombre}`}>Ver</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section id="detalle-accion" aria-labelledby="titulo-detalle" className="scroll-mt-6">
          <h2 id="titulo-detalle" className="rotulo border-b border-white pb-2">Detalle</h2>
          {!accion ? <p className="mt-3 text-suave">Seleccione una acción.</p> : (
            <div className="mt-3 grid gap-5 text-sm">
              <div>
                <p className="rotulo text-dorado-300">{TIPOS_ACCION[accion.tipo].etiqueta}</p>
                <h3 className="titular mt-1 text-2xl">{accion.nombre}</h3>
                <div className="mt-2"><Chip estado={accion.estado} /></div>
              </div>
              <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
                <div><dt className="etiqueta-campo text-suave">Actor</dt><dd>{actorDe(accion.actor_id)}</dd></div>
                <div><dt className="etiqueta-campo text-suave">Sector</dt><dd>{SECTORES[accion.sector].largo}</dd></div>
                <div><dt className="etiqueta-campo text-suave">Hectáreas</dt><dd>{accion.hectareas.toLocaleString('es-CO')} ha</dd></div>
                <div><dt className="etiqueta-campo text-suave">Sitio</dt><dd>{accion.lat.toFixed(5)}, {accion.lon.toFixed(5)}</dd></div>
                <div className="col-span-2"><dt className="etiqueta-campo text-suave">Plan de manejo heredado</dt><dd>{ACCIONES_PLAN[accion.accion_plan].etiqueta}{accion.prioridad_plan ? ` · prioridad ${NIVEL[accion.prioridad_plan].toLowerCase()}` : ''}{accion.plan_aproximado ? ' (aproximado)' : ' · capa de prioridades de la C.R.A.'}</dd></div>
                {accion.comunidad_coparticipante && <div className="col-span-2"><dt className="etiqueta-campo text-suave">Comunidad coparticipante</dt><dd>{accion.comunidad_coparticipante}</dd></div>}
              </dl>
              {accion.descripcion && <p className="text-suave">{accion.descripcion}</p>}
              <div>
                <p className="etiqueta-campo text-suave">Requerimientos</p>
                <ul className="mt-1 grid gap-1">
                  {accion.requerimientos.map((r) => <li key={r.id} className="flex items-start gap-2">{r.cumplido ? <Check className="mt-0.5 size-4 shrink-0 text-emerald-300" aria-label="Cumplido" /> : <CircleDashed className="mt-0.5 size-4 shrink-0 text-tenue" aria-label="Pendiente" />}<span className={r.cumplido ? '' : 'text-suave'}>{r.texto}</span></li>)}
                </ul>
              </div>
              {accion.observaciones.length > 0 && (
                <div className="border-l-4 border-capa-recuperacion bg-white/5 p-3">
                  <p className="etiqueta-campo text-orange-200">Observaciones de la Corporación</p>
                  <ul className="mt-1 grid gap-1">{accion.observaciones.map((o, i) => <li key={i}>{o}</li>)}</ul>
                </div>
              )}
              <div>
                <p className="etiqueta-campo text-suave">Línea de tiempo</p>
                <ol className="mt-2 grid border-l-2 border-linea">
                  {linea.map((c) => (
                    <li key={c.id} className="relative py-1.5 pl-4">
                      <span aria-hidden="true" className="absolute -left-[5px] top-3 size-2 bg-dorado-300" />
                      <Chip estado={c.estado} /> <span className="text-xs text-tenue">{fechaLarga(c.fecha)} · {c.rol === 'sistema' ? 'Actor proponente' : ROLES[c.rol].etiqueta}</span>
                      {c.nota && <p className="mt-0.5 text-xs text-suave">{c.nota}</p>}
                    </li>
                  ))}
                </ol>
              </div>
              {monitoreos.some((m) => m.accion_id === accion.id) && (
                <div>
                  <p className="etiqueta-campo text-suave">Monitoreos</p>
                  <ul className="mt-1 grid gap-1">{monitoreos.filter((m) => m.accion_id === accion.id).sort((a, b) => b.fecha.localeCompare(a.fecha)).map((m) => <li key={m.id}>{fechaCorta(m.fecha)}: {m.vivas_pct} % vivas · {m.altura_cm} cm · {m.fotos.length} fotos ubicadas</li>)}</ul>
                </div>
              )}
            </div>
          )}
        </section>
      </div>

      <section aria-labelledby="titulo-jornadas">
        <div className="flex flex-wrap items-end justify-between gap-2 border-b border-white pb-2">
          <h2 id="titulo-jornadas" className="rotulo">Próximas jornadas</h2>
          <p className="text-xs text-tenue">Siembras, limpiezas, recorridos de vigías y monitoreos ligados a las acciones. Invite por WhatsApp o con el enlace.</p>
        </div>
        {proximas.length === 0 ? <p className="mt-4 text-suave">No hay jornadas programadas.</p> : (
          <div className="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {proximas.map((j) => (
              <TarjetaJornada key={j.id} jornada={j} accion={acciones.find((a) => a.id === j.accion_id)} resaltada={resaltada === j.id} inscrito={inscripciones.some((i) => i.jornada_id === j.id)} />
            ))}
          </div>
        )}
        {proximas.some((j) => j.fin < ahora) && <p className="mt-2 text-xs text-tenue">Las jornadas ya realizadas quedan visibles como registro.</p>}
      </section>
    </div>
  );
}
