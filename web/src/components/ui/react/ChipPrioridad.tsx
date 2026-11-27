import { PRIORIDADES } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { PrioridadReporte } from '../../../types/manglar';
export default function ChipPrioridad({ prioridad }: { prioridad: PrioridadReporte }) {
 const dato = PRIORIDADES[prioridad];
 return <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium', dato.chip)}><span aria-hidden="true" className={cn('h-1.5 w-1.5 rounded-full', dato.punto)} />{dato.etiqueta}</span>;
}
