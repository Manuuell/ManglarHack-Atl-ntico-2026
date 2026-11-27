import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/pronostico/reglas.dart';
import '../../datos/pronostico/servicio_pronostico.dart';
import '../../datos/zonas.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../pronostico/detalle_pronostico.dart';
import '../pronostico/tarjeta_pronostico.dart';

/// Quién arma el servicio de pronóstico de Inicio. Las pruebas lo cambian por uno sin red.
ServicioPronostico Function() crearServicioPronosticoInicio = ServicioPronostico.new;

/// El pronóstico del manglar en una sola fila para Inicio: la zona de mayor señal de riesgo y
/// su nivel, con «Ver pronóstico» que abre el detalle de esa zona. Usa las mismas reglas y la
/// misma copia local que la tarjeta completa (que mide 480 px o más y no cabe en Inicio).
class PronosticoCompacto extends StatefulWidget {
  const PronosticoCompacto({super.key, this.servicio});
  final ServicioPronostico? servicio;

  @override
  State<PronosticoCompacto> createState() => _PronosticoCompactoState();
}

class _PronosticoCompactoState extends State<PronosticoCompacto> {
  late final ServicioPronostico _servicio = widget.servicio ?? crearServicioPronosticoInicio();
  final _datos = <String, PronosticoZona?>{};
  bool _cargando = true;
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciada) {
      _iniciada = true;
      final zonas = Zanky.leer(context).manglar.zonas;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargar(zonas);
      });
    }
  }

  Future<void> _cargar(List<ZonaManglar> zonas) async {
    try {
      final copias = await Future.wait(zonas.map((z) => _servicio.ultimo(z.id)));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < zonas.length; i++) {
          if (copias[i] != null) _datos[zonas[i].id] = copias[i];
        }
      });
      final nuevos = await Future.wait(zonas.map((z) => _servicio.cargar(z)));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < zonas.length; i++) {
          final n = nuevos[i];
          final actual = _datos[zonas[i].id];
          if (n != null && (actual == null || !n.leido.isBefore(actual.leido))) _datos[zonas[i].id] = n;
        }
      });
    } catch (_) {
      // Sin red y sin copia: la fila lo dice, no inventa un nivel.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    if (widget.servicio == null) _servicio.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final estado = Zanky.de(context);
    final zonas = estado.manglar.zonas;
    final ahora = DateTime.now();
    ZonaManglar? mayor;
    NivelPronostico? nivelMayor;
    for (final z in zonas) {
      final n = nivelZona(_datos[z.id], estado.reportes, z.id, ahora);
      if (n != null && (nivelMayor == null || n.index > nivelMayor.index)) {
        mayor = z;
        nivelMayor = n;
      }
    }
    final hayDatos = _datos.values.any((v) => v != null);
    final destino = mayor ?? (zonas.isEmpty ? null : zonas.first);
    final color = colorNivel(nivelMayor);
    final titulo = nivelMayor != null
        ? 'Mayor señal: ${mayor!.nombre}'
        : (_cargando ? 'Consultando el pronóstico…' : (hayDatos ? 'Sin señales de riesgo vigentes' : 'Pronóstico sin datos'));
    final detalle = nivelMayor != null
        ? 'Nivel ${nivelMayor.name} · próximos 3 días, para observar, no alerta oficial'
        : (hayDatos
            ? 'Las copias guardadas ya vencieron o no marcan nada.'
            : 'Aparece cuando haya señal; no inventamos un nivel.');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        etiqueta: 'Ver el pronóstico del manglar. $titulo',
        onTap: destino == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DetallePronostico(
                      zona: destino,
                      pronostico: _datos[destino.id],
                      reportes: estado.reportes,
                    ),
                  ),
                ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Zc.superficie,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: nivelMayor == null ? Zc.linea : color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.troubleshoot_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRONÓSTICO DEL MANGLAR', style: tt.labelSmall),
                    Text(titulo, style: tt.titleSmall),
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
