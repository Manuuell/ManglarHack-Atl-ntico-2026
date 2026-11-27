import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Avisos del sistema en la web. Con el service worker de la app (PWA instalada o pestaña en
/// segundo plano) se usa `registration.showNotification`, que también funciona en Chrome de
/// Android, donde `new Notification()` no existe. Sin service worker, el aviso clásico.
/// El permiso nunca se pide aquí: lo pide [CentroAvisos.activarNavegador] desde un toque.
bool concedido() {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

Future<void> mostrar(String titulo, String cuerpo, String clave, void Function(String) alTocar) async {
  if (!concedido()) return;
  final opciones = web.NotificationOptions(
    body: cuerpo,
    tag: clave, // el mismo aviso reemplaza, nunca se apila repetido
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-maskable-192.png',
    data: {'clave': clave}.jsify(),
  );
  try {
    final sw = web.window.navigator.serviceWorker;
    final registro = await sw.getRegistration().toDart.timeout(const Duration(seconds: 2));
    if (registro != null) {
      await registro.showNotification(titulo, opciones).toDart;
      return;
    }
  } catch (_) {}
  try {
    final n = web.Notification(titulo, opciones);
    n.onclick = ((web.Event _) {
      web.window.focus();
      n.close();
      alTocar(clave);
    }).toJS;
  } catch (_) {
    // El navegador no deja crearlo: quedan la campana y la píldora de la app.
  }
}

/// El service worker avisa qué notificación se tocó (ver `notificationclick` en service_worker.js).
void escucharToques(void Function(String) alTocar) {
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.MessageEvent e) {
        final d = e.data.dartify();
        if (d is Map && d['tipo'] == 'zanky-aviso' && d['clave'] is String) alTocar(d['clave'] as String);
      }).toJS,
    );
  } catch (_) {}
}

/// `?aviso=…` cuando la app se abrió desde un aviso con la pestaña cerrada.
String? avisoDeLaDireccion() => Uri.base.queryParameters['aviso'];
