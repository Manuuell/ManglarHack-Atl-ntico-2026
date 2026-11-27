import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../servidor.dart';
import '../tipos.dart';

/// Lo de comunidad que muestra la web (mimanglar.sentralabs.co), leído de LAS MISMAS fuentes:
///
/// | Dato | Fuente (igual que la web) | Archivo de la web |
/// |---|---|---|
/// | Alertas del manglar | `GET zanqui.sentralabs.co/alertas` | `components/comunidad/AlertasManglar.tsx` |
/// | Reportes de la comunidad (WhatsApp y web) | `GET zanqui.sentralabs.co/datos-abiertos/reportes.geojson` | servidor `reportes/datosAbiertos.ts` |
/// | Noticias del manglar | WordPress de la C.R.A. (`/wp-json/wp/v2/posts`, búsquedas «manglar» y «Mallorquín») | `lib/craApi.ts` |
/// | Inscripción a jornadas | `POST zanqui.sentralabs.co/api/jornadas/:id/inscripciones` | `lib/plataforma/jornadasApi.ts` |
///
/// Las jornadas salen de `FuenteJornadas` (`experiencia/jornada.dart`) y el ranking de colegios de
/// `RankingColegios` (`crecimiento/ranking_colegios.dart`): no se duplican aquí.
///
/// Cada fuente guarda en el teléfono la última respuesta buena: sin señal se muestra esa, con su hora.
const urlZanky = 'https://zanqui.sentralabs.co';
const noticiasCra = 'https://www.crautonoma.gov.co/wp-json/wp/v2/posts';

/// Límites de la franja costera del manglar (los mismos de `web/src/lib/areaReporte.ts`).
bool enFranjaManglar(double lat, double lon) => lat >= 10.655 && lat <= 11.09 && lon >= -75.285 && lon <= -74.795;

enum OrigenDato { red, cache, nada }

/// Una lectura con su procedencia: de la red ahora, o la última guardada (y cuándo llegó).
class Lote<T> {
  const Lote(this.datos, this.origen, this.cuando);
  final T datos;
  final OrigenDato origen;
  final DateTime? cuando;
  bool get sinSenal => origen != OrigenDato.red;
}

/// Pide un texto con plazo y lo guarda; si la red falla, devuelve lo guardado.
class LectorConCache {
  LectorConCache({http.Client? cliente, this.plazo = const Duration(seconds: 15)}) : _http = cliente ?? http.Client();
  final http.Client _http;
  final Duration plazo;

  Future<Lote<T>> leer<T>(String clave, Uri uri, T Function(String) convertir, T vacio) async {
    try {
      final r = await _http.get(uri, headers: {'Accept': 'application/json'}).timeout(plazo);
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final texto = utf8.decode(r.bodyBytes);
      final datos = convertir(texto); // si no se entiende, no se guarda
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('comunidad.$clave', texto);
        await p.setInt('comunidad.$clave.t', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
      return Lote(datos, OrigenDato.red, DateTime.now());
    } catch (_) {
      try {
        final p = await SharedPreferences.getInstance();
        final texto = p.getString('comunidad.$clave');
        final t = p.getInt('comunidad.$clave.t');
        if (texto != null) {
          return Lote(convertir(texto), OrigenDato.cache, t == null ? null : DateTime.fromMillisecondsSinceEpoch(t));
        }
      } catch (_) {}
      return Lote(vacio, OrigenDato.nada, null);
    }
  }
}

// ------------------------------------------------------------------ alertas

enum NivelAlerta {
  amarilla('Alerta amarilla'),
  naranja('Alerta naranja'),
  roja('Alerta roja');

  const NivelAlerta(this.texto);
  final String texto;
  static NivelAlerta deSlug(String? s) =>
      NivelAlerta.values.firstWhere((n) => n.name == s, orElse: () => NivelAlerta.amarilla);
}

/// Los íconos de la web (AlertasManglar.tsx), uno por tipo de alerta.
const iconoAlerta = {
  'mar_de_leva': '🌊',
  'inundacion_costera': '🌕',
  'lluvia_fuerte': '🌧️',
  'vendaval': '💨',
  'riesgo_incendio': '🔥',
  'foco_calor': '🛰️',
  'amenaza_ciudadana': '📣',
};
const nombreFuente = {'ideam': 'IDEAM', 'dimar': 'DIMAR', 'mareas': 'DIMAR · CIOH', 'cra': 'C.R.A.', 'comunidad': 'Comunidad'};

class AlertaManglar {
  const AlertaManglar({
    required this.id,
    required this.tipo,
    required this.nivel,
    required this.titulo,
    required this.detalle,
    required this.recomendacion,
    required this.lugar,
    required this.punto,
    required this.desde,
    required this.hasta,
    required this.medido,
    required this.fuentes,
  });
  final String id, tipo, titulo, detalle, recomendacion, lugar;
  final NivelAlerta nivel;
  final LatLng? punto;
  final DateTime desde, hasta;
  final bool medido;
  final List<String> fuentes;

