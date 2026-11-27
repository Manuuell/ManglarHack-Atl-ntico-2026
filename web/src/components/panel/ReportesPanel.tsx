import { ArrowDown, ArrowUp, ArrowUpDown, BadgeCheck, FileWarning, RotateCcw } from 'lucide-react';
import type { EstadoReporte, Reporte } from '../../types/manglar';
import { formatearFecha } from '../../lib/catalogos';
import BarraConfianza from '../ui/react/BarraConfianza';
import ChipEstado from '../ui/react/ChipEstado';
import ChipOrigen from '../ui/react/ChipOrigen';
import ChipPrioridad from '../ui/react/ChipPrioridad';
import ChipTipo from '../ui/react/ChipTipo';

export type CampoOrden = 'fecha' | 'confianza_ia';
export interface Orden { campo: CampoOrden; direccion: 'asc' | 'desc'; }
type CambiarEstado = (id: string, estado: EstadoReporte) => void;

function Acciones({ reporte, cambiarEstado }: { reporte: Reporte; cambiarEstado: CambiarEstado }) {
  const boton = 'inline-flex items-center justify-center gap-1 rounded-xl px-2.5 py-1.5 text-xs font-medium disabled:cursor-not-allowed disabled:opacity-40';
  return <div className="flex flex-wrap items-center gap-2">
    <button type="button" className={`${boton} text-agua-700 ring-1 ring-inset ring-agua-500/40 hover:bg-agua-50`} disabled={reporte.estado === 'validado'} aria-label={`Validar ${reporte.id}`} onClick={() => cambiarEstado(reporte.id, 'validado')}><BadgeCheck size={14} aria-hidden="true" />Validar</button>
    <button type="button" className={`${boton} bg-manglar-900 text-white hover:bg-manglar-800`} disabled={reporte.estado === 'escalado'} aria-label={`Escalar a expediente ${reporte.id}`} onClick={() => cambiarEstado(reporte.id, 'escalado')}><FileWarning size={14} aria-hidden="true" />Escalar a expediente</button>
    {reporte.estado !== 'pendiente' && <button type="button" className={`${boton} text-suave hover:bg-fondo-alt`} aria-label={`Volver a pendiente ${reporte.id}`} title="Volver a pendiente" onClick={() => cambiarEstado(reporte.id, 'pendiente')}><RotateCcw size={14} aria-hidden="true" /></button>}
  </div>;
}

function Identidad({ reporte }: { reporte: Reporte }) {
  return <div className="flex items-center gap-3">
    <img src={reporte.foto_url} alt={`Fotografía: ${reporte.titulo}`} width={44} height={44} loading="lazy" className="h-11 w-11 shrink-0 rounded-xl bg-fondo-alt object-cover" />
    <div className="min-w-0"><p className="font-medium text-texto">{reporte.titulo}</p><p className="mt-1 text-xs text-tenue">{reporte.id} · <time dateTime={reporte.fecha}>{formatearFecha(reporte.fecha)}</time></p></div>
  </div>;
}

export default function ReportesPanel({ reportes, orden, ordenar, cambiarEstado }: {
  reportes: Reporte[]; orden: Orden; ordenar: (campo: CampoOrden) => void; cambiarEstado: CambiarEstado;
}) {
  function encabezado(campo: CampoOrden, etiqueta: string) {
    const activo = orden.campo === campo;
    const Icono = !activo ? ArrowUpDown : orden.direccion === 'asc' ? ArrowUp : ArrowDown;
    return <th scope="col" className="px-4 py-3" aria-sort={activo ? (orden.direccion === 'asc' ? 'ascending' : 'descending') : 'none'}>
      <button type="button" className="inline-flex items-center gap-2 text-left uppercase tracking-wide" onClick={() => ordenar(campo)} aria-label={`Ordenar por ${campo === 'fecha' ? 'fecha' : 'confianza IA'} ${activo && orden.direccion === 'desc' ? 'ascendente' : 'descendente'}`}>{etiqueta}<Icono size={14} aria-hidden="true" /></button>
    </th>;
  }
  return <>
    <div className="hidden overflow-x-auto md:block">
      <table className="w-full min-w-[980px] text-left text-sm">
        <caption className="sr-only">Reportes ciudadanos filtrados para validación y seguimiento</caption>
        <thead className="sticky top-0 bg-fondo-alt text-xs uppercase tracking-wide text-tenue"><tr>
          {encabezado('fecha', 'Reporte')}
          <th scope="col" className="px-4 py-3">Tipo</th><th scope="col" className="px-4 py-3">Zona</th><th scope="col" className="px-4 py-3">Prioridad</th>
          {encabezado('confianza_ia', 'Confianza IA')}
          <th scope="col" className="px-4 py-3">Origen</th><th scope="col" className="px-4 py-3">Estado</th><th scope="col" className="px-4 py-3">Acciones</th>
        </tr></thead>
        <tbody className="divide-y divide-linea-suave">{reportes.map((reporte) => <tr key={reporte.id} className="hover:bg-fondo">
          <td className="min-w-64 px-4 py-4"><Identidad reporte={reporte} /></td>
          <td className="px-4 py-4"><ChipTipo tipo={reporte.tipo} /></td>
          <td className="px-4 py-4 text-suave">{reporte.zona}</td>
          <td className="px-4 py-4"><ChipPrioridad prioridad={reporte.prioridad} /></td>
          <td className="w-[140px] min-w-[140px] px-4 py-4"><BarraConfianza valor={reporte.confianza_ia} compacta /></td>
          <td className="px-4 py-4"><ChipOrigen origen={reporte.origen} /></td>
          <td className="px-4 py-4"><ChipEstado estado={reporte.estado} /></td>
          <td className="min-w-48 px-4 py-4"><Acciones reporte={reporte} cambiarEstado={cambiarEstado} /></td>
        </tr>)}</tbody>
      </table>
    </div>
    <ul className="space-y-3 p-4 md:hidden" aria-label="Reportes filtrados">{reportes.map((reporte) => <li key={reporte.id} className="space-y-4 rounded-2xl bg-superficie p-4 ring-1 ring-linea-suave">
      <Identidad reporte={reporte} />
      <div className="flex flex-wrap gap-2"><ChipTipo tipo={reporte.tipo} /><ChipPrioridad prioridad={reporte.prioridad} /><ChipOrigen origen={reporte.origen} /><ChipEstado estado={reporte.estado} /></div>
      <p className="text-sm text-suave"><span className="font-medium">Zona: </span>{reporte.zona}</p>
      <div><p className="mb-2 text-xs text-tenue">Confianza IA</p><BarraConfianza valor={reporte.confianza_ia} compacta /></div>
      <Acciones reporte={reporte} cambiarEstado={cambiarEstado} />
    </li>)}</ul>
  </>;
}
