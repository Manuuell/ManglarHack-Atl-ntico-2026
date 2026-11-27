// «Por confirmar» en /admin: publicaciones de la comunidad que invitan a actividades y reportes ciudadanos que
// esperan que el equipo los confirme o los rechace antes de publicarse. Hoy son datos de ejemplo (simulados):
// las decisiones quedan en este navegador (lib/admin/porConfirmar.ts).
import { useEffect, useMemo, useState } from 'react';
import { CalendarDays, Check, Globe, MapPin, MessageCircle, RotateCcw, Smartphone, X } from 'lucide-react';
import { TIPOS } from '../../lib/catalogos';
import { cn } from '../../lib/utils';
import { EJEMPLOS_POR_CONFIRMAR, guardarDecisiones, leerDecisiones, type Canal, type Decision, type ItemPorConfirmar } from '../../lib/admin/porConfirmar';

const ZONA = 'America/Bogota';
const CANAL: Record<Canal, { texto: string; icono: typeof Globe }> = {
  whatsapp: { texto: 'WhatsApp', icono: MessageCircle }, web: { texto: 'Web', icono: Globe }, app: { texto: 'App', icono: Smartphone },
};
const hace = (iso: string) => {
  const min = Math.max(1, Math.round((Date.now() - Date.parse(iso)) / 60_000));
  return min < 60 ? `hace ${min} min` : min < 1440 ? `hace ${Math.round(min / 60)} h` : `hace ${Math.round(min / 1440)} d`;
};
const fecha = (iso: string) => {
  const d = new Date(iso);
  const dia = new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, weekday: 'short', day: 'numeric', month: 'short' }).format(d).replace(/\./g, '');
  return `${dia} · ${new Intl.DateTimeFormat('es-CO', { timeZone: ZONA, hour: 'numeric', minute: '2-digit' }).format(d)}`;
};

type Vista = 'pendiente' | 'confirmada' | 'rechazada';
type Clase = 'todo' | 'publicacion' | 'reporte';

const chip = (activo: boolean) => cn('inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full border px-4 text-sm font-semibold transition-colors',
  activo ? 'border-dorado-500 bg-dorado-500 text-cra-950' : 'border-linea bg-white/5 text-suave hover:border-dorado-300 hover:text-texto');
const boton = 'inline-flex min-h-11 items-center justify-center gap-2 rounded-full px-5 text-sm font-bold transition-colors';

function Tarjeta({ it, decision, decidir }: { it: ItemPorConfirmar; decision: Decision; decidir: (d: Decision) => void }) {
  const C = CANAL[it.canal];
  const esReporte = it.clase === 'reporte';
  const Icono = esReporte ? TIPOS[it.tipo].icono : null;
  const titulo = esReporte ? TIPOS[it.tipo].etiquetaLarga : it.titulo;
  return (
    <li className="min-w-0">
      <article className={cn('flex h-full flex-col overflow-hidden rounded-3xl border bg-white/5 transition-colors',
        decision === 'confirmada' ? 'border-emerald-400/50' : decision === 'rechazada' ? 'border-white/10 opacity-70' : 'border-linea')}>
        <div className="relative aspect-[16/9] bg-cra-900">
          <img src={`/cra/img/z${it.sector}_img.jpg`} alt="" loading="lazy" decoding="async" className="absolute inset-0 h-full w-full object-cover" />
          <span className={cn('absolute top-3 left-3 inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold shadow-lg',
            esReporte ? 'bg-alta text-white' : 'bg-dorado-500 text-cra-950')}>
            {esReporte && Icono ? <><Icono className="size-3.5" aria-hidden="true" />Reporte</> : <><span aria-hidden="true">{it.clase === 'publicacion' ? it.emoji : ''}</span>Publicación</>}
          </span>
          <span className="absolute top-3 right-3 rounded-full bg-cra-950 px-2.5 py-1 text-[11px] font-extrabold tracking-[0.12em] text-white uppercase">Simulado</span>
        </div>
        <div className="flex flex-1 flex-col gap-2 p-4">
          <p className="flex flex-wrap items-center gap-x-1.5 text-xs text-tenue">
            <span className="font-semibold text-suave">{it.autor}</span> · {it.quien} · <C.icono className="size-3.5" aria-hidden="true" />{C.texto} · {hace(it.recibido)}
          </p>
          <h3 className="text-lg leading-snug font-bold">{titulo}</h3>
          <p className="line-clamp-3 text-sm text-suave">{it.texto}</p>
          <p className="flex items-start gap-1.5 text-xs text-tenue"><MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />{it.lugar}</p>
          {it.clase === 'publicacion' && <p className="flex items-center gap-1.5 text-xs text-tenue"><CalendarDays className="size-3.5 shrink-0" aria-hidden="true" />{fecha(it.fecha_actividad)}</p>}
          {it.clase === 'reporte' && <p className="text-xs text-tenue">Confianza propuesta por la IA: <strong className="text-suave">{it.confianza} %</strong></p>}
          <div className="mt-auto flex flex-wrap items-center gap-2 pt-2">
            {decision === 'pendiente' ? <>
              <button type="button" onClick={() => decidir('confirmada')} className={cn(boton, 'bg-dorado-500 text-cra-950 hover:bg-dorado-300')}><Check className="size-4" aria-hidden="true" />Confirmar</button>
              <button type="button" onClick={() => decidir('rechazada')} className={cn(boton, 'border border-white/20 bg-white/5 text-texto hover:border-alta-texto hover:text-alta-texto')}><X className="size-4" aria-hidden="true" />Rechazar</button>
            </> : <>
              <span role="status" className={cn('inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 text-sm font-bold', decision === 'confirmada' ? 'bg-emerald-500/15 text-emerald-200' : 'bg-white/10 text-suave')}>
                {decision === 'confirmada' ? <><Check className="size-4" aria-hidden="true" />{esReporte ? 'Confirmado' : 'Publicada'}</> : <><X className="size-4" aria-hidden="true" />{esReporte ? 'Rechazado' : 'Rechazada'}</>}
              </span>
              <button type="button" onClick={() => decidir('pendiente')} className="inline-flex min-h-11 items-center gap-1.5 px-2 text-sm font-semibold text-dorado-300 hover:underline"><RotateCcw className="size-4" aria-hidden="true" />Deshacer</button>
            </>}
          </div>
        </div>
      </article>
    </li>
  );
}

