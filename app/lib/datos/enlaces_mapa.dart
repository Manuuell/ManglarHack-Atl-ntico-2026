import 'package:latlong2/latlong.dart';

/// Saca la coordenada de un enlace o texto de Google Maps, como sugirió la CRA
/// («un pescador… va a poder georreferenciar desde Google Maps»).
///
/// Entiende los formatos que se comparten de verdad:
/// - `https://www.google.com/maps/@11.0432,-74.8611,17z`
/// - `https://www.google.com/maps/place/…/@11.0432,-74.8611,17z/data=…!3d11.0435!4d-74.8607`
///   (manda el `!3d!4d`: es el pin, la `@` es solo el centro de la vista)
/// - `https://maps.google.com/?q=11.0432,-74.8611` · `?ll=` · `?query=` · `?daddr=`
/// - `geo:11.0432,-74.8611` y el texto suelto `11.0432, -74.8611` (o `11.0432 -74.8611`)
///
/// Los enlaces cortos (`maps.app.goo.gl/…`) no traen la coordenada: hay que abrirlos
/// con internet. Para esos devuelve [ResultadoEnlace.corto] y la app pide compartir la
/// ubicación o marcar el punto.
class ResultadoEnlace {
  const ResultadoEnlace._(this.punto, this.corto);
  final LatLng? punto;
  final bool corto;
  static const nada = ResultadoEnlace._(null, false);
  static const enlaceCorto = ResultadoEnlace._(null, true);
}

ResultadoEnlace leerEnlaceMapa(String texto) {
  // Lo que la persona pega puede no ser una URL válida (tildes, «%» suelto): si no se
  // puede decodificar, se lee tal cual en vez de romperse.
  String t;
  try {
    t = Uri.decodeFull(texto.trim());
  } on ArgumentError {
    t = texto.trim();
  }
  if (t.isEmpty) return ResultadoEnlace.nada;
  if (RegExp(r'(maps\.app\.goo\.gl|goo\.gl/maps)', caseSensitive: false).hasMatch(t)) {
    return ResultadoEnlace.enlaceCorto;
  }
  const num = r'(-?\d{1,3}(?:\.\d+)?)';
  final patrones = [
    RegExp('!3d$num!4d$num'),
    RegExp('[?&](?:q|ll|query|daddr|destination|center)=(?:loc:)?$num\\s*,\\s*$num'),
    RegExp('@$num,$num'),
    RegExp('geo:$num,$num'),
    RegExp('^$num\\s*[, ]\\s*$num\$'),
  ];
  for (final p in patrones) {
    final m = p.firstMatch(t);
    if (m == null) continue;
    final lat = double.tryParse(m.group(1)!), lon = double.tryParse(m.group(2)!);
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) continue;
    return ResultadoEnlace._(LatLng(lat, lon), false);
  }
  return ResultadoEnlace.nada;
}

/// ¿Está en el Atlántico (con margen)? Un punto en otra parte suele ser un error al
/// pegar, y se avisa antes de usarlo.
bool enElAtlantico(LatLng p) =>
    p.latitude > 10.2 && p.latitude < 11.25 && p.longitude > -75.45 && p.longitude < -74.6;
