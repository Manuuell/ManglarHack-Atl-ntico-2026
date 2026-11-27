import 'reporte.dart';
import 'tipos.dart';

/// En qué va cada reporte del teléfono, contado para el «estado de mis reportes» de Inicio.
/// Cada reporte cae en UNA sola casilla, así la suma siempre cierra.
class ResumenReportes {
  const ResumenReportes({
    this.enTelefono = 0,
    this.enRevision = 0,
    this.validados = 0,
    this.descartados = 0,
    this.rechazados = 0,
  });

  /// Guardados en el teléfono, esperando salir (sin señal, enviándose o con un error pasajero).
  final int enTelefono;

  /// Ya en la CRA, sin validar todavía.
  final int enRevision;
  final int validados;
  final int descartados;

  /// El servidor no los aceptó (no se reintentan solos).
  final int rechazados;

  int get total => enTelefono + enRevision + validados + descartados + rechazados;
  bool get vacio => total == 0;

  static ResumenReportes de(Iterable<Reporte> reportes) {
    var tel = 0, rev = 0, val = 0, des = 0, rec = 0;
    for (final r in reportes) {
      if (r.envio == Envio.rechazado) {
        rec++;
      } else if (r.envio != Envio.enviado) {
        tel++;
      } else if (r.estado.validado) {
        val++;
      } else if (r.estado == EstadoReporte.descartado) {
        des++;
      } else {
        rev++;
      }
    }
    return ResumenReportes(enTelefono: tel, enRevision: rev, validados: val, descartados: des, rechazados: rec);
  }
}
