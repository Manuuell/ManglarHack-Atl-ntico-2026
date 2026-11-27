import { useId, useState } from 'react';
import type { Banda, Barra, Bloque, GrupoSeries } from '../../lib/workflow';
import { CAPAS_METODOLOGIA, NOTA_CAPAS_VIVAS, PASOS_METODOLOGIA } from '../../lib/workflow';

const num = (v: number, decimales = 0) => v.toLocaleString('es-CO', { minimumFractionDigits: decimales, maximumFractionDigits: decimales });
const conSigno = (v: number, decimales: number) => `${v < 0 ? '−' : ''}${num(Math.abs(v), decimales)}`;

/** Convierte 2016, «2016Q3» o «2016-07» en un año decimal para el eje horizontal. */
function aAnio(x: string | number): number {
  if (typeof x === 'number') return x + 0.5;
  const t = /^(\d{4})Q([1-4])$/.exec(x);
  if (t) return Number(t[1]) + (Number(t[2]) - 1) / 4 + 0.125;
  const m = /^(\d{4})-(\d{2})$/.exec(x);
  if (m) return Number(m[1]) + (Number(m[2]) - 1) / 12 + 1 / 24;
  return Number.NaN;
}
const etiquetaPeriodo = (x: string | number) => typeof x === 'number' ? String(x) : x.replace(/Q([1-4])$/, ' · trimestre $1');

function Subtitulo({ children }: { children: string }) {
  return <h3 className="rotulo text-dorado-300">{children}</h3>;
}
function Nota({ children }: { children?: string }) {
  return children ? <p className="text-xs leading-relaxed text-tenue">{children}</p> : null;
}

function Cifras({ items }: Extract<Bloque, { tipo: 'cifras' }>) {
  return <dl className="grid gap-x-4 gap-y-5 sm:grid-cols-2">
    {items.map(c => <div key={c.valor + c.texto} className="border-t border-linea pt-3">
      <dt className="sr-only">{c.texto}</dt>
      <dd>
        <span className="titular block text-3xl">{c.valor}{c.unidad && <span className="ml-1.5 text-sm font-semibold text-dorado-300">{c.unidad}</span>}</span>
        <span aria-hidden="true" className="mt-1.5 block text-sm leading-snug text-suave">{c.texto}</span>
      </dd>
    </div>)}
  </dl>;
}

function Barras({ titulo, items, nota }: Extract<Bloque, { tipo: 'barras' }>) {
  const maximo = Math.max(...items.map(i => Math.abs(i.valor))) || 1;
  const hayNegativos = items.some(i => i.valor < 0);
  const color = (b: Barra) => b.valor < 0 ? 'bg-capa-riesgo' : hayNegativos ? 'bg-capa-dosel' : 'bg-dorado-500';
  return <section className="space-y-3">
    <Subtitulo>{titulo}</Subtitulo>
    <ul className="space-y-1">
      {items.map((b, i) => {
        const fila = <>
          <span className="flex items-baseline justify-between gap-3">
            <span className="min-w-0 text-sm"><span aria-hidden="true" className="mr-2 text-xs tabular-nums text-tenue">{String(i + 1).padStart(2, '0')}</span>{b.etiqueta}</span>
            <span className="shrink-0 text-sm font-semibold tabular-nums">{b.texto}</span>
          </span>
          <span aria-hidden="true" className="mt-1.5 block h-1.5 rounded-full bg-white/10">
            <span className={`block h-full rounded-full ${color(b)}`} style={{ width: `${Math.max(1.5, Math.abs(b.valor) / maximo * 100)}%` }} />
          </span>
        </>;
        return <li key={`${b.etiqueta}-${i}`}>
          {b.explicacion
            ? <details className="group rounded-sm open:bg-white/5">
              <summary className="block min-h-11 cursor-pointer list-none rounded-sm px-2 py-2 hover:bg-white/5 [&::-webkit-details-marker]:hidden">
                {fila}
                <span className="mt-1 block text-xs text-dorado-300"><span aria-hidden="true" className="inline-block transition-transform group-open:rotate-90">▸</span> Explicar</span>
              </summary>
              <p className="px-2 pb-3 text-sm leading-relaxed text-suave">{b.explicacion}</p>
            </details>
            : <div className="px-2 py-2">{fila}</div>}
        </li>;
      })}
    </ul>
    <Nota>{nota}</Nota>
  </section>;
}

