import { ArrowDown, ArrowUp, ArrowUpDown, ChevronDown } from 'lucide-react';
import { Fragment, useState } from 'react';
import type { CambioEstado, EstadoReporte, Reporte } from '../../types/manglar';
import { formatearFecha, TIPOS, TRANSICIONES, sincronizadoTarde } from '../../lib/catalogos';
import BarraConfianza from '../ui/react/BarraConfianza';
import ChipEstado from '../ui/react/ChipEstado';
import ChipCanal from '../ui/react/ChipCanal';
import ChipPrioridad from '../ui/react/ChipPrioridad';
import ChipTipo from '../ui/react/ChipTipo';

export type CampoOrden = 'capturado_en' | 'confianza';
export interface Orden { campo: CampoOrden; direccion: 'asc' | 'desc'; }
type CambiarEstado = (id: string, estado: EstadoReporte) => void;

function Acciones({ reporte, cambiarEstado }: { reporte: Reporte; cambiarEstado: CambiarEstado }) {
 const tonos = { primaria: 'bg-dorado-500 text-cra-950', peligro: 'text-alta-texto ring-1 ring-alta/30', secundaria: 'text-suave ring-1 ring-linea' };
 return <div className="flex flex-wrap gap-2">{TRANSICIONES[reporte.estado].map((t) => <button key={t.a} type="button" className={`min-h-11 rounded-xl px-3 py-2 text-xs font-medium ${tonos[t.tono]}`} onClick={() => cambiarEstado(reporte.id, t.a)}>{t.accion}</button>)}</div>;
}
function Identidad({ reporte }: { reporte: Reporte }) {
 return <div><p className="font-medium text-texto">{TIPOS[reporte.tipo].etiqueta} · {reporte.zona ?? 'Fuera de zona'}</p><p className="mt-1 text-xs text-tenue">{reporte.id.slice(0, 8)} · <time dateTime={reporte.capturado_en}>{formatearFecha(reporte.capturado_en)}</time></p><div className="mt-2 flex flex-wrap gap-2 text-xs text-suave">{sincronizadoTarde(reporte) && <span className="rounded-full bg-white/10 px-2 py-1">Sincronizado tarde</span>}{reporte.reportante_id === null && <span className="rounded-full bg-fondo-alt px-2 py-1">Anónimo</span>}</div></div>;
}
function LineaTiempo({ reporte, historial }: { reporte: Reporte; historial: CambioEstado[] }) {
 return <div className="space-y-3 p-4">
  {reporte.ia_tipo_detectado !== null && reporte.ia_tipo_detectado !== reporte.tipo && <p className="rounded-xl bg-white/10 p-3 text-sm">La IA detectó: {TIPOS[reporte.ia_tipo_detectado].etiqueta} ({reporte.ia_confianza ?? '—'} %)</p>}
  <ol aria-label="Historial del reporte" className="space-y-4 border-l-2 border-linea pl-4">{historial.filter((c) => c.reporte_id === reporte.id).sort((a, b) => Date.parse(a.fecha) - Date.parse(b.fecha)).map((c) => <li key={c.id}><ChipEstado estado={c.estado} /><p className="mt-1 text-xs text-suave">{c.usuario_id} · <time dateTime={c.fecha}>{formatearFecha(c.fecha)}</time></p><p className="text-sm">{c.nota}</p></li>)}</ol>
 </div>;
}

