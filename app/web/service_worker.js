// La consulta v se calcula de la huella SHA-256 del arranque del build publicado.
const parametros = new URL(self.location.href).searchParams;
const version = parametros.get('v') || 'sin-huella';
const nombreCache = `zanky-app-${version}`;
const prefijo = 'zanky-app-';
const raiz = new URL(self.registration.scope);
const url = (ruta) => new URL(ruta, raiz).href;
const principal = parametros.get('principal') || 'main.dart.js';
const arranque = parametros.get('arranque') || 'flutter_bootstrap.js';

const webp = [
  'zanky-celebrando.webp', 'zanky-curioso.webp', 'zanky-feliz.webp', 'zanky-preocupado.webp',
  ...[1, 2, 3, 4, 5].flatMap((n) => [`etapas/etapa-${n}.webp`, `etapas/etapa-${n}-sola.webp`]),
].map((nombre) => `assets/assets/zanky/${nombre}`);
const recursos = [
  './', 'index.html', arranque, principal, 'pwa.js', 'manifest.json', 'favicon.png',
  'zanky-arranque.webp', 'og-zanky.png',
  'icons/Icon-192.png', 'icons/Icon-512.png',
  'icons/Icon-maskable-192.png', 'icons/Icon-maskable-512.png', 'icons/apple-touch-icon.png',
  'assets/AssetManifest.bin', 'assets/FontManifest.json',
  'fuentes/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2',
  'assets/assets/datos/jornadas_respaldo.json', 'assets/assets/datos/manglar_zonas.json',
  'assets/assets/datos/prioridades_cra.json',
  'assets/packages/flutter_map/lib/assets/flutter_map_logo.png',
  // Fotos del manglar (bienvenida, pantalla del punto, próximo evento): sin ellas la app abre gris sin señal.
  ...['manglar-raices-cartagena', 'garza-mallorquin', 'sendero-mallorquin', 'cano-san-bernardo']
    .map((f) => `assets/assets/fotos/${f}.webp`),
  ...webp,
];
// CanvasKit es indispensable: se guarda solo la variante que usa este navegador (la elige pwa.js igual que
// el cargador de Flutter). Antes se bajaba la completa aquí y la de Chrome desde el CDN: 13 MB en vez de 6.
const carpetaMotor = parametros.get('motor') === 'chromium' ? 'canvaskit/chromium/' : 'canvaskit/';
const motor = [`${carpetaMotor}canvaskit.js`, `${carpetaMotor}canvaskit.wasm`];
const motorOpcional = [];

self.addEventListener('install', (evento) => {
  evento.waitUntil((async () => {
    const cache = await caches.open(nombreCache);
    await cache.addAll([...new Set([...recursos, ...motor].map(url))]);
    const fuentes = await (await cache.match(url('assets/FontManifest.json'))).json();
    await cache.addAll([...new Set(fuentes.flatMap((familia) =>
      familia.fonts.map((fuente) => url(`assets/${fuente.asset}`))))]);
    await Promise.all(motorOpcional.map(async (ruta) => {
      try {
        const respuesta = await fetch(url(ruta));
        if (respuesta.ok) await cache.put(url(ruta), respuesta);
      } catch (_) { /* Este motor no forma parte de todas las compilaciones. */ }
    }));
    // Si es la primera visita, queda activo sin pedir una actualización vacía.
    if (!self.registration.active) await self.skipWaiting();
  })());
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil((async () => {
    await Promise.all((await caches.keys())
      .filter((nombre) => nombre.startsWith(prefijo) && nombre !== nombreCache)
      .map((nombre) => caches.delete(nombre)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (evento) => {
  if (evento.data?.tipo === 'ACTUALIZAR') self.skipWaiting();
});

const jornadas = 'https://mimanglar.sentralabs.co/datos/jornadas.json';
function esEntrada(solicitud) {
  const ruta = new URL(solicitud.url).pathname;
  return solicitud.mode === 'navigate' || ruta === raiz.pathname || ruta === new URL('index.html', raiz).pathname;
}

self.addEventListener('fetch', (evento) => {
  const solicitud = evento.request;
  if (solicitud.method !== 'GET') return;
  const destino = new URL(solicitud.url);
  const entrada = esEntrada(solicitud);
  if (destino.origin !== raiz.origin && destino.href !== jornadas) return;
  if (entrada || destino.href === jornadas) {
    evento.respondWith((async () => {
      const cache = await caches.open(nombreCache);
      const control = new AbortController();
      // Sin señal no se espera a la red: se abre la copia local al instante. Con señal floja, 1,5 s como
      // máximo para la portada (antes 3,5 s) y 3 s para las jornadas.
      const guardada = entrada ? await cache.match(url('index.html')) : null;
      if (entrada && guardada && self.navigator.onLine === false) return guardada;
      const limite = setTimeout(() => control.abort(), entrada && guardada ? 1500 : 3000);
      try {
        const respuesta = await fetch(solicitud, { signal: control.signal });
        if (respuesta.ok) {
          try { await cache.put(entrada ? url('index.html') : solicitud, respuesta.clone()); }
          catch (_) { /* La lectura de red sigue disponible si el almacenamiento está lleno. */ }
        }
        return respuesta;
      } catch (_) {
        if (entrada) return guardada || Response.error();
        return await cache.match(solicitud) ||
          await cache.match(url('assets/assets/datos/jornadas_respaldo.json')) || Response.error();
      } finally {
        clearTimeout(limite);
      }
    })());
    return;
  }
  if (!destino.pathname.startsWith(raiz.pathname)) return;
  evento.respondWith((async () => {
    const cache = await caches.open(nombreCache);
    const guardada = await cache.match(solicitud);
    if (guardada) return guardada;
    const respuesta = await fetch(solicitud);
    if (respuesta.ok) await cache.put(solicitud, respuesta.clone());
    return respuesta;
  })());
});

// Tocar un aviso de Zanky: trae al frente la pestaña abierta (o abre la app) y le dice qué
// aviso abrir; la app lleva al lugar exacto (alerta en el mapa, jornada o reporte).
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const clave = evento.notification.data && evento.notification.data.clave;
  evento.waitUntil((async () => {
    const ventanas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const ventana = ventanas.find((v) => v.url.startsWith(self.registration.scope));
    if (ventana) {
      await ventana.focus();
      if (clave) ventana.postMessage({ tipo: 'zanky-aviso', clave });
      return;
    }
    await self.clients.openWindow(self.registration.scope + (clave ? `?aviso=${encodeURIComponent(clave)}` : ''));
  })());
});