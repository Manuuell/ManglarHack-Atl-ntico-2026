import { MUNICIPIOS, ROLES, TIPOS } from '../reportes/modelo';
import { PROPONENTES, TIPOS_PROPUESTA } from '../api/almacenPropuestas';
import { detectarAmenaza } from './amenaza';

/**
 * Entiende una respuesta escrita (o dictada por nota de voz) como si fuera el botón del paso en curso:
 * «sí» en el consentimiento, «quema» en el tipo, «ahora» en cuándo, «grande» en el tamaño, «sí, envíalo» en el
 * resumen… Devuelve el id del botón o undefined. `t` llega normalizado (minúsculas, sin tildes ni signos).
 */

const SI = /^(si|sii+|claro|dale|listo|ok|okey|de una|acepto|de acuerdo|correcto|confirmo|confirmar|esta bien|bueno|va|perfecto)\b/;
const NO = /^(no|nop|nel|para nada|no gracias)$/;

const sinTildes = (x: string) => x.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

/** Busca un id cuyo nombre (o el id mismo) aparezca en el texto. */
function porNombre(t: string, opciones: Record<string, { nombre: string }>, extra: Record<string, RegExp> = {}): string | undefined {
  for (const [id, re] of Object.entries(extra)) if (re.test(t)) return id;
  for (const [id, o] of Object.entries(opciones)) {
    const nombre = sinTildes(o.nombre).replace(/[^a-z0-9 ]/g, ' ').trim();
    const primera = nombre.split(/\s+/)[0];
    if (t === id.replace(/_/g, ' ') || t === nombre || (primera.length >= 4 && t.startsWith(primera))) return id;
  }
  return undefined;
}

export function opcionDesdeTexto(paso: string, t: string, original: string): string | undefined {
  if (!t) return undefined;
  switch (paso) {
    case 'consentimiento':
      if (/anonim/.test(t)) return 'anonimo';
      if (/^no acepto|^no quiero|^no$/.test(t)) return 'no_acepto';
      if (SI.test(t) || /con mi numero/.test(t)) return 'acepto';
      return undefined;
    case 'tipo':
      return detectarAmenaza(original) ?? porNombre(t, TIPOS, {
        cano_taponado: /\bcano\b|tapon|tapad/,
        basuras: /basura|residuo|desecho/,
        vertimiento: /vertim|aguas negras|contamina/,
        relleno: /rellen|escombro|construc/,
        fauna: /fauna|animal|peces|aves/,
        quema: /quema|incendio|fuego|humo/,
        tala: /\btala|cortan|cortando/,
      });
    case 'fuera_area':
    case 'prop_fuera_area':
      if (/cambiar|otra|otro sitio|otro lugar/.test(t)) return 'otra_ubicacion';
      return undefined;
    case 'foto':
      if (/sin foto|no tengo|no puedo|no hay foto|no tome|^no$/.test(t)) return 'sin_foto';
      return undefined;
    case 'descripcion':
      if (/^(omitir|no|nada|ninguna|ninguno|sin descripcion|paso)$/.test(t)) return 'omitir';
      return undefined;
    case 'cuando':
      if (/^(ahora|ya|en este momento|ahorita|ahora mismo|esta pasando)/.test(t)) return 'ahora';
      if (/^(hoy|esta manana|esta tarde|mas temprano|hace un rato|hace rato)/.test(t)) return 'hoy';
      if (/^(antes|ayer|antier|la semana|hace dias|hace unos dias|el mes|hace tiempo)/.test(t)) return 'antes';
      return undefined;
    case 'magnitud':
      if (/pequen|chiquit|poquit|poco|unos metros/.test(t)) return 'pequena';
      if (/median|regular|como una cancha/.test(t)) return 'mediana';
      if (/grande|enorme|mucho|inmens|mas que una cancha/.test(t)) return 'grande';
      return undefined;
    case 'confirmar':
      if (/corregir|cambiar|editar|arreglar/.test(t)) return 'reiniciar';
      if (SI.test(t) || /^(enviar|envialo|envia|mandalo|manda|enviarlo)/.test(t)) return 'enviar';
      return undefined;
    case 'prop_confirmar':
      if (/corregir|cambiar|editar|arreglar/.test(t)) return 'p_corregir';
      if (SI.test(t) || /^(enviar|envialo|envia|mandalo|manda|enviarlo)/.test(t)) return 'p_enviar';
      return undefined;
    case 'registro_inicio':
      if (/sin (mi )?nombre|anonim/.test(t)) return 'reg_anonimo';
      if (/^(ahora no|despues|luego|mas tarde)/.test(t) || NO.test(t)) return 'ahora_no';
      if (SI.test(t) || /registr/.test(t)) return 'registrarme';
      return undefined;
    case 'registro_rol':
      return porNombre(t, ROLES, { pescador: /pesca/, habitante: /habit|vivo|vecin/, estudiante: /estudi|colegio|universi/, turista: /turist|visit/ });
    case 'registro_municipio':
      return porNombre(t, Object.fromEntries(Object.entries(MUNICIPIOS).map(([k, v]) => [k, { nombre: v }])), { barranquilla: /barranquilla|quilla/ });
    case 'prop_tipo':
      return porNombre(t, TIPOS_PROPUESTA, { restauracion: /restaur|cano|agua/, emprendimiento: /emprend|producto|negocio/, educacion: /educa|taller|colegio/ });
    case 'prop_quien':
      return porNombre(t, PROPONENTES, { universidad: /universi|colegio|academ/, persona: /^yo\b|persona|ciudadan/, cra: /\bcra\b|corporacion/ });
    case 'jornada_confirmar':
      if (SI.test(t)) return 'ins_si';
      if (/otro nombre|cambiar nombre/.test(t)) return 'ins_nombre';
      return undefined;
    default:
      return undefined;
  }
}
