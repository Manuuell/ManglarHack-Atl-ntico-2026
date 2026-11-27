import { ESTADOS } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { EstadoReporte } from '../../../types/manglar';
export default function ChipEstado({ estado }: { estado: EstadoReporte }) {
 const { icono: Icono, etiqueta, chip } = ESTADOS[estado];
 return <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium', chip)}><Icono size={13} aria-hidden="true" />{etiqueta}</span>;
}
