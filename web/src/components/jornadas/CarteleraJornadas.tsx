// Cartelera de jornadas comunitarias: filtros y tarjetas. Cada tarjeta lleva a la ficha de su jornada
// (/plataforma/jornada?id=<id>, FichaJornada.tsx), con inscripción, compartir, QR y cartel imprimible.
// Las jornadas y las inscripciones viven en el servidor de Zanky; se crean desde /admin. No tienen
// límite de cupos.
import { useMemo, useState } from 'react';
import { Plus } from 'lucide-react';
import type { Accion, Jornada, TipoJornada } from '../../types/plataforma';
import { useInscripciones, useJornadas } from '../../lib/plataforma/estado';
import { useOrigenJornadas } from '../../lib/plataforma/jornadasApi';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { cn } from '../../lib/utils';
import AvisoZanky from '../marca/AvisoZanky';
import { TarjetaJornada, estaPasada } from './piezas';

interface Props { jornadas: Jornada[]; acciones: Accion[]; aviso: string }

const TIPOS = Object.keys(TIPOS_JORNADA) as TipoJornada[];

export default function CarteleraJornadas(props: Props) {
  const lista = useJornadas(props.jornadas);
  const inscripciones = useInscripciones();
  const { origen } = useOrigenJornadas();
  // El aviso del servidor está pensado para el bot; aquí se dice en palabras de la cartelera.
  const aviso = origen === 'servidor'
    ? (lista.some((j) => j.ejemplo) ? 'Las jornadas rotuladas «Datos de ejemplo» son de la demostración; las demás son reales.' : 'Jornadas publicadas por la organización.')
    : origen === 'respaldo' ? `${props.aviso}. Sin conexión con el servidor de jornadas: lo que ves y lo que hagas queda solo en este navegador.` : props.aviso;
  const [tipo, setTipo] = useState<TipoJornada | 'todas'>('todas');
  const [cuando, setCuando] = useState<'proximas' | 'realizadas'>('proximas');

  const visibles = useMemo(() => lista
    .filter((j) => (tipo === 'todas' || j.tipo === tipo) && (cuando === 'proximas' ? !estaPasada(j) : estaPasada(j)))
    .sort((a, b) => (cuando === 'proximas' ? a.inicio.localeCompare(b.inicio) : b.inicio.localeCompare(a.inicio))), [lista, tipo, cuando]);
  const inscrito = (id: string) => inscripciones.some((i) => i.jornada_id === id);
  const chip = (activo: boolean) => cn('inline-flex min-h-11 shrink-0 items-center gap-1.5 rounded-full border px-4 text-sm font-semibold transition-colors', activo ? 'border-dorado-500 bg-dorado-500 text-cra-950' : 'border-linea bg-white/5 text-suave hover:border-dorado-300 hover:text-texto');

  return (
    <div className="grid gap-8">
      <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="rotulo text-dorado-300">Jornadas comunitarias</p>
          <h2 className="titular mt-2 text-3xl sm:text-4xl">Siembras, limpiezas y recorridos para cuidar el manglar</h2>
          <p className="mt-3 max-w-2xl text-suave">Todas son gratis y sin límite de cupos. Cada jornada tiene su página: se comparte por WhatsApp, se agenda en el calendario y se imprime con un QR para el punto de encuentro.</p>
        </div>
        <a href="/admin#jornadas" title="Las jornadas se crean desde el panel de administración" className="inline-flex min-h-12 shrink-0 items-center gap-2 self-start rounded-full bg-dorado-500 px-6 font-bold text-cra-950 shadow-[0_12px_34px_-14px_rgb(237_181_18/0.8)] hover:bg-dorado-300 sm:self-auto"><Plus className="size-5" aria-hidden="true" />Crear jornada</a>
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

      <p className="text-xs text-tenue" aria-live="polite">{origen === 'cargando' ? 'Cargando las jornadas del servidor…' : aviso}</p>

      {visibles.length === 0 ? (
        <AvisoZanky animo="curioso" forma="bloque" className="rounded-3xl border border-dashed border-linea p-10"
          titulo={cuando === 'proximas' ? 'No hay jornadas próximas con este filtro' : 'Todavía no hay jornadas realizadas'}>
          <p>{cuando === 'proximas' ? 'Cuando la organización publique una, aparecerá aquí con su invitación.' : 'Aquí aparecerán las jornadas cuando pasen.'}</p>
        </AvisoZanky>
      ) : (
        <ul className="grid gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
          {visibles.map((j) => <li key={j.id} className="min-w-0"><TarjetaJornada j={j} inscrito={inscrito(j.id)} /></li>)}
        </ul>
      )}
    </div>
  );
}
