import { PRIORIDADES, nivelPrioridad, etiquetaPrioridad } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { Prioridad } from '../../../types/manglar';
export default function ChipPrioridad({ prioridad }: { prioridad: Prioridad }) {
 const dato = PRIORIDADES[nivelPrioridad(prioridad)];
 return <span title="Prioridad sugerida por IA" className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium', dato.chip)}><span aria-hidden="true" className={cn('h-1.5 w-1.5 rounded-full', dato.punto)} />{etiquetaPrioridad(prioridad)}</span>;
}
