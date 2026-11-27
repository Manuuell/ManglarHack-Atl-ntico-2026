import '../comunidad/comunidad.dart';
import '../experiencia/jornada.dart';

/// Reglas de los avisos de Zanky: qué avisar, cuándo y sin repetir.
///
/// Todo son funciones puras con `ahora` inyectable: se prueban sin plataforma, sin red y sin
/// reloj. Cada aviso lleva una [AvisoApp.clave] estable; lo ya avisado se guarda y nunca se
/// repite (si una alerta sube de naranja a roja, la clave cambia y sí se avisa otra vez).

enum TipoAvisoApp {
  alerta('Alertas del manglar'),
  jornada('Jornadas'),
  reporte('Mis reportes');

  const TipoAvisoApp(this.nombre);
  final String nombre;

  static TipoAvisoApp deNombre(String? s) =>
      TipoAvisoApp.values.firstWhere((t) => t.name == s, orElse: () => TipoAvisoApp.alerta);
}

/// Un aviso de la bandeja. [destino] es el id de lo que abre: la alerta, la jornada o el reporte.
class AvisoApp {
  AvisoApp({
    required this.clave,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.creado,
    required this.destino,
    this.lat,
    this.lon,
    this.nivel,
    this.leido = false,
  });

  final String clave, titulo, cuerpo, destino;
  final TipoAvisoApp tipo;
  final DateTime creado;
  final double? lat, lon;

  /// Solo en alertas: «naranja» o «roja».
  final String? nivel;
  bool leido;

  Map<String, dynamic> aJson() => {
        'clave': clave,
        'tipo': tipo.name,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'creado': creado.toUtc().toIso8601String(),
        'destino': destino,
        'lat': lat,
        'lon': lon,
        'nivel': nivel,
        'leido': leido,
      };

  static AvisoApp? deJson(Object? j) {
    if (j is! Map) return null;
    final creado = DateTime.tryParse('${j['creado']}');
    if (creado == null || j['clave'] is! String) return null;
    return AvisoApp(
      clave: j['clave'] as String,
      tipo: TipoAvisoApp.deNombre(j['tipo'] as String?),
      titulo: '${j['titulo'] ?? ''}',
      cuerpo: '${j['cuerpo'] ?? ''}',
      creado: creado.toLocal(),
      destino: '${j['destino'] ?? ''}',
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      nivel: j['nivel'] as String?,
      leido: j['leido'] == true,
    );
  }
}

/// Qué tipos quiere recibir la persona (Configuración → Avisos). Todo encendido al empezar.
class PreferenciasAvisos {
  const PreferenciasAvisos({this.alertas = true, this.jornadas = true, this.reportes = true});
  final bool alertas, jornadas, reportes;

  bool permite(TipoAvisoApp t) => switch (t) {
        TipoAvisoApp.alerta => alertas,
        TipoAvisoApp.jornada => jornadas,
        TipoAvisoApp.reporte => reportes,
      };

  PreferenciasAvisos con(TipoAvisoApp t, bool v) => PreferenciasAvisos(
        alertas: t == TipoAvisoApp.alerta ? v : alertas,
        jornadas: t == TipoAvisoApp.jornada ? v : jornadas,
        reportes: t == TipoAvisoApp.reporte ? v : reportes,
      );

  Map<String, bool> aJson() => {'alertas': alertas, 'jornadas': jornadas, 'reportes': reportes};

  static PreferenciasAvisos deJson(Object? j) => j is Map
      ? PreferenciasAvisos(
          alertas: j['alertas'] != false, jornadas: j['jornadas'] != false, reportes: j['reportes'] != false)
      : const PreferenciasAvisos();
}

// ------------------------------------------------------------------ alertas

/// Clave de una alerta en su nivel: la misma alerta en el mismo nivel no se repite nunca.
String claveAlerta(AlertaManglar a) => 'alerta|${a.id}|${a.nivel.name}';

/// Las alertas naranja o roja vigentes que aún no se avisaron, con lugar, nivel y qué hacer.
List<AvisoApp> avisosDeAlertas(List<AlertaManglar> alertas, Set<String> yaAvisados, DateTime ahora) => [
      for (final a in alertas)
        if (a.nivel != NivelAlerta.amarilla && a.hasta.isAfter(ahora) && !yaAvisados.contains(claveAlerta(a)))
          AvisoApp(
            clave: claveAlerta(a),
            tipo: TipoAvisoApp.alerta,
            titulo: '${a.icono} ${a.nivel.texto}: ${a.titulo}',
            cuerpo: [
              if (a.lugar.isNotEmpty) a.lugar,
              if (a.recomendacion.isNotEmpty) 'Qué hacer: ${a.recomendacion}' else if (a.detalle.isNotEmpty) a.detalle,
              if (a.nivel == NivelAlerta.roja) 'Si hay peligro para las personas, llama al 123.',
            ].join('. ').replaceAll('..', '.'),
            creado: ahora,
            destino: a.id,
            lat: a.punto?.latitude,
            lon: a.punto?.longitude,
            nivel: a.nivel.name,
          ),
    ];

