import 'reporte.dart';
import 'tipos.dart';

/// Reglas y textos del reporte por WhatsApp (Zanky BOT), llevados a la app para que un
/// reporte se viva igual por los dos canales.
///
/// Origen: `bot/src/flujos/textos.ts`, `bot/src/config.ts` y `bot/src/reportes/evaluacion.ts`.
/// Los textos se adaptan de WhatsApp (negritas con *, botones) a la app; las reglas y los
/// números son los mismos. Todo es puro: no toca red ni almacenamiento.
abstract final class ReglasCanal {
  /// Más allá de esta distancia al manglar se pregunta si la ubicación es correcta
  /// (`config.distanciaSospechosaM`).
  static const distanciaSospechosaM = 3000.0;

  /// Reportes por hora antes de pedir una pausa (`config.maxReportesPorHora`).
  /// El servidor corta en 10 por hora; el bot pide calma desde 5.
  static const maxReportesPorHora = 5;

  /// Radio del área de influencia del manglar (`config.radioInfluenciaM`).
  static const radioInfluenciaM = 500.0;
}

/// ¿La ubicación queda tan lejos que conviene preguntar «¿seguro que es ahí?»?
/// Misma condición que el bot: fuera del polígono y a más de 3 km.
bool ubicacionSospechosa({required bool dentro, required double distanciaM}) =>
    !dentro && distanciaM.isFinite && distanciaM > ReglasCanal.distanciaSospechosaM;

/// Reportes propios creados en la última hora (los rechazados no cuentan: nunca llegaron).
int reportesUltimaHora(Iterable<Reporte> propios, {DateTime? ahora}) {
  final t = ahora ?? DateTime.now();
  return propios
      .where((r) => r.envio != Envio.rechazado && t.difference(r.capturadoEn) < const Duration(hours: 1))
      .length;
}

/// ¿Ya envió tantos seguidos que el bot le pediría una pausa?
bool demasiadosSeguidos(Iterable<Reporte> propios, {DateTime? ahora}) =>
    reportesUltimaHora(propios, ahora: ahora) >= ReglasCanal.maxReportesPorHora;

/// Textos de Zanky BOT, adaptados a la app.
abstract final class TextosCanal {
  static const emergencia = 'Si hay peligro para las personas, llama primero al 123.';

  static const consentimiento =
      'Para atender tu reporte, la CRA guarda la ubicación, la foto y lo que me cuentes. Tus datos se tratan '
      'según la Ley 1581 de 2012 y nunca se publican tu nombre ni tu número.';

  static const pedirUbicacion = '¿Dónde está pasando? Usa tu ubicación, mueve el pin al sitio exacto o pega un enlace de Google Maps.';

  static const pedirFoto =
      'Una foto de lo que está pasando, tomada ahora mismo. Si no puedes acercarte, no te arriesgues: sigue sin foto.';

  static const pedirDescripcion = 'Cuéntame en pocas palabras qué viste: qué pasa, cuántas personas o máquinas, desde cuándo.';

  static const fueraDelAtlantico =
      'Esa ubicación queda fuera del Atlántico, y Zanky solo recibe reportes del manglar del departamento.';

  static const demasiados =
      'Has enviado varios reportes seguidos. Si es algo nuevo, adelante; si es lo mismo, espera un rato. '
      '$emergencia';

  static const envioPendiente =
      'Guardé tu reporte, pero el servidor de la CRA no respondió. Lo reenvío solo en cuanto vuelva. '
      'No tienes que hacer nada más.';

  static const envioRechazado = 'El servidor de la CRA no aceptó este reporte. $emergencia';

  /// «✅ Ubicación recibida…» (`ubicacionRecibida`).
  static String ubicacionRecibida({required bool dentro, required double distanciaM, String? zona}) {
    final lugar = zona != null && zona.isNotEmpty ? ' ($zona)' : '';
    if (dentro) return 'Ubicación recibida: está dentro del manglar$lugar.';
    return 'Ubicación recibida: está a ${distanciaM.round()} m del manglar$lugar. Lo que pasa cerca también lo afecta.';
  }

  /// «🤔 Esa ubicación está a X km…» (`ubicacionLejana`).
  static String ubicacionLejana(double distanciaM) =>
      'Esa ubicación está a ${(distanciaM / 1000).toStringAsFixed(1)} km del manglar más cercano. ¿Seguro que es ahí?';

  /// El servidor confirmó que lo guardó (`enviado`). Solo entonces se dice «en el panel».
  static String enviado(String codigo) =>
      '¡Gracias, vigía! Tu reporte $codigo ya está en el panel de la CRA. La CRA lo verifica y decide cómo '
      'actuar. También aparece en el mapa, sin tus datos.';

  /// Un reporte que estaba en cola por fin llegó (`enviadoTarde`).
  static String enviadoTarde(String codigo) =>
      'Listo: tu reporte $codigo ya llegó al panel de la CRA. ¡Gracias por cuidar el manglar!';

  /// Aviso cuando cambia el estado (`cambioDeEstado`).
  static String cambioDeEstado(String codigo, EstadoReporte estado) =>
      'Novedad de tu reporte $codigo: ahora está ${nombreEstado(estado)}. ¡Gracias por cuidar el manglar!';

  /// Nombre del estado como lo dice el bot (`ESTADOS`).
  static String nombreEstado(EstadoReporte e) =>
      e == EstadoReporte.alertaOficial ? 'Alerta oficial (expediente abierto)' : e.nombre;

  /// Estado corto en «Mis reportes» (`misReportes`): primero cómo va el envío.
  static String estadoEnLista(Reporte r) => switch (r.envio) {
        Envio.rechazado => 'No se pudo enviar',
        Envio.enviado => nombreEstado(r.estado),
        _ => 'Pendiente de envío',
      };

  /// Las filas del resumen «Revisa tu reporte» (`resumen`), en el mismo orden que el bot.
  static List<(String, String)> resumen({
    required TipoAmenaza tipo,
    required bool dentro,
    required double distanciaM,
    String? zona,
    required bool conFoto,
    required String descripcion,
    required Momento momento,
    required Magnitud magnitud,
  }) {
    final z = zona != null && zona.isNotEmpty ? ' ($zona)' : '';
    final lugar = dentro ? 'Dentro del manglar$z' : 'A ${distanciaM.round()} m del manglar$z';
    final d = descripcion.trim();
    return [
      ('Qué pasa', tipo.nombre),
      ('Dónde', lugar),
      ('Foto', conFoto ? 'Con foto' : 'Sin foto'),
      ('Qué viste', d.isEmpty ? 'Sin descripción' : (d.length > 200 ? '${d.substring(0, 200)}…' : d)),
      ('Cuándo', momento.nombre),
      ('Tamaño', '${magnitud.nombre} (${magnitud.ejemplo.toLowerCase()})'),
    ];
  }

  /// ¿Toca recordar la línea 123? Lo que pasa ahora y es de los más graves (fuego, tala).
  static bool pideEmergencia(TipoAmenaza tipo, Momento momento) => momento == Momento.ahora && tipo.gravedad >= 5;
}
