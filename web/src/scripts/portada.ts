// Portada: cabecera que se vuelve cápsula al bajar, entradas al hacer scroll, el visor del manglar
// en vivo, la conversación con Zanky, el boceto del panel y las descargas de datos abiertos.
import type { ReportePublico, ZonasManglar } from '../types/manglar';
import { exportarCSV, exportarGeoJSON, exportarKML } from '../lib/exportar';

interface PuntoVisor { id: string; caso: string; tipo: string; lat: number; lon: number; prioridad: number; estado: string; zona: string | null; color: string; reciente: boolean }
interface DatosPortada { sectores: ZonasManglar; reportes: PuntoVisor[]; exportar: ReportePublico[] }

const reducir = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Integra la navegación con el hero y la convierte en cápsula al avanzar. */
function montarCabeceraFlotante(): void {
  const cabecera = document.getElementById('cab');
  if (!cabecera) return;
  const actualizar = () => cabecera.classList.toggle('flotante', window.scrollY > 24);
  actualizar();
  window.addEventListener('scroll', actualizar, { passive: true });
}

/** Revela cada bloque una sola vez cuando entra en el campo visual. */
function montarRevelados(): void {
  const elementos = [...document.querySelectorAll<HTMLElement>('[data-reveal]')];
  if (!elementos.length) return;
  if (reducir() || !('IntersectionObserver' in window)) {
    elementos.forEach((e) => e.classList.add('is-in'));
    return;
  }
  elementos.forEach((e) => { if (e.dataset.revealDelay) e.style.transitionDelay = `${e.dataset.revealDelay}ms`; });
  const observador = new IntersectionObserver((entradas) => {
    for (const entrada of entradas) {
      if (!entrada.isIntersecting) continue;
      entrada.target.classList.add('is-in');
      observador.unobserve(entrada.target);
    }
  }, { threshold: 0.15, rootMargin: '0px 0px -12% 0px' });
  elementos.forEach((e) => observador.observe(e));
}

/** Corre una animación cuando la caja entra en pantalla; la detiene y la deja al final si se va. */
function alVerse(caja: Element, iniciar: () => void, terminar: () => void): void {
  if (reducir() || !('IntersectionObserver' in window)) { terminar(); return; }
  let corriendo = false;
  let hecha = false;
  new IntersectionObserver((entradas) => {
    const r = Math.max(...entradas.map((e) => e.intersectionRatio));
    if (r >= 0.4 && !corriendo && !hecha) { corriendo = true; iniciar(); }
    if (r < 0.05 && corriendo) { corriendo = false; hecha = true; terminar(); }
  }, { threshold: [0, 0.05, 0.4] }).observe(caja);
}

/** El visor del hero: sectores de manglar y reportes ciudadanos sobre el mapa. */
async function montarVisor(datos: DatosPortada): Promise<void> {
  const caja = document.getElementById('visor-mapa');
  if (!caja) return;
  const [{ default: L }] = await Promise.all([import('leaflet'), import('leaflet/dist/leaflet.css')]);
  const mapa = L.map(caja, {
    zoomControl: false, attributionControl: true, scrollWheelZoom: false, dragging: !L.Browser.mobile,
    tap: false, keyboard: false,
  } as L.MapOptions);
  // Imagen satelital: se ve el manglar de verdad debajo de los sectores.
  L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
    maxZoom: 18, attribution: 'Imágenes © Esri, Maxar, Earthstar Geographics',
  }).addTo(mapa);
  const sectores = L.geoJSON(datos.sectores, {
    style: () => ({ color: '#f8d86f', weight: 2, fillColor: '#4ade80', fillOpacity: 0.18, dashArray: '4 4' }),
    onEachFeature: (f, capa) => capa.bindTooltip(`Sector ${f.properties?.nombre ?? ''}`, { sticky: true }),
  }).addTo(mapa);
  for (const r of datos.reportes) {
    const icono = L.divIcon({ className: `pin-reporte${r.reciente ? ' ahora' : ''}`, html: `<span style="--c:${r.color}"></span>`, iconSize: [16, 16] });
    L.marker([r.lat, r.lon], { icon: icono, keyboard: false })
      .bindPopup(`<b>${r.caso}</b> · ${r.tipo}<br>${r.zona ?? ''} · prioridad ${r.prioridad} · ${r.estado}<br><small>Ubicación aproximada · dato de ejemplo</small>`)
      .addTo(mapa);
  }
  const ajustar = () => mapa.fitBounds(sectores.getBounds(), { padding: [40, 40] });
  ajustar();
  new ResizeObserver(() => { mapa.invalidateSize(); ajustar(); }).observe(caja);
}

