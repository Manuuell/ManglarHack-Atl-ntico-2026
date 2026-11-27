import type { Accion, Actor, SectorId } from '../../types/plataforma';
import { SECTORES_WORKFLOW, CIFRAS } from '../workflow';
import { SECTORES, TIPOS_ACCION, ACCIONES_PLAN } from './catalogos';

export interface PlantillaProyecto { titulo: string; secciones: { titulo: string; texto: string }[] }
type SectorProyecto = SectorId | (typeof SECTORES_WORKFLOW)[number];
const numero = (valor: number) => valor.toLocaleString('es-CO', { maximumFractionDigits: 2 });
function contexto(accion: Accion, actor: Actor, sector: SectorProyecto): PlantillaProyecto['secciones'] {
  const id = typeof sector === 'string' ? sector : sector.id;
  const datos = SECTORES_WORKFLOW.find((item) => item.id === id);
  const cifra = (valor: number | null | undefined) => valor == null ? '[dato del workflow para el sector]' : numero(valor);
  return [
    { titulo: 'Alcance y fuentes', texto: 'Borrador de demostración con datos de ejemplo; no constituye aprobación ni proyecto radicado. Fuente del modelo y cifras: https://manglarcra.netlify.app/maqueta y https://manglarcra.netlify.app/plataforma; cifras sectoriales del workflow de la C.R.A. ' + (accion.plan_aproximado ? 'El plan heredado es aproximado: la capa de prioridades de conservación no estaba disponible al proponer.' : 'Acción y prioridad del plan heredadas de la capa «Prioridades de conservación» entregada por la C.R.A.') },
    { titulo: 'Nombre y localización', texto: `${accion.nombre}. Actor proponente: ${actor.nombre}. Sector: ${SECTORES[id].largo}. Sitio propuesto: ${accion.lat}, ${accion.lon}. Área propuesta: ${numero(accion.hectareas)} ha. Acción del plan de manejo: ${ACCIONES_PLAN[accion.accion_plan].etiqueta}${accion.prioridad_plan ? `, prioridad ${accion.prioridad_plan}` : ""}${accion.plan_aproximado ? " (aproximada)" : ""}.${SECTORES[id].nota ? ` ${SECTORES[id].nota}.` : ''}` },
    { titulo: 'Problema central', texto: `Contexto sectorial según el workflow de la C.R.A.: ${cifra(datos?.total_ha)} ha de extensión de referencia; ${cifra(datos?.probable_ha)} ha de manglar probable; ${cifra(datos?.por_revisar_ha)} ha por revisar; ${cifra(datos?.dosel_seco_ha)} ha con el dosel claramente más seco en 2026. Índice de riesgo medio: ${cifra(datos?.riesgo_medio)} en escala de 0 a 1 (mitad amenaza, mitad vulnerabilidad). Problema específico, causas y línea base del sitio: [diagnóstico participativo por completar]. Descripción aportada: ${accion.descripcion}` },
    { titulo: 'Objetivo general', texto: `Contribuir al manejo del manglar en ${SECTORES[id].largo} mediante ${TIPOS_ACCION[accion.tipo].etiqueta.toLocaleLowerCase('es-CO')} sobre ${numero(accion.hectareas)} ha propuestas, con participación comunitaria y seguimiento verificable.` },
    { titulo: 'Objetivos específicos', texto: '1. Validar el diagnóstico, la localización y los requerimientos con la comunidad y la C.R.A.\n2. Ejecutar las actividades autorizadas y documentar sus resultados.\n3. Monitorear los resultados a 3, 6 y 12 meses con fotografías ubicadas y metodología acordada.' },
    { titulo: 'Cadena de valor', texto: `Insumos: [personal, materiales, equipos y permisos por definir]. Actividades: diagnóstico, acuerdos comunitarios, ${TIPOS_ACCION[accion.tipo].etiqueta.toLocaleLowerCase('es-CO')}, mantenimiento y monitoreo. Productos: ${numero(accion.hectareas)} ha atendidas según el alcance autorizado e informes a 3, 6 y 12 meses. Resultados: [cambio esperado y línea base por validar]. Cronograma y responsables: [por acordar].` },
    { titulo: 'Indicadores y metas', texto: `Meta de área: ${numero(accion.hectareas)} ha; línea base: [por medir]. Supervivencia objetivo: ≥ 70 % a 12 meses, cuando exista siembra; para conservación o intervención hídrica, [indicador específico por acordar con la C.R.A.]. Medios de verificación: mediciones, actas y fotografías ubicadas; responsables: [por definir].` },
    { titulo: 'Carbono potencial a madurez', texto: `${numero(accion.hectareas)} ha × ${numero(CIFRAS.carbono_t_c_ha)} t C/ha = ${numero(accion.hectareas * CIFRAS.carbono_t_c_ha)} t C potenciales a madurez. Factor de referencia: workflow de la C.R.A. Es una estimación ilustrativa de existencias potenciales, no captura anual, adicionalidad, carbono medido ni créditos certificados. Requiere validación para el sitio y el tipo de acción.` },
    { titulo: 'Beneficiarios y participación', texto: `[número] familias; [número] participantes directos y [número] beneficiarios indirectos. Comunidad coparticipante: ${accion.comunidad_coparticipante || '[por acordar]'}. Acuerdos y aportes: [por documentar].` },
    { titulo: 'Presupuesto', texto: '[por costear por rubros]. Desglosar diagnóstico, trámites, materiales, personal, transporte, seguridad, mantenimiento y monitoreo. Moneda: pesos colombianos. Total y contrapartidas: [por calcular con cotizaciones].' },
    { titulo: 'Fuentes de financiación', texto: '[fuentes por gestionar]. Aportes comunitarios, recursos públicos, cooperación y aportes privados: [montos y compromisos por confirmar]. Ninguna financiación se presume aprobada.' },
  ];
}
export function plantillaMGA(accion: Accion, actor: Actor, sector: SectorProyecto): PlantillaProyecto {
  return { titulo: `Plantilla MGA · ${accion.nombre}`, secciones: contexto(accion, actor, sector) };
}
export function notaConceptual(accion: Accion, actor: Actor, sector: SectorProyecto): PlantillaProyecto {
  const secciones = contexto(accion, actor, sector);
  return { titulo: `Nota conceptual · ${accion.nombre}`, secciones: [
    secciones[0], secciones[1],
    { titulo: 'Resumen de la propuesta', texto: `${accion.descripcion}\nProponente: ${actor.nombre}. Alcance: ${numero(accion.hectareas)} ha. Duración: [número] meses. Apoyo solicitado: [monto y modalidad por definir].` },
    ...secciones.slice(2),
    { titulo: 'Sostenibilidad y riesgos', texto: 'Mantenimiento, gobernanza comunitaria y continuidad del monitoreo: [acuerdos por completar]. Riesgos hidrológicos, climáticos y de participación: [evaluación y medidas por definir].' },
  ] };
}
export function textoPlano(plantilla: PlantillaProyecto): string {
  return `${plantilla.titulo}\n\n${plantilla.secciones.map((seccion) => `${seccion.titulo}\n${seccion.texto}`).join('\n\n')}\n`;
}
