import { Axe, Flame, Construction, Droplets, Trash2, Waves, Fish, CircleHelp, Inbox, ScanSearch, BadgeCheck, Siren, HardHat, CircleCheck, CircleX, Smartphone, QrCode, MessageCircle, type LucideIcon } from 'lucide-react';
import type { Canal, EstadoReporte, NivelPrioridad, Prioridad, PrioridadZona, Reporte, TipoReporte } from '../types/manglar';
export const UMBRAL_IA = 80;
export const TIPOS: Record<TipoReporte, { etiqueta: string; etiquetaLarga: string; icono: LucideIcon; gravedad: Prioridad }> = {
 tala: { etiqueta: 'Tala', etiquetaLarga: 'Tala o corte de mangle', icono: Axe, gravedad: 5 },
 quema: { etiqueta: 'Quema', etiquetaLarga: 'Quema o incendio', icono: Flame, gravedad: 5 },
 relleno: { etiqueta: 'Relleno', etiquetaLarga: 'Relleno o construcción', icono: Construction, gravedad: 4 },
 vertimiento: { etiqueta: 'Vertimiento', etiquetaLarga: 'Vertimiento o contaminación del agua', icono: Droplets, gravedad: 4 },
 basuras: { etiqueta: 'Basuras', etiquetaLarga: 'Basuras o residuos', icono: Trash2, gravedad: 2 },
 cano_taponado: { etiqueta: 'Caño taponado', etiquetaLarga: 'Caño taponado o alteración del agua', icono: Waves, gravedad: 3 },
 fauna: { etiqueta: 'Fauna', etiquetaLarga: 'Fauna afectada', icono: Fish, gravedad: 3 },
 otro: { etiqueta: 'Otro', etiquetaLarga: 'Otro', icono: CircleHelp, gravedad: 1 },
};
export const PRIORIDADES: Record<NivelPrioridad, { etiqueta: string; color: string; chip: string; punto: string }> = {
  alta: { etiqueta: 'Alta', color: '#dc2626', chip: 'bg-alta-suave text-alta-texto border border-alta-texto/40', punto: 'bg-alta' },
  media: { etiqueta: 'Media', color: '#d97706', chip: 'bg-media-suave text-media-texto border border-media-texto/40', punto: 'bg-media' },
  baja: { etiqueta: 'Baja', color: '#16a34a', chip: 'bg-baja-suave text-baja-texto border border-baja-texto/40', punto: 'bg-baja' },
};

export const PRIORIDADES_ZONA: Record<PrioridadZona, { etiqueta: string; color: string; relleno: string; opacidadRelleno: number; chip: string }> = {
  critica: { etiqueta: 'Crítica', color: '#7f1d1d', relleno: '#dc2626', opacidadRelleno: 0.32, chip: 'bg-critica-suave text-critica-texto border border-critica-texto/40' },
  alta: { etiqueta: 'Alta', color: '#dc2626', relleno: '#f87171', opacidadRelleno: 0.24, chip: 'bg-alta-suave text-alta-texto border border-alta-texto/40' },
  media: { etiqueta: 'Media', color: '#d97706', relleno: '#fbbf24', opacidadRelleno: 0.24, chip: 'bg-media-suave text-media-texto border border-media-texto/40' },
  baja: { etiqueta: 'Baja', color: '#16a34a', relleno: '#4ade80', opacidadRelleno: 0.22, chip: 'bg-baja-suave text-baja-texto border border-baja-texto/40' },
};


