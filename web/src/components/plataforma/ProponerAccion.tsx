// Proponer una acción marcando el sitio en el mapa (pestaña PROPONER ACCIÓN).
// Solo cliente: incluye el mapa. La acción hereda la acción y la prioridad del
// plan de manejo de la C.R.A. en el punto marcado.
import { useMemo, useRef, useState, type FormEvent } from 'react';
import { MapPin, Send } from 'lucide-react';
import type { CapaPrioridades, ZonasManglar } from '../../types/manglar';
import type { Accion, Actor, CambioAccion, SectorId, TipoAccion } from '../../types/plataforma';
import { proponerAccion, useAcciones, useActores, useCambiosAccion } from '../../lib/plataforma/estado';
import { ACCIONES_PLAN, NOTA_REQUERIMIENTOS_PROPUESTOS, REQUERIMIENTOS_POR_TIPO, SECTORES, TIPOS_ACCION } from '../../lib/plataforma/catalogos';
import { heredarPlan, planDesdeCapa, sectorDePunto, type PlanHeredado } from '../../lib/plataforma/geo';
import MapaPlataforma, { type PuntoMapa } from './MapaPlataforma';

interface Props { zonas: ZonasManglar; actores: Actor[]; acciones: Accion[]; cambios: CambioAccion[] }

const campo = 'mt-1 w-full min-h-11 border-0 border-b border-white/60 bg-white/5 px-3 text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none aria-[invalid=true]:border-alta';
const NIVEL: Record<string, string> = { alta: 'Alta', media: 'Media', baja: 'Baja' };

