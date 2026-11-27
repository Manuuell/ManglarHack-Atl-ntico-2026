import fs from 'fs';
import path from 'path';
import { config } from '../config';

/**
 * Un Map que sobrevive a los reinicios del bot: se guarda en DATA_DIR/<nombre>.json (escritura atómica, agrupada
 * en ráfagas de 300 ms) y se lee la primera vez que se usa. Sirve para lo que antes solo vivía en memoria y se
 * perdía en cada despliegue: la conversación en curso de cada persona y los ids de mensaje ya atendidos (Meta
 * reenvía un mensaje si no está segura de que llegó, y tras un reinicio el bot lo respondía otra vez).
 * Las entradas viejas se descartan al cargar con `vigente`.
 */
export class MapaPersistente<V> {
  private datos: Map<string, V> | null = null;
  private pendiente: NodeJS.Timeout | null = null;

  constructor(private readonly nombre: string, private readonly vigente: (v: V) => boolean) {}

  private ruta(): string {
    return path.join(config.dataDir, `${this.nombre}.json`);
  }

  private mapa(): Map<string, V> {
    if (this.datos) return this.datos;
    this.datos = new Map();
    try {
      const crudo = JSON.parse(fs.readFileSync(this.ruta(), 'utf8')) as Record<string, V>;
      for (const [k, v] of Object.entries(crudo)) if (this.vigente(v)) this.datos.set(k, v);
    } catch {
      /* primera vez o archivo dañado: se empieza vacío */
    }
    return this.datos;
  }

  get(k: string): V | undefined {
    return this.mapa().get(k);
  }

  has(k: string): boolean {
    return this.mapa().has(k);
  }

  /** Guarda (o vuelve a guardar tras cambiar el objeto por dentro). */
  set(k: string, v: V): void {
    this.mapa().set(k, v);
    this.guardarLuego();
  }

  delete(k: string): void {
    if (this.mapa().delete(k)) this.guardarLuego();
  }

  entries(): IterableIterator<[string, V]> {
    return this.mapa().entries();
  }

  /** Quita lo que ya no está vigente. */
  limpiar(): void {
    for (const [k, v] of this.mapa()) if (!this.vigente(v)) this.mapa().delete(k);
    this.guardarLuego();
  }

  private guardarLuego(): void {
    if (this.pendiente) return;
    this.pendiente = setTimeout(() => this.guardarYa(), 300);
    this.pendiente.unref?.();
  }

  /** Escribe ya (al apagar el proceso). */
  guardarYa(): void {
    if (this.pendiente) clearTimeout(this.pendiente);
    this.pendiente = null;
    if (!this.datos) return;
    try {
      fs.mkdirSync(config.dataDir, { recursive: true });
      const tmp = `${this.ruta()}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(Object.fromEntries(this.datos)));
      fs.renameSync(tmp, this.ruta());
    } catch (err) {
      console.warn(`[persistente] no se pudo guardar ${this.nombre}: ${(err as Error).message}`);
    }
  }
}
