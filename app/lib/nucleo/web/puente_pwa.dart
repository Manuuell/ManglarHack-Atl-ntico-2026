import 'puente_pwa_stub.dart'
    if (dart.library.js_interop) 'puente_pwa_web.dart'
    as plataforma;

bool hayVersionNueva() => plataforma.hayVersionNueva();
String estadoConexion() => plataforma.estadoConexion();
void actualizarVersion() => plataforma.actualizarVersion();