// ------------------------------------------------------------------ jornadas

/// Hora de la víspera a la que se recuerda: 6:00 p. m. (hora de Colombia) del día anterior.
const horaVispera = 18;

/// El momento de la víspera de [inicio] (6:00 p. m. de Colombia del día anterior), en UTC.
DateTime momentoVispera(DateTime inicio) {
  final c = aHoraColombia(inicio); // reloj de pared de Colombia guardado como UTC
  return DateTime.utc(c.year, c.month, c.day - 1, horaVispera).add(const Duration(hours: 5));
}

/// Recordatorios de las jornadas inscritas: la víspera y 2 h antes. Solo el que toca ahora:
/// quien se inscribe una hora antes recibe el de «2 h» (no el de la víspera, ya pasado).
List<AvisoApp> recordatoriosJornadas(List<Jornada> inscritas, Set<String> yaAvisados, DateTime ahora) {
  final t = ahora.toUtc();
  final salida = <AvisoApp>[];
  for (final j in inscritas) {
    final inicio = j.inicio.toUtc();
    if (!inicio.isAfter(t)) continue; // ya empezó o pasó
    final dosHoras = inicio.subtract(const Duration(hours: 2));
    final cuando = 'el ${fechaLarga(j.inicio)} a las ${horaCorta(j.inicio)}';
    final donde = j.puntoEncuentro.isEmpty ? '' : ' Punto de encuentro: ${j.puntoEncuentro}.';
    final llevar = j.queLlevar.isEmpty ? '' : ' Lleva: ${j.queLlevar.take(4).join(', ')}.';
    if (!t.isBefore(dosHoras)) {
      final clave = 'jornada|${j.id}|2h';
      if (!yaAvisados.contains(clave)) {
        salida.add(AvisoApp(
          clave: clave,
          tipo: TipoAvisoApp.jornada,
          titulo: 'Tu jornada empieza pronto: ${j.titulo}',
          cuerpo: 'Empieza a las ${horaCorta(j.inicio)}.$donde$llevar',
          creado: ahora,
          destino: j.id,
          lat: j.lat == 0 ? null : j.lat,
          lon: j.lon == 0 ? null : j.lon,
        ));
      }
    } else if (!t.isBefore(momentoVispera(j.inicio))) {
      final clave = 'jornada|${j.id}|vispera';
      if (!yaAvisados.contains(clave)) {
        salida.add(AvisoApp(
          clave: clave,
          tipo: TipoAvisoApp.jornada,
          titulo: 'Mañana: ${j.titulo}',
          cuerpo: 'Te inscribiste. Es $cuando.$donde$llevar',
          creado: ahora,
          destino: j.id,
          lat: j.lat == 0 ? null : j.lat,
          lon: j.lon == 0 ? null : j.lon,
        ));
      }
    }
  }
  return salida;
}

// ------------------------------------------------------------------ reportes

/// La novedad de un reporte propio, con el texto del bot tal cual («… ya llegó», «Novedad de…»).
/// La clave junta el reporte y el texto: el mismo cambio no se avisa dos veces.
AvisoApp? avisoDeNovedad(String? texto, String? reporteId, Set<String> yaAvisados, DateTime ahora) {
  if (texto == null || texto.trim().isEmpty) return null;
  final clave = 'reporte|${reporteId ?? ''}|${texto.hashCode}';
  if (yaAvisados.contains(clave)) return null;
  return AvisoApp(
    clave: clave,
    tipo: TipoAvisoApp.reporte,
    titulo: texto.contains('ya llegó') ? 'Tu reporte llegó a la CRA' : 'Novedad de tu reporte',
    cuerpo: texto,
    creado: ahora,
    destino: reporteId ?? '',
  );
}

// ------------------------------------------------------------------ bandeja

/// Tope de avisos guardados y de claves recordadas: la bandeja no crece sin fin.
const maxAvisos = 60;
const maxClaves = 400;

/// Une lo nuevo con la bandeja: lo más reciente arriba, sin claves repetidas y con tope.
List<AvisoApp> unirBandeja(List<AvisoApp> bandeja, List<AvisoApp> nuevos) {
  final vistas = <String>{};
  final todos = [...nuevos, ...bandeja]..sort((a, b) => b.creado.compareTo(a.creado));
  return [
    for (final a in todos)
      if (vistas.add(a.clave)) a,
  ].take(maxAvisos).toList();
}

/// Recorta las claves recordadas a las más recientes (el conjunto mantiene el orden de entrada).
Set<String> recortarClaves(Set<String> claves) =>
    claves.length <= maxClaves ? claves : claves.skip(claves.length - maxClaves).toSet();

/// «hace 5 min», «hace 2 h», «ayer», «12 nov».
String haceCuantoAviso(DateTime t, DateTime ahora) {
  final d = ahora.difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays == 1) return 'ayer';
  if (d.inDays < 7) return 'hace ${d.inDays} días';
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${t.day} ${meses[t.month - 1]}';
}
