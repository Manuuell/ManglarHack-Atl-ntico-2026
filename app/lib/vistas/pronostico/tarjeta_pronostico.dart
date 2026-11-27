import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/pronostico/reglas.dart';
import '../../datos/pronostico/servicio_pronostico.dart';
import '../../datos/reporte.dart';
import '../../datos/zonas.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'detalle_pronostico.dart';

String antiguedadPronostico(DateTime fecha, DateTime ahora) {
  final diferencia = ahora.difference(fecha);
  if (diferencia.isNegative || diferencia.inMinutes < 1) {
    return 'de hace menos de 1 min';
  }
  if (diferencia.inMinutes < 60) return 'de hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'de hace ${diferencia.inHours} h';
  return 'de hace ${diferencia.inDays} días';
}

String horaPronostico(DateTime fecha) {
  final local = fecha.toUtc().subtract(const Duration(hours: 5));
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} COT';
}

bool pronosticoVigente(PronosticoZona p, DateTime ahora) {
  final hoy = ahora.toUtc().subtract(const Duration(hours: 5));
  final fechaHoy = DateTime.utc(hoy.year, hoy.month, hoy.day);
  return p.dias.any((d) => !d.fecha.isBefore(fechaHoy));
}

Color colorNivel(NivelPronostico? nivel) => switch (nivel) {
  NivelPronostico.bajo => Zc.raizSuave,
  NivelPronostico.medio => const Color(0xFF805000),
  NivelPronostico.alto => const Color(0xFFA52727),
  null => Zc.textoSuave,
};

NivelPronostico? nivelZona(
  PronosticoZona? p,
  List<Reporte> reportes,
  String zonaId,
  DateTime ahora,
) {
  NivelPronostico? mayor;
  if (p == null || !pronosticoVigente(p, ahora)) return null;
  for (final dia in p.dias) {
    final hoy = ahora.toUtc().subtract(const Duration(hours: 5));
    if (dia.fecha.isBefore(DateTime.utc(hoy.year, hoy.month, hoy.day))) {
      continue;
    }
    for (final alerta in evaluarPronostico(
      dia,
      reportes: reportes,
      zonaId: zonaId,
      ahora: ahora,
    )) {
      if (alerta.nivel != null &&
          (mayor == null || alerta.nivel!.index > mayor.index)) {
        mayor = alerta.nivel;
      }
    }
  }
  return mayor;
}

/// Pieza autónoma para Inicio: obtiene las cuatro zonas del estado si no se inyectan.
class TarjetaPronostico extends StatefulWidget {
  const TarjetaPronostico({
    super.key,
    this.zonas,
    this.reportes,
    this.servicio,
  });
  final List<ZonaManglar>? zonas;
  final List<Reporte>? reportes;
  final ServicioPronostico? servicio;

  @override
  State<TarjetaPronostico> createState() => _TarjetaPronosticoState();
}

class _TarjetaPronosticoState extends State<TarjetaPronostico> {
  late final ServicioPronostico _servicio =
      widget.servicio ?? ServicioPronostico();
  final _datos = <String, PronosticoZona?>{};
  bool _cargando = true;
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciada) {
      _iniciada = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar();
      });
    }
  }

  List<ZonaManglar> get _zonas =>
      widget.zonas ?? Zanky.de(context).manglar.zonas;
  List<Reporte> get _reportes => widget.reportes ?? Zanky.de(context).reportes;

  Future<void> _cargar() async {
    final zonas = _zonas;
    setState(() => _cargando = true);
    final copias = await Future.wait(zonas.map((z) => _servicio.ultimo(z.id)));
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < zonas.length; i++) {
        final copia = copias[i];
        final actual = _datos[zonas[i].id];
        if (copia != null &&
            (actual == null || copia.leido.isAfter(actual.leido))) {
          _datos[zonas[i].id] = copia;
        }
      }
    });
    final resultados = await Future.wait(zonas.map((z) => _servicio.cargar(z)));
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < zonas.length; i++) {
        final nuevo = resultados[i];
        final actual = _datos[zonas[i].id];
        if (nuevo != null &&
            (actual == null || !nuevo.leido.isBefore(actual.leido))) {
          _datos[zonas[i].id] = nuevo;
        }
      }
      _cargando = false;
    });
  }

  @override
  void dispose() {
    if (widget.servicio == null) _servicio.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final zonas = _zonas;
    final reportes = _reportes;
    final ahora = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.troubleshoot_rounded,
                  color: Zc.raiz,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pronóstico del manglar', style: tt.titleMedium),
                ),
                IconButton(
                  tooltip: 'Actualizar pronóstico',
                  onPressed: _cargando ? null : _cargar,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              'Próximos 3 días · señales para observar, no alerta oficial',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final zona in zonas)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Presionable(
                  etiqueta: 'Ver pronóstico de ${zona.nombre}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetallePronostico(
                        zona: zona,
                        pronostico: _datos[zona.id],
                        reportes: reportes,
                      ),
                    ),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Zc.arena,
                      borderRadius: BorderRadius.circular(Zr.s),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                zona.nombre,
                                style: tt.labelMedium,
                                maxLines: 2,
                              ),
                              if (_datos[zona.id] != null)
                                Text(
                                  '${_datos[zona.id]!.deCache ? 'Copia guardada' : 'Actualizado'} · ${horaPronostico(_datos[zona.id]!.leido)} · ${antiguedadPronostico(_datos[zona.id]!.leido, ahora)}',
                                  style: tt.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EtiquetaNivel(
                          nivelZona(_datos[zona.id], reportes, zona.id, ahora),
                          caducado:
                              _datos[zona.id] != null &&
                              !pronosticoVigente(_datos[zona.id]!, ahora),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_cargando) Text('Consultando Open-Meteo…', style: tt.bodySmall),
            if (!_cargando && _datos.values.every((v) => v == null))
              Text(
                'No se pudo cargar el pronóstico y no hay copia guardada. Reintenta cuando haya señal.',
                style: tt.bodySmall,
              ),
            if (_datos.values.any((v) => v != null))
              Text(
                'Fuente: Open-Meteo Forecast y Marine. Copias antiguas no indican riesgo actual.',
                style: tt.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaNivel extends StatelessWidget {
  const _EtiquetaNivel(this.nivel, {this.caducado = false});
  final NivelPronostico? nivel;
  final bool caducado;

  @override
  Widget build(BuildContext context) {
    final nombre = caducado ? 'Vencido' : nivel?.name ?? 'Sin datos';
    final color = colorNivel(nivel);
    return Semantics(
      label: 'Nivel $nombre',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          nombre,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
