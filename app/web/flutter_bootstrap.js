// Flutter sustituye estas dos marcas durante la compilación.
{{flutter_js}}
{{flutter_build_config}}

// El service worker de Zanky se registra desde pwa.js.
// El motor (CanvasKit) se sirve desde la misma carpeta y no desde el CDN de Google: así queda en la copia
// local del service worker y la app abre sin señal en la jornada.
// La fuente de reserva (Roboto, recortada a latín, Apache 2.0) también se sirve en local desde fuentes/ y no desde
// fonts.gstatic.com: una petición menos a Google y la app abre igual sin señal.
_flutter.loader.load({ config: { canvasKitBaseUrl: 'canvaskit/', fontFallbackBaseUrl: 'fuentes/' } });
