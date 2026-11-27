import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../experiencia/jornada.dart';
import '../servidor.dart';
import '../tipos.dart';
import 'comunidad.dart';

/// Un reporte del feed «Lo que reporta la comunidad»: real (Supabase `reportes_publicos` o datos
/// abiertos del servidor, WhatsApp incluido) o SIMULADO para la demostración.
///
/// Los simulados se muestran SIEMPRE rotulados «Simulado» y nunca entran en las cifras reales.
class ReporteFeed {
  const ReporteFeed(this.publico, {this.canal = 'app', this.simulado = false, this.prueba = false});
  final ReportePublico publico;
  final String canal;
  final bool simulado;

  /// Reporte de prueba del bot: visible, pero fuera de las cifras.
  final bool prueba;
  bool get porWhatsapp => canal == 'whatsapp';
}

/// Nombre legible de las 4 zonas reales del manglar (los ids de `manglar_zonas.json`).
const nombresZona = {
  'mallorquin': 'Ciénaga de Mallorquín',
  'piojo': 'Ciénaga del Totumo',
  'tubara': 'Costa de Tubará',
  'juan_de_acosta': 'Costa de Juan de Acosta',
};
String nombreZona(String id) => nombresZona[id] ?? (id.isEmpty ? 'Atlántico' : id);

const assetSimulados = 'assets/datos/reportes_simulados.json';

/// Lee los simulados del asset. Las horas son relativas (`hace_min`) para que siempre se vean recientes.
List<ReporteFeed> simuladosDeTexto(String texto, {DateTime? ahora}) {
  final j = jsonDecode(texto);
  final filas = j is Map ? j['reportes'] : null;
  if (filas is! List) return const [];
  final t = ahora ?? DateTime.now();
  return [
    for (final f in filas)
      if (f is Map && f['lat'] is num && f['lon'] is num)
        ReporteFeed(
          ReportePublico(
            id: '${f['id']}',
            tipo: TipoAmenaza.deSlug('${f['tipo']}'),
            punto: LatLng((f['lat'] as num).toDouble(), (f['lon'] as num).toDouble()),
            prioridad: (f['prioridad'] as num?)?.toInt() ?? 3,
            estado: EstadoReporte.deSlug('${f['estado']}'),
            capturadoEn: t.subtract(Duration(minutes: (f['hace_min'] as num?)?.toInt() ?? 60)),
            zona: '${f['zona'] ?? ''}',
          ),
          canal: '${f['canal'] ?? 'app'}',
          simulado: true,
        ),
  ];
}

/// Se puede cambiar en pruebas.
Future<List<ReporteFeed>> Function() cargaSimulados = () async {
  try {
    return simuladosDeTexto(await rootBundle.loadString(assetSimulados));
  } catch (_) {
    return const [];
  }
};

/// Une los reales (datos abiertos primero, porque traen el canal; luego Supabase) sin repetir por id,
/// y les suma los simulados. Todo de lo más nuevo a lo más viejo.
List<ReporteFeed> unirFeed({
  List<ReporteComunidad> abiertos = const [],
  List<ReportePublico> supabase = const [],
  List<ReporteFeed> simulados = const [],
}) {
  final vistos = <String>{};
  bool fuera(ReportePublico p) => p.estado == EstadoReporte.descartado;
  final salida = <ReporteFeed>[
    for (final r in abiertos)
      if (!fuera(r.publico) && vistos.add(r.publico.id)) ReporteFeed(r.publico, canal: r.canal, prueba: r.prueba),
    for (final p in supabase)
      if (!fuera(p) && vistos.add(p.id)) ReporteFeed(p, prueba: esReporteDePrueba(codigo: p.id)),
    for (final s in simulados)
      if (vistos.add(s.publico.id)) s,
  ]..sort((a, b) => b.publico.capturadoEn.compareTo(a.publico.capturadoEn));
  return salida;
}

/// «Ver en el mapa»: el punto que el mapa debe enfocar al abrirse (lo consume y lo deja en null).
final puntoPedidoMapa = ValueNotifier<LatLng?>(null);

/// Cuenta solo los reales: los simulados y los de prueba del bot nunca se suman a las cifras.
int contarReales(List<ReporteFeed> feed) => feed.where((r) => !r.simulado && !r.prueba).length;

// ------------------------------------------------------------------ eventos

/// Una jornada de la cartelera y si viene del respaldo de la app (no del servidor).
class EventoCartelera {
  const EventoCartelera(this.jornada, {this.respaldo = false});
  final Jornada jornada;
  final bool respaldo;
}

const assetJornadasRespaldo = 'assets/datos/jornadas_respaldo.json';

Future<List<Jornada>> Function() cargaJornadasRespaldo = () async {
  try {
    final j = jsonDecode(await rootBundle.loadString(assetJornadasRespaldo));
    final filas = j is Map ? j['jornadas'] : j;
    return [
      for (final f in (filas as List))
        if (f is Map) Jornada.fromJson(f),
    ];
  } catch (_) {
    return const [];
  }
};

/// Las próximas jornadas del servidor; si son menos de [minimo], se completan con las del respaldo
/// (rotuladas), sin repetir por id ni por título. De la más cercana a la más lejana.
List<EventoCartelera> completarCartelera(List<Jornada> servidor, List<Jornada> respaldo,
    {int minimo = 3, DateTime? ahora}) {
  final t = ahora ?? DateTime.now();
  bool vigente(Jornada j) => j.fin.isAfter(t) && !j.cancelada;
  final reales = [for (final j in servidor) if (vigente(j)) EventoCartelera(j)];
  final ids = {for (final e in reales) e.jornada.id};
  final titulos = {for (final e in reales) e.jornada.titulo.trim().toLowerCase()};
  final extra = reales.length >= minimo
      ? const <EventoCartelera>[]
      : [
          for (final j in respaldo)
            if (vigente(j) && !ids.contains(j.id) && !titulos.contains(j.titulo.trim().toLowerCase()))
              EventoCartelera(j, respaldo: true),
        ];
  return [...reales, ...extra.take(minimo - reales.length < 0 ? 0 : minimo - reales.length + 1)]
    ..sort((a, b) => a.jornada.inicio.compareTo(b.jornada.inicio));
}
