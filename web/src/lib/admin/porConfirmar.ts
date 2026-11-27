// «Por confirmar» en /admin: publicaciones de la comunidad (invitaciones a actividades) y reportes que esperan
// que alguien del equipo los confirme antes de publicarse.
// DATOS DE EJEMPLO (simulados): todavía no hay una cola de moderación en el servidor. Las decisiones viven en
// este navegador (modo demostración). Cuando el servidor tenga la cola, esta es la única fuente que cambia.
import type { TipoReporte } from '../../types/manglar';

export type Decision = 'pendiente' | 'confirmada' | 'rechazada';
export type Canal = 'whatsapp' | 'web' | 'app';
type Sector = 1 | 2 | 3 | 4;

interface Base {
  id: string;
  /** Quién lo manda (nombre como lo escribió) y qué es (comunidad, colegio, persona…). */
  autor: string;
  quien: string;
  canal: Canal;
  recibido: string;
  lugar: string;
  /** Sector de la C.R.A. para la imagen (1 Mallorquín, 2 Puerto Colombia, 3 Tubará, 4 Totumo). */
  sector: Sector;
  texto: string;
}
export interface PublicacionPorConfirmar extends Base {
  clase: 'publicacion';
  titulo: string;
  emoji: string;
  /** Cuándo es la actividad a la que invita. */
  fecha_actividad: string;
}
export interface ReportePorConfirmar extends Base {
  clase: 'reporte';
  tipo: TipoReporte;
  /** Confianza que propone la IA (0 a 100). */
  confianza: number;
}
export type ItemPorConfirmar = PublicacionPorConfirmar | ReportePorConfirmar;

const hace = (horas: number) => new Date(Date.now() - horas * 3_600_000).toISOString();
const enDias = (dias: number, hora: number) => {
  const d = new Date(Date.now() + dias * 86_400_000);
  d.setUTCHours(hora + 5, 0, 0, 0); // hora de Colombia
  return d.toISOString();
};

export const EJEMPLOS_POR_CONFIRMAR: ItemPorConfirmar[] = [
  {
    id: 'pub-siembra-flores', clase: 'publicacion', emoji: '🌱', titulo: 'Siembra de mangle rojo en el caño de Las Flores',
    autor: 'Junta de Acción Comunal Las Flores', quien: 'Comunidad', canal: 'whatsapp', recibido: hace(2),
    lugar: 'Caño de Las Flores, Ciénaga de Mallorquín', sector: 1, fecha_actividad: enDias(2, 7),
    texto: 'Invitamos a vecinos y colegios a sembrar 200 plántulas de mangle rojo. Llevamos las plántulas; trae agua, gorra y botas.',
  },
  {
    id: 'rep-tala-totumo', clase: 'reporte', tipo: 'tala', confianza: 78,
    autor: 'Pescador de Galerazamba', quien: 'Persona', canal: 'app', recibido: hace(3),
    lugar: 'Orilla norte de la Ciénaga del Totumo', sector: 4,
    texto: 'Cortaron varios árboles de mangle para abrir paso a una cerca. Se ven troncos apilados junto a la orilla.',
  },
  {
    id: 'pub-aves-velero', clase: 'publicacion', emoji: '🐦', titulo: 'Recorrido de aves del manglar en Puerto Velero',
    autor: 'Colegio Técnico de Tubará', quien: 'Colegio', canal: 'web', recibido: hace(5),
    lugar: 'Puerto Velero, Tubará', sector: 3, fecha_actividad: enDias(4, 6),
    texto: 'Salida con estudiantes de grado décimo para contar aves y reportar con Zanky. Abierta a familias.',
  },
  {
    id: 'rep-vertimiento-mallorquin', clase: 'reporte', tipo: 'vertimiento', confianza: 64,
    autor: 'Vigía de Mallorquín', quien: 'Persona', canal: 'whatsapp', recibido: hace(6),
    lugar: 'Desembocadura del arroyo León, Ciénaga de Mallorquín', sector: 1,
    texto: 'Agua oscura y con olor fuerte entrando a la ciénaga desde el arroyo. Hay peces muertos en la orilla.',
  },
  {
    id: 'pub-limpieza-bocas', clase: 'publicacion', emoji: '🧹', titulo: 'Limpieza de playa en Bocas de Ceniza',
    autor: 'María P.', quien: 'Persona', canal: 'whatsapp', recibido: hace(9),
    lugar: 'Bocas de Ceniza, Barranquilla', sector: 1, fecha_actividad: enDias(6, 8),
    texto: 'Somos un grupo de amigos y queremos recoger plástico de la orilla antes de que llegue al manglar. ¡Súmate!',
  },
  {
    id: 'rep-quema-tubara', clase: 'reporte', tipo: 'quema', confianza: 81,
    autor: 'Estudiante de Juan de Acosta', quien: 'Colegio', canal: 'app', recibido: hace(12),
    lugar: 'Vía al Mar, entre Tubará y Juan de Acosta', sector: 3,
    texto: 'Humo saliendo de un lote junto al manglar. Parece una quema de maleza que se está extendiendo.',
  },
  {
    id: 'pub-taller-artesanias', clase: 'publicacion', emoji: '🧺', titulo: 'Taller de artesanías con fibra natural',
    autor: 'Asociación de Mujeres de Puerto Colombia', quien: 'Comunidad', canal: 'web', recibido: hace(20),
    lugar: 'Casa de la cultura, Puerto Colombia', sector: 2, fecha_actividad: enDias(8, 15),
    texto: 'Taller gratis para aprender a hacer canastos sin cortar mangle, con materiales que no dañan el ecosistema.',
  },
  {
    id: 'rep-basuras-balboa', clase: 'reporte', tipo: 'basuras', confianza: 55,
    autor: 'Turista', quien: 'Persona', canal: 'web', recibido: hace(26),
    lugar: 'Ciénaga de Balboa, Puerto Colombia', sector: 2,
    texto: 'Muchas botellas y bolsas atrapadas entre las raíces del mangle en la orilla sur.',
  },
];

const CLAVE = 'zanky-web:v1:admin-por-confirmar';

export function leerDecisiones(): Record<string, Decision> {
  try {
    const v: unknown = JSON.parse(localStorage.getItem(CLAVE) ?? '{}');
    return v && typeof v === 'object' ? (v as Record<string, Decision>) : {};
  } catch { return {}; }
}
export function guardarDecisiones(d: Record<string, Decision>): void {
  try { localStorage.setItem(CLAVE, JSON.stringify(d)); } catch { /* sin almacenamiento: queda en memoria */ }
}
