import 'dart:math' as math;

/// La misma frontera que usa la cola SQL: 1-2 baja, 3 media, 4-5 alta.
enum NivelAviso { baja, media, alta }

NivelAviso nivelDePrioridad(int prioridad) =>
    prioridad >= 4 ? NivelAviso.alta : prioridad == 3 ? NivelAviso.media : NivelAviso.baja;

double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0088;
  double rad(double v) => v * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

bool avisarVoluntario({required NivelAviso nivel, required double distanciaKm,
  required double radioKm, required int eventosUltimaHora, required bool activo,
  required bool tipoAceptado}) =>
    activo && tipoAceptado && eventosUltimaHora < 3 && distanciaKm <= radioKm &&
    (nivel == NivelAviso.alta || (nivel == NivelAviso.media && distanciaKm < 2));

/// Horario local de Colombia, medido en minutos desde medianoche.
bool enSilencio(int minutoActual, int? desde, int? hasta) {
  if (desde == null || hasta == null || desde == hasta) return false;
  if (desde < hasta) return minutoActual >= desde && minutoActual < hasta;
  return minutoActual >= desde || minutoActual < hasta;
}

// ---- Consentimiento y baja (portado del bot de WhatsApp) ----------------
// Origen: integracion/src/services/consentimientoService.ts (decisión si/no con
// fecha, sin caducidad), integracion/src/flows/campanaReco.ts (frases de baja
// que valen en cualquier paso) e integracion/src/services/broadcastService.ts
// (normalizar a E.164 y quitar duplicados antes de difundir).

enum Decision { si, no }

/// Constancia de lo que la persona decidió y cuándo. Revocable: una baja la
/// deja en [Decision.no] sin borrar la fecha de la decisión anterior.
class ConstanciaConsentimiento {
  const ConstanciaConsentimiento(this.decision, this.fecha);
  final Decision decision;
  final DateTime fecha;

  bool get vigente => decision == Decision.si;
  ConstanciaConsentimiento revocar(DateTime ahora) => ConstanciaConsentimiento(Decision.no, ahora);
}

String _normalizar(String t) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  var s = t.toLowerCase();
  for (var i = 0; i < de.length; i++) {
    s = s.replaceAll(de[i], a[i]);
  }
  return s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _bajaFuerte = {
  'no me interesa', 'darme de baja', 'dar de baja', 'baja', 'stop', 'cancelar',
  'no quiero recibir mensajes', 'no me escriban mas', 'no quiero mas avisos',
};
const _bajaDebil = {'no', 'no gracias', 'no por ahora'};

enum RespuestaAviso { baja, bajaDebil, ninguna }

/// Lee una respuesta libre a un aviso. `bajaDebil` («no») solo cuenta si la
/// persona no estaba respondiendo otra cosa; quien llama decide.
RespuestaAviso interpretarRespuesta(String texto) {
  final n = _normalizar(texto);
  if (n.isEmpty) return RespuestaAviso.ninguna;
  if (_bajaFuerte.contains(n) || n.startsWith('no me interesa')) return RespuestaAviso.baja;
  if (_bajaDebil.contains(n)) return RespuestaAviso.bajaDebil;
  return RespuestaAviso.ninguna;
}

/// Deja un teléfono colombiano en E.164 o devuelve nulo si no se puede.
/// Acepta «300 123 4567», «57 300…», «+57…».
String? normalizarTelefono(String entrada) {
  final digitos = entrada.replaceAll(RegExp(r'[^0-9]'), '');
  final e164 = entrada.trim().startsWith('+')
      ? '+$digitos'
      : digitos.length == 10 && digitos.startsWith('3') ? '+57$digitos' : '+$digitos';
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(e164) ? e164 : null;
}

/// Normaliza, descarta inválidos y quita repetidos conservando el orden.
List<String> depurarDestinatarios(Iterable<String> telefonos) {
  final vistos = <String>{};
  return [for (final t in telefonos) if (normalizarTelefono(t) case final n? when vistos.add(n)) n];
}

/// Texto de privacidad que se muestra junto a la casilla y que se guarda como
/// versión aceptada (la fecha la pone el servidor al inscribir).
const textoConsentimientoAvisos =
    'Autorizo que Zanky guarde mi nombre, teléfono y ubicación aproximada '
    '(redondeada a ~100 m) solo para avisarme de lo que pase en mi zona por '
    'WhatsApp o en la app, conforme a la Ley 1581 de 2012. No se comparte con '
    'terceros ni se muestra a otras personas. Puedo retirar mi autorización y '
    'darme de baja cuando quiera, desde esta pantalla o escribiendo BAJA.';
