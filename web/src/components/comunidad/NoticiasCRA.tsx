// «La C.R.A. en el manglar»: las noticias más recientes de crautonoma.gov.co sobre el
// manglar y la ciénaga de Mallorquín, leídas en vivo cada vez que se abre la portada.
import { useEffect, useState } from 'react';
import { ArrowUpRight, Newspaper } from 'lucide-react';
import { formatoFechaCRA, obtenerNoticiasCRA, type NoticiaCRA } from '../../lib/craApi';

const SALA_DE_PRENSA = 'https://www.crautonoma.gov.co/prensa/noticias';

/** limite: cuántas noticias mostrar (la portada usa las 3 últimas). */
export default function NoticiasCRA({ limite = 6 }: { limite?: number }) {
  const [noticias, setNoticias] = useState<NoticiaCRA[] | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let activo = true;
    obtenerNoticiasCRA(limite).then((lista) => { if (activo) setNoticias(lista); }).catch(() => { if (activo) setError(true); });
    return () => { activo = false; };
  }, [limite]);

  return (
    <div aria-labelledby="titulo-noticias-cra">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-dorado-300">Desde la C.R.A.</p>
          <h3 id="titulo-noticias-cra" className="mt-1 font-[Figtree,sans-serif] text-2xl font-extrabold leading-tight">La C.R.A. en el manglar</h3>
          <p className="mt-1 max-w-[60ch] text-sm text-suave">Lo último que publica la Corporación sobre el manglar y la ciénaga de Mallorquín, tomado en vivo de su sitio.</p>
        </div>
        <a href={SALA_DE_PRENSA} target="_blank" rel="noopener noreferrer" className="inline-flex min-h-11 items-center gap-1 text-sm font-semibold text-dorado-300 underline underline-offset-4">
          Todas las noticias<ArrowUpRight size={16} aria-hidden="true" />
        </a>
      </div>

      {!noticias && !error && (
        <ul aria-busy="true" aria-label="Cargando noticias de la C.R.A." className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: Math.min(3, limite) }, (_, i) => i).map((i) => <li key={i} className="h-72 animate-pulse rounded-3xl bg-white/5 ring-1 ring-linea motion-reduce:animate-none" />)}
        </ul>
      )}

      {error && (
        <p role="status" className="mt-5 rounded-3xl bg-white/5 p-5 text-sm text-suave ring-1 ring-linea">
          No se pudieron leer las noticias de la C.R.A. en este momento. Puedes verlas en <a href={SALA_DE_PRENSA} target="_blank" rel="noopener noreferrer" className="font-semibold text-dorado-300 underline underline-offset-4">su sala de prensa</a>.
        </p>
      )}

      {noticias && noticias.length === 0 && (
        <p role="status" className="mt-5 rounded-3xl bg-white/5 p-5 text-sm text-suave ring-1 ring-linea">La C.R.A. no tiene noticias recientes sobre el manglar.</p>
      )}

      {noticias && noticias.length > 0 && (
        <ul className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {noticias.map((n, i) => (
            // En el teléfono bastan tres; el resto está en «Todas las noticias».
            <li key={n.id} className={i >= 3 ? 'hidden min-w-0 sm:block' : 'min-w-0'}>
              <a href={n.enlace} target="_blank" rel="noopener noreferrer"
                className="group flex h-full flex-col overflow-hidden rounded-3xl bg-white/5 ring-1 ring-linea transition-colors hover:bg-white/10 focus-visible:bg-white/10">
                <div className="aspect-[16/10] overflow-hidden bg-white/5">
                  {n.imagen
                    ? <img src={n.imagen} alt="" loading="lazy" decoding="async" referrerPolicy="no-referrer" className="size-full object-cover transition-transform duration-300 group-hover:scale-[1.03] motion-reduce:transition-none" />
                    : <div className="grid size-full place-items-center text-suave"><Newspaper size={32} aria-hidden="true" /></div>}
                </div>
                <div className="flex flex-1 flex-col gap-2 p-5">
                  <time dateTime={n.fecha} className="text-xs font-semibold text-dorado-300">{formatoFechaCRA(n.fecha)}</time>
                  <h4 className="text-base font-bold leading-snug text-texto">{n.titulo}</h4>
                  <p className="line-clamp-3 text-sm text-suave">{n.resumen}</p>
                  <span className="mt-auto inline-flex items-center gap-1 pt-2 text-xs font-semibold text-texto">Leer en crautonoma.gov.co<ArrowUpRight size={14} aria-hidden="true" /></span>
                </div>
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
