import { TipoId } from '../reportes/modelo';

/**
 * Reconoce si un texto libre ya describe una amenaza al manglar («están talando mangle en la ciénaga»,
 * «hay una quema», «botaron escombros»…), para ir directo a reportar sin pasar por el menú ni el registro.
 * Devuelve el tipo del contrato o undefined. Es a propósito conservador: una pregunta («¿qué es la tala?»)
 * o algo sobre jornadas («jornada de limpieza de basura») no cuenta; eso lo atiende el menú o la IA.
 */

const normalizar = (t: string) =>
  t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();

/** En orden de gravedad: si el texto nombra varias, gana la primera de esta lista. */
const PATRONES: [TipoId, RegExp][] = [
  ['tala', /\b(tal(a|an|ando|aron|ado|ados)|cort(an|ando|aron|ado) (el |los |un |unos )?mangl\w*|tumb(an|ando|aron) (el |los )?mangl\w*|arranc(an|ando|aron) (el |los )?mangl\w*|motosierra)\b/],
  ['quema', /\b(quem(a|an|ando|aron|ado|ada)|incendio|fuego|humareda)\b/],
  ['vertimiento', /\b(vert(imiento|iendo|ieron|ido)|aguas (negras|servidas|residuales)|aceite|quimicos?|alcantarill\w*|desague)\b/],
  ['relleno', /\b(rellen(o|an|ando|aron)|escombros?|construy(en|endo|eron)|construccion|invasion|lotean\w*)\b/],
  ['cano_taponado', /\b(cano|canos) ((esta|estan|quedo|quedaron|lo|los|fue|fueron) )?(tapad\w*|taponad\w*|bloquead\w*|cerrad\w*)\b|\b(taparon|taponaron|bloquearon) (el |un )?cano\b/],
  ['fauna', /\b(peces|pescados?|aves|pajaros?|tortugas?|babillas?|manaties?|iguanas?) muert\w*|\b(caza|cazando|cazaron|cazadores?)\b/],
  ['basuras', /\b(basura\w*|residuos|desechos|plasticos?|botadero)\b/],
];

const PREGUNTA = /^(que|como|por que|porque|cual|cuales|donde|cuando|quien|quienes|para que|sabes|me puedes|puedes)\b/;
const NO_ES_DENUNCIA = /\b(jornada\w*|siembra\w*|voluntari\w*|inscrib\w*|evento\w*)\b/;

export function detectarAmenaza(texto: string): TipoId | undefined {
  if (/[?¿]/.test(texto)) return undefined;
  const t = normalizar(texto);
  if (t.length < 4 || PREGUNTA.test(t) || NO_ES_DENUNCIA.test(t)) return undefined;
  return PATRONES.find(([, re]) => re.test(t))?.[0];
}