  String get icono => iconoAlerta[tipo] ?? '⚠️';
  String get fuentesTexto => fuentes.map((f) => nombreFuente[f] ?? f).join(' + ');

  static AlertaManglar? deJson(Object? v) {
    if (v is! Map) return null;
    final desde = DateTime.tryParse('${v['desde']}');
    final titulo = v['titulo'];
    if (desde == null || titulo is! String) return null;
    final lat = v['lat'], lon = v['lon'];
    return AlertaManglar(
      id: '${v['id']}',
      tipo: '${v['tipo']}',
      nivel: NivelAlerta.deSlug(v['nivel'] as String?),
      titulo: titulo,
      detalle: v['detalle'] as String? ?? '',
      recomendacion: v['recomendacion'] as String? ?? '',
      lugar: v['lugar'] as String? ?? '',
      punto: lat is num && lon is num ? LatLng(lat.toDouble(), lon.toDouble()) : null,
      desde: desde.toLocal(),
      hasta: (DateTime.tryParse('${v['hasta']}') ?? desde).toLocal(),
      medido: v['medido'] == true,
      fuentes: [for (final f in (v['fuentes'] as List? ?? const [])) '$f'],
    );
  }
}

/// Una cifra de «Ahora» (viento, lluvia, ola, pleamar, calor), con los textos de la web.
class CifraAhora {
  const CifraAhora(this.icono, this.titulo, this.valor, this.pie);
  final String icono, titulo, valor, pie;
}

class EstadoFuente {
  const EstadoFuente(this.nombre, this.ok);
  final String nombre;
  final bool ok;
}

class ResultadoInscripcion {
  const ResultadoInscripcion.hecha(this.inscritos) : ok = true, mensaje = '';
  const ResultadoInscripcion.falla(this.mensaje) : ok = false, inscritos = null;
  final bool ok;
  final String mensaje;
  final int? inscritos;
}

class ResultadoAlertas {
  const ResultadoAlertas({
    required this.generado,
    required this.alertas,
    required this.ahora,
    required this.fuentes,
    required this.nota,
    this.simulacro = false,
  });
  final DateTime? generado;
  final List<AlertaManglar> alertas;
  final List<CifraAhora> ahora;
  final List<EstadoFuente> fuentes;
  final String nota;
  final bool simulacro;

  /// Una alerta por lugar: el servidor repite la misma ciénaga (p. ej. varias amenazas ciudadanas);
  /// se deja la de nivel más alto y se cuenta cuántas más hay allí. Nunca dos niveles para el mismo sitio.
  List<(AlertaManglar, int)> get porLugar {
    final grupos = <String, List<AlertaManglar>>{};
    for (final a in alertas) {
      grupos.putIfAbsent(a.lugar.isEmpty ? a.id : a.lugar, () => []).add(a);
    }
    final salida = [
      for (final g in grupos.values) ((g..sort((a, b) => b.nivel.index.compareTo(a.nivel.index))).first, g.length - 1),
    ]..sort((a, b) => b.$1.nivel.index.compareTo(a.$1.nivel.index));
    return salida;
  }

  NivelAlerta? get nivelMaximo => alertas.isEmpty
      ? null
      : alertas.map((a) => a.nivel).reduce((a, b) => a.index >= b.index ? a : b);

  static const vacio = ResultadoAlertas(generado: null, alertas: [], ahora: [], fuentes: [], nota: '');

  static String _n(num v, [int dec = 1]) {
    final t = v.toStringAsFixed(dec);
    final limpio = t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
    return limpio.replaceAll('.', ',');
  }