export default function ProponerAccion({ zonas, actores: actoresIniciales, acciones: accionesIniciales, cambios }: Props) {
  const actores = useActores(actoresIniciales);
  const acciones = useAcciones(accionesIniciales);
  useCambiosAccion(cambios); // proponerAccion también registra el cambio de estado

  const [capa, setCapa] = useState<CapaPrioridades | null | undefined>(undefined);
  const [punto, setPunto] = useState<PuntoMapa | null>(null);
  const [sectorElegido, setSectorElegido] = useState<SectorId>('mallorquin');
  const [actorId, setActorId] = useState(actores[0]?.id ?? '');
  const [tipo, setTipo] = useState<TipoAccion>('siembra');
  const [nombre, setNombre] = useState('');
  const [cumplidos, setCumplidos] = useState<string[]>([]);
  const [hectareas, setHectareas] = useState('');
  const [comunidad, setComunidad] = useState('');
  const [descripcion, setDescripcion] = useState('');
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [creada, setCreada] = useState<Accion | null>(null);
  const formulario = useRef<HTMLFormElement>(null);

  const ubicacion = useMemo(() => (punto ? sectorDePunto(punto.lat, punto.lon, zonas) : null), [punto, zonas]);
  const sector: SectorId = ubicacion?.sector ?? sectorElegido;
  const plan: PlanHeredado | null = useMemo(() => {
    if (!punto) return null;
    return capa ? planDesdeCapa(punto.lat, punto.lon, capa) : heredarPlan(sector);
  }, [punto, capa, sector]);

  function marcar(p: PuntoMapa) {
    setPunto(p);
    setCreada(null);
    setErrores((e) => { const { sitio: _sitio, ...resto } = e; return resto; });
  }

  function enviar(evento: FormEvent) {
    evento.preventDefault();
    setCreada(null);
    const r = proponerAccion({
      actor_id: actorId,
      nombre,
      tipo,
      sector,
      lat: punto?.lat ?? Number.NaN,
      lon: punto?.lon ?? Number.NaN,
      hectareas: hectareas === '' ? Number.NaN : Number(hectareas),
      descripcion,
      comunidad_coparticipante: comunidad,
      requerimientos_cumplidos: cumplidos,
      plan: plan ? { accion_plan: plan.accion_plan, prioridad_plan: plan.prioridad_plan, plan_aproximado: plan.plan_aproximado } : undefined,
    });
    if (!r.ok) {
      const errs = { ...r.errores };
      if (errs.sitio) errs.sitio = 'Marque el sitio en el mapa.';
      setErrores(errs);
      formulario.current?.querySelector<HTMLElement>(`[data-campo="${Object.keys(errs)[0]}"]`)?.focus();
      return;
    }
    setErrores({});
    setCreada(r.accion);
    setNombre(''); setCumplidos([]); setHectareas(''); setComunidad(''); setDescripcion(''); setPunto(null);
  }

  const error = (clave: string) => errores[clave] ? <p id={`error-${clave}`} className="mt-1 text-sm text-alta-texto">{errores[clave]}</p> : null;
  const describe = (clave: string) => (errores[clave] ? `error-${clave}` : undefined);

  return (
    <div className="grid gap-10 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
      <section aria-labelledby="titulo-sitio">
        <h2 id="titulo-sitio" className="rotulo border-b border-white pb-2">Proponer una acción: marque el sitio en el mapa</h2>
        <div className="mt-4">
          <MapaPlataforma zonas={zonas} acciones={acciones} modo="marcar" punto={punto} alMarcar={marcar} alCargarPrioridades={setCapa} alto="min(62vh, 560px)" />
        </div>
        <div data-campo="sitio" tabIndex={-1} className="mt-4 border border-linea-suave bg-superficie p-4 text-sm" aria-live="polite">
          {!punto ? (
            <p className="text-suave">Sin sitio marcado. Al marcarlo, la acción hereda la acción y la prioridad del plan de manejo en ese punto.</p>
          ) : (
            <dl className="grid gap-x-6 gap-y-2 sm:grid-cols-2">
              <div><dt className="etiqueta-campo text-suave">Sitio</dt><dd><MapPin className="mr-1 inline size-3.5 text-dorado-300" aria-hidden="true" />{punto.lat.toFixed(5)}, {punto.lon.toFixed(5)}</dd></div>
              <div>
                <dt className="etiqueta-campo text-suave">Sector</dt>
                <dd>
                  {ubicacion?.dentro ? SECTORES[sector].largo : (
                    <>
                      Fuera de los sectores{Number.isFinite(ubicacion?.distancia_m) ? ` (a ${Math.round(ubicacion!.distancia_m).toLocaleString('es-CO')} m)` : ''}. Elija el sector:
                      <select value={sectorElegido} onChange={(e) => setSectorElegido(e.target.value as SectorId)} className={campo} aria-label="Sector de la acción">
                        {Object.entries(SECTORES).map(([k, v]) => <option key={k} value={k} className="bg-cra-900">{v.largo}</option>)}
                      </select>
                    </>
                  )}
                </dd>
              </div>
              <div><dt className="etiqueta-campo text-suave">Acción del plan de manejo heredada</dt><dd className="flex items-center gap-2"><span aria-hidden="true" className="inline-block size-3" style={{ background: plan ? ACCIONES_PLAN[plan.accion_plan].color : undefined }} />{plan ? ACCIONES_PLAN[plan.accion_plan].etiqueta : '—'}</dd></div>
              <div><dt className="etiqueta-campo text-suave">Prioridad heredada</dt><dd>{plan?.prioridad_plan ? NIVEL[plan.prioridad_plan] : 'Sin prioridad asignada'}</dd></div>
              {plan && !plan.plan_aproximado && (plan.unidad || plan.escenario) && (
                <p className="text-xs text-tenue sm:col-span-2">Unidad hidrográfica: {plan.unidad ?? '—'} · {plan.escenario ?? ''}{plan.figura ? ` · ${plan.figura}` : ''}. Fuente: capa «Prioridades de conservación» de la C.R.A.</p>
              )}
              {plan?.plan_aproximado && <p className="text-xs text-media-texto sm:col-span-2">Plan aproximado por sector: la capa de prioridades de la C.R.A. no cargó.</p>}
              {plan?.accion_plan === 'fuera_zonificacion' && <p className="text-xs text-media-texto sm:col-span-2">El punto queda fuera de la zonificación de la Corporación; la revisión lo tendrá en cuenta.</p>}
            </dl>
          )}
          {error('sitio')}
        </div>
      </section>

      <form ref={formulario} onSubmit={enviar} noValidate aria-labelledby="titulo-datos" className="grid content-start gap-5">
        <h2 id="titulo-datos" className="rotulo border-b border-white pb-2">Datos de la acción</h2>
        <label className="block">
          <span className="etiqueta-campo">Actor que propone</span>
          <select data-campo="actor_id" value={actorId} onChange={(e) => setActorId(e.target.value)} className={campo} aria-invalid={!!errores.actor_id} aria-describedby={describe('actor_id')}>
            {actores.map((a) => <option key={a.id} value={a.id} className="bg-cra-900">{a.nombre}</option>)}
          </select>
          <a href="/plataforma/registro" className="mt-1 inline-flex min-h-9 items-center text-xs text-dorado-300 hover:underline">¿No aparece? Regístrese como actor</a>
          {error('actor_id')}
        </label>
        <label className="block">
          <span className="etiqueta-campo">Tipo de acción</span>
          <select data-campo="tipo" value={tipo} onChange={(e) => { setTipo(e.target.value as TipoAccion); setCumplidos([]); }} className={campo}>
            {Object.entries(TIPOS_ACCION).map(([k, v]) => <option key={k} value={k} className="bg-cra-900">{v.etiqueta}</option>)}
          </select>
        </label>
        <label className="block">
          <span className="etiqueta-campo">Nombre corto</span>
          <input data-campo="nombre" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Ej.: Siembra de mangle rojo en el caño" className={campo} aria-invalid={!!errores.nombre} aria-describedby={describe('nombre')} />
          {error('nombre')}
        </label>
        <fieldset>
          <legend className="etiqueta-campo">Requerimientos para este tipo de acción</legend>
          <ul className="mt-2 grid gap-1">
            {REQUERIMIENTOS_POR_TIPO[tipo].map((texto, i) => {
              const id = `${tipo}-${i + 1}`;
              const marcado = cumplidos.includes(id);
              return (
                <li key={id}>
                  <label className="flex min-h-11 items-start gap-3 py-1 text-sm">
                    <input type="checkbox" className="mt-0.5 size-5 shrink-0 accent-dorado-500" checked={marcado} onChange={() => setCumplidos((c) => (marcado ? c.filter((x) => x !== id) : [...c, id]))} />
                    {texto}
                  </label>
                </li>
              );
            })}
          </ul>
          <p className="mt-1 text-xs text-tenue">Marque los requerimientos que ya cumple; los demás quedan como pendientes de la propuesta y la Corporación los verá en la revisión.{tipo !== 'siembra' && ` Lista ${NOTA_REQUERIMIENTOS_PROPUESTOS}.`}</p>
        </fieldset>
        <div className="grid gap-5 sm:grid-cols-2">
          <label className="block">
            <span className="etiqueta-campo">Hectáreas previstas</span>
            <input data-campo="hectareas" type="number" inputMode="decimal" min={0} step="0.1" value={hectareas} onChange={(e) => setHectareas(e.target.value)} className={campo} aria-invalid={!!errores.hectareas} aria-describedby={describe('hectareas')} />
            {error('hectareas')}
          </label>
          <label className="block">
            <span className="etiqueta-campo">Comunidad coparticipante</span>
            <input value={comunidad} onChange={(e) => setComunidad(e.target.value)} placeholder="Ej.: pescadores de la ciénaga" className={campo} />
          </label>
        </div>
        <label className="block">
          <span className="etiqueta-campo">Descripción breve</span>
          <textarea value={descripcion} onChange={(e) => setDescripcion(e.target.value)} rows={3} className={`${campo} py-2`} />
        </label>
        <div>
          <button type="submit" className="inline-flex min-h-11 items-center justify-center gap-2 bg-dorado-500 px-6 text-xs font-black uppercase tracking-[0.08em] text-cra-950 hover:bg-dorado-300"><Send className="size-4" aria-hidden="true" />Enviar propuesta</button>
          <p className="mt-2 text-xs text-tenue">La propuesta se envía con la lista de requerimientos del tipo de acción; la Corporación la revisa punto por punto.</p>
        </div>
        <div aria-live="polite">
          {creada && (
            <p className="border-l-4 border-dorado-300 bg-white/5 p-3 text-sm">
              Propuesta «{creada.nombre}» enviada (demostración, guardada en este navegador). La Corporación la revisará punto por punto.{' '}
              <a className="font-bold text-dorado-300 underline" href={`/plataforma/seguimiento?accion=${creada.id}`}>Ver su seguimiento</a>
            </p>
          )}
        </div>
      </form>
    </div>
  );
}
