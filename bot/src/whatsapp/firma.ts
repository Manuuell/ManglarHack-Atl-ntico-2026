import { createHmac, timingSafeEqual } from 'crypto';

/** Verifica el encabezado X-Hub-Signature-256 que Meta firma con el secreto de la app. */
export function firmaValida(cuerpoCrudo: Buffer | undefined, firma: string | undefined, secreto: string): boolean {
  if (!secreto || !cuerpoCrudo || !firma || !/^sha256=[a-f0-9]{64}$/i.test(firma)) return false;
  const esperada = Buffer.from(`sha256=${createHmac('sha256', secreto).update(cuerpoCrudo).digest('hex')}`);
  const recibida = Buffer.from(firma.toLowerCase());
  return esperada.length === recibida.length && timingSafeEqual(esperada, recibida);
}