  static ResultadoAlertas deTexto(String texto) {
    final j = jsonDecode(texto);
    if (j is! Map || j['alertas'] is! List) throw const FormatException('sin alertas');
    final a = j['ahora'] is Map ? j['ahora'] as Map : const {};
    final ahora = <CifraAhora>[];
    final viento = a['viento_ms'];
    if (viento is num) {
      ahora.add(CifraAhora('💨', 'Viento ahora', '${_n(viento)} m/s', '${_n(viento * 3.6)} km/h · ${a['viento_estacion'] ?? 'IDEAM'}'));
    }
    final lluvia = a['lluvia_24h_mm'];
    if (lluvia is num) {
      ahora.add(CifraAhora('🌧️', 'Lluvia en 24 h', '${_n(lluvia)} mm', 'La más alta, en ${a['lluvia_estacion'] ?? 'IDEAM'}'));
    }
    final ola = a['ola_max_m'];
    if (ola is num) {
      final cuando = DateTime.tryParse('${a['ola_cuando']}');
      ahora.add(CifraAhora('🌊', 'Ola más alta (3 días)', '${_n(ola)} m',
          [if (cuando != null) cuandoTexto(cuando.toLocal()), if (a['ola_lugar'] is String) a['ola_lugar']].join(' · ')));
    }
    final plea = a['proxima_pleamar'];
    if (plea is Map && plea['m'] is num) {
      final t = DateTime.tryParse('${plea['t']}');
      ahora.add(CifraAhora('🌕', 'Próxima pleamar', '${_n(plea['m'] as num, 2)} m',
          '${t == null ? '' : cuandoTexto(t.toLocal())} · Barranquilla'));
    }
    final calor = a['temp_max_pronostico_c'];
    if (calor is num) ahora.add(CifraAhora('🌡️', 'Calor máximo (24 h)', '${_n(calor)} °C', 'Pronóstico DIMAR en la costa'));
    return ResultadoAlertas(
      generado: DateTime.tryParse('${j['generado']}')?.toLocal(),
      simulacro: j['simulacro'] == true,
      alertas: [for (final x in j['alertas'] as List) ?AlertaManglar.deJson(x)],
      ahora: ahora,
      fuentes: [
        for (final f in (j['fuentes'] as List? ?? const []))
          if (f is Map) EstadoFuente('${f['nombre']}', f['ok'] == true),
      ],
      nota: j['nota'] as String? ?? '',
    );
  }
}

// ------------------------------------------------------------------ reportes de la comunidad

/// Pasa el nombre que publica el servidor («Basuras o residuos», «Tala de mangle»…) al tipo de la app.
TipoAmenaza tipoDeNombre(String nombre) {
  final n = nombre.toLowerCase();
  for (final t in TipoAmenaza.values) {
    if (t.nombre.toLowerCase() == n || t.slug == n) return t;
  }
  if (n.contains('tala')) return TipoAmenaza.tala;
  if (n.contains('quema') || n.contains('incendio')) return TipoAmenaza.quema;
  if (n.contains('relleno') || n.contains('constru')) return TipoAmenaza.relleno;
  if (n.contains('vertim') || n.contains('contamin')) return TipoAmenaza.vertimiento;
  if (n.contains('caño') || n.contains('cano')) return TipoAmenaza.canoTaponado;
  if (n.contains('fauna')) return TipoAmenaza.fauna;
  if (n.contains('basura') || n.contains('residuo')) return TipoAmenaza.basuras;
  return TipoAmenaza.otro;
}

EstadoReporte estadoDeNombre(String nombre) {
  final n = nombre.toLowerCase();
  for (final e in EstadoReporte.values) {
    if (e.nombre.toLowerCase() == n || e.slug == n) return e;
  }
  return EstadoReporte.recibido;
}

/// Un reporte de la comunidad, con el canal (WhatsApp o app/web) que la web también muestra.
class ReporteComunidad {
  const ReporteComunidad(this.publico, this.canal);
  final ReportePublico publico;
  final String canal;
}

/// GeoJSON de datos abiertos del servidor de Zanky (coordenadas a 3 decimales, sin descripción
/// ni contacto). Los descartados no salen.
List<ReporteComunidad> reportesDeGeoJson(String texto) {
  final j = jsonDecode(texto);
  if (j is! Map || j['features'] is! List) throw const FormatException('sin features');
  final salida = <ReporteComunidad>[];
  for (final f in j['features'] as List) {
    if (f is! Map) continue;
    final p = f['properties'], g = f['geometry'];
    if (p is! Map || g is! Map || g['coordinates'] is! List) continue;
    final c = g['coordinates'] as List;
    if (c.length < 2 || c[0] is! num || c[1] is! num) continue;
    final fecha = DateTime.tryParse('${p['fecha']}');
    final codigo = p['codigo'];
    if (fecha == null || codigo is! String) continue;
    final estado = estadoDeNombre('${p['estado'] ?? ''}');
    if (estado == EstadoReporte.descartado) continue;
    salida.add(ReporteComunidad(
      ReportePublico(
        id: codigo,
        tipo: tipoDeNombre('${p['tipo'] ?? ''}'),
        punto: LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        prioridad: (p['prioridad'] as num?)?.toInt() ?? 3,
        estado: estado,
        capturadoEn: fecha.toLocal(),
        zona: p['zona'] as String? ?? '',
      ),
      p['canal'] as String? ?? 'whatsapp',
    ));
  }
  salida.sort((a, b) => b.publico.capturadoEn.compareTo(a.publico.capturadoEn));
  return salida;
}

/// Suma dos listas de reportes sin repetir ninguno por id (el primero que llega se queda).
List<ReportePublico> sumarSinDuplicar(List<ReportePublico> a, List<ReportePublico> b) {
  final vistos = <String>{};
  return [
    for (final r in [...a, ...b])
      if (vistos.add(r.id)) r,
  ];
}

// ------------------------------------------------------------------ noticias

class NoticiaManglar {
  const NoticiaManglar({
    required this.id,
    required this.fecha,
    required this.titulo,
    required this.resumen,
    required this.parrafos,
    required this.enlace,
    required this.imagen,
  });
  final int id;
  final DateTime fecha;
  final String titulo, resumen, enlace;
  final List<String> parrafos;
  final String? imagen;
  String get fuente => 'C.R.A. · Prensa';
}

const _entidades = {
  '&nbsp;': ' ', '&amp;': '&', '&quot;': '"', '&#8220;': '“', '&#8221;': '”', '&#8216;': '‘', '&#8217;': '’',
  '&#8211;': '–', '&#8212;': '—', '&#8230;': '…', '&hellip;': '…', '&lt;': '<', '&gt;': '>', '&#038;': '&', '&#39;': "'",
};

/// Quita etiquetas y entidades HTML (como `textoPlano` de la web): nunca se pinta HTML.
String textoPlano(String html) {
  var t = html.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'<[^>]+>'), ' ');
  _entidades.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Los párrafos del cuerpo de la noticia, para leerla dentro de la app.
