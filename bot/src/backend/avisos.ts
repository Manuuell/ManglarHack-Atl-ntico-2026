import * as almacen from '../reportes/almacen';
import { ESTADOS_FINALES, Reporte } from '../reportes/modelo';
import { whatsapp } from '../whatsapp/cloudApi';
import { cambioDeEstado } from '../flujos/textos';
import { enlaceSeguimiento } from '../reportes/seguimiento';
import { backendActivo, estadoDeReportes } from './supabase';

/**
 * Aviso al ciudadano cuando la C.R.A. cambia el estado de su reporte.
 *
 * La C.R.A. cambia el estado en el panel con la RPC cambiar_estado de Supabase; el bot no recibe ningún
 * aviso de eso. Así que cada SONDEO_ESTADOS_MS pregunta con estado_de_reportes (RPC pública, por id) por los
 * reportes que se pueden avisar: enviados al backend, hechos «con mi número» (consentimiento identificado) y
 * todavía no cerrados ni descartados. Avisa una sola vez por cambio y guarda en el reporte el último estado
 * avisado (estadoAvisado), así un reinicio del bot no repite avisos.
 *
 * Un webhook del panel hacia el bot (más inmediato) queda para después: ver handoff/13.
 */

/** Después de estos intentos fallidos se deja de intentar avisar ese estado (y se espera al siguiente). */
const MAX_FALLIDOS = 3;

function avisables(): Reporte[] {
  return almacen.todos().filter(r =>
    r.envio?.estado === 'enviado' && r.contacto && !ESTADOS_FINALES.has(r.estadoAvisado ?? 'recibido'),
  );
}

let enCurso = false;

/** Una vuelta del sondeo. Devuelve cuántos avisos salieron. */
export async function sondearEstados(): Promise<number> {
  if (!backendActivo() || enCurso) return 0;
  enCurso = true;
  let avisos = 0;
  try {
    const lista = avisables();
    for (let i = 0; i < lista.length; i += 100) {
      const lote = lista.slice(i, i + 100);
      let estados;
      try {
        estados = await estadoDeReportes(lote.map(r => r.id));
      } catch (err) {
        console.warn(`[avisos] no se pudo leer el estado: ${(err as Error).message.slice(0, 200)}`);
        return avisos;
      }
      for (const e of estados) {
        const r = lote.find(x => x.id === e.id);
        if (!r) continue;
        if (e.id_publico) r.idPublico ??= e.id_publico;
        if (r.estado !== e.estado) {
          r.historial.push({ estado: e.estado, fecha: e.actualizado_en, por: 'cra (backend)', ...(e.nota_publica ? { nota: e.nota_publica } : {}) });
          r.estado = e.estado;
        }
        r.prioridad = e.prioridad;
        r.confianza = e.confianza;
        if (e.estado === (r.estadoAvisado ?? 'recibido')) continue;
        try {
          await whatsapp.texto(r.contacto!, cambioDeEstado(r.codigo, e.estado, e.nota_publica, enlaceSeguimiento(r.id)));
          r.estadoAvisado = e.estado;
          r.avisoFallidos = 0;
          avisos++;
          console.log(`[avisos] ${r.codigo}: avisado «${e.estado}»`);
        } catch (err) {
          // Fuera de la ventana de 24 horas WhatsApp exige una plantilla aprobada (handoff/13).
          r.avisoFallidos = (r.avisoFallidos ?? 0) + 1;
          console.warn(`[avisos] ${r.codigo}: no se pudo avisar «${e.estado}» (intento ${r.avisoFallidos}): ${(err as Error).message.slice(0, 200)}`);
          if (r.avisoFallidos >= MAX_FALLIDOS) {
            r.estadoAvisado = e.estado;
            r.avisoFallidos = 0;
            console.warn(`[avisos] ${r.codigo}: se deja de intentar «${e.estado}»; el estado sigue visible en «Mis reportes»`);
          }
        }
      }
      almacen.actualizar(lote[0]);
    }
    return avisos;
  } finally {
    enCurso = false;
  }
}
