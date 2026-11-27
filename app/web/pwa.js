// Se carga antes de Flutter para registrar la copia local y exponer el estado a Dart.
(function () {
  'use strict';
  let nuevaVersion = false;
  let conexion = navigator.onLine ? '' : 'Sin señal · Puedes seguir usando Zanky';
  let registro;
  let recargaPendiente = false;
  const arranque = document.getElementById('arranque-flutter');

  window.zankyVersionNueva = () => nuevaVersion;
  window.zankyEstadoConexion = () => conexion;
  window.zankyActualizar = () => {
    if (!registro || !registro.waiting) return;
    recargaPendiente = true;
    registro.waiting.postMessage({ tipo: 'ACTUALIZAR' });
  };
  window.zankyNfcDisponible = () => 'NDEFReader' in window && window.isSecureContext;
  window.zankyNfcGrabar = async (enlace) => {
    if (!window.zankyNfcDisponible()) throw new Error('NFC no disponible');
    // write() conserva el gesto del botón y solicita permiso al navegador.
    await new NDEFReader().write({ records: [{ recordType: 'url', data: enlace }] });
  };

  // Instalar la app web: se guarda el aviso del navegador para mostrarlo cuando el visitante toque «Instalar».
  let avisoInstalar = null;
  window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); avisoInstalar = e; });
  window.addEventListener('appinstalled', () => { avisoInstalar = null; });
  // iPhone/iPad: Safari no ofrece aviso de instalación; se explica «Compartir → Agregar a inicio».
  window.zankyEsIos = () => /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  window.zankyInstalada = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  window.zankyPuedeInstalar = () => avisoInstalar !== null;
  window.zankyInstalar = async () => {
    if (!avisoInstalar) return 'no';
    const e = avisoInstalar;
    avisoInstalar = null;
    await e.prompt();
    const r = await e.userChoice;
    return r && r.outcome === 'accepted' ? 'si' : 'no';
  };

  window.addEventListener('offline', () => {
    conexion = 'Sin señal · Puedes seguir usando Zanky';
  });
  window.addEventListener('online', () => {
    conexion = 'Reconectado';
    setTimeout(() => { if (navigator.onLine) conexion = ''; }, 5000);
    buscarActualizacion();
  });

  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (recargaPendiente) location.reload();
  });

  async function registrar(nombreArranque) {
    try {
      // La huella del arranque incluye el nombre del JS principal tras el renombrado de publicación.
      const url = new URL(nombreArranque || arranque.getAttribute('src'), document.baseURI);
      const texto = await (await fetch(url, { cache: 'no-store' })).text();
      const datos = new TextEncoder().encode(texto);
      const huella = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', datos)))
        .map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 20);
      const nombres = texto.match(/[\w.-]*main(?:[\w.-]*)?\.js/g) || [];
      const principal = nombres.find((n) => n.includes('main')) || 'main.dart.js';
      const sw = new URL('service_worker.js', document.baseURI);
      sw.searchParams.set('v', huella);
      sw.searchParams.set('arranque', url.pathname.split('/').pop());
      sw.searchParams.set('principal', principal);
      // El mismo motor que elige el cargador de Flutter: la copia «chromium» (5,8 MB) en Chrome/Edge y la
      // completa (7,2 MB) en el resto. Así la copia local guarda solo el que este navegador usa.
      sw.searchParams.set('motor', motorCanvasKit());
      registro = await navigator.serviceWorker.register(sw.href, { scope: new URL('./', document.baseURI).pathname });
      const revisar = () => { nuevaVersion = Boolean(registro.waiting && navigator.serviceWorker.controller); };
      revisar();
      registro.addEventListener('updatefound', () => {
        const instalando = registro.installing;
        instalando?.addEventListener('statechange', revisar);
      });
      // El navegador puede conservar una página abierta durante toda la jornada.
    } catch (_) {
      // Sin señal, el controlador anterior sigue atendiendo la aplicación.
    }
  }
  function motorCanvasKit() {
    const chromium = typeof ImageDecoder !== 'undefined' && typeof Intl.v8BreakIterator !== 'undefined' &&
      typeof Intl.Segmenter !== 'undefined';
    return chromium ? 'chromium' : 'completo';
  }
  async function buscarActualizacion() {
    try {
      const respuesta = await fetch(new URL('index.html', document.baseURI), { cache: 'no-store' });
      if (!respuesta.ok) return;
      const documento = new DOMParser().parseFromString(await respuesta.text(), 'text/html');
      const nuevoArranque = documento.getElementById('arranque-flutter')?.getAttribute('src');
      if (nuevoArranque) await registrar(nuevoArranque);
    } catch (_) { /* La búsqueda se repite al recuperar señal. */ }
  }
  window.addEventListener('focus', buscarActualizacion);
  // Primera visita: la copia local se arma DESPUÉS del primer cuadro de Flutter, para no competir por la red
  // con el motor y el código de la app (en 3G eran ~13 MB a la vez). Si el primer cuadro no llega, a los 8 s.
  let registrado = false;
  const registrarUnaVez = () => { if (!registrado) { registrado = true; registrar(); } };
  if (navigator.serviceWorker.controller) {
    // Ya hay copia local: se revisa si cambió apenas cargue la página.
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', registrarUnaVez);
    else registrarUnaVez();
  } else {
    window.addEventListener('flutter-first-frame', () => setTimeout(registrarUnaVez, 300), { once: true, capture: true });
    setTimeout(registrarUnaVez, 8000);
  }
})();