List<String> parrafosDe(String html) {
  final bloques = RegExp(r'<(p|h[1-6]|li)[^>]*>([\s\S]*?)</\1>', caseSensitive: false).allMatches(html);
  final salida = [
    for (final b in bloques)
      if (textoPlano(b[2]!).length > 2) textoPlano(b[2]!),
  ];
  return salida.isEmpty ? [if (textoPlano(html).isNotEmpty) textoPlano(html)] : salida;
}

/// Une las dos búsquedas de la web («manglar» y «Mallorquín»), sin repetir, de la más nueva a la más vieja.
List<NoticiaManglar> noticiasDeTexto(String texto, {int cantidad = 8}) {
  final j = jsonDecode(texto);
  if (j is! List) throw const FormatException('sin noticias');
  final porId = <int, NoticiaManglar>{};
  for (final p in j) {
    if (p is! Map || p['id'] is! num) continue;
    final fecha = DateTime.tryParse('${p['date']}');
    if (fecha == null) continue;
    final sizes = (((p['_embedded'] as Map?)?['wp:featuredmedia'] as List?)?.firstOrNull as Map?)?['media_details'];
    final tam = sizes is Map ? sizes['sizes'] as Map? : null;
    String? img;
    for (final k in ['medium_large', 'medium', 'large', 'full']) {
      final u = (tam?[k] as Map?)?['source_url'];
      if (u is String) {
        img = u;
        break;
      }
    }
    final enlace = '${p['link']}';
    porId[(p['id'] as num).toInt()] = NoticiaManglar(
      id: (p['id'] as num).toInt(),
      fecha: fecha,
      titulo: textoPlano('${(p['title'] as Map?)?['rendered'] ?? ''}'),
      resumen: textoPlano('${(p['excerpt'] as Map?)?['rendered'] ?? ''}'),
      parrafos: parrafosDe('${(p['content'] as Map?)?['rendered'] ?? ''}'),
      // Solo enlaces e imágenes del propio sitio de la C.R.A.
      enlace: enlace.startsWith('https://www.crautonoma.gov.co/') ? enlace : 'https://www.crautonoma.gov.co/prensa/noticias',
      imagen: img != null && img.startsWith('https://www.crautonoma.gov.co/') ? img : null,
    );
  }
  final lista = porId.values.toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
  return lista.take(cantidad).toList();
}

// ------------------------------------------------------------------ fuente única

/// Lee todo lo de comunidad con caché. Una instancia por app (ver [FuenteComunidad.compartida]).
class FuenteComunidad {
  FuenteComunidad({http.Client? cliente, this.base = urlZanky}) : _lector = LectorConCache(cliente: cliente);
  final LectorConCache _lector;
  final String base;

