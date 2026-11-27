import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/confirmar.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'detalle_reporte.dart';
import 'foto_reporte.dart';
import 'tarjeta_reporte.dart';

/// Lo que se puede decir en voz alta de un reporte: caso, tipo, zona y estado.
/// Nunca las coordenadas ni nada del perfil.
String textoCompartirReporte(Reporte r) {
  final estado = r.envio == Envio.enviado ? r.estado.nombre : 'Guardado en mi teléfono, aún sin enviar';
  return 'Reporté un problema en el manglar con Zanky.\n'
      'Caso: ${r.caso}\n'
      'Qué: ${r.tipo.nombre}\n'
      'Zona: ${r.zonaNombre}\n'
      'Estado: $estado';
}

Future<void> compartirReporte(BuildContext context, Reporte r) async {
  try {
    await SharePlus.instance.share(ShareParams(text: textoCompartirReporte(r), subject: 'Caso ${r.caso} en Zanky'));
  } catch (_) {
    if (context.mounted) avisar(context, 'No pude abrir el menú de compartir.', tipo: TipoAviso.error);
  }
}

/// Quitar del teléfono: confirma en hoja y deja «Deshacer». [raiz] es un contexto
/// que sigue vivo cuando la tarjeta ya no está.
Future<void> quitarReporteConDeshacer(BuildContext context, Reporte r) {
  final estado = Zanky.leer(context);
  return accionConDeshacer(
    context,
    titulo: '¿Quitar este reporte?',
    texto: 'Solo se quita de este teléfono: todavía no salió hacia la CRA. Puedes deshacerlo unos segundos.',
    textoConfirmar: 'Quitar del teléfono',
    avisoHecho: 'Reporte quitado',
    hacer: () => estado.quitarReporte(r),
    deshacer: () => estado.restaurarReporte(r),
  );
}

/// Las acciones de una tarjeta de «Mis reportes»: se usan al deslizar, en el menú
/// al mantener y en el lector de pantalla (una sola lista, tres caminos).
class AccionesReporte {
  AccionesReporte(this.context, this.reporte);
  final BuildContext context;
  final Reporte reporte;

  AccionGesto get compartir => AccionGesto(
        etiqueta: 'Compartir',
        icono: Icons.ios_share_rounded,
        color: Zc.cienaga,
        alEjecutar: () => compartirReporte(context, reporte),
      );

  AccionGesto get abrir => AccionGesto(
        etiqueta: 'Ver detalle',
        icono: Icons.open_in_new_rounded,
        alEjecutar: () => abrirDetalleReporte(context, reporte),
      );

  AccionGesto get quitar => AccionGesto(
        etiqueta: 'Quitar del teléfono',
        icono: Icons.delete_outline_rounded,
        destructiva: true,
        alEjecutar: () => quitarReporteConDeshacer(context, reporte),
      );
}

/// La vista previa del «peek»: foto grande y el resumen del detalle.
class VistaPreviaReporte extends StatelessWidget {
  const VistaPreviaReporte({super.key, required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = reporte;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: FotoReporte(reporte: r, ancho: double.infinity, alto: 150, cacheAncho: 600),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(r.tipo.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleMedium)),
                const SizedBox(width: 8),
                PildoraPrioridad(r.prioridad, compacta: true),
              ]),
              const SizedBox(height: 2),
              Text('${r.caso} · ${r.zonaNombre} · ${haceCuanto(r.capturadoEn)}', style: tt.bodySmall),
              const SizedBox(height: 8),
              ChipEstado(r),
              const SizedBox(height: 8),
              MiniCamino(reporte: r),
            ],
          ),
        ),
      ],
    );
  }
}
