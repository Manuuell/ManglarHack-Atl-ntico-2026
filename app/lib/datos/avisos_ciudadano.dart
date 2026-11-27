import 'reporte.dart';
import 'tipos.dart';

/// Un reporte propio cuyo estado cambió desde la última vez que la persona lo vio.
class CambioDeReporte {
  const CambioDeReporte(this.reporte, this.antes);
  final Reporte reporte;
  final EstadoReporte antes;

  EstadoReporte get ahora => reporte.estado;

  /// Una frase para la persona, con lo que la CRA le dejó dicho si lo hay.
  String get frase {
    final tipo = reporte.tipo.corto.toLowerCase();
    final nota = _ultimaNota;
    final con = nota == null ? '' : ' «$nota»';
    return switch (ahora) {
      EstadoReporte.verificado => 'Aprobaron tu reporte de $tipo: se confirmó que es real. ¡Gracias!',
      EstadoReporte.alertaOficial => 'Tu reporte de $tipo abrió un expediente en la CRA.',
      EstadoReporte.enAtencion => 'Hay un operativo por tu reporte de $tipo.',
      EstadoReporte.cerrado => 'Se atendió y se cerró tu reporte de $tipo.',
      EstadoReporte.descartado => 'No se pudo confirmar tu reporte de $tipo.$con',
      EstadoReporte.enVerificacion =>
        nota == null ? 'Ya están revisando tu reporte de $tipo.' : 'Piden más datos de tu reporte de $tipo:$con',
      EstadoReporte.recibido => 'Tu reporte de $tipo volvió a «Recibido».',
    };
  }

  String? get _ultimaNota {
    for (final c in reporte.historial.reversed) {
      if (c.estado == ahora && c.nota != null && c.nota!.trim().isNotEmpty) return c.nota!.trim();
    }
    return null;
  }
}

/// El aviso al ciudadano cuando su reporte cambia de estado (aprobado, rechazado…).
///
/// La app guarda el último estado que la persona VIO de cada reporte suyo. Al volver a
/// abrirla, `EstadoZanky` trae los estados del servidor; todo lo que difiere de lo visto
/// es un cambio nuevo. Se avisa una sola vez: al mostrarlo se anota como visto.
abstract final class AvisosCiudadano {
  static const clave = 'avisos.vistos.v1';

  /// Los cambios que la persona aún no ha visto. Solo cuentan reportes ya enviados y un
  /// reporte que no está en [vistos] se toma como «recibido» (así nace).
  static List<CambioDeReporte> pendientes(Iterable<Reporte> reportes, Map<String, String> vistos) {
    final l = <CambioDeReporte>[];
    for (final r in reportes) {
      if (r.envio != Envio.enviado) continue;
      final antes = EstadoReporte.deSlug(vistos[r.id] ?? EstadoReporte.recibido.slug);
      if (antes != r.estado) l.add(CambioDeReporte(r, antes));
    }
    l.sort((a, b) => (b.reporte.cambiadoEn ?? b.reporte.capturadoEn).compareTo(a.reporte.cambiadoEn ?? a.reporte.capturadoEn));
    return l;
  }

  /// Lo que hay que guardar para dar por vistos [reportes] tal como están ahora.
  static Map<String, String> instantanea(Iterable<Reporte> reportes) => {
        for (final r in reportes)
          if (r.envio == Envio.enviado) r.id: r.estado.slug,
      };

  /// Título del aviso: uno solo o varios.
  static String titulo(List<CambioDeReporte> c) =>
      c.length == 1 ? 'Tu reporte cambió' : '${c.length} de tus reportes cambiaron';

  static String cuerpo(List<CambioDeReporte> c) =>
      c.length == 1 ? c.first.frase : '${c.first.frase} Y ${c.length - 1} más.';
}
