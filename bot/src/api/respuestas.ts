import type { MensajeEntrante } from '../whatsapp/parser';
import { whatsapp } from '../whatsapp/cloudApi';
import * as J from './almacenJornadas';
import { normalizarTelefono } from './cuentas';

/**
 * Botón «No podré ir» de la invitación por plantilla (carga no_ire:<id de la jornada>): libera el cupo de
 * esa persona en la jornada y se lo confirma. Devuelve true si el mensaje era eso.
 */
export async function atenderRespuestaInvitacion(m: MensajeEntrante): Promise<boolean> {
  if (m.entrada.tipo !== 'opcion' || !m.entrada.id.startsWith('no_ire:')) return false;
  const j = J.jornada(m.entrada.id.slice('no_ire:'.length));
  const telefono = normalizarTelefono(m.de);
  const liberados = j && telefono ? J.cancelarPorTelefono(j.id, telefono) : 0;
  const texto = j
    ? `Gracias por avisar 🙏. ${liberados ? `Liberamos tu cupo en *${j.titulo}*` : `Tomamos nota: no irás a *${j.titulo}*`}, así otra persona puede ir.\n\nCuando quieras, escribe *jornadas* para ver las próximas. 🌱`
    : 'Gracias por avisar 🙏. Cuando quieras, escribe *jornadas* para ver las próximas. 🌱';
  await whatsapp.texto(m.de, texto);
  return true;
}
