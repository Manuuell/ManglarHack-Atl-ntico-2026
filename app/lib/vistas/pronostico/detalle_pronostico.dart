import 'package:flutter/material.dart';

import '../../datos/pronostico/reglas.dart';
import '../../datos/pronostico/servicio_pronostico.dart';
import '../../datos/reporte.dart';
import '../../datos/zonas.dart';
import '../../nucleo/tema.dart';
import 'tarjeta_pronostico.dart'
    show antiguedadPronostico, colorNivel, horaPronostico, pronosticoVigente;

class DetallePronostico extends StatelessWidget {
  const DetallePronostico({
    super.key,
    required this.zona,
    required this.pronostico,
    this.reportes = const [],
  });
  final ZonaManglar zona;
  final PronosticoZona? pronostico;
  final List<Reporte> reportes;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final p = pronostico;
    return Scaffold(
      appBar: AppBar(title: const Text('Pronóstico del manglar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(zona.nombre, style: tt.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Centro de la zona · orientación para observar, no alerta oficial',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          if (p == null)
            const Text(
              'No se pudo cargar un pronóstico ni hay copia guardada para esta zona. Vuelve a intentar desde Inicio.',
            ),
          if (p != null) ...[
            Text(
              'Fuente: Open-Meteo Forecast y Marine · ${p.deCache ? 'copia guardada ' : 'consultado '}${horaPronostico(p.leido)}, ${antiguedadPronostico(p.leido, DateTime.now())}',
              style: tt.bodySmall,
            ),
            if (!pronosticoVigente(p, DateTime.now()))
              const Text(
                'Copia vencida: estas fechas son históricas y no indican el riesgo actual.',
              ),
            const SizedBox(height: 16),
            for (var i = 0; i < p.dias.length; i++) ...[
              Text(
                '${p.dias[i].fecha.day}/${p.dias[i].fecha.month}/${p.dias[i].fecha.year}',
                style: tt.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final alerta in evaluarPronostico(
                p.dias[i],
                reportes: pronosticoVigente(p, DateTime.now())
                    ? reportes
                    : const [],
                zonaId: zona.id,
                ahora: DateTime.now(),
              ))
                _FilaAlerta(alerta),
              const SizedBox(height: 16),
            ],
            Text(
              'Los umbrales son orientativos. Los reportes de este teléfono en los últimos 7 días elevan un nivel si corresponden a la zona y al tipo; no confirman causas. Los días secos son días previos con menos de 1 mm de lluvia modelada retrospectivamente o prevista.',
              style: tt.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaAlerta extends StatelessWidget {
  const _FilaAlerta(this.alerta);
  final AlertaManglar alerta;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = colorNivel(alerta.nivel);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(alerta.nombre, style: tt.titleSmall)),
                Semantics(
                  label: 'Nivel ${alerta.nivelTexto}',
                  child: Text(
                    alerta.nivelTexto.toUpperCase(),
                    style: tt.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Por qué: ${alerta.porQue}', style: tt.bodyMedium),
            const SizedBox(height: 6),
            Text(
              'Qué hacer: ${alerta.queHacer}',
              style: tt.bodyMedium?.copyWith(color: Zc.texto),
            ),
            const SizedBox(height: 6),
            Text('Fuente: ${alerta.fuente}', style: tt.bodySmall),
          ],
        ),
      ),
    );
  }
}
