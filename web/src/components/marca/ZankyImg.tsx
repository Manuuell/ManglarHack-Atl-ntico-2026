// Zanky dentro de las islas de React: el mismo arte, las mismas props y los mismos WebP que
// `Zanky.astro` (único lugar, junto a este, donde se elige su imagen).
import { cn } from '../../lib/utils';

export type AnimoZanky = 'feliz' | 'curioso' | 'preocupado' | 'celebrando';

export const DESCRIPCION_ZANKY: Record<AnimoZanky, string> = {
  feliz: 'Zanky, el mangle rojo con zancos, saluda contento',
  curioso: 'Zanky, el mangle rojo con zancos, mira con curiosidad',
  preocupado: 'Zanky, el mangle rojo con zancos, se ve preocupado',
  celebrando: 'Zanky, el mangle rojo con zancos, celebra',
};

interface Props {
  className?: string;
  /** Texto alternativo propio; si no, se describe el ánimo. */
  title?: string;
  animo?: AnimoZanky;
  /** Acompaña a un texto que ya lo dice: sin alt y oculto a los lectores de pantalla. */
  decorativo?: boolean;
  carga?: 'lazy' | 'eager';
  /** Ancho con que se muestra (atributo `sizes`); por omisión, el de las ilustraciones. */
  sizes?: string;
}

export default function ZankyImg({ className, title, animo = 'feliz', decorativo = false, carga = 'lazy', sizes = '(min-width: 1024px) 160px, 120px' }: Props) {
  const base = `/marca/zanky/zanky-${animo}`;
  return (
    <img
      src={`${base}-256.webp`}
      srcSet={`${base}-256.webp 256w, ${base}-512.webp 512w`}
      sizes={sizes}
      width={256}
      height={256}
      alt={decorativo ? '' : (title ?? DESCRIPCION_ZANKY[animo])}
      aria-hidden={decorativo ? true : undefined}
      loading={carga}
      decoding="async"
      className={cn('object-contain drop-shadow-[0_6px_12px_rgb(0_0_0/0.35)]', className)}
    />
  );
}
