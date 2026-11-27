// Registro de actor (pestaña REGISTRO DE ACTOR de la maqueta de la C.R.A.).
import { useRef, useState, type FormEvent } from 'react';
import { BadgeCheck, Clock } from 'lucide-react';
import type { Actor, Papel, SectorId, TipoActor } from '../../types/plataforma';
import { registrarActor, useActores } from '../../lib/plataforma/estado';
import { PAPELES, SECTORES, TIPOS_ACTOR } from '../../lib/plataforma/catalogos';
import { cn } from '../../lib/utils';

interface Props { actores: Actor[] }

const campo = 'mt-1 w-full min-h-11 border-0 border-b border-white/60 bg-white/5 px-3 text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none aria-[invalid=true]:border-alta';

export default function RegistroActor({ actores: iniciales }: Props) {
  const actores = useActores(iniciales);
  const [tipo, setTipo] = useState<TipoActor>('comunidad');
  const [nombre, setNombre] = useState('');
  const [correo, setCorreo] = useState('');
  const [sector, setSector] = useState<SectorId>('mallorquin');
  const [papeles, setPapeles] = useState<Papel[]>([]);
  const [acepta, setAcepta] = useState(false);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [exito, setExito] = useState<string | null>(null);
  const formulario = useRef<HTMLFormElement>(null);

  function enviar(evento: FormEvent) {
    evento.preventDefault();
    setExito(null);
    const r = registrarActor({ tipo, nombre, correo, sector, papeles, acepta_datos: acepta });
    if (!r.ok) {
      setErrores(r.errores);
      const primero = Object.keys(r.errores)[0];
      formulario.current?.querySelector<HTMLElement>(`[data-campo="${primero}"]`)?.focus();
      return;
    }
    setErrores({});
    setNombre(''); setCorreo(''); setPapeles([]); setAcepta(false);
    setExito(`«${r.actor.nombre}» quedó registrado (demostración, guardado en este navegador). En la versión real se verifica el correo y, para entidades, el acto que faculta a quien registra.`);
  }

  const error = (clave: string) => errores[clave] ? <p id={`error-${clave}`} className="mt-1 text-sm text-alta-texto">{errores[clave]}</p> : null;
  const describe = (clave: string) => (errores[clave] ? `error-${clave}` : undefined);

  return (
    <div className="grid gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
      <form ref={formulario} onSubmit={enviar} noValidate aria-labelledby="titulo-registro" className="grid content-start gap-5">
        <h2 id="titulo-registro" className="rotulo border-b border-white pb-2">Registro de actor</h2>
        <label className="block">
          <span className="etiqueta-campo">Tipo de actor</span>
          <select data-campo="tipo" value={tipo} onChange={(e) => setTipo(e.target.value as TipoActor)} className={campo} aria-invalid={!!errores.tipo} aria-describedby={describe('tipo')}>
            {Object.entries(TIPOS_ACTOR).map(([k, v]) => <option key={k} value={k} className="bg-cra-900">{v.etiqueta}</option>)}
          </select>
          {error('tipo')}
        </label>
        <label className="block">
          <span className="etiqueta-campo">Nombre de la organización o persona</span>
          <input data-campo="nombre" value={nombre} onChange={(e) => setNombre(e.target.value)} autoComplete="organization" className={campo} aria-invalid={!!errores.nombre} aria-describedby={describe('nombre')} />
          {error('nombre')}
        </label>
        <label className="block">
          <span className="etiqueta-campo">Correo de contacto</span>
          <input data-campo="correo" type="email" inputMode="email" value={correo} onChange={(e) => setCorreo(e.target.value)} autoComplete="email" className={campo} aria-invalid={!!errores.correo} aria-describedby={describe('correo') ?? 'ayuda-correo'} />
          <p id="ayuda-correo" className="mt-1 text-xs text-tenue">No se muestra en la plataforma pública.</p>
          {error('correo')}
        </label>
        <label className="block">
          <span className="etiqueta-campo">Sector de interés</span>
          <select data-campo="sector" value={sector} onChange={(e) => setSector(e.target.value as SectorId)} className={campo} aria-invalid={!!errores.sector} aria-describedby={describe('sector')}>
            {Object.entries(SECTORES).map(([k, v]) => <option key={k} value={k} className="bg-cra-900">{v.largo}</option>)}
          </select>
          {error('sector')}
        </label>
        <fieldset data-campo="papeles" tabIndex={-1} aria-describedby={describe('papeles')}>
          <legend className="etiqueta-campo">Papel que quiere cumplir</legend>
          <div className="mt-2 grid gap-1 sm:grid-cols-2">
            {Object.entries(PAPELES).map(([k, v]) => {
              const marcado = papeles.includes(k as Papel);
              return (
                <label key={k} className="flex min-h-11 items-center gap-3 text-sm">
                  <input type="checkbox" className="size-5 accent-dorado-500" checked={marcado} onChange={() => setPapeles((p) => (marcado ? p.filter((x) => x !== k) : [...p, k as Papel]))} />
                  {v.etiqueta}
                </label>
              );
            })}
          </div>
          {error('papeles')}
        </fieldset>
        <label className="flex items-start gap-3 text-sm">
          <input data-campo="acepta_datos" type="checkbox" className="mt-1 size-5 shrink-0 accent-dorado-500" checked={acepta} onChange={(e) => setAcepta(e.target.checked)} aria-invalid={!!errores.acepta_datos} aria-describedby={describe('acepta_datos')} />
          <span>Acepto el tratamiento de mis datos según la Ley 1581 de 2012 (texto por definir con la Corporación).</span>
        </label>
        {error('acepta_datos')}
        <div>
          <button type="submit" className="inline-flex min-h-11 items-center justify-center bg-dorado-500 px-6 text-xs font-black uppercase tracking-[0.08em] text-cra-950 hover:bg-dorado-300">Registrar</button>
        </div>
        <div aria-live="polite">{exito && <p className="border-l-4 border-dorado-300 bg-white/5 p-3 text-sm">{exito}</p>}</div>
      </form>

      <section aria-labelledby="titulo-actores">
        <h2 id="titulo-actores" className="rotulo border-b border-white pb-2">Actores registrados</h2>
        <div className="overflow-x-auto">
          <table className="mt-2 w-full min-w-[460px] text-left text-[13px]">
            <thead>
              <tr className="border-b border-white text-[11px] font-bold uppercase tracking-[0.06em] text-suave">
                <th scope="col" className="py-2 pr-3">Actor</th><th scope="col" className="py-2 pr-3">Tipo</th><th scope="col" className="py-2 pr-3">Sector</th><th scope="col" className="py-2">Verificación</th>
              </tr>
            </thead>
            <tbody>
              {actores.map((a) => (
                <tr key={a.id} className="border-b border-white/25 align-top">
                  <td className="py-2 pr-3 font-bold">{a.nombre}</td>
                  <td className="py-2 pr-3 text-suave">{TIPOS_ACTOR[a.tipo].etiqueta}</td>
                  <td className="py-2 pr-3 text-suave">{SECTORES[a.sector].nombre}</td>
                  <td className="py-2">
                    <span className={cn('inline-flex items-center gap-1 whitespace-nowrap px-2 py-0.5 text-[10px] font-black tracking-[0.1em]', a.verificado ? 'border border-plan-preservacion text-emerald-200' : 'border border-white/50 text-suave')}>
                      {a.verificado ? <BadgeCheck className="size-3" aria-hidden="true" /> : <Clock className="size-3" aria-hidden="true" />}
                      {a.verificado ? 'VERIFICADO' : 'POR VERIFICAR'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-xs text-tenue">En la versión real el registro exige verificación del correo y, para entidades, el acto que faculta a quien registra. Los correos nunca se publican.</p>
      </section>
    </div>
  );
}
