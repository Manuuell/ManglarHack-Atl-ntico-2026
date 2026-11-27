import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../datos/servidor.dart';
import '../../datos/tipos.dart';
import '../../datos/zonas.dart';

/// Un punto del mapa: un reporte mío (con todos sus datos) o uno público (los pocos
/// que publica el servidor: tipo, lugar aproximado, prioridad y estado).
class PuntoMapa {
  PuntoMapa.mio(Reporte r)
      : id = r.id,
        punto = r.punto,
        prioridad = r.prioridad,
        tipo = r.tipo,
        capturadoEn = r.capturadoEn,
        zonaId = r.zonaId,
        estado = r.estado,
        mio = r,
        publico = null;

  PuntoMapa.publico(ReportePublico p)
      : id = p.id,
        punto = p.punto,
        prioridad = p.prioridad,
        tipo = p.tipo,
        capturadoEn = p.capturadoEn,
        zonaId = p.zona,
        estado = p.estado,
        mio = null,
        publico = p;

  final String id;
  final LatLng punto;
  final int prioridad;
  final TipoAmenaza tipo;
  final DateTime capturadoEn;
  final String zonaId;
  final EstadoReporte estado;
  final Reporte? mio;
  final ReportePublico? publico;

  bool get esMio => mio != null;

  /// Mío y todavía no llegó a la CRA: sigue solo en el teléfono.
  bool get enCola => mio != null && mio!.envio != Envio.enviado;

  /// «Late» si pasó hace menos de 3 h (la ventana de corroboración de la prioridad).
  bool esReciente(DateTime ahora) => ahora.difference(capturadoEn) < ventanaReciente;

  static const ventanaReciente = Duration(hours: 3);
}

/// Los míos primero (con sus datos completos); los públicos que ya son míos no se repiten.
/// [comunidad]: los reportes que la web también muestra (datos abiertos del servidor de Zanky,
/// WhatsApp incluido). Se suman a los de Supabase sin repetir ninguno por id.
List<PuntoMapa> construirPuntos(EstadoZanky e, {List<ReportePublico> comunidad = const []}) {
  final propios = {for (final r in e.reportes) ...[r.id, ?r.idPublico]};
  final vistos = <String>{};
  return [
    for (final r in e.reportes) PuntoMapa.mio(r),
    for (final p in [...e.publicos, ...comunidad])
      if (!propios.contains(p.id) && vistos.add(p.id)) PuntoMapa.publico(p),
  ];
}

/// Firma barata de lo que dibuja el mapa: si no cambia, no se recalcula nada.
int firmaPuntos(EstadoZanky e, {List<ReportePublico> comunidad = const []}) => Object.hash(
      Object.hashAll([for (final r in e.reportes) Object.hash(r.id, r.envio, r.prioridad, r.estado)]),
      e.publicos.length,
      identityHashCode(e.publicos),
      identityHashCode(comunidad),
    );

enum FiltroTiempo { todas, ultimas24h, mias }

/// Qué se ve en el mapa. Sin tipos elegidos = todos los tipos.
class FiltroMapa {
  const FiltroMapa({this.tiempo = FiltroTiempo.todas, this.tipos = const {}});

  final FiltroTiempo tiempo;
  final Set<TipoAmenaza> tipos;

  bool get activo => tiempo != FiltroTiempo.todas || tipos.isNotEmpty;

  FiltroMapa conTiempo(FiltroTiempo t) => FiltroMapa(tiempo: t, tipos: tipos);

  FiltroMapa alternarTipo(TipoAmenaza t) {
    final nuevos = {...tipos};
    if (!nuevos.remove(t)) nuevos.add(t);
    return FiltroMapa(tiempo: tiempo, tipos: nuevos);
  }

  bool pasa(PuntoMapa p, DateTime ahora) {
    if (tipos.isNotEmpty && !tipos.contains(p.tipo)) return false;
    return switch (tiempo) {
      FiltroTiempo.todas => true,
      FiltroTiempo.ultimas24h => ahora.difference(p.capturadoEn) < const Duration(hours: 24),
      FiltroTiempo.mias => p.esMio,
    };
  }
}

/// Uno o varios puntos que se dibujan juntos.
class GrupoMapa {
  GrupoMapa(this.puntos)
      : centro = _promedio(puntos),
        prioridadMax = puntos.map((p) => p.prioridad).reduce(math.max),
        hayMio = puntos.any((p) => p.esMio);

  final List<PuntoMapa> puntos;
  final LatLng centro;
  final int prioridadMax;
  final bool hayMio;

  bool get esUno => puntos.length == 1;

  static LatLng _promedio(List<PuntoMapa> ps) {
    if (ps.length == 1) return ps.first.punto;
    var lat = 0.0, lon = 0.0;
    for (final p in ps) {
      lat += p.punto.latitude;
      lon += p.punto.longitude;
    }
    return LatLng(lat / ps.length, lon / ps.length);
  }
}

/// Desde este nivel de zoom cada reporte se ve solo.
const nivelSinAgrupar = 16;

/// Lado de la cuadrícula de agrupación, en píxeles.
const _celda = 54.0;

/// Agrupación simple por cuadrícula de píxeles: los puntos que caen en la misma celda
/// del nivel de zoom entero se funden en un grupo. La cuadrícula está fija al mundo (no a
/// la pantalla), así que al desplazar el mapa los grupos no cambian.
List<GrupoMapa> agrupar(List<PuntoMapa> puntos, int nivel) {
  final List<GrupoMapa> grupos;
  if (nivel >= nivelSinAgrupar) {
    grupos = [for (final p in puntos) GrupoMapa([p])];
  } else {
    final escala = 256.0 * math.pow(2, nivel);
    final celdas = <int, List<PuntoMapa>>{};
    for (final p in puntos) {
      final x = (p.punto.longitude + 180) / 360 * escala;
      final s = math.sin(p.punto.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
      final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * escala;
      final clave = (x ~/ _celda) * 1000000 + (y ~/ _celda);
      (celdas[clave] ??= []).add(p);
    }
    grupos = [for (final c in celdas.values) GrupoMapa(c)];
  }
  // Lo más grave y lo mío se dibuja encima.
  grupos.sort((a, b) {
    final m = (a.hayMio ? 1 : 0) - (b.hayMio ? 1 : 0);
    return m != 0 ? m : a.prioridadMax - b.prioridadMax;
  });
  return grupos;
}

/// Caja que envuelve todas las cajas de una zona (o de todas).
LatLngBounds limitesDe(Iterable<Caja> cajas) {
  var a = 90.0, b = -90.0, c = 180.0, d = -180.0;
  for (final k in cajas) {
    a = math.min(a, k.minLat);
    b = math.max(b, k.maxLat);
    c = math.min(c, k.minLon);
    d = math.max(d, k.maxLon);
  }
  return LatLngBounds(LatLng(a, c), LatLng(b, d));
}

/// Metros que mide un píxel a esta latitud y zoom (para dar margen al dedo).
double metrosPorPixel(double lat, double zoom) =>
    156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
