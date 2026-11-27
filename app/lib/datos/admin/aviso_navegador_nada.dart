// Sin navegador no hay Notification API: en el teléfono el aviso es el de dentro de la app.
bool disponible() => false;

String permiso() => 'unsupported';

Future<bool> pedirPermiso() async => false;

void mostrar(String titulo, String cuerpo) {}
