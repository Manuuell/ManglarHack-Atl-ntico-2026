import 'package:latlong2/latlong.dart';

import '../tipos.dart';

/// Un reporte tal como lo ve el equipo de la CRA (columnas que el esquema le concede al
/// rol del panel: nunca el reportante ni la geometría).
class ReporteAdmin {
  const ReporteAdmin({
    required this.id,
    required this.tipo,
    required this.punto,
    required this.zona,
    required this.municipio,
    required this.prioridad,
    required this.confianza,
    required this.estado,
    required this.capturadoEn,
    this.descripcion = '',
    this.distanciaM,
    this.dentroPoligono = false,
    this.recibidoEn,
    this.tieneFoto = false,
    this.notaPublica,
    this.magnitud = Magnitud.pequena,
    this.momento = Momento.ahora,
    this.corroboraciones = 0,
    this.iaMotivo,
    this.expediente,
  });

  final String id;
  final TipoAmenaza tipo;
  final LatLng punto;
  final String zona;
  final String municipio;
  final int prioridad;
  final int confianza;
  final EstadoReporte estado;
  final DateTime capturadoEn;
  final String descripcion;

  /// Metros al manglar más cercano; nulo si el servidor no lo calculó.
  final int? distanciaM;
  final bool dentroPoligono;
  final DateTime? recibidoEn;
  final bool tieneFoto;

  /// Lo que lee quien reportó (el motivo del rechazo o lo que se le pide).
  final String? notaPublica;
  final Magnitud magnitud;
  final Momento momento;
  final int corroboraciones;
  final String? iaMotivo;
  final String? expediente;

  /// Cuándo llegó a la CRA (la hora del servidor; si falta, la del teléfono).
  DateTime get llegadaEn => recibidoEn ?? capturadoEn;

  /// ¿Espera una decisión? Recibido o en verificación.
  bool get pendiente => estado == EstadoReporte.recibido || estado == EstadoReporte.enVerificacion;

  ReporteAdmin conEstado(EstadoReporte e, {String? notaPublica}) => ReporteAdmin(
        id: id,
        tipo: tipo,
        punto: punto,
        zona: zona,
        municipio: municipio,
        prioridad: prioridad,
        confianza: confianza,
        estado: e,
        capturadoEn: capturadoEn,
        descripcion: descripcion,
        distanciaM: distanciaM,
        dentroPoligono: dentroPoligono,
        recibidoEn: recibidoEn,
        tieneFoto: tieneFoto,
        notaPublica: notaPublica ?? this.notaPublica,
        magnitud: magnitud,
        momento: momento,
        corroboraciones: corroboraciones,
        iaMotivo: iaMotivo,
        expediente: expediente,
      );

  static ReporteAdmin fromJson(Map<String, dynamic> j) => ReporteAdmin(
        id: j['id'] as String,
        tipo: TipoAmenaza.deSlug(j['tipo'] as String? ?? 'otro'),
        punto: LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
        zona: (j['zona'] as String?) ?? 'Sin zona',
        municipio: (j['municipio'] as String?) ?? '',
        prioridad: ((j['prioridad'] as num?) ?? 3).toInt().clamp(1, 5),
        confianza: ((j['confianza'] as num?) ?? 0).toInt().clamp(0, 100),
        estado: EstadoReporte.deSlug(j['estado'] as String? ?? 'recibido'),
        capturadoEn: DateTime.parse(j['capturado_en'] as String).toLocal(),
        descripcion: (j['descripcion'] as String?) ?? '',
        distanciaM: (j['distancia_m'] as num?)?.toInt(),
        dentroPoligono: j['dentro_poligono'] == true,
        recibidoEn: j['recibido_en'] == null ? null : DateTime.parse(j['recibido_en'] as String).toLocal(),
        tieneFoto: j['foto_url'] != null,
        notaPublica: j['nota_publica'] as String?,
        magnitud: Magnitud.deSlug(j['magnitud'] as String? ?? 'pequena'),
        momento: Momento.deSlug(j['momento'] as String? ?? 'ahora'),
        corroboraciones: ((j['corroboraciones'] as num?) ?? 0).toInt(),
        iaMotivo: j['ia_motivo'] as String?,
        expediente: j['expediente'] as String?,
      );
}

