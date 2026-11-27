// Plantillas prellenadas con los datos del sitio (pestaña PROYECTOS de la maqueta de la C.R.A.).
import { Fragment, useMemo, useState } from 'react';
import { Copy, Download, Printer } from 'lucide-react';
import type { Accion, Actor } from '../../types/plataforma';
import { useAcciones, useActores } from '../../lib/plataforma/estado';
import { SECTORES } from '../../lib/plataforma/catalogos';
import { notaConceptual, plantillaMGA, textoPlano } from '../../lib/plataforma/proyectos';
import { descargarArchivo } from '../../lib/exportar';
import { cn } from '../../lib/utils';

interface Props { acciones: Accion[]; actores: Actor[] }
type Tipo = 'mga' | 'nota';

// Resalta lo que va entre corchetes: lo completa quien formula, nunca se inventa.
function ConHuecos({ texto }: { texto: string }) {
  const partes = texto.split(/(\[[^\]]+\])/g);
  return (
    <>
      {partes.map((p, i) => (p.startsWith('[') && p.endsWith(']')
        ? <mark key={i} className="hueco bg-dorado-500/20 px-0.5 text-dorado-300">{p}</mark>
        : <Fragment key={i}>{p}</Fragment>))}
    </>
  );
}

const nombreArchivo = (texto: string) => texto.toLocaleLowerCase('es-CO').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export default function ProyectosPlantillas({ acciones: accionesIniciales, actores: actoresIniciales }: Props) {
  const acciones = useAcciones(accionesIniciales).filter((a) => a.canal !== 'whatsapp' && a.sector !== null && a.accion_plan !== null);
  const actores = useActores(actoresIniciales);
  const [accionId, setAccionId] = useState(acciones[0]?.id ?? '');
  const [tipo, setTipo] = useState<Tipo>('mga');
  const [aviso, setAviso] = useState<string | null>(null);

  const accion = acciones.find((a) => a.id === accionId) ?? acciones[0];
  const actor = accion ? actores.find((a) => a.id === accion.actor_id) : undefined;
  const plantilla = useMemo(() => {
    if (!accion || !accion.sector) return null;
    const proponente = actor ?? { id: '', nombre: '[actor proponente]', tipo: 'ciudadano', correo: '', sector: accion.sector, papeles: [], verificado: false, acepta_datos: true, creado_en: '' } satisfies Actor;
    return tipo === 'mga' ? plantillaMGA(accion, proponente, accion.sector) : notaConceptual(accion, proponente, accion.sector);
  }, [accion, actor, tipo]);

  if (!accion || !plantilla) return <p className="text-suave">No hay acciones registradas para formular un proyecto. <a href="/plataforma/proponer" className="text-dorado-300 underline">Proponga una acción</a>.</p>;

  const encabezado = tipo === 'mga' ? 'PROYECTO (Metodología General Ajustada) — borrador prellenado con los datos del sitio' : 'NOTA CONCEPTUAL DE COOPERACIÓN — borrador prellenado con los datos del sitio';
  const texto = `${encabezado}\n\n${textoPlano(plantilla)}`;
  const avisar = (t: string) => { setAviso(t); setTimeout(() => setAviso(null), 2500); };
  const boton = 'inline-flex min-h-11 items-center gap-2 border border-white/60 px-4 text-xs font-black uppercase tracking-[0.06em] hover:border-dorado-300 hover:text-dorado-300';

  return (
    <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
      <style>{`@media print {
        body * { visibility: hidden !important; }
        #documento-proyecto, #documento-proyecto * { visibility: visible !important; }
        #documento-proyecto { position: absolute; inset: 0; background: #fff !important; color: #000 !important; border: 0 !important; padding: 0 !important; }
        #documento-proyecto * { color: #000 !important; background: transparent !important; }
        #documento-proyecto .hueco { text-decoration: underline; }
      }`}</style>

      <aside className="grid content-start gap-5 print:hidden">
        <h2 className="rotulo border-b border-white pb-2">Plantillas prellenadas con los datos del sitio</h2>
        <label className="block">
          <span className="etiqueta-campo">Acción</span>
          <select value={accion.id} onChange={(e) => setAccionId(e.target.value)} className="mt-1 min-h-11 w-full border-0 border-b border-white/60 bg-white/5 px-3 text-texto focus:border-dorado-300 focus:outline-none">
            {acciones.map((a) => <option key={a.id} value={a.id} className="bg-cra-900">{a.nombre} · {a.sector ? SECTORES[a.sector].nombre : 'Sin sector confirmado'}</option>)}
          </select>
        </label>
        <fieldset>
          <legend className="etiqueta-campo">Plantilla</legend>
          <div className="mt-2 grid gap-2">
            {([['mga', 'Metodología General Ajustada'], ['nota', 'Nota conceptual de cooperación']] as const).map(([k, v]) => (
              <label key={k} className={cn('flex min-h-11 cursor-pointer items-center gap-3 border px-3 text-sm', tipo === k ? 'border-dorado-300 text-texto' : 'border-white/25 text-suave hover:text-texto')}>
                <input type="radio" name="plantilla" className="size-4 accent-dorado-500" checked={tipo === k} onChange={() => setTipo(k)} />{v}
              </label>
            ))}
          </div>
        </fieldset>
        <div className="flex flex-wrap gap-2">
          <button type="button" className={boton} onClick={() => descargarArchivo(texto, `${tipo === 'mga' ? 'proyecto-mga' : 'nota-conceptual'}-${nombreArchivo(accion.nombre)}.txt`, 'text/plain;charset=utf-8')}><Download className="size-4" aria-hidden="true" />Descargar .txt</button>
          <button type="button" className={boton} onClick={async () => { try { await navigator.clipboard.writeText(texto); avisar('Texto copiado.'); } catch { avisar('El navegador no permitió copiar; use Descargar.'); } }}><Copy className="size-4" aria-hidden="true" />Copiar texto</button>
          <button type="button" className={boton} onClick={() => window.print()}><Printer className="size-4" aria-hidden="true" />Imprimir</button>
        </div>
        <p aria-live="polite" className="min-h-5 text-xs text-dorado-300">{aviso}</p>
        <div className="border border-linea-suave bg-white/5 p-4 text-sm text-suave">
          <p className="rotulo text-dorado-300">Qué se prellena</p>
          <p className="mt-2">Nombre y ubicación, hectáreas, sector, acción y prioridad del plan de manejo, cifras del workflow para el sitio (manglar probable, hectáreas por revisar, dosel seco, riesgo, carbono por hectárea) y las fuentes. <mark className="bg-dorado-500/20 px-0.5 text-dorado-300">[Lo que va entre corchetes]</mark> lo completa el formulador: la plataforma no inventa cifras.</p>
          <p className="mt-2 text-xs text-tenue">La cadena de valor y los indicadores siguen la estructura del Departamento Nacional de Planeación para la Metodología General Ajustada; la nota conceptual sigue el formato común de convocatorias de cooperación (contexto, problema, objetivo, resultados, presupuesto indicativo).</p>
        </div>
      </aside>

      <article id="documento-proyecto" className="border border-linea-suave bg-superficie p-6 sm:p-8" aria-labelledby="titulo-documento">
        <p className="rotulo text-dorado-300">{encabezado}</p>
        <h2 id="titulo-documento" className="titular mt-3 text-2xl">{plantilla.titulo}</h2>
        <div className="mt-6 grid gap-5">
          {plantilla.secciones.map((s) => (
            <section key={s.titulo}>
              <h3 className="rotulo border-b border-white/25 pb-1 text-texto">{s.titulo}</h3>
              <p className="mt-2 whitespace-pre-line text-sm leading-relaxed text-suave"><ConHuecos texto={s.texto} /></p>
            </section>
          ))}
        </div>
      </article>
    </div>
  );
}
