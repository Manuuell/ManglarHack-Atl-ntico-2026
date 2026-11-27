import 'package:latlong2/latlong.dart';

import 'reporte.dart';
import 'tipos.dart';
import 'zonas.dart';

/// Prioridad 1-5 con sus motivos a la vista: quien la lee (el ciudadano, el vigía, la
/// CRA) sabe por qué salió ese número. Responde a la pregunta 1 del reto.
///
/// Los pesos son PROVISIONALES: se ajustan con los mentores ambientales. El servidor
/// recalcula con la corroboración de otros reportes y la revisión de la IA.
class Prioridad {
  const Prioridad(this.valor, this.motivos);
  final int valor;
  final List<String> motivos;

  static const nombres = {1: 'Baja', 2: 'Moderada', 3: 'Media', 4: 'Alta', 5: 'Crítica'};
  String get nombre => nombres[valor]!;

  static Prioridad calcular({
    required TipoAmenaza tipo,
    required Ubicacion ubicacion,
    required Momento momento,
    required Magnitud magnitud,
    double? vientoKmh,
    int corroboraciones = 0,
  }) {
    var p = tipo.gravedad.toDouble();
    final m = <String>['${tipo.corto}: gravedad base ${tipo.gravedad} de 5'];

    if (ubicacion.dentro && ubicacion.zona.prioridadConservacion >= 5) {
      p += 1;
      m.add('Dentro de ${ubicacion.zona.nombre}, zona de conservación prioritaria');
    } else if (ubicacion.dentro) {
      m.add('Dentro del manglar de ${ubicacion.zona.municipio}');
    } else if (ubicacion.enInfluencia) {
      m.add('A ${ubicacion.distanciaM.round()} m: dentro del área de influencia (500 m)');
    } else {
      p -= 1;
      m.add('Lejos del manglar: se revisa si lo afecta');
    }

    switch (momento) {
      case Momento.ahora:
        m.add('Está pasando ahora: se puede actuar');
      case Momento.hoy:
        break;
      case Momento.antes:
        p -= 1;
        m.add('Ya pasó: sirve como registro, no como urgencia');
    }

    if (magnitud == Magnitud.grande) {
      p += 1;
      m.add('Afecta un área grande');
    }

    if (tipo == TipoAmenaza.quema && vientoKmh != null && vientoKmh >= 25) {
      p += 1;
      m.add('Viento de ${vientoKmh.round()} km/h: el fuego puede crecer');
    }

    if (corroboraciones > 0) {
      p += 1;
      m.add(corroboraciones == 1
          ? 'Otro reporte parecido cerca en las últimas 3 h'
          : '$corroboraciones reportes parecidos cerca en las últimas 3 h');
    }

    return Prioridad(p.round().clamp(1, 5), m);
  }
}

/// Solidez del reporte (0-100): cuánto se puede confiar en él antes de que lo revise
/// una persona. En la app sirve para guiar («toma una foto y sube a 80»); la decisión de
/// abrir un expediente siempre la toma un humano (pregunta 2 del reto).
class Solidez {
  const Solidez(this.valor, this.partes);
  final int valor;
  final List<(String, int, int)> partes; // (qué, obtenido, máximo)

  static Solidez calcular({
    required bool tieneFoto,
    required bool fotoDeCamara,
    required MetodoUbicacion metodo,
    required double? precisionM,
    required Ubicacion? ubicacion,
    required String descripcion,
    required Momento momento,
    required bool anonimo,
  }) {
    final partes = <(String, int, int)>[];
    final foto = !tieneFoto ? 0 : (fotoDeCamara ? 30 : 12);
    partes.add(('Foto tomada en el sitio', foto, 30));

    int ubic;
    if (metodo == MetodoUbicacion.gps) {
      final pr = precisionM ?? 999;
      ubic = pr <= 30 ? 20 : (pr <= 100 ? 14 : 8);
    } else {
      ubic = metodo == MetodoUbicacion.enlace ? 10 : 8;
    }
    partes.add(('Ubicación precisa', ubic, 20));

    partes.add(('Cerca del manglar', ubicacion?.enInfluencia == true ? 15 : 0, 15));

    final largo = descripcion.trim().length;
    partes.add(('Descripción', largo >= 25 ? 15 : (largo >= 8 ? 8 : 0), 15));

    partes.add(('Está pasando ahora', momento == Momento.antes ? 3 : 10, 10));
    partes.add(('Con tu nombre', anonimo ? 3 : 10, 10));

    final total = partes.fold<int>(0, (s, p) => s + p.$2);
    return Solidez(total.clamp(0, 100), partes);
  }
}

/// Reportes del mismo tipo a menos de 1 km en las últimas 3 horas (corroboración).
/// Con los reportes que ve el teléfono (los propios y los públicos del servidor).
int contarCorroboraciones({
  required TipoAmenaza tipo,
  required LatLng punto,
  required DateTime cuando,
  required Iterable<Reporte> otros,
  String? excluirId,
}) {
  const metros = Distance();
  var n = 0;
  for (final r in otros) {
    if (r.id == excluirId || r.tipo != tipo) continue;
    if (cuando.difference(r.capturadoEn).inMinutes.abs() > 180) continue;
    if (metros(punto, r.punto) <= 1000) n++;
  }
  return n;
}
