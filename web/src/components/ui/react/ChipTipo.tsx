import { TIPOS } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
import type { TipoReporte } from '../../../types/manglar';
export default function ChipTipo({ tipo }: { tipo: TipoReporte }) {
 const { icono: Icono, etiqueta } = TIPOS[tipo];
 return <span className={cn('inline-flex items-center gap-1 rounded-full bg-fondo-alt px-2.5 py-0.5 text-xs font-medium text-texto ring-1 ring-linea')}><Icono size={13} aria-hidden="true" />{etiqueta}</span>;
}