export default function ReportesPanel({ reportes, historial, orden, ordenar, cambiarEstado }: {
  reportes: Reporte[]; historial: CambioEstado[]; orden: Orden; ordenar: (campo: CampoOrden) => void; cambiarEstado: CambiarEstado;
}) {
  const [expandidos, setExpandidos] = useState<string[]>([]);
  const expandir = (id: string) => setExpandidos((actuales) => actuales.includes(id) ? actuales.filter((v) => v !== id) : [...actuales, id]);
  const botonHistorial = (r: Reporte) => <button type="button" aria-expanded={expandidos.includes(r.id)} onClick={() => expandir(r.id)} className="mt-2 inline-flex min-h-11 items-center gap-2 rounded-xl px-3 text-xs ring-1 ring-linea">Historial<ChevronDown size={16} className={expandidos.includes(r.id) ? 'rotate-180' : ''} aria-hidden="true" /></button>;
  function encabezado(campo: CampoOrden, etiqueta: string) {
    const activo = orden.campo === campo;
    const Icono = !activo ? ArrowUpDown : orden.direccion === 'asc' ? ArrowUp : ArrowDown;
    return <th scope="col" className="px-4 py-3" aria-sort={activo ? (orden.direccion === 'asc' ? 'ascending' : 'descending') : 'none'}>
      <button type="button" className="inline-flex items-center gap-2 text-left uppercase tracking-wide" onClick={() => ordenar(campo)} aria-label={`Ordenar por ${campo === 'capturado_en' ? 'fecha' : 'confianza IA'} ${activo && orden.direccion === 'desc' ? 'ascendente' : 'descendente'}`}>{etiqueta}<Icono size={14} aria-hidden="true" /></button>
    </th>;
  }
  return <>
    <div className="hidden overflow-x-auto md:block">
      <table className="w-full min-w-[980px] text-left text-sm">
        <caption className="sr-only">Reportes ciudadanos filtrados para validación y seguimiento</caption>
        <thead className="sticky top-0 bg-fondo-alt text-xs uppercase tracking-wide text-tenue"><tr>
          {encabezado('capturado_en', 'Reporte')}
          <th scope="col" className="px-4 py-3">Tipo</th><th scope="col" className="px-4 py-3">Zona/Municipio</th><th scope="col" className="px-4 py-3">Prioridad</th>
          {encabezado('confianza', 'Confianza IA')}
          <th scope="col" className="px-4 py-3">Canal</th><th scope="col" className="px-4 py-3">Estado</th><th scope="col" className="px-4 py-3">Acciones</th>
        </tr></thead>
        <tbody className="divide-y divide-linea-suave">{reportes.map((reporte) => <Fragment key={reporte.id}><tr className="hover:bg-fondo">
          <td className="min-w-64 px-4 py-4"><Identidad reporte={reporte} /></td>
          <td className="px-4 py-4"><ChipTipo tipo={reporte.tipo} /></td>
          <td className="px-4 py-4 text-suave">{reporte.zona ?? 'Fuera de zona'}<br />{reporte.municipio}</td>
          <td className="px-4 py-4"><ChipPrioridad prioridad={reporte.prioridad} /></td>
          <td className="w-[140px] min-w-[140px] px-4 py-4"><BarraConfianza valor={reporte.confianza} compacta /></td>
          <td className="px-4 py-4"><ChipCanal canal={reporte.canal} /></td>
          <td className="px-4 py-4"><ChipEstado estado={reporte.estado} /></td>
          <td className="min-w-48 px-4 py-4"><Acciones reporte={reporte} cambiarEstado={cambiarEstado} />{botonHistorial(reporte)}</td>
        </tr>{expandidos.includes(reporte.id) && <tr><td colSpan={8} className="bg-fondo"><LineaTiempo reporte={reporte} historial={historial} /></td></tr>}</Fragment>)}</tbody>
      </table>
    </div>
    <ul className="space-y-3 p-4 md:hidden" aria-label="Reportes filtrados">{reportes.map((reporte) => <li key={reporte.id} className="space-y-4 rounded-sm bg-superficie p-4 ring-1 ring-linea-suave">
      <Identidad reporte={reporte} />
      <div className="flex flex-wrap gap-2"><ChipTipo tipo={reporte.tipo} /><ChipPrioridad prioridad={reporte.prioridad} /><ChipCanal canal={reporte.canal} /><ChipEstado estado={reporte.estado} /></div>
      <p className="text-sm text-suave"><span className="font-medium">Zona: </span>{reporte.zona ?? 'Fuera de zona'} · {reporte.municipio}</p>
      <div><p className="mb-2 text-xs text-tenue">Confianza IA</p><BarraConfianza valor={reporte.confianza} compacta /></div>
      <Acciones reporte={reporte} cambiarEstado={cambiarEstado} />{botonHistorial(reporte)}
      {expandidos.includes(reporte.id) && <LineaTiempo reporte={reporte} historial={historial} />}
    </li>)}</ul>
  </>;
}
