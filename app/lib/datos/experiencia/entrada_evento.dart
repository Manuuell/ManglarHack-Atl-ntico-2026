import 'package:flutter/foundation.dart';

/// Dirección pública de la app web (la misma app Flutter, servida con `--base-href /app/`).
const urlAppWeb = 'https://mimanglar.sentralabs.co/app/';

final _codigoValido = RegExp(r'^[a-z0-9_-]{1,64}$');

/// Un evento al que se llegó por un QR: el código de la jornada o un código libre.
class EntradaEvento {
  const EntradaEvento(this.codigo, {this.accionAsistencia = false});
  final String codigo;
  final bool accionAsistencia;

  @override
  bool operator ==(Object other) =>
      other is EntradaEvento &&
      other.codigo == codigo &&
      other.accionAsistencia == accionAsistencia;
  @override
  int get hashCode => Object.hash(codigo, accionAsistencia);
  @override
  String toString() => 'EntradaEvento($codigo)';
}

/// Normaliza y valida un código (`[a-z0-9_-]{1,64}`, en minúscula). Null si no sirve.
String? codigoEventoValido(String? crudo) {
  final c = crudo?.trim().toLowerCase();
  if (c == null || !_codigoValido.hasMatch(c)) return null;
  return c;
}

/// Lee el evento de una dirección. Acepta `?evento=`, `?jornada=`, la consulta después del «#»
/// (`/#/?evento=…`) y `#/evento/<codigo>` (o `/evento/<codigo>` en la ruta). Null si no hay uno válido.
EntradaEvento? leerEntradaEvento(Uri uri) {
  final params = <String, String>{...uri.queryParameters};
  final f = uri.fragment;
  final i = f.indexOf('?');
  if (i >= 0) {
    try {
      for (final e in Uri.splitQueryString(f.substring(i + 1)).entries) {
        params.putIfAbsent(e.key, () => e.value);
      }
    } catch (_) {
      /* fragmento raro: se ignora */
    }
  }
  for (final clave in const ['evento', 'jornada']) {
    final c = codigoEventoValido(params[clave]);
    if (c != null) {
      return EntradaEvento(
        c,
        accionAsistencia: params['accion']?.toLowerCase() == 'asistencia',
      );
    }
  }
  final rutaFragmento = i >= 0 ? f.substring(0, i) : f;
  for (final ruta in [rutaFragmento, uri.path]) {
    final partes = ruta.split('/').where((p) => p.isNotEmpty).toList();
    final k = partes.indexOf('evento');
    if (k >= 0 && k + 1 < partes.length) {
      String parte = partes[k + 1];
      try {
        parte = Uri.decodeComponent(parte);
      } catch (_) {
        /* se usa tal cual */
      }
      final c = codigoEventoValido(parte);
      if (c != null) {
        return EntradaEvento(
          c,
          accionAsistencia: params['accion']?.toLowerCase() == 'asistencia',
        );
      }
    }
  }
  return null;
}

/// El evento con el que se abrió la app (o que se escaneó). `null` = ninguno.
final ValueNotifier<EntradaEvento?> entradaEvento =
    ValueNotifier<EntradaEvento?>(null);

/// Se llama una vez al arrancar. No pisa una entrada ya guardada (recargar el enlace no la pierde).
void registrarEntradaEvento([Uri? uri]) {
  if (entradaEvento.value != null) return;
  final e = leerEntradaEvento(uri ?? Uri.base);
  if (e != null) entradaEvento.value = e;
}

/// El enlace que lleva a un evento: el que va dentro del QR.
String enlaceEvento(String codigo) =>
    '$urlAppWeb?evento=${Uri.encodeQueryComponent(codigo)}';

/// Enlace NDEF para abrir el evento directamente en la hoja de asistencia.
String enlaceAsistenciaEvento(String codigo) =>
    '${enlaceEvento(codigo)}&accion=asistencia';
