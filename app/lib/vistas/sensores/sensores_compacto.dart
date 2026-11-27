import 'package:flutter/material.dart';

import '../../datos/comunidad/comunidad.dart' show NivelAlerta;
import '../../datos/sensores/lecturas_sensor.dart';
import '../../datos/sensores/servicio_sensores.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comunidad/alertas_diseno.dart';
import 'pantalla_sensores.dart';

/// Los sensores en una fila para Inicio (misma forma que `PronosticoCompacto`): la alerta si la
/// hay, o cuántas estaciones están en línea; un toque abre «Sensores del manglar».
class SensoresCompacto extends StatefulWidget {
  const SensoresCompacto({super.key, this.servicio});
  final ServicioSensores? servicio;

  @override
  State<SensoresCompacto> createState() => _SensoresCompactoState();
}

class _SensoresCompactoState extends State<SensoresCompacto> {
  ServicioSensores? _servicio;
  ResultadoSensores? _r;

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

  Future<void> _cargar() async {
    final copia = await _servicio!.copia();
    if (mounted && copia != null) setState(() => _r = copia);
    final r = await _servicio!.cargar();
    if (mounted) setState(() => _r = r);
  }

  @override
  void dispose() {
    if (widget.servicio == null) _servicio?.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ahora = relojSensores();
    final r = _r;
    final estaciones = r == null ? const <Estacion>[] : agruparEstaciones(r.lecturas, ahora);
    final alertas = [for (final e in estaciones) ...e.enAlerta(ahora)];
    final enLinea = estaciones.where((e) {
      final s = e.estado(ahora);
      return s == EstadoLectura.enLinea || s == EstadoLectura.alerta;
    }).length;
    final ultima = estaciones.map((e) => e.ultimaLectura).whereType<DateTime>().fold<DateTime?>(
          null,
          (u, t) => u == null || t.isAfter(u) ? t : u,
        );
    final hayAlerta = alertas.isNotEmpty;
    // Con alerta, el sistema de niveles de las alertas (naranja: un umbral superado; sello «Sensores»).
    const nivel = EstiloNivel.naranja;
    final color = hayAlerta ? nivel.color : Zc.cienaga;
    final titulo = r == null
        ? 'Leyendo las estaciones…'
        : hayAlerta
            ? 'Alerta: ${alertas.first.tipo.nombre.toLowerCase()} en ${alertas.first.zonaNombre}'
            : '$enLinea de ${estaciones.length} estaciones en línea';
    final detalle = r == null
        ? 'Nivel de agua, salinidad y temperatura.'
        : [
            if (r.esDemostracion) 'DEMOSTRACIÓN',
            if (r.origen == OrigenSensores.copia) 'Sin señal',
            if (hayAlerta)
              '${alertas.first.tipo.formatear(alertas.first.valor!)}, umbral ${alertas.first.tipo.formatear(alertas.first.umbral)}'
            else
              'Última lectura ${haceCuanto(ultima, ahora)}',
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        etiqueta: 'Ver los sensores del manglar. $titulo. $detalle',
        onTap: () => abrirSensores(context, servicio: widget.servicio),
        child: Container(
          key: const ValueKey('sensores-compacto'),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Zc.superficie,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: hayAlerta ? color.withValues(alpha: 0.5) : Zc.linea, width: hayAlerta ? 1.5 : 1),
            boxShadow: hayAlerta ? [BoxShadow(color: color.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6))] : null,
          ),
          child: Row(
            children: [
              if (hayAlerta)
                const InsigniaAlerta(tipo: 'sensor', nivel: NivelAlerta.naranja, tamano: 44)
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.sensors_rounded, color: Zc.cienaga),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hayAlerta)
                      Text('ALERTA NARANJA · SENSORES',
                          style: tt.labelSmall?.copyWith(color: nivel.tinta, fontWeight: FontWeight.w900))
                    else
                      Text('SENSORES DEL MANGLAR', style: tt.labelSmall),
                    Text(titulo, style: tt.titleSmall?.copyWith(color: hayAlerta ? Zc.texto : null, fontWeight: hayAlerta ? FontWeight.w800 : null)),
                    Text(detalle, style: tt.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Ver', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
              const Icon(Icons.chevron_right_rounded, color: Zc.hoja, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