function Tabla({ titulo, columnas, filas, decimales = 0, colores, total, nota }: Extract<Bloque, { tipo: 'tabla' }>) {
  const apiladas = colores ? columnas.slice(0, total ? -1 : undefined) : [];
  const sumas = filas.map(f => apiladas.reduce((a, _, i) => a + (f.valores[i] ?? 0), 0));
  const maximo = Math.max(...sumas) || 1;
  return <section className="space-y-3">
    <Subtitulo>{titulo}</Subtitulo>
    {colores && <div aria-hidden="true" className="space-y-2.5">
      <ul className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-suave">
        {apiladas.map((c, i) => <li key={c} className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-full" style={{ background: colores[i] }} />{c}</li>)}
      </ul>
      {filas.map((f, j) => <div key={f.etiqueta} className="grid grid-cols-[6.5rem_1fr] items-center gap-2 text-xs">
        <span className="truncate text-suave">{f.etiqueta}</span>
        <span className="flex h-3 overflow-hidden rounded-full bg-white/10" style={{ width: `${sumas[j]! / maximo * 100}%` }}>
          {apiladas.map((c, i) => <span key={c} style={{ width: `${(f.valores[i] ?? 0) / (sumas[j] || 1) * 100}%`, background: colores[i] }} />)}
        </span>
      </div>)}
    </div>}
    <div className="overflow-x-auto">
      <table className="w-full min-w-[20rem] text-sm" lang="es">
        <caption className="sr-only">{titulo}</caption>
        <thead><tr className="border-b border-linea text-xs text-suave">
          <th scope="col" className="py-2 pr-2 text-left font-semibold">{filas.length === 1 ? 'Componente' : 'Categoría'}</th>
          {columnas.map(c => <th key={c} scope="col" className="px-1.5 py-2 text-right font-semibold [overflow-wrap:normal] [hyphens:auto]">{c}</th>)}
        </tr></thead>
        <tbody>{filas.map(f => <tr key={f.etiqueta} className="border-b border-linea-suave">
          <th scope="row" className="whitespace-nowrap py-2 pr-2 text-left font-normal">{f.etiqueta}</th>
          {f.valores.map((v, i) => <td key={i} className={`whitespace-nowrap px-1.5 py-2 text-right tabular-nums ${total && i === f.valores.length - 1 ? 'font-semibold' : ''}`}>{v === null ? '—' : num(v, decimales)}</td>)}
        </tr>)}</tbody>
      </table>
    </div>
    <Nota>{nota}</Nota>
  </section>;
}

const ANCHO = 320, ALTO = 170, MI = 38, MD = 8, MS = 8, MB = 22;

function GraficaSerie({ titulo, unidad, decimales, desdeCero, grupos, bandas, nota }: Extract<Bloque, { tipo: 'serie' }>) {
  const id = useId();
  const [grupoIdx, setGrupoIdx] = useState(0);
  const grupo: GrupoSeries = grupos[grupoIdx] ?? grupos[0]!;
  const puntos = grupo.series.flatMap(s => s.puntos.map(([x, y]) => ({ x: aAnio(x), y })));
  const xs = puntos.map(p => p.x);
  const ys = puntos.flatMap(p => p.y === null ? [] : [p.y]);
  const x0 = Math.floor(Math.min(...xs)), x1 = Math.ceil(Math.max(...xs));
  let y0 = desdeCero ? Math.min(0, ...ys) : Math.min(...ys), y1 = Math.max(...ys);
  if (!desdeCero) { const margen = (y1 - y0) * 0.08 || 1; y0 -= margen; y1 += margen; } else y1 *= 1.06;
  const px = (x: number) => MI + (x - x0) / (x1 - x0 || 1) * (ANCHO - MI - MD);
  const py = (y: number) => MS + (1 - (y - y0) / (y1 - y0 || 1)) * (ALTO - MS - MB);
  const ticksY = [y0, (y0 + y1) / 2, y1];
  const pasoX = x1 - x0 > 6 ? 2 : 1;
  const ticksX = Array.from({ length: Math.floor((x1 - x0) / pasoX) + 1 }, (_, i) => x0 + i * pasoX);
  const trazo = (pts: readonly (readonly [string | number, number | null])[]) => {
    let d = ''; let abierto = false;
    for (const [x, y] of pts) {
      if (y === null) { abierto = false; continue; }
      d += `${abierto ? 'L' : 'M'}${px(aAnio(x)).toFixed(1)},${py(y).toFixed(1)}`; abierto = true;
    }
    return d;
  };
  const bandasVisibles = (bandas ?? []).map(b => ({ ...b, a: Math.max(x0, aAnio(b.desde)), z: Math.min(x1, b.hasta ? aAnio(b.hasta) : x1) })).filter(b => b.z > b.a);
  const resumen = grupo.series.map(s => {
    const validos = s.puntos.filter((p): p is readonly [string | number, number] => p[1] !== null);
    if (!validos.length) return `${s.nombre}: sin datos`;
    const vals = validos.map(p => p[1]);
    return `${s.nombre}: de ${conSigno(validos[0]![1], decimales)} en ${etiquetaPeriodo(validos[0]![0])} a ${conSigno(validos.at(-1)![1], decimales)} en ${etiquetaPeriodo(validos.at(-1)![0])}; mínimo ${conSigno(Math.min(...vals), decimales)}, máximo ${conSigno(Math.max(...vals), decimales)}`;
  }).join('. ');
  const filas = [...new Set(grupo.series.flatMap(s => s.puntos.map(p => p[0])))].sort((a, b) => aAnio(a) - aAnio(b));
  const valor = (s: GrupoSeries['series'][number], x: string | number) => s.puntos.find(p => p[0] === x)?.[1];

  return <section className="space-y-3">
    <Subtitulo>{titulo}</Subtitulo>
    {grupos.length > 1 && <label className="flex flex-wrap items-center gap-2 text-sm">
      <span className="text-suave">Ciénaga</span>
      <select value={grupoIdx} onChange={e => setGrupoIdx(Number(e.target.value))} className="min-h-11 rounded-full border border-linea bg-cra-900 px-4 text-texto">
        {grupos.map((g, i) => <option key={g.nombre} value={i}>{g.nombre}</option>)}
      </select>
    </label>}
    <figure className="space-y-2">
      <svg viewBox={`0 0 ${ANCHO} ${ALTO}`} role="img" aria-labelledby={`${id}-t`} className="h-auto w-full overflow-visible">
        <title id={`${id}-t`}>{`${titulo}${grupos.length > 1 ? ` · ${grupo.nombre}` : ''} (${unidad}). ${resumen}.`}</title>
        {bandasVisibles.map(b => <rect key={b.etiqueta} x={px(b.a)} width={px(b.z) - px(b.a)} y={MS} height={ALTO - MS - MB} className={b.tipo === 'nino' ? 'fill-capa-riesgo/15' : 'fill-capa-agua/15'} />)}
        {ticksY.map(t => <g key={t}>
          <line x1={MI} x2={ANCHO - MD} y1={py(t)} y2={py(t)} className="stroke-white/15" strokeWidth={0.6} />
          <text x={MI - 4} y={py(t) + 3} textAnchor="end" className="fill-current text-[9px] text-tenue">{conSigno(t, Math.abs(y1 - y0) < 3 ? Math.max(decimales, 1) : 0)}</text>
        </g>)}
        {desdeCero && y0 === 0 && <line x1={MI} x2={ANCHO - MD} y1={py(0)} y2={py(0)} className="stroke-white/40" strokeWidth={0.8} />}
        {ticksX.map(t => <text key={t} x={px(t)} y={ALTO - 6} textAnchor="middle" className="fill-current text-[9px] text-tenue">{t}</text>)}
        {grupo.series.map(s => <path key={s.nombre} d={trazo(s.puntos)} fill="none" stroke={s.color} strokeWidth={1.6} strokeDasharray={s.trazo} strokeLinejoin="round" strokeLinecap="round" />)}
        {grupo.series.length === 1 && grupo.series[0]!.puntos.length <= 16 && grupo.series[0]!.puntos.map(([x, y]) => y === null ? null :
          <circle key={String(x)} cx={px(aAnio(x))} cy={py(y)} r={2.2} fill={grupo.series[0]!.color} />)}
      </svg>
      <figcaption className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-suave">
        <span className="text-tenue">{unidad}</span>
        {grupo.series.length > 1 && grupo.series.map(s => <span key={s.nombre} className="flex items-center gap-1.5">
          <svg aria-hidden="true" width="22" height="6"><line x1="1" x2="21" y1="3" y2="3" stroke={s.color} strokeWidth="2" strokeDasharray={s.trazo} /></svg>{s.nombre}
        </span>)}
        {bandasVisibles.some(b => b.tipo === 'nino') && <span className="flex items-center gap-1.5"><span aria-hidden="true" className="h-2.5 w-3 bg-capa-riesgo/30" />El Niño</span>}
        {bandasVisibles.some(b => b.tipo === 'nina') && <span className="flex items-center gap-1.5"><span aria-hidden="true" className="h-2.5 w-3 bg-capa-agua/30" />La Niña</span>}
      </figcaption>
    </figure>
    <details className="rounded-sm border border-linea-suave">
      <summary className="flex min-h-11 cursor-pointer items-center px-3 text-sm text-dorado-300">Tabla de datos ({filas.length} {filas.length === 1 ? 'fila' : 'filas'})</summary>
      <div className="max-h-72 overflow-auto">
        <table className="w-full text-xs">
          <caption className="sr-only">{`${titulo}${grupos.length > 1 ? ` · ${grupo.nombre}` : ''}, ${unidad}`}</caption>
          <thead className="sticky top-0 bg-fondo-alt"><tr className="border-b border-linea">
            <th scope="col" className="px-3 py-2 text-left">Periodo</th>
            {grupo.series.map(s => <th key={s.nombre} scope="col" className="px-3 py-2 text-right">{s.nombre}</th>)}
          </tr></thead>
          <tbody>{filas.map(x => <tr key={String(x)} className="border-b border-linea-suave">
            <th scope="row" className="px-3 py-1.5 text-left font-normal tabular-nums">{etiquetaPeriodo(x)}</th>
            {grupo.series.map(s => { const v = valor(s, x); return <td key={s.nombre} className="whitespace-nowrap px-3 py-1.5 text-right tabular-nums">{v == null ? 'sin dato' : conSigno(v, decimales)}</td>; })}
          </tr>)}</tbody>
        </table>
      </div>
      {bandas && bandas.length > 0 && <p className="border-t border-linea-suave px-3 py-2 text-xs text-tenue">Episodios: {bandas.map((b: Banda) => b.etiqueta).join('; ')}.</p>}
    </details>
    <Nota>{nota}</Nota>
  </section>;
}

function Metodologia() {
  return <div className="space-y-6">
    <p className="text-sm leading-relaxed text-suave">Nueve capas, de las fuentes abajo a los productos arriba, y dieciocho pasos agrupados en ellas.</p>
    <section className="space-y-2">
      <Subtitulo>Las nueve capas</Subtitulo>
      {CAPAS_METODOLOGIA.map(c => <details key={c.numero} className="group rounded-3xl border border-linea-suave bg-white/[0.03] open:bg-white/5" open={c.numero === 1}>
        <summary className="flex min-h-12 cursor-pointer list-none items-center gap-3 px-4 py-2 [&::-webkit-details-marker]:hidden">
          <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-dorado-500 text-xs font-bold text-cra-950">{c.numero}</span>
          <span className="min-w-0 flex-1 text-sm font-semibold">Capa {c.numero} de 9 · {c.nombre}</span>
          <span aria-hidden="true" className="text-dorado-300 transition-transform group-open:rotate-90">▸</span>
        </summary>
        <dl className="space-y-3 px-4 pb-4 text-sm leading-relaxed">
          {([['Mide', c.mide], ['Datos', c.datos], ['Fórmula o regla', c.formula], ['Resultado', c.resultado], ['Comprobación', c.comprobacion]] as const).map(([k, v]) =>
            <div key={k}><dt className="rotulo text-[11px] text-dorado-300">{k}</dt><dd className={k === 'Fórmula o regla' ? 'mt-1 rounded-sm bg-fondo-alt px-3 py-2 font-mono text-[13px]' : 'mt-1 text-suave'}>{v}</dd></div>)}
          <div><dt className="rotulo text-[11px] text-dorado-300">Pasos de esta capa</dt>
            <dd className="mt-1 text-suave">{c.pasos.map(p => `${p}. ${PASOS_METODOLOGIA[p - 1]!.nombre}`).join(' · ')}</dd></div>
        </dl>
      </details>)}
    </section>
    <section className="space-y-2">
      <Subtitulo>Los dieciocho pasos</Subtitulo>
      <ol className="space-y-2">
        {PASOS_METODOLOGIA.map(p => <li key={p.numero} className="rounded-sm border-l-2 border-dorado-500 bg-white/[0.03] px-3 py-2 text-sm leading-relaxed">
          <p><strong>Paso {p.numero} de 18 · {p.nombre}.</strong> <span className="text-suave">{p.texto}</span></p>
          {p.comprobacion && <p className="mt-1 text-xs text-tenue">Comprobación: {p.comprobacion}</p>}
          {!p.comprobacion && <p className="mt-1 text-xs text-tenue">Paso abierto: aún sin comprobación.</p>}
        </li>)}
      </ol>
    </section>
    <section className="space-y-2">
      <Subtitulo>Capas vivas</Subtitulo>
      <p className="text-sm leading-relaxed text-suave">{NOTA_CAPAS_VIVAS}</p>
      <p className="rounded-sm border border-dashed border-dorado-300/60 px-3 py-2 text-sm">Vista 3D y láminas ráster de la C.R.A. pendientes de entrega: aquí no se reproducen.</p>
    </section>
  </div>;
}

export function BloqueWorkflow({ bloque }: { bloque: Bloque }) {
  switch (bloque.tipo) {
    case 'cifras': return <Cifras {...bloque} />;
    case 'barras': return <Barras {...bloque} />;
    case 'tabla': return <Tabla {...bloque} />;
    case 'serie': return <GraficaSerie {...bloque} />;
    case 'texto': return <section className="space-y-2">{bloque.titulo && <Subtitulo>{bloque.titulo}</Subtitulo>}{bloque.parrafos.map(p => <p key={p.slice(0, 40)} className="text-sm leading-relaxed text-suave">{p}</p>)}</section>;
    case 'formula': return <section className="space-y-2">{bloque.titulo && <Subtitulo>{bloque.titulo}</Subtitulo>}<p className="rounded-sm bg-fondo px-3 py-2 font-mono text-[13px]">{bloque.texto}</p><Nota>{bloque.nota}</Nota></section>;
    case 'referencias': return <dl className="space-y-4">{bloque.items.map(r => <div key={r.titulo}><dt className="rotulo text-dorado-300">{r.titulo}</dt><dd className="mt-1 text-sm leading-relaxed text-suave">{r.texto}</dd></div>)}</dl>;
    case 'pendiente': return <aside className="rounded-3xl border border-dashed border-dorado-300/60 p-4 text-sm">
      <p className="font-semibold">Capa de la C.R.A. pendiente de entrega</p>
      <p className="mt-1 text-suave">{bloque.capas.join(' · ')}. El mapa de esta web no la dibuja hasta recibirla: nunca se inventa.</p>
      {bloque.convenciones && <p className="mt-2 text-xs text-tenue">Convenciones en el visor de la C.R.A.: {bloque.convenciones.join(' · ')}.</p>}
    </aside>;
    case 'metodologia': return <Metodologia />;
  }
}