/** La conversación con Zanky aparece mensaje a mensaje. */
function montarChat(): void {
  const caja = document.getElementById('chat');
  const boton = document.getElementById('chat-repetir');
  if (!caja || !boton) return;
  const mensajes = [...caja.querySelectorAll<HTMLElement>('.msg')];
  let reloj = 0;
  const mostrarTodo = () => { clearTimeout(reloj); mensajes.forEach((m) => m.classList.add('visto')); boton.hidden = false; };
  const reproducir = () => {
    clearTimeout(reloj);
    boton.hidden = true;
    mensajes.forEach((m) => m.classList.remove('visto'));
    let i = 0;
    const siguiente = () => {
      mensajes[i]?.classList.add('visto');
      i += 1;
      if (i < mensajes.length) reloj = window.setTimeout(siguiente, mensajes[i].classList.contains('zanky') ? 900 : 700);
      else boton.hidden = false;
    };
    reloj = window.setTimeout(siguiente, 300);
  };
  boton.addEventListener('click', reproducir);
  alVerse(caja, reproducir, mostrarTodo);
}

/** Boceto del panel: la confianza se arma por capas y el caso pasa de recibido a alerta oficial. */
function montarPanel(): void {
  const caja = document.getElementById('demo-panel');
  const barra = document.getElementById('gd-conf-barra');
  const numero = document.getElementById('gd-conf');
  const estado = document.getElementById('gd-estado');
  const boton = document.getElementById('gd-repetir');
  if (!caja || !barra || !numero || !estado || !boton) return;
  const motivos = [...caja.querySelectorAll<HTMLElement>('#gd-motivos span')];
  const pasos = [...caja.querySelectorAll<HTMLElement>('#gd-pasos span')];
  const textos = ['Llega el reporte con foto y GPS…', 'Un vigía revisa la evidencia…', 'Confirmado por una persona', 'Se abre el expediente: alerta oficial'];
  const tope = 80; // el servidor acepta del cliente hasta 80; el resto lo suben la IA y las personas
  let relojes: number[] = [];
  const limpiar = () => { relojes.forEach(clearTimeout); relojes = []; };
  const pintar = (puntos: number, paso: number, encendidos: number) => {
    barra.style.width = `${Math.min(100, (puntos / 100) * 100)}%`;
    numero.textContent = String(puntos);
    motivos.forEach((m, i) => m.classList.toggle('on', i < encendidos));
    pasos.forEach((p, i) => { p.classList.toggle('on', i <= paso); p.classList.toggle('final', i === pasos.length - 1 && i <= paso); });
    estado.textContent = textos[Math.max(0, paso)];
  };
  const final = () => { limpiar(); pintar(tope, pasos.length - 1, motivos.length); boton.hidden = false; };
  const reproducir = () => {
    limpiar();
    boton.hidden = true;
    pintar(0, 0, 0);
    let suma = 0;
    motivos.forEach((m, i) => {
      relojes.push(window.setTimeout(() => { suma = Math.min(tope, suma + Number(m.dataset.p ?? 0)); pintar(suma, 0, i + 1); }, 500 + i * 650));
    });
    const base = 500 + motivos.length * 650;
    [1, 2, 3].forEach((paso, k) => relojes.push(window.setTimeout(() => pintar(tope, paso, motivos.length), base + 300 + k * 900)));
    relojes.push(window.setTimeout(() => { boton.hidden = false; }, base + 300 + 3 * 900));
  };
  boton.addEventListener('click', reproducir);
  pintar(0, 0, 0);
  alVerse(caja, reproducir, final);
}

/** Descargas de datos abiertos con las mismas funciones que el monitoreo. */
function montarDescargas(datos: DatosPortada): void {
  const acciones: Record<string, () => void> = {
    geojson: () => exportarGeoJSON(datos.exportar),
    csv: () => exportarCSV(datos.exportar),
    kml: () => exportarKML(datos.exportar),
  };
  document.querySelectorAll<HTMLButtonElement>('[data-exportar]').forEach((b) => {
    b.addEventListener('click', () => acciones[b.dataset.exportar ?? '']?.());
  });
}

export function montarPortada(): void {
  const nodo = document.getElementById('datos-portada');
  const datos = nodo ? (JSON.parse(nodo.textContent ?? '{}') as DatosPortada) : null;
  montarCabeceraFlotante();
  montarRevelados();
  montarChat();
  montarPanel();
  if (datos) {
    montarDescargas(datos);
    const visor = () => void montarVisor(datos).catch(() => document.querySelector('.visor')?.classList.add('sin-mapa'));
    if ('requestIdleCallback' in window) window.requestIdleCallback(visor, { timeout: 800 });
    else setTimeout(visor, 200);
  }
}
