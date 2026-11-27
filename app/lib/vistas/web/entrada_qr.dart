import 'package:flutter/foundation.dart';

/// De dónde llegó el visitante a la web: el letrero con QR de una zona del manglar.
///
/// El letrero apunta a `https://…/?zona=mallorquin` (o `tubara`, `juan_de_acosta`, `piojo`); un QR genérico puede
/// traer solo `?origen=qr`. Se lee una vez al arrancar y se guarda aquí.
///
/// En el reporte (`vistas/reporte/borrador.dart`): si `zonaId` viene, el borrador abre con esa zona preseleccionada
/// como sugerencia; la primera lectura del GPS o una marca en el mapa la reemplazan. Si se envía con la zona del
/// letrero, el método de ubicación va como «enlace». El canal va como 'web': el servidor solo acepta app, web o
/// whatsapp (`backend/supabase/schema.sql`), así que [EntradaQr.canal] no se manda.
final ValueNotifier<EntradaQr?> entradaQr = ValueNotifier<EntradaQr?>(null);

/// Zonas válidas: los mismos ids que `assets/datos/manglar_zonas.json`.
const zonasConLetrero = {'mallorquin', 'tubara', 'juan_de_acosta', 'piojo'};

class EntradaQr {
  const EntradaQr({this.zonaId, required this.viaQr});

  /// Id de zona si el enlace traía `?zona=` válido; null si solo traía `?origen=qr`.
  final String? zonaId;

  /// Llegó por un código QR (o se sabe una zona, que solo viene de un letrero).
  final bool viaQr;

  /// Cómo llegó (para mostrar o medir en la app). No es el `canal` del reporte: el servidor no acepta 'qr'.
  String get canal => viaQr ? 'qr' : 'web';

  @override
  String toString() => 'EntradaQr(zona: $zonaId, qr: $viaQr)';
}

/// Lee `zona` y `origen` de la dirección. Con la ruta por «#» de Flutter web, la consulta puede venir antes
/// del «#» (`/?zona=tubara#/`) o después (`/#/?zona=tubara`): se miran las dos.
EntradaQr? leerEntradaQr(Uri uri) {
  final params = <String, String>{...uri.queryParameters};
  final f = uri.fragment;
  final i = f.indexOf('?');
  if (i >= 0) {
    try {
      for (final e in Uri.splitQueryString(f.substring(i + 1)).entries) {
        params.putIfAbsent(e.key, () => e.value);
      }
    } catch (_) {/* fragmento raro: se ignora */}
  }
  final zona = params['zona']?.trim().toLowerCase();
  final zonaOk = zona != null && zonasConLetrero.contains(zona) ? zona : null;
  final viaQr = zonaOk != null || params['origen']?.trim().toLowerCase() == 'qr';
  if (zonaOk == null && !viaQr) return null;
  return EntradaQr(zonaId: zonaOk, viaQr: viaQr);
}

/// Se llama una vez al arrancar. No pisa una entrada ya guardada (recargar el enlace no la pierde).
void registrarEntradaQr([Uri? uri]) {
  final e = leerEntradaQr(uri ?? Uri.base);
  if (e != null) entradaQr.value = e;
}