  static final compartida = FuenteComunidad();

  Future<Lote<ResultadoAlertas>> alertas() =>
      _lector.leer('alertas', Uri.parse('$base/alertas'), ResultadoAlertas.deTexto, ResultadoAlertas.vacio);

  Future<Lote<List<ReporteComunidad>>> reportes() => _lector.leer(
      'reportes', Uri.parse('$base/datos-abiertos/reportes.geojson'), reportesDeGeoJson, const <ReporteComunidad>[]);

  Future<Lote<List<NoticiaManglar>>> noticias() async {
    const campos = '_fields=id,date,title,link,excerpt,content,_links,_embedded&_embed=wp:featuredmedia';
    final [a, b] = await Future.wait([
      for (final q in ['manglar', 'Mallorquín'])
        _lector.leer('noticias.$q', Uri.parse('$noticiasCra?search=${Uri.encodeQueryComponent(q)}&per_page=6&$campos'),
            (t) => t, ''),
    ]);
    final unidos = [
      for (final l in [a, b])
        if (l.datos.isNotEmpty) ...(jsonDecode(l.datos) as List),
    ];
    final origen = a.origen == OrigenDato.red || b.origen == OrigenDato.red
        ? OrigenDato.red
        : (unidos.isEmpty ? OrigenDato.nada : OrigenDato.cache);
    return Lote(noticiasDeTexto(jsonEncode(unidos)), origen, a.cuando ?? b.cuando);
  }

  /// Inscripción a una jornada (el mismo contrato que usa la web: `POST /api/jornadas/:id/inscripciones`).
  /// Exige el consentimiento de datos; el celular es opcional (10 dígitos) y solo con él se avisa por WhatsApp.
  Future<ResultadoInscripcion> inscribirse(String jornadaId,
      {required String nombre, String? telefono, required bool aceptaDatos, bool aceptaWhatsapp = false}) async {
    if (!aceptaDatos) return const ResultadoInscripcion.falla('Para inscribirte, acepta el tratamiento de tus datos (Ley 1581).');
    try {
      final r = await _lector._http
          .post(Uri.parse('$base/api/jornadas/${Uri.encodeComponent(jornadaId)}/inscripciones'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'nombre': nombre.trim(),
                if (telefono != null && telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
                'acepta_datos': true,
                'acepta_whatsapp': aceptaWhatsapp,
              }))
          .timeout(const Duration(seconds: 20));
      Map? j;
      try {
        j = jsonDecode(utf8.decode(r.bodyBytes)) as Map?;
      } catch (_) {}
      if (r.statusCode == 201 || r.statusCode == 200) {
        return ResultadoInscripcion.hecha((j?['inscritos'] as num?)?.toInt());
      }
      final porEstado = {
        400: 'Revisa los datos: el servidor no los aceptó.',
        404: 'No encontramos esa jornada.',
        409: 'Esta jornada ya no tiene cupos.',
        429: 'Hiciste varias inscripciones seguidas. Espera unos minutos.',
      };
      return ResultadoInscripcion.falla(j?['mensaje'] as String? ?? porEstado[r.statusCode] ?? 'El servidor respondió ${r.statusCode}.');
    } catch (_) {
      return const ResultadoInscripcion.falla('No hay conexión con el servidor de Zanky. Revisa tu internet e inténtalo de nuevo.');
    }
  }
}

/// «hoy, 3:00 p. m.», «mañana, …», «ayer, …» o «vie 28, …» (como `cuando` de la web).
String cuandoTexto(DateTime d, [DateTime? ahora]) {
  final hoy = ahora ?? DateTime.now();
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final hora = '$h12:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
  final dia = DateTime(d.year, d.month, d.day);
  final base = DateTime(hoy.year, hoy.month, hoy.day);
  final dif = dia.difference(base).inDays;
  if (dif == 0) return 'hoy, $hora';
  if (dif == 1) return 'mañana, $hora';
  if (dif == -1) return 'ayer, $hora';
  const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  return '${dias[d.weekday - 1]} ${d.day}, $hora';
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
String fechaCorta(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

String haceCuanto(DateTime d, [DateTime? ahora]) {
  final min = (ahora ?? DateTime.now()).difference(d).inMinutes;
  if (min < 1) return 'hace un momento';
  if (min < 60) return 'hace $min min';
  final h = (min / 60).round();
  if (h < 24) return 'hace $h h';
  final dias = (h / 24).round();
  return 'hace $dias ${dias == 1 ? 'día' : 'días'}';
}
