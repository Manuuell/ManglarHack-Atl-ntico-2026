import 'package:flutter/material.dart';

import '../../../datos/sensores/lecturas_sensor.dart';
import '../../../datos/sensores/servicio_sensores.dart';
import '../../../nucleo/identidad.dart';
import '../../../nucleo/presionable.dart';
import '../../../nucleo/tema.dart';
import '../../sensores/detalle_estacion.dart';
import '../../sensores/graficas_sensor.dart';
import '../../sensores/pantalla_sensores.dart';

/// «Sensores y microcontroladores» dentro del panel: estaciones ESP32 con su estado, mini
/// gráficas de nivel, salinidad y temperatura, alertas de umbral con su hora y acceso a la
/// pantalla completa. Usa el mismo servicio, modelos y gráficas de «Sensores del manglar».
class SeccionSensoresAdmin extends StatefulWidget {
  const SeccionSensoresAdmin({super.key, this.servicio});
  final ServicioSensores? servicio;

  @override
  State<SeccionSensoresAdmin> createState() => _SeccionSensoresAdminState();
}

class _SeccionSensoresAdminState extends State<SeccionSensoresAdmin> {
  ServicioSensores? _servicio;
  ResultadoSensores? _r;
  bool _cargando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicio == null) {
      _servicio = widget.servicio ?? crearServicioSensores(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar();
      });
    }
  }

  Future<ResultadoSensores> _cargar() async {
    setState(() => _cargando = true);
    final copia = _r == null ? await _servicio!.copia() : null;
    if (mounted && copia != null) setState(() => _r = copia);
    final r = await _servicio!.cargar();
    if (mounted) {
      setState(() {
        _r = r;
        _cargando = false;
      });
    }
    return r;
  }

  @override
  void dispose() {
    if (widget.servicio == null) _servicio?.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final tt = Theme.of(context).textTheme;
    if (r == null) {
      return const Center(
        child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Cra.dorado)),
      );
    }
    final ahora = relojSensores();
    final estaciones = agruparEstaciones(r.lecturas, ahora);
    final alertas = [for (final e in estaciones) ...e.enAlerta(ahora)]
      ..sort((a, b) => (b.medidoEn ?? ahora).compareTo(a.medidoEn ?? ahora));
    final enLinea = estaciones.where((e) => e.estado(ahora).index <= EstadoLectura.enLinea.index).length;
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho >= 1100 ? 3 : (ancho >= 700 ? 2 : 1);

    return RefreshIndicator(
      color: Cra.dorado,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Origen(resultado: r, ahora: ahora, cargando: _cargando),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Cifra(valor: '${estaciones.length}', texto: 'estaciones', color: Cra.info),
                      _Cifra(valor: '$enLinea', texto: 'en línea', color: Cra.acierto),
                      _Cifra(valor: '${estaciones.length - enLinea}', texto: 'sin reportar', color: Cra.textoTenue),
                      _Cifra(
                        valor: '${alertas.length}',
                        texto: alertas.length == 1 ? 'alerta' : 'alertas',
                        color: alertas.isEmpty ? Cra.textoTenue : Cra.riesgo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(header: true, child: Text('Alertas de umbral', style: tt.titleMedium)),
                  const SizedBox(height: 8),
                  if (alertas.isEmpty)
                    _Caja(
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Cra.acierto),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Ninguna sonda pasó su umbral en las últimas horas.', style: tt.bodyMedium),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final l in alertas) _FilaAlerta(lectura: l, ahora: ahora),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(header: true, child: Text('Estaciones ESP32', style: tt.titleMedium)),
                      TextButton.icon(
                        onPressed: () => abrirSensores(context, servicio: _servicio),
                        icon: const Icon(Icons.open_in_full_rounded, size: 18),
                        label: const Text('Pantalla completa'),
                        style: TextButton.styleFrom(foregroundColor: Cra.dorado, minimumSize: const Size(48, 48)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (estaciones.isEmpty)
                    _Caja(child: Text('Aún no hay estaciones registradas.', style: tt.bodyMedium))
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = (c.maxWidth - 12 * (columnas - 1)) / columnas;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final e in estaciones)
                              SizedBox(
                                width: w,
                                child: _TarjetaEstacion(
                                  estacion: e,
                                  resultado: r,
                                  ahora: ahora,
                                  alTocar: () =>
                                      abrirDetalleEstacion(context, estacion: e, resultado: r, alActualizar: _cargar),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorEstado(EstadoLectura e) => switch (e) {
  EstadoLectura.alerta => Cra.riesgo,
  EstadoLectura.enLinea => Cra.acierto,
  EstadoLectura.vieja => Cra.dorado,
  EstadoLectura.sinDatos => Cra.textoTenue,
};

class _Origen extends StatelessWidget {
  const _Origen({required this.resultado, required this.ahora, required this.cargando});
  final ResultadoSensores resultado;
  final DateTime ahora;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (resultado.origen) {
      OrigenSensores.demostracion => (
        Icons.science_outlined,
        'Datos de demostración: aún no llegan lecturas reales.',
        Cra.dorado,
      ),
      OrigenSensores.copia => (
        Icons.cloud_off_rounded,
        'Sin conexión: copia de ${haceCuanto(resultado.leido, ahora)}.',
        Cra.textoTenue,
      ),
      _ => (Icons.cloud_done_rounded, 'En vivo · leído ${haceCuanto(resultado.leido, ahora)}', Cra.textoTenue),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
          ),
          if (cargando)
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Cra.dorado)),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child, this.borde = Cra.linea});
  final Widget child;
  final Color borde;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Cra.superficie,
      borderRadius: BorderRadius.circular(Zr.m),
      border: Border.all(color: borde),
    ),
    child: child,
  );
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.texto, required this.color});
  final String valor;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: '$valor $texto',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Cra.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Cra.linea),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: valor,
                style: tt.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
              TextSpan(text: '  $texto', style: tt.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaAlerta extends StatelessWidget {
  const _FilaAlerta({required this.lectura, required this.ahora});
  final LecturaSensor lectura;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final l = lectura;
    final tt = Theme.of(context).textTheme;
    final hora = l.medidoEn == null ? '' : '${horaColombia(l.medidoEn!)} · ${haceCuanto(l.medidoEn, ahora)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Caja(
        borde: Cra.riesgo,
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Cra.riesgo),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.tipo.nombre} · ${l.zonaNombre}',
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${l.valor == null ? 'Sin valor' : l.tipo.formatear(l.valor!)} (umbral ${l.tipo.formatear(l.umbral)}'
                    '${l.umbralEsDeReferencia ? ', de referencia' : ''})',
                    style: tt.bodySmall,
                  ),
                  if (hora.isNotEmpty)
                    Text(
                      hora,
                      style: tt.bodySmall?.copyWith(color: Cra.textoSuave, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaEstacion extends StatelessWidget {
  const _TarjetaEstacion({required this.estacion, required this.resultado, required this.ahora, required this.alTocar});
  final Estacion estacion;
  final ResultadoSensores resultado;
  final DateTime ahora;
  final VoidCallback alTocar;

  static const _tipos = [TipoSensor.nivelAgua, TipoSensor.salinidad, TipoSensor.temperatura];

  @override
  Widget build(BuildContext context) {
    final e = estacion;
    final tt = Theme.of(context).textTheme;
    final estado = e.estado(ahora);
    final color = _colorEstado(estado);
    return Presionable(
      etiqueta: 'Estación ${e.zonaNombre}, ${textoEstado(estado, e.ultimaLectura, ahora)}',
      onTap: alTocar,
      child: _Caja(
        borde: estado == EstadoLectura.alerta ? Cra.riesgo : Cra.linea,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory_rounded, color: Cra.dorado, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.zonaNombre,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoEstado(estado), size: 14, color: color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              switch (estado) {
                                EstadoLectura.alerta => 'Alerta',
                                EstadoLectura.enLinea => 'En línea',
                                EstadoLectura.vieja => 'Sin reportar',
                                EstadoLectura.sinDatos => 'Sin datos',
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('Última lectura: ${haceCuanto(e.ultimaLectura, ahora)}', style: tt.bodySmall),
              const SizedBox(height: 10),
              for (final t in _tipos)
                if (e.lecturas.where((l) => l.tipo == t).firstOrNull case final l?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 118,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.nombre,
                                style: tt.labelSmall?.copyWith(color: Cra.textoTenue),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l.valor == null ? '—' : t.formatear(l.valor!),
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: l.superaUmbral ? Cra.riesgo : Cra.blanco,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChispaSensor(
                            valores: [for (final p in resultado.series[l.sensorId] ?? const <PuntoSerie>[]) p.valor],
                            color: l.superaUmbral ? Cra.riesgo : Cra.info,
                            umbral: l.umbral,
                            altura: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
