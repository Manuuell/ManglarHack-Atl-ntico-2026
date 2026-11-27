import 'package:flutter/material.dart';

import '../../datos/reporte.dart';
import '../../datos/tipos.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import 'foto_reporte.dart';

/// Hasta qué paso del camino llegó el reporte: índice en [EstadoReporte.camino]
/// (0 = recibido), o -1 si todavía no salió del teléfono. Mira el estado y todo el
/// historial, porque la CRA puede saltarse un paso sin avisar.
int indiceAlcanzado(Reporte r) {
  if (r.envio != Envio.enviado) return -1;
  var m = 0;
  for (final e in [r.estado, ...r.historial.map((h) => h.estado)]) {
    final i = EstadoReporte.camino.indexOf(e);
    if (i > m) m = i;
  }
  return m;
}

/// Una fila de «Mis reportes»: miniatura, qué es, dónde y cuándo, en qué va.
class TarjetaReporte extends StatelessWidget {
  const TarjetaReporte({super.key, required this.reporte, required this.alTocar});
  final Reporte reporte;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = reporte;
    return Presionable(
      onTap: alTocar,
      escala: 0.98,
      vibracion: Vibracion.ligera,
      etiqueta: '${r.tipo.nombre}, caso ${r.caso}, ${r.zonaNombre}. Abrir el detalle',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FotoReporte(reporte: r, ancho: 84, alto: 84, radio: Zr.m - 2, hero: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(r.tipo.corto,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                    ),
                    const SizedBox(width: 8),
                    PildoraPrioridad(r.prioridad, compacta: true),
                  ]),
                  const SizedBox(height: 2),
                  Text('${r.caso} · ${r.zonaNombre}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                  Text(haceCuanto(r.capturadoEn), style: tt.bodySmall?.copyWith(color: Zc.textoTenue)),
                  const SizedBox(height: 8),
                  ChipEstado(r),
                  const SizedBox(height: 8),
                  MiniCamino(reporte: r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seis rayitas, una por paso del camino de estados. Las alcanzadas toman el color
/// del estado; con «descartado» quedan en gris.
class MiniCamino extends StatelessWidget {
  const MiniCamino({super.key, required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final r = reporte;
    final alcanzado = indiceAlcanzado(r);
    final color = r.estado == EstadoReporte.descartado ? Zc.textoTenue : ChipEstado.colorDe(r.estado);
    final total = EstadoReporte.camino.length;
    final texto = alcanzado < 0
        ? 'Aún no sale del teléfono'
        : r.estado == EstadoReporte.descartado
            ? 'Descartado tras la revisión'
            : 'Paso ${alcanzado + 1} de $total: ${EstadoReporte.camino[alcanzado].nombre}';
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: AnimatedContainer(
                duration: Zm.medio,
                curve: Zm.entrar,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= alcanzado ? color : Zc.linea,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
