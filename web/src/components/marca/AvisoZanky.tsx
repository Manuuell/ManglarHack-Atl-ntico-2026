// Zanky acompañando un mensaje de la interfaz: estados vacíos y de error (curioso o preocupado)
// y confirmaciones (celebrando). El texto ya dice lo que pasa, así que Zanky es decorativo.
import type { ReactNode } from 'react';
import { cn } from '../../lib/utils';
import ZankyImg, { type AnimoZanky } from './ZankyImg';

interface Props {
  animo: AnimoZanky;
  /** «bloque»: centrado, para estados vacíos; «linea»: Zanky al lado del texto, para avisos cortos. */
  forma?: 'bloque' | 'linea';
  titulo?: ReactNode;
  children?: ReactNode;
  className?: string;
}

export default function AvisoZanky({ animo, forma = 'linea', titulo, children, className }: Props) {
  if (forma === 'bloque') {
    return (
      <div className={cn('flex flex-col items-center gap-3 text-center', className)}>
        <ZankyImg animo={animo} decorativo sizes="96px" className="size-24 shrink-0" />
        {titulo && <p className="titular text-2xl text-texto">{titulo}</p>}
        {children && <div className="max-w-md text-suave">{children}</div>}
      </div>
    );
  }
  return (
    <div className={cn('flex items-center gap-3', className)}>
      <ZankyImg animo={animo} decorativo sizes="56px" className="size-14 shrink-0" />
      <div className="min-w-0">
        {titulo && <p className="font-semibold text-texto">{titulo}</p>}
        {children}
      </div>
    </div>
  );
}
