import { CANALES } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { Canal } from '../../../types/manglar';
export default function ChipCanal({ canal }: { canal: Canal }) {
 const { icono: Icono, etiqueta } = CANALES[canal];
 return <span className={cn('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium text-manglar-700')}><Icono size={13} aria-hidden="true" />{etiqueta}</span>;
}
