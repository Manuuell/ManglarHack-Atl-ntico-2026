import { PRIORIDADES_ZONA } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { PrioridadZona } from '../../../types/manglar';
export default function ChipPrioridadZona({ prioridad }: { prioridad: PrioridadZona }) {
 const dato = PRIORIDADES_ZONA[prioridad];
 return <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium', dato.chip)}>{dato.etiqueta}</span>;
}
