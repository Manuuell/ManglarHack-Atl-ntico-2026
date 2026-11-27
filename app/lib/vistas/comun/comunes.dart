import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/prioridad.dart';
import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/tema.dart';

/// Piezas pequeñas que comparten todas las pantallas. Si una pantalla necesita una
/// variante, se agrega aquí (no se copia): así todo se ve igual.

/// Título grande estilo iOS con subtítulo y acción opcional a la derecha.
class CabeceraZ extends StatelessWidget {
  const CabeceraZ({super.key, required this.titulo, this.subtitulo, this.accion});
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitulo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(subtitulo!.toUpperCase(), style: tt.labelSmall?.copyWith(color: Zc.hoja)),
                  ),
                Text(titulo, style: tt.headlineMedium),
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Prioridad 1-5: color + número + palabra (nunca solo color: se lee con daltonismo y al sol).
class PildoraPrioridad extends StatelessWidget {
  const PildoraPrioridad(this.prioridad, {super.key, this.compacta = false});
  final int prioridad;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final c = Zc.dePrioridad(prioridad);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacta ? 8 : 10, vertical: compacta ? 3 : 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              compacta ? 'P$prioridad' : 'Prioridad ${Prioridad.nombres[prioridad]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Color.lerp(c, Zc.texto, 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dónde está el reporte: en el teléfono, enviándose, o ya en la CRA con su estado.
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.reporte, {super.key});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final demo = !Zanky.de(context).servidor.configurado;
    final (texto, color, icono) = switch (reporte.envio) {
      Envio.enCola when demo => ('Demostración · guardado en este teléfono', Zc.textoSuave, Icons.phone_android_rounded),
      Envio.enCola => ('En el teléfono · se envía con señal', Zc.textoSuave, Icons.schedule_rounded),
      Envio.enviando => ('Enviando…', Zc.cienaga, Icons.cloud_upload_rounded),
      Envio.error => ('Reintentando', Zc.sol, Icons.refresh_rounded),
      Envio.rechazado => ('La CRA no pudo recibirlo', Zc.prioridad[5]!, Icons.error_outline_rounded),
      Envio.enviado => (reporte.estado.nombre, _colorEstado(reporte.estado), _iconoEstado(reporte.estado)),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  static Color _colorEstado(EstadoReporte e) => switch (e) {
        EstadoReporte.recibido => Zc.cienaga,
        EstadoReporte.enVerificacion => Zc.sol,
        EstadoReporte.verificado => Zc.hoja,
        EstadoReporte.alertaOficial => const Color(0xFF6A4FA3),
        EstadoReporte.enAtencion => const Color(0xFFE06B2D),
        EstadoReporte.cerrado => Zc.raizSuave,
        EstadoReporte.descartado => Zc.textoTenue,
      };

  static IconData _iconoEstado(EstadoReporte e) => switch (e) {
        EstadoReporte.recibido => Icons.mark_email_read_rounded,
        EstadoReporte.enVerificacion => Icons.manage_search_rounded,
        EstadoReporte.verificado => Icons.verified_rounded,
        EstadoReporte.alertaOficial => Icons.gavel_rounded,
        EstadoReporte.enAtencion => Icons.directions_boat_rounded,
        EstadoReporte.cerrado => Icons.task_alt_rounded,
        EstadoReporte.descartado => Icons.do_not_disturb_on_rounded,
      };

  static Color colorDe(EstadoReporte e) => _colorEstado(e);
  static IconData iconoDe(EstadoReporte e) => _iconoEstado(e);
}

/// Ícono del tipo de amenaza en su círculo de color.
class IconoTipo extends StatelessWidget {
  const IconoTipo(this.tipo, {super.key, this.tamano = 44});
  final TipoAmenaza tipo;
  final double tamano;

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: tipo.color.withValues(alpha: 0.13), shape: BoxShape.circle),
        child: Icon(tipo.icono, color: tipo.color, size: tamano * 0.52),
      );
}

/// Franja de conexión: aparece solo si hay algo que decir (sin señal, o reportes en
/// cola). Con todo al día no ocupa espacio.
class FranjaConexion extends StatelessWidget {
  const FranjaConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final e = Zanky.de(context);
    final String? texto;
    final IconData icono;
    final Color color;
    if (!e.servidor.configurado) {
      texto = e.pendientes == 0
          ? null
          : 'Modo demostración: ${e.pendientes == 1 ? 'tu reporte queda' : 'tus ${e.pendientes} reportes quedan'} en este teléfono';
      icono = Icons.phone_android_rounded;
      color = Zc.textoSuave;
    } else if (!e.enLinea) {
      texto = e.pendientes == 0
          ? 'Sin señal. Puedes reportar igual: lo envío cuando vuelva.'
          : 'Sin señal · ${e.pendientes} ${e.pendientes == 1 ? 'reporte espera' : 'reportes esperan'} para enviarse';
      icono = Icons.signal_cellular_off_rounded;
      color = Zc.fango;
    } else if (e.pendientes > 0) {
      texto = e.sincronizando ? 'Enviando ${e.pendientes} ${e.pendientes == 1 ? 'reporte' : 'reportes'}…' : 'Reintentando el envío…';
      icono = Icons.cloud_upload_rounded;
      color = Zc.cienaga;
    } else {
      texto = null;
      icono = Icons.check;
      color = Zc.hoja;
    }
    return AnimatedSize(
      duration: Zm.medio,
      curve: Zm.entrar,
      child: texto == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Zr.s),
              ),
              child: Row(children: [
                Icon(icono, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(texto,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Color.lerp(color, Zc.texto, 0.4))),
                ),
              ]),
            ),
    );
  }
}

/// «hace 5 min», «hace 2 h», «ayer 16:40», «12 nov 09:15».
String haceCuanto(DateTime t, [DateTime? ahora]) {
  final n = ahora ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24 && n.day == t.day) return 'hace ${d.inHours} h';
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final ayer = n.subtract(const Duration(days: 1));
  if (t.year == ayer.year && t.month == ayer.month && t.day == ayer.day) return 'ayer $hm';
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${t.day} ${meses[t.month - 1]} $hm';
}
