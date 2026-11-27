// Flutter sustituye estas dos marcas durante la compilación.
{{flutter_js}}
{{flutter_build_config}}

// El service worker de Zanky se registra desde pwa.js.
// El motor (CanvasKit) se sirve desde la misma carpeta y no desde el CDN de Google: así queda en la copia
// local del service worker y la app abre sin señal en la jornada.
_flutter.loader.load({ config: { canvasKitBaseUrl: 'canvaskit/' } });