/// Filtros segmentados de la bandeja.
enum FiltroBandeja {
  pendientes('Pendientes'),
  aprobados('Aprobados'),
  rechazados('Rechazados'),
  todos('Todos');

  const FiltroBandeja(this.nombre);
  final String nombre;

  bool admite(ReporteAdmin r) => switch (this) {
        FiltroBandeja.pendientes => r.pendiente,
        FiltroBandeja.aprobados => r.estado.validado,
        FiltroBandeja.rechazados => r.estado == EstadoReporte.descartado,
        FiltroBandeja.todos => true,
      };
}

/// Filtra y ordena la bandeja: lo que espera decisión primero y, dentro, lo más
/// urgente (prioridad alta, luego lo más reciente). Lo ya resuelto va por fecha.
List<ReporteAdmin> bandeja(Iterable<ReporteAdmin> todos, FiltroBandeja filtro) {
  final l = [for (final r in todos) if (filtro.admite(r)) r];
  l.sort((a, b) {
    if (a.pendiente != b.pendiente) return a.pendiente ? -1 : 1;
    if (a.pendiente && a.prioridad != b.prioridad) return b.prioridad.compareTo(a.prioridad);
    return b.llegadaEn.compareTo(a.llegadaEn);
  });
  return l;
}

/// Cuántos reportes admite cada filtro (para los números de los segmentos).
Map<FiltroBandeja, int> contarPorFiltro(Iterable<ReporteAdmin> todos) => {
      for (final f in FiltroBandeja.values) f: todos.where(f.admite).length,
    };

/// Cifras de un periodo (el día o la semana).
class CifrasPeriodo {
  const CifrasPeriodo({
    required this.nuevos,
    required this.altaPrioridad,
    required this.pendientes,
    required this.porZona,
    required this.porTipo,
  });
  final int nuevos;
  final int altaPrioridad;
  final int pendientes;
  final Map<String, int> porZona;
  final Map<TipoAmenaza, int> porTipo;

  bool get vacio => nuevos == 0;
}

/// Resumen de los reportes llegados desde [desde] (incluido). Alta prioridad = 4 o 5.
CifrasPeriodo resumir(Iterable<ReporteAdmin> todos, DateTime desde) {
  var nuevos = 0, alta = 0, pend = 0;
  final zonas = <String, int>{};
  final tipos = <TipoAmenaza, int>{};
  for (final r in todos) {
    if (r.llegadaEn.isBefore(desde)) continue;
    nuevos++;
    if (r.prioridad >= 4) alta++;
    if (r.pendiente) pend++;
    zonas[r.zona] = (zonas[r.zona] ?? 0) + 1;
    tipos[r.tipo] = (tipos[r.tipo] ?? 0) + 1;
  }
  Map<K, int> ordenado<K>(Map<K, int> m) =>
      Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  return CifrasPeriodo(
    nuevos: nuevos,
    altaPrioridad: alta,
    pendientes: pend,
    porZona: ordenado(zonas),
    porTipo: ordenado(tipos),
  );
}

/// Medianoche de [ahora] (el «día» del resumen).
DateTime inicioDelDia(DateTime ahora) => DateTime(ahora.year, ahora.month, ahora.day);

/// Los últimos 7 días contando hoy.
DateTime inicioDeLaSemana(DateTime ahora) => inicioDelDia(ahora).subtract(const Duration(days: 6));

/// Reportes por día de los últimos [dias] días (el más viejo primero), para las barras.
List<int> porDia(Iterable<ReporteAdmin> todos, DateTime ahora, {int dias = 7}) {
  final hoy = inicioDelDia(ahora);
  final cuentas = List<int>.filled(dias, 0);
  for (final r in todos) {
    final d = inicioDelDia(r.llegadaEn);
    final atras = hoy.difference(d).inDays;
    if (atras >= 0 && atras < dias) cuentas[dias - 1 - atras]++;
  }
  return cuentas;
}

