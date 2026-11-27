import { nivelConfianza } from '../../../lib/catalogos';
import { cn } from '../../../lib/utils';
export default function BarraConfianza({ valor, compacta = false }: { valor: number; compacta?: boolean }) {
 const porcentaje = Number.isFinite(valor) ? Math.min(100, Math.max(0, valor)) : 0;
 const colores = { alta: 'bg-agua-600', media: 'bg-agua-400', baja: 'bg-media' };
 return <div className="flex items-center gap-2"><div role="meter" aria-label="Confianza IA" aria-valuemin={0} aria-valuemax={100} aria-valuenow={porcentaje} className="h-1.5 flex-1 overflow-hidden rounded-full bg-fondo-alt"><div className={cn('h-full rounded-full', colores[nivelConfianza(porcentaje)])} style={{ width: `${porcentaje}%` }} /></div><span className={cn('shrink-0 tabular-nums text-suave', compacta ? 'text-xs' : 'text-sm')}>{porcentaje} %</span></div>;
}
