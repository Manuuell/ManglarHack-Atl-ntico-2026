import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../comunidad/comunidad.dart';
import '../experiencia/jornada.dart';
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

const _prefijoPanel = 'panel-';

/// Las jornadas abiertas que convocó el equipo desde el panel, como jornadas de la cartelera.
/// Las cerradas no salen (ya no reciben gente). Con el pin del mapa del panel; las viejas, sin
/// pin, quedan en 0,0 (el lugar va en el texto).
List<Jornada> jornadasDelPanel([ContenidoPanel? c]) => [
      for (final j in (c ?? contenidoPublico.value).jornadas)
        if (!j.cerrada)
          Jornada(
            id: '$_prefijoPanel${j.id}',
            accionId: '',
            titulo: j.titulo,
            tipo: '',
            inicio: j.fecha,
            fin: j.fecha.add(const Duration(hours: 3)),
            puntoEncuentro: j.lugar,
            lat: j.lat ?? 0,
            lon: j.lon ?? 0,
            cupos: j.cupos ?? 0,
            inscritos: 0,
            queLlevar: const [],
            descripcion: 'Convocada por el equipo de la CRA desde el panel.',
            imagenUrl: j.fotoUrl,
          ),
    ];

/// Las del panel no viven en el servidor del bot (que solo conoce sus jornadas): su inscripción
/// va a Supabase, a `inscripciones_panel` (`backend/supabase/inscripciones_panel.sql`).
bool esJornadaDelPanel(Jornada j) => esIdDelPanel(j.id);

bool esIdDelPanel(String id) => id.startsWith(_prefijoPanel);

/// Inscribe en una jornada del panel: una fila en `inscripciones_panel` con el consentimiento.
/// La política de la tabla deja insertar a cualquiera (con consentimiento) y leer solo al equipo
/// con `gestionar_jornadas`; por eso no se pide la fila de vuelta (`return=minimal`).
Future<ResultadoInscripcion> inscribirseEnJornadaDelPanel(
  String jornadaId, {
  required String nombre,
  String? telefono,
  required bool aceptaDatos,
  bool aceptaWhatsapp = false,
  Servidor? servidor,
}) async {
  if (!aceptaDatos) return const ResultadoInscripcion.falla('Para inscribirte, acepta el tratamiento de tus datos (Ley 1581).');
  final n = nombre.trim();
  if (n.length < 2) return const ResultadoInscripcion.falla('Escribe tu nombre.');
  final tel = telefono?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (tel.isNotEmpty && tel.length != 10) return const ResultadoInscripcion.falla('El celular debe tener 10 dígitos.');
  final s = servidor ?? Servidor();
  if (!s.configurado) {
    return const ResultadoInscripcion.falla('No hay conexión con el servidor de Zanky. Revisa tu internet e inténtalo de nuevo.');
  }
  final id = esIdDelPanel(jornadaId) ? jornadaId.substring(_prefijoPanel.length) : jornadaId;
  try {
    final res = await s.pedir(
      'POST',
      Uri.parse('${s.base}/rest/v1/inscripciones_panel'),
      {
        'apikey': s.anon,
        'Authorization': 'Bearer ${s.anon}',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      cuerpo: jsonEncode({
        'jornada_id': id,
        'nombre': n,
        if (tel.isNotEmpty) 'telefono': tel,
        'acepta_datos': true,
        'acepta_whatsapp': aceptaWhatsapp && tel.isNotEmpty,
      }),
    );
    if (res.statusCode < 300) return const ResultadoInscripcion.hecha(null);
    if (res.statusCode == 404) {
      return const ResultadoInscripcion.falla('Esta jornada aún no recibe inscripciones en línea: llega al punto de encuentro.');
    }
    if (res.statusCode == 409) return const ResultadoInscripcion.falla('Ya estás inscrito en esta jornada.');
    return ResultadoInscripcion.falla('El servidor respondió ${res.statusCode}. Inténtalo de nuevo en un momento.');
  } catch (_) {
    return const ResultadoInscripcion.falla('No hay conexión con el servidor de Zanky. Revisa tu internet e inténtalo de nuevo.');
  }
}
