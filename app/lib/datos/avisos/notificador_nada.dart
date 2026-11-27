// Fuera de la web no hay Notification API: en el teléfono avisan la campana y la píldora.
bool concedido() => false;

Future<void> mostrar(String titulo, String cuerpo, String clave, void Function(String) alTocar) async {}

void escucharToques(void Function(String) alTocar) {}

String? avisoDeLaDireccion() => null;