export const ESTADOS: Record<EstadoReporte, { etiqueta: string; descripcion: string; icono: LucideIcon; chip: string; abierto: boolean }> = {
 recibido: { etiqueta: 'Recibido', descripcion: 'Recibido para revisión.', icono: Inbox, chip: 'bg-white/10 text-suave border border-linea', abierto: true },
 en_verificacion: { etiqueta: 'En verificación', descripcion: 'Una persona revisa la evidencia.', icono: ScanSearch, chip: 'bg-cra-500/20 text-cra-100 border border-cra-300/40', abierto: true },
 verificado: { etiqueta: 'Verificado', descripcion: 'Hallazgo confirmado por una persona.', icono: BadgeCheck, chip: 'bg-cra-500/30 text-cra-100 ring-1 ring-inset ring-cra-300/40', abierto: true },
 alerta_oficial: { etiqueta: 'Alerta oficial', descripcion: 'Alerta emitida con apertura de expediente.', icono: Siren, chip: 'bg-dorado-500 text-cra-950', abierto: true },
 en_atencion: { etiqueta: 'En atención', descripcion: 'Caso en atención por el equipo.', icono: HardHat, chip: PRIORIDADES.media.chip, abierto: true },
 cerrado: { etiqueta: 'Cerrado', descripcion: 'Seguimiento finalizado.', icono: CircleCheck, chip: PRIORIDADES.baja.chip, abierto: false },
 descartado: { etiqueta: 'Descartado', descripcion: 'La evidencia no confirma el reporte.', icono: CircleX, chip: 'bg-white/5 text-tenue line-through', abierto: false },
};
export const TRANSICIONES: Record<EstadoReporte, { a: EstadoReporte; accion: string; tono: 'primaria' | 'peligro' | 'secundaria' }[]> = {
 recibido: [{ a: 'en_verificacion', accion: 'Iniciar verificación', tono: 'primaria' }, { a: 'descartado', accion: 'Descartar', tono: 'peligro' }],
 en_verificacion: [{ a: 'verificado', accion: 'Marcar verificado', tono: 'primaria' }, { a: 'descartado', accion: 'Descartar', tono: 'peligro' }],
 verificado: [{ a: 'alerta_oficial', accion: 'Emitir alerta oficial (abre expediente)', tono: 'primaria' }, { a: 'cerrado', accion: 'Cerrar sin alerta', tono: 'secundaria' }],
 alerta_oficial: [{ a: 'en_atencion', accion: 'Pasar a atención', tono: 'primaria' }],
 en_atencion: [{ a: 'cerrado', accion: 'Cerrar caso', tono: 'primaria' }], cerrado: [], descartado: [],
};
export const CANALES: Record<Canal, { etiqueta: string; icono: LucideIcon }> = {
 app: { etiqueta: 'App móvil', icono: Smartphone }, web: { etiqueta: 'Web · QR', icono: QrCode }, whatsapp: { etiqueta: 'WhatsApp · Zanky', icono: MessageCircle },
};
export const LISTA_TIPOS = Object.keys(TIPOS) as TipoReporte[];
export const LISTA_ESTADOS = Object.keys(ESTADOS) as EstadoReporte[];
export const LISTA_PRIORIDADES = Object.keys(PRIORIDADES) as NivelPrioridad[];
export const LISTA_PRIORIDADES_ZONA = Object.keys(PRIORIDADES_ZONA) as PrioridadZona[];
export const LISTA_CANALES = Object.keys(CANALES) as Canal[];
export function nivelPrioridad(p: Prioridad): NivelPrioridad { return p >= 4 ? 'alta' : p === 3 ? 'media' : 'baja'; }
export function etiquetaPrioridad(p: Prioridad): string { return `P${p} · ${PRIORIDADES[nivelPrioridad(p)].etiqueta}`; }
export function nivelConfianza(n: number): NivelPrioridad { return n >= UMBRAL_IA ? 'alta' : n >= 60 ? 'media' : 'baja'; }
export function sincronizadoTarde(r: Pick<Reporte, 'recibido_en' | 'capturado_en'>): boolean { return Date.parse(r.recibido_en) - Date.parse(r.capturado_en) > 30 * 60 * 1000; }
export function esAbierto(r: Pick<Reporte, 'estado'>): boolean { return ESTADOS[r.estado].abierto; }
export function formatearFecha(iso: string, conHora = true): string {
  return new Intl.DateTimeFormat('es-CO', {
    timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric',
    ...(conHora ? { hour: 'numeric', minute: '2-digit', hour12: true } as const : {}),
  }).format(new Date(iso));
}
