import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Lato (la fuente empaquetada de la app) en las pruebas de pantalla. Sin esto el test mide
/// con la fuente cuadrada de prueba (Ahem) y da desbordes falsos. Úsala en `setUpAll`.
Future<void> cargarLato() async {
  final lato = FontLoader('Lato');
  for (final f in ['Regular', 'Bold', 'Black']) {
    final bytes = File('assets/fuentes/Lato-$f.ttf').readAsBytesSync();
    lato.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await lato.load();
}
