// Piezas que comparten la cartelera de jornadas y la ficha de cada jornada: banner con la fecha,
// tarjeta, QR, botón de compartir y el conteo de inscritos. Las jornadas no tienen límite de
// cupos: se muestra cuánta gente va, nunca cuántos cupos quedan.
import { useEffect, useState, type ReactNode } from 'react';
import QRCode from 'qrcode';
import { Check, MapPin, Users } from 'lucide-react';
import type { Jornada, TipoJornada } from '../../types/plataforma';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { fmt, urlEventoZanky, urlInvitacion } from '../../lib/plataforma/jornadas';
import { cn } from '../../lib/utils';

export const BANNER: Record<TipoJornada, string> = {
  siembra: 'from-emerald-500 via-emerald-700 to-cra-900',
  limpieza: 'from-cra-500 via-cra-700 to-cra-950',
  recorrido_vigias: 'from-dorado-400 via-amber-600 to-cra-900',
  monitoreo: 'from-sky-400 via-cra-600 to-cra-950',
};
export const capital = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
export const estaPasada = (j: Jornada) => Date.parse(j.fin) < Date.now();

/** «12 personas inscritas»; sin nadie todavía, una invitación a ser la primera. */
export function textoInscritos(n: number): string {
  if (n <= 0) return 'Sé la primera persona en inscribirte';
  return `${n.toLocaleString('es-CO')} ${n === 1 ? 'persona inscrita' : 'personas inscritas'}`;
}

export function Banner({ j, className, grande = false }: { j: Jornada; className?: string; grande?: boolean }) {
  const Icono = TIPOS_JORNADA[j.tipo].icono;
  const pasada = estaPasada(j);
  return (
    <div className={cn('relative isolate overflow-hidden bg-linear-to-br', BANNER[j.tipo], className)}>
      {j.imagen_url && <>
        <img src={j.imagen_url} alt="" loading="lazy" className="absolute inset-0 -z-10 h-full w-full object-cover" />
        <span aria-hidden="true" className="absolute inset-0 -z-10 bg-linear-to-t from-black/45 via-transparent to-black/20" />
      </>}
      {!j.imagen_url && <svg aria-hidden="true" viewBox="0 0 400 225" preserveAspectRatio="none" className="absolute inset-0 -z-10 h-full w-full fill-none stroke-white/15">
        {[0, 1, 2, 3, 4].map((i) => <path key={i} d={`M-20 ${150 + i * 14} C 80 ${110 + i * 14}, 180 ${190 + i * 14}, 420 ${130 + i * 14}`} strokeWidth="1.2" />)}
      </svg>}
      {!j.imagen_url && <Icono aria-hidden="true" strokeWidth={1.2} className={cn('absolute -right-5 -bottom-6 text-white/20 transition-transform duration-500 group-hover:scale-110', grande ? 'size-56' : 'size-36')} />}
      <div className="absolute top-3 left-3 rounded-2xl bg-white px-3 py-1.5 text-center text-cra-950 shadow-lg">
        <span className="block font-[family-name:var(--font-titulo)] text-2xl leading-none font-extrabold">{fmt.dia(j.inicio)}</span>
        <span className="text-[11px] font-bold tracking-wider uppercase">{fmt.mes(j.inicio)}</span>
      </div>
      {pasada && <span className="absolute top-3 right-3 rounded-full bg-black/45 px-3 py-1 text-xs font-bold text-white">Realizada</span>}
    </div>
  );
}

/** QR en SVG (tinta azul C.R.A. sobre blanco) para pantalla y para el cartel impreso. */
export function useQr(url: string): string {
  const [svg, setSvg] = useState('');
  useEffect(() => {
    QRCode.toString(url, { type: 'svg', margin: 1, errorCorrectionLevel: 'M', color: { dark: '#05243a', light: '#ffffff' } }).then(setSvg).catch(() => setSvg(''));
  }, [url]);
  return svg;
}

export function BotonCompartir({ onClick, href, icono, children, externo }: { onClick?: () => void; href?: string; icono: ReactNode; children: ReactNode; externo?: boolean }) {
  const clase = 'inline-flex min-h-11 items-center justify-center gap-2 rounded-full border border-white/20 bg-white/5 px-4 text-sm font-semibold text-texto transition-colors hover:border-dorado-300 hover:text-dorado-300';
  return href
    ? <a href={href} className={clase} {...(externo ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>{icono}{children}</a>
    : <button type="button" onClick={onClick} className={clase}>{icono}{children}</button>;
}

/** Tarjeta de una jornada: lleva a su ficha. Debajo, «Interactúa con Zanky» si todavía no pasó. */
export function TarjetaJornada({ j, inscrito }: { j: Jornada; inscrito: boolean }) {
  const T = TIPOS_JORNADA[j.tipo];
  return (
    <article className="group">
      <a href={urlInvitacion(j.id)} className="block" aria-label={`Ver la jornada: ${j.titulo}`}>
        <Banner j={j} className="aspect-[16/9] rounded-2xl shadow-[var(--c-sombra)]" />
        <div className="mt-3 px-1">
          <p className={cn('rotulo flex items-center gap-1.5', T.clase)}><T.icono className="size-3.5" aria-hidden="true" />{T.etiqueta}</p>
          <h3 className="mt-1.5 font-[family-name:var(--font-titulo)] text-xl leading-snug font-bold transition-colors group-hover:text-dorado-300">{j.titulo}</h3>
          <p className="mt-1 text-sm text-suave">{capital(fmt.diaSemana(j.inicio))} {fmt.dia(j.inicio)} de {fmt.mes(j.inicio)} · {fmt.hora(j.inicio)} – {fmt.hora(j.fin)}</p>
          <p className="mt-0.5 flex items-start gap-1 text-sm text-suave"><MapPin className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />{j.punto_encuentro}</p>
          <p className="mt-2 flex items-center gap-1.5 text-sm text-suave"><Users className="size-3.5 shrink-0" aria-hidden="true" />{textoInscritos(j.inscritos)}</p>
          {j.ejemplo && <p className="mt-2 inline-flex rounded-full border border-white/15 px-3 py-1 text-xs text-tenue">Datos de ejemplo</p>}
          {inscrito && <p className="mt-2 inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-3 py-1 text-xs font-bold text-emerald-200"><Check className="size-3.5" aria-hidden="true" />Vas a ir</p>}
        </div>
      </a>
      {!estaPasada(j) && (
        <a href={urlEventoZanky(j.id)} className="mt-3 ml-1 inline-flex min-h-11 items-center gap-2 rounded-full border border-dorado-500/40 bg-dorado-500/10 py-1 pr-4 pl-1.5 text-sm font-bold text-dorado-300 transition-colors hover:border-dorado-300 hover:bg-dorado-500/20">
          <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={32} height={32} className="size-8" />Interactúa con Zanky
        </a>
      )}
    </article>
  );
}