export default function PorConfirmar() {
  const [decisiones, setDecisiones] = useState<Record<string, Decision>>({});
  const [vista, setVista] = useState<Vista>('pendiente');
  const [clase, setClase] = useState<Clase>('todo');
  useEffect(() => { setDecisiones(leerDecisiones()); }, []);

  const estado = (id: string): Decision => decisiones[id] ?? 'pendiente';
  function decidir(id: string, d: Decision) {
    setDecisiones((previo) => { const nuevo = { ...previo, [id]: d }; guardarDecisiones(nuevo); return nuevo; });
  }
  const cuenta = useMemo(() => {
    const c: Record<Vista, number> = { pendiente: 0, confirmada: 0, rechazada: 0 };
    for (const it of EJEMPLOS_POR_CONFIRMAR) c[estado(it.id)] += 1;
    return c;
  }, [decisiones]); // eslint-disable-line react-hooks/exhaustive-deps
  const visibles = EJEMPLOS_POR_CONFIRMAR.filter((it) => estado(it.id) === vista && (clase === 'todo' || it.clase === clase));

  return (
    <div className="grid gap-5">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Estado">
          {([['pendiente', 'Pendientes'], ['confirmada', 'Confirmadas'], ['rechazada', 'Rechazadas']] as const).map(([v, t]) => (
            <button key={v} type="button" aria-pressed={vista === v} onClick={() => setVista(v)} className={chip(vista === v)}>{t} <span className="tabular-nums opacity-80">({cuenta[v]})</span></button>
          ))}
        </div>
        <div className="inline-flex shrink-0 self-start rounded-full border border-linea bg-white/5 p-1" role="group" aria-label="Tipo">
          {([['todo', 'Todo'], ['publicacion', 'Publicaciones'], ['reporte', 'Reportes']] as const).map(([v, t]) => (
            <button key={v} type="button" aria-pressed={clase === v} onClick={() => setClase(v)} className={cn('min-h-10 rounded-full px-4 text-sm font-semibold', clase === v ? 'bg-white text-cra-950' : 'text-suave hover:text-texto')}>{t}</button>
          ))}
        </div>
      </div>
      <p className="rounded-2xl border border-dorado-500/40 bg-dorado-500/10 px-4 py-2.5 text-sm text-suave">
        <strong className="text-dorado-300">Simulado.</strong> Son publicaciones y reportes de ejemplo para mostrar cómo se confirma. Lo que confirmes o rechaces queda solo en este navegador; en producción lo decide el servidor con tu rol y queda en la auditoría.
      </p>
      {visibles.length === 0 ? (
        <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">
          {vista === 'pendiente' ? 'No hay nada pendiente por confirmar. ¡Al día!' : vista === 'confirmada' ? 'Todavía no confirmas nada.' : 'No has rechazado nada.'}
        </p>
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {visibles.map((it) => <Tarjeta key={it.id} it={it} decision={estado(it.id)} decidir={(d) => decidir(it.id, d)} />)}
        </ul>
      )}
    </div>
  );
}
