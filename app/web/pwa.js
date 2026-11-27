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
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', registrar);
  else registrar();
})();
