import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../comunidad/comunidad.dart';
import '../servidor.dart';
import 'contenido_panel.dart';

/// Lo que el equipo editó en el panel, tal como lo ve la app de todos (Inicio, Comunidad).
/// Empieza en los valores de fábrica: sin `contenido_editable.sql` la app se ve como siempre.
final ValueNotifier<ContenidoPanel> contenidoPublico = ValueNotifier(ContenidoPanel.fabrica);

const _claveCopia = 'contenido_publico_copia_v1';
Future<void>? _carga;

/// Lo trae UNA vez por sesión (las demás llamadas esperan la misma): primero la copia del
/// teléfono, luego el servidor con plazo corto. Nunca lanza.
Future<void> cargarContenidoPublico({Servidor? servidor, Future<SharedPreferences> Function()? preferencias}) =>
    _carga ??= _cargar(servidor ?? Servidor(), preferencias ?? SharedPreferences.getInstance);

/// Solo para pruebas.
@visibleForTesting
void reiniciarContenidoPublico() {
  _carga = null;
  contenidoPublico.value = ContenidoPanel.fabrica;
}

Future<void> _cargar(Servidor s, Future<SharedPreferences> Function() prefs) async {
  try {
    final t = (await prefs()).getString(_claveCopia);
    if (t != null) {
      contenidoPublico.value =
          ContenidoPanel.deFilas([for (final f in jsonDecode(t) as List) Map<String, dynamic>.from(f as Map)]);
    }
  } catch (_) {}
  if (!s.configurado) return;
  try {
    final res = await s
        .pedir('GET', Uri.parse('${s.base}/rest/v1/ajustes_panel?select=clave,valor'),
            {'apikey': s.anon, 'Authorization': 'Bearer ${s.anon}'})
        .timeout(const Duration(seconds: 5));
    if (res.statusCode >= 300) return; // sin la tabla: fábrica (o la copia)
    final filas = [for (final f in jsonDecode(res.body) as List) Map<String, dynamic>.from(f as Map)];
    contenidoPublico.value = ContenidoPanel.deFilas(filas);
    (await prefs()).setString(_claveCopia, jsonEncode(filas));
  } catch (_) {}
}

/// Noticias con lo que decidió el equipo: sin las ocultas y con las fijadas arriba (en su orden).
List<NoticiaManglar> aplicarAjustesNoticias(List<NoticiaManglar> lista, [ContenidoPanel? c]) {
  final a = c ?? contenidoPublico.value;
  if (a.fijadas.isEmpty && a.ocultas.isEmpty) return lista;
  final visibles = [for (final n in lista) if (!a.ocultas.contains(n.id)) n];
  return [
    for (final n in visibles) if (a.fijadas.contains(n.id)) n,
    for (final n in visibles) if (!a.fijadas.contains(n.id)) n,
  ];
}

/// Igual, para un lote de Comunidad: espera la carga (con su plazo) y conserva el origen.
Future<Lote<List<NoticiaManglar>>> ajustarLoteNoticias(Lote<List<NoticiaManglar>> l) async {
  await cargarContenidoPublico();
  return Lote(aplicarAjustesNoticias(l.datos), l.origen, l.cuando);
}
