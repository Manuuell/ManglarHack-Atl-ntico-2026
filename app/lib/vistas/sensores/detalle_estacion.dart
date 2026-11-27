import 'package:flutter/material.dart';

import '../../datos/sensores/lecturas_sensor.dart';
import '../../datos/sensores/servicio_sensores.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/tema.dart';
import '../admin/piezas_admin.dart' show BotonIcono;
import 'graficas_sensor.dart';
import 'pantalla_sensores.dart';

/// Detalle de una estación. Ruta de borde del kit: deslizar desde el borde izquierdo vuelve.
Future<void> abrirDetalleEstacion(
  BuildContext context, {
  required Estacion estacion,
  required ResultadoSensores resultado,
  required Future<ResultadoSensores> Function() alActualizar,
}) {
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'detalle_estacion'),
      builder: (_) => DetalleEstacion(estacion: estacion, resultado: resultado, alActualizar: alActualizar),
    ),
  );
}

class DetalleEstacion extends StatefulWidget {
  const DetalleEstacion({super.key, required this.estacion, required this.resultado, required this.alActualizar});
  final Estacion estacion;
  final ResultadoSensores resultado;
  final Future<ResultadoSensores> Function() alActualizar;

  @override
  State<DetalleEstacion> createState() => _DetalleEstacionState();
}

class _DetalleEstacionState extends State<DetalleEstacion> {
  late Estacion _e = widget.estacion;
  late ResultadoSensores _r = widget.resultado;

  Future<void> _actualizar() async {
    final r = await widget.alActualizar();
    if (!mounted) return;
    final propias = [for (final l in r.lecturas) if (l.zonaId == _e.zonaId) l];
    setState(() {
      _r = r;
      if (propias.isNotEmpty) _e = Estacion(_e.zonaId, _e.zonaNombre, propias);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ahora = relojSensores();
    final estado = _e.estado(ahora);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
              child: Row(
                children: [
                  BotonIcono(
                    icono: Icons.arrow_back_rounded,
                    etiqueta: 'Volver a las estaciones',
                    alTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(_e.zonaNombre, style: tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          _r.esDemostracion ? 'DEMOSTRACIÓN · datos de ejemplo' : 'Estación de sensores',
                          style: tt.bodySmall?.copyWith(color: _r.esDemostracion ? Zc.fango : null),
                        ),
                      ],
                    ),
                  ),
                  BotonIcono(icono: Icons.refresh_rounded, etiqueta: 'Actualizar lecturas', alTocar: _actualizar),
                ],
              ),
            ),
            Expanded(
              child: TirarActualizar(
                alActualizar: _actualizar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PastillaEstado(
                                estado: estado,
                                riesgo: _e.riesgo(ahora),
                                texto: textoEstado(estado, _e.ultimaLectura, ahora),
                              ),
                            ),
                            for (final l in _e.lecturas) ...[
                              const SizedBox(height: 12),
                              _TarjetaSonda(lectura: l, serie: _r.series[l.sensorId] ?? const [], ahora: ahora),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'La estación mide cada 10 minutos y guarda las lecturas si pierde el WiFi. '
                              'La gráfica muestra lo que este teléfono ha visto en las últimas 12 horas.',
                              style: tt.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaSonda extends StatelessWidget {
  const _TarjetaSonda({required this.lectura, required this.serie, required this.ahora});
  final LecturaSensor lectura;
  final List<PuntoSerie> serie;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = lectura;
    final estado = l.estado(ahora);
    final color = colorEstado(estado, l.riesgo(ahora));
    final alerta = estado == EstadoLectura.alerta;
    return Container(
      key: ValueKey('sonda-${l.sensorId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: alerta ? color : Zc.linea, width: alerta ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.tipo.nombre, style: tt.titleMedium),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: PastillaEstado(estado: estado, riesgo: l.riesgo(ahora), texto: textoEstado(estado, l.medidoEn, ahora)),
          ),
          const SizedBox(height: 6),
          Text(
            l.valor == null ? 'Sin lecturas' : l.tipo.formatear(l.valor!),
            style: tt.displaySmall?.copyWith(
              color: alerta ? color : Zc.texto,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (l.medidoEn != null)
            Text('Medido a las ${horaColombia(l.medidoEn!)} (hora de Colombia)', style: tt.bodySmall),
          const SizedBox(height: 12),
          MedidorUmbral(lectura: l, ahora: ahora),
          const SizedBox(height: 4),
          Text(
            'Umbral ${l.tipo.formatear(l.umbral)}${l.umbralEsDeReferencia ? ' (de referencia)' : ' (fijado por la CRA)'}',
            style: tt.labelSmall,
          ),
          const SizedBox(height: 14),
          ChispaSensor(
            valores: [for (final p in serie) p.valor],
            color: color,
            umbral: l.valor == null ? null : l.umbral,
            altura: 72,
            grosor: 2.5,
          ),
          const SizedBox(height: 4),
          Text(
            serie.length < 2
                ? 'La gráfica aparece con la segunda lectura.'
                : 'De ${horaColombia(serie.first.en)} a ${horaColombia(serie.last.en)} · ${serie.length} lecturas · '
                    'línea roja: umbral',
            style: tt.labelSmall,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: alerta ? color.withValues(alpha: 0.08) : Zc.arena,
              borderRadius: BorderRadius.circular(Zr.s),
            ),
            child: Text(
              alerta
                  ? 'Pasó el umbral. ${l.tipo.explicacion} Un vigía debe revisarlo; no es una alerta oficial.'
                  : l.tipo.explicacion,
              style: tt.bodySmall?.copyWith(color: Zc.texto),
            ),
          ),
        ],
      ),
    );
  }
}
