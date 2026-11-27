/**
 * Saca coordenadas de lo que la persona escribe: "11.04, -74.86" o un enlace de Google Maps.
 * Los enlaces cortos (maps.app.goo.gl) se expanden siguiendo redirecciones, pero solo hacia
 * dominios de Google Maps, para no convertir el bot en un proxy hacia cualquier URL.
 */

const HOSTS_PERMITIDOS = new Set(['maps.app.goo.gl', 'goo.gl', 'maps.google.com', 'www.google.com', 'google.com', 'maps.google.com.co', 'www.google.com.co']);

function valida(lat: number, lon: number): { lat: number; lon: number } | null {
  return Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 ? { lat, lon } : null;
}

const NUM = String.raw`(-?\d{1,3}(?:\.\d+)?)`;

export function coordenadasEnTexto(texto: string): { lat: number; lon: number } | null {
  let t = texto.replace(/\+/g, ' ');
  try {
    t = decodeURIComponent(t);
  } catch {
    // Texto con "%" sueltos: se usa tal cual.
  }
  const patrones = [
    new RegExp(String.raw`@${NUM},${NUM}`),                       // .../@11.04,-74.86,15z
    new RegExp(String.raw`[?&](?:q|query|ll|destination)=${NUM},\s*${NUM}`),
    new RegExp(String.raw`!3d${NUM}!4d${NUM}`),                    // datos internos de Maps
    new RegExp(String.raw`^\s*${NUM}\s*[,; ]\s*${NUM}\s*$`),       // "11.04, -74.86"
  ];
  for (const p of patrones) {
    const m = t.match(p);
    if (m) {
      const r = valida(Number(m[1]), Number(m[2]));
      if (r) return r;
    }
  }
  return null;
}

function primeraUrl(texto: string): URL | null {
  const m = texto.match(/https?:\/\/\S+/);
  if (!m) return null;
  try {
    return new URL(m[0]);
  } catch {
    return null;
  }
}

/** Intenta obtener coordenadas del texto; si es un enlace corto de Maps, lo expande (máximo 4 saltos). */
export async function ubicacionDesdeTexto(texto: string): Promise<{ lat: number; lon: number } | null> {
  const directa = coordenadasEnTexto(texto);
  if (directa) return directa;
  let url = primeraUrl(texto);
  for (let salto = 0; url && salto < 4; salto++) {
    if (url.protocol !== 'https:' || !HOSTS_PERMITIDOS.has(url.hostname)) return null;
    const coords = coordenadasEnTexto(url.toString());
    if (coords) return coords;
    try {
      const res = await fetch(url, { method: 'GET', redirect: 'manual', signal: AbortSignal.timeout(5_000) });
      const destino = res.headers.get('location');
      if (!destino) return null;
      url = new URL(destino, url);
    } catch {
      return null;
    }
  }
  return url ? coordenadasEnTexto(url.toString()) : null;
}
