import 'instalar_web_stub.dart' if (dart.library.js_interop) 'instalar_web_js.dart' as plataforma;

/// Ya corre como app instalada (pantalla de inicio).
bool appInstalada() => plataforma.appInstalada();

/// El navegador ofrece instalar (Chrome/Edge en Android y escritorio). En iPhone se explica a mano.
bool puedeInstalarApp() => plataforma.puedeInstalarApp();

/// iPhone o iPad: Safari no avisa; se explica «Compartir → Agregar a inicio».
bool esIos() => plataforma.esIos();

/// Muestra el aviso del navegador; true si el visitante aceptó.
Future<bool> instalarApp() => plataforma.instalarApp();
