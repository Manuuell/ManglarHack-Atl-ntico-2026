import { config } from '../config';

/**
 * Enlace para que el ciudadano siga su caso en la web: <SEGUIMIENTO_URL>#caso=<uuid>.
 *
 * El número ZK-XXXX solo tiene 4 hex (65.536 valores): sirve para decirlo por teléfono, pero no para buscar un
 * reporte sin más, porque cualquiera recorrería todos los números y vería reportes ajenos (schema.sql, vista
 * reportes_publicos). La llave es el UUID, que ninguna vista publica. Va en el fragmento (#), que el navegador
 * no manda al servidor ni queda en los registros: la web lo lee y pregunta con estado_de_reportes([uuid]).
 * Sin SEGUIMIENTO_URL no se manda enlace (la web todavía no tiene esa página).
 */
export function enlaceSeguimiento(id: string): string | undefined {
  if (!config.seguimientoUrl) return undefined;
  return `${config.seguimientoUrl.replace(/#.*$/, '')}#caso=${id}`;
}
