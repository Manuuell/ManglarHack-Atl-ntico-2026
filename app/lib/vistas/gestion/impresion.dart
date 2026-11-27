import 'impresion_stub.dart' if (dart.library.js_interop) 'impresion_web.dart' as plataforma;

bool get puedeImprimirCartel => plataforma.puedeImprimirCartel;
void imprimirCartel(String titulo, String codigo, String imagenBase64) =>
    plataforma.imprimirCartel(titulo, codigo, imagenBase64);
bool get puedeDescargarQr => plataforma.puedeDescargarQr;
void descargarQr(String nombre, String imagenBase64) => plataforma.descargarQr(nombre, imagenBase64);