/// Datos de demostración (sin servidor): doce casos repartidos en una semana y en las
/// cuatro zonas, con todos los estados. Determinista para poder probarlo.
List<ReporteAdmin> reportesDemo(DateTime ahora) {
  ReporteAdmin r(
    String n,
    TipoAmenaza tipo,
    String zona,
    String municipio,
    LatLng p,
    int prio,
    int conf,
    EstadoReporte e,
    Duration hace, {
    int? dist,
    bool dentro = true,
    String desc = '',
    String? nota,
    int corro = 0,
  }) =>
      ReporteAdmin(
        id: 'demo-$n',
        tipo: tipo,
        punto: p,
        zona: zona,
        municipio: municipio,
        prioridad: prio,
        confianza: conf,
        estado: e,
        capturadoEn: ahora.subtract(hace),
        recibidoEn: ahora.subtract(hace),
        descripcion: desc,
        distanciaM: dist ?? (dentro ? 0 : 400),
        dentroPoligono: dentro,
        notaPublica: nota,
        corroboraciones: corro,
      );
  const mall = 'Ciénaga de Mallorquín', tub = 'Costa de Tubará', jda = 'Costa de Juan de Acosta', tot = 'Ciénaga del Totumo';
  const mM = 'Barranquilla', mT = 'Tubará', mJ = 'Juan de Acosta', mP = 'Piojó';
  return [
    r('01', TipoAmenaza.tala, mall, mM, const LatLng(11.0531, -74.8509), 5, 82, EstadoReporte.recibido,
        const Duration(minutes: 20), desc: 'Troncos de mangle rojo recién cortados junto al caño.', corro: 2),
    r('02', TipoAmenaza.quema, tub, mT, const LatLng(10.9905, -74.9441), 5, 74, EstadoReporte.recibido,
        const Duration(hours: 1), desc: 'Humo espeso entre los manglares, se ve fuego.'),
    r('03', TipoAmenaza.vertimiento, mall, mM, const LatLng(11.0522, -74.8467), 4, 66, EstadoReporte.enVerificacion,
        const Duration(hours: 3), desc: 'Agua con aceite y mal olor en la boca del caño.', nota: 'Un vigía ya va para allá.'),
    r('04', TipoAmenaza.relleno, jda, mJ, const LatLng(10.8296, -75.0377), 4, 58, EstadoReporte.recibido,
        const Duration(hours: 5), dentro: false, dist: 180, desc: 'Volquetas botando escombros.'),
    r('05', TipoAmenaza.basuras, tot, mP, const LatLng(10.7556, -74.9208), 2, 50, EstadoReporte.recibido,
        const Duration(hours: 7), desc: 'Botadero de plásticos en las raíces.'),
    r('06', TipoAmenaza.fauna, tub, mT, const LatLng(10.9912, -74.9398), 4, 70, EstadoReporte.verificado,
        const Duration(hours: 26), desc: 'Aves muertas en la orilla.', corro: 3),
    r('07', TipoAmenaza.canoTaponado, mall, mM, const LatLng(11.0488, -74.8551), 4, 77, EstadoReporte.alertaOficial,
        const Duration(days: 2), desc: 'El caño está cerrado con tierra y ya no corre agua.', corro: 1),
    r('08', TipoAmenaza.tala, jda, mJ, const LatLng(10.8311, -75.0344), 5, 40, EstadoReporte.descartado,
        const Duration(days: 2, hours: 4), nota: 'La foto es de otro lugar. Gracias por avisar.'),
    r('09', TipoAmenaza.basuras, mall, mM, const LatLng(11.0545, -74.8483), 2, 62, EstadoReporte.cerrado,
        const Duration(days: 3), desc: 'Jornada de limpieza hecha.'),
    r('10', TipoAmenaza.quema, tot, mP, const LatLng(10.7541, -74.9187), 5, 55, EstadoReporte.enAtencion,
        const Duration(days: 4), desc: 'Quema de residuos cerca de la ciénaga.'),
    r('11', TipoAmenaza.vertimiento, tub, mT, const LatLng(10.9931, -74.9425), 4, 45, EstadoReporte.descartado,
        const Duration(days: 5), nota: 'No se pudo confirmar.'),
    r('12', TipoAmenaza.relleno, mall, mM, const LatLng(11.0510, -74.8530), 4, 68, EstadoReporte.verificado,
        const Duration(days: 8), desc: 'Obra sobre el agua, ya verificada.'),
  ];
}
