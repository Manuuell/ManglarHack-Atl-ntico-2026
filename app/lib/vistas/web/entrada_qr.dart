import 'package:flutter/foundation.dart';

/// De dónde llegó el visitante a la web: el letrero con QR de una zona del manglar.
///
/// El letrero apunta a `https://…/?zona=mallorquin` (o `tubara`, `juan_de_acosta`, `piojo`); un QR genérico puede
/// traer solo `?origen=qr`. Se lee una vez al arrancar y se guarda aquí.
///
/// CÓMO ENGANCHARLO EN EL REPORTE (lo hace el chat principal, no esta carpeta):
///  - Al abrir el flujo, si `entradaQr.value?.zonaId != null`, preseleccionar esa zona como sugerencia (el GPS manda:
///    si el teléfono está dentro de otra zona, gana el GPS) con `Zanky.de(context).manglar.zonaPorId(id)`.
///  - Al enviar, mandar `entradaQr.value?.canal` ('qr') junto al reporte para que la CRA vea qué letreros funcionan.
final ValueNotifier<EntradaQr?> entradaQr = ValueNotifier<EntradaQr?>(null);

/// Zonas válidas: los mismos ids que `assets/datos/manglar_zonas.json`.
const zonasConLetrero = {'mallorquin', 'tubara', 'juan_de_acosta', 'piojo'};

class EntradaQr {
  const EntradaQr({this.zonaId, required this.viaQr});

  /// Id de zona si el enlace traía `?zona=` válido; null si solo traía `?origen=qr`.
  final String? zonaId;

  /// Llegó por un código QR (o se sabe una zona, que solo viene de un letrero).
  final bool viaQr;

  /// Canal para el reporte.
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
