import type { Jornada } from '../../types/plataforma';

const escapar = (texto: string) => texto.replace(/\\/g, '\\\\').replace(/\r\n|\r|\n/g, '\\n').replace(/;/g, '\\;').replace(/,/g, '\\,');
const utc = (fecha: string | Date) => new Date(fecha).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
function plegar(linea: string): string {
  const partes: string[] = [];
  const codificador = new TextEncoder();
  let actual = '', bytes = 0;
  for (const caracter of linea) {
    const longitud = codificador.encode(caracter).length;
    if (bytes + longitud > 74) { partes.push(actual); actual = ''; bytes = 0; }
    actual += caracter;
    bytes += longitud;
  }
  partes.push(actual);
  return partes.join('\r\n ');
}
export function generarICS(jornada: Jornada, url: string): string {
  return [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Zanqui//Jornadas del manglar//ES',
    'CALSCALE:GREGORIAN', 'METHOD:PUBLISH', 'BEGIN:VEVENT',
    `UID:${escapar(jornada.id)}@zanqui.ejemplo.org`, `DTSTAMP:${utc(new Date())}`,
    `DTSTART:${utc(jornada.inicio)}`, `DTEND:${utc(jornada.fin)}`,
    `SUMMARY:${escapar(jornada.titulo)}`, `LOCATION:${escapar(jornada.punto_encuentro)}`,
    `DESCRIPTION:${escapar(`${jornada.descripcion}\nQué llevar: ${jornada.que_llevar.join(', ')}\nEnlace: ${url}`)}`,
    `GEO:${jornada.lat};${jornada.lon}`, 'END:VEVENT', 'END:VCALENDAR', '',
  ].map(plegar).join('\r\n');
}
export function descargarICS(jornada: Jornada, url: string): void {
  if (typeof document === 'undefined') return;
  const enlace = document.createElement('a');
  const recurso = URL.createObjectURL(new Blob([generarICS(jornada, url)], { type: 'text/calendar;charset=utf-8' }));
  enlace.href = recurso;
  enlace.download = `${jornada.titulo.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'jornada-del-manglar'}.ics`;
  document.body.append(enlace);
  enlace.click();
  enlace.remove();
  setTimeout(() => URL.revokeObjectURL(recurso), 1000);
}
export function enlaceInvitacionWhatsApp(jornada: Jornada, url: string): string {
  const fecha = new Intl.DateTimeFormat('es-CO', { dateStyle: 'long', timeStyle: 'short', timeZone: 'America/Bogota' }).format(new Date(jornada.inicio));
  const texto = `Te invitamos a ${jornada.titulo}.\n${fecha} (hora de Colombia).\nPunto de encuentro: ${jornada.punto_encuentro}.\nQué llevar: ${jornada.que_llevar.join(', ')}.\n${jornada.descripcion}\nConsulta los cupos y la inscripción: ${url}`;
  return `https://wa.me/?text=${encodeURIComponent(texto)}`;
}
export async function copiarEnlace(url: string): Promise<boolean> {
  if (typeof document === 'undefined') return false;
  try { await navigator.clipboard.writeText(url); return true; } catch { /* Respaldo para contextos sin Clipboard API. */ }
  const anterior = document.activeElement;
  const seleccion = document.getSelection();
  const rangos = seleccion ? Array.from({ length: seleccion.rangeCount }, (_, i) => seleccion.getRangeAt(i).cloneRange()) : [];
  const campo = document.createElement('textarea');
  campo.value = url;
  campo.setAttribute('aria-label', 'Enlace de invitación');
  campo.style.cssText = 'position:fixed;left:-9999px;top:0;';
  document.body.append(campo);
  campo.select();
  try { return document.execCommand('copy'); }
  catch { return false; }
  finally {
    campo.remove();
    if (anterior instanceof HTMLElement) anterior.focus({ preventScroll: true });
    if (seleccion) { seleccion.removeAllRanges(); rangos.forEach((rango) => seleccion.addRange(rango)); }
  }
}
