import { useCallback, useSyncExternalStore } from 'react';

/** Almacén de demostración compartido por islas; no sustituye la API ni su autorización. */
export function crearAlmacen<T>(clave: string) {
  const claveLocal = 'zanqui-web:v1:' + clave;
  const oyentes = new Set<() => void>();
  let listo = false;
  let base: T;
  let valor: T;
  let escuchando = false;
  const avisar = () => oyentes.forEach((oyente) => oyente());
  const interpretar = (texto: string | null): T => {
    if (texto === null) return structuredClone(base);
    try { return JSON.parse(texto) as T; }
    catch {
      console.warn('No se pudieron leer los datos de demostración; se recuperan los valores iniciales.');
      return structuredClone(base);
    }
  };
  const leer = () => {
    try { valor = interpretar(window.localStorage.getItem(claveLocal)); }
    catch { console.warn('Almacenamiento local no disponible; se usará la memoria.'); }
  };
  const alCambiar = (evento: StorageEvent) => {
    if (!listo || (evento.key !== claveLocal && evento.key !== null)) return;
    try { if (evento.storageArea !== window.localStorage) return; } catch { return; }
    valor = interpretar(evento.newValue);
    avisar();
  };
  function inicializar(iniciales: T): void {
    // Nunca conservar datos de una petición SSR en el singleton de otra petición.
    if (typeof window === 'undefined' || listo) return;
    base = structuredClone(iniciales);
    valor = structuredClone(base);
    listo = true;
    leer();
  }
  function obtener(): T {
    if (!listo) throw new Error('Inicializa el almacén de demostración antes de usarlo.');
    return valor;
  }
  function establecer(fn: (previo: T) => T): void {
    const siguiente = fn(obtener());
    if (Object.is(siguiente, valor)) return;
    valor = siguiente;
    if (typeof window !== 'undefined') {
      try { window.localStorage.setItem(claveLocal, JSON.stringify(valor)); }
      catch { console.warn('No se pudo guardar la demostración; los cambios siguen disponibles en memoria.'); }
    }
    avisar();
  }
  function suscribir(oyente: () => void): () => void {
    oyentes.add(oyente);
    if (typeof window !== 'undefined' && !escuchando) {
      window.addEventListener('storage', alCambiar);
      escuchando = true;
      if (listo) { leer(); avisar(); }
    }
    return () => {
      oyentes.delete(oyente);
      if (!oyentes.size && escuchando) {
        window.removeEventListener('storage', alCambiar);
        escuchando = false;
      }
    };
  }
  function restablecer(): void {
    // La copia local se borra aunque esta página no haya usado el almacén:
    // así «Restablecer demostración» limpia también lo guardado en otras secciones.
    if (typeof window !== 'undefined') {
      try { window.localStorage.removeItem(claveLocal); }
      catch { console.warn('No se pudo borrar la copia local de la demostración.'); }
    }
    if (!listo) return;
    valor = structuredClone(base);
    avisar();
  }
  function usar(iniciales: T): T {
    inicializar(iniciales);
    const servidor = useCallback(() => iniciales, [iniciales]);
    return useSyncExternalStore(suscribir, obtener, servidor);
  }
  return { inicializar, obtener, establecer, suscribir, restablecer, usar };
}
