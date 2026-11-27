import 'package:flutter/material.dart';

import '../../datos/cra/modelos_cra.dart';
import '../../datos/cra/servicio_visores.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'pantalla_visores.dart';
import 'piezas_visores.dart';

/// Los visores de la CRA en una fila para Inicio (misma forma que `SensoresCompacto`): el aviso
/// de focos cerca del manglar si lo hay, o cuántos puntos críticos hay en la franja. Lee solo las
/// copias guardadas (no gasta datos en Inicio); un toque abre «Visores del manglar».
class VisoresCompacto extends StatefulWidget {
  const VisoresCompacto({super.key, this.servicio});
  final ServicioVisores? servicio;

  @override
  State<VisoresCompacto> createState() => _VisoresCompactoState();
}

class _VisoresCompactoState extends State<VisoresCompacto> {
  ServicioVisores? _s;
  ResultadoVisor<DatosRiesgo>? _riesgo;
  ResultadoVisor<List<FocoCalor>>? _focos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s == null) {
      _s = widget.servicio ?? crearServicioVisores(context);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final r = await _s!.copiaRiesgo();
        final f = await _s!.copiaFocos();
        if (!mounted) return;
        setState(() {
          _riesgo = r;
          _focos = f;
        });
      });
    }
  }

  @override
  void dispose() {
    if (widget.servicio == null) _s?.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final focos = _focos?.datos ?? const <FocoCalor>[];
    final cerca = focosCercaDelManglar(focos, relojVisores(), (la, lo) => distanciaAlManglar(context, la, lo));
    final n = cerca.fold<int>(0, (s, f) => s + (f.focos > 0 ? f.focos : 1));
    final puntos = _riesgo?.datos?.puntos.where((p) => p.enFranja).length;
    final hay = n > 0;
    final color = hay ? Zc.dePrioridad(5) : Zc.cienaga;
    final titulo = hay
        ? '$n ${n == 1 ? 'foco' : 'focos'} de calor a menos de 2 km del manglar'
        : puntos == null
        ? 'Riesgos, focos de calor y agua'
        : '$puntos puntos críticos de riesgo en la franja';
    const detalle = 'Datos oficiales de la CRA, también sin señal.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Presionable(
        escala: 0.98,
        etiqueta: 'Abrir los visores del manglar. $titulo. $detalle',
        onTap: () => abrirVisores(context, servicio: widget.servicio, pestana: hay ? PestanaVisor.focos : PestanaVisor.riesgo),
        child: Container(
          key: const ValueKey('visores-compacto'),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Zc.superficie,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: hay ? color : Zc.linea, width: hay ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(hay ? Icons.local_fire_department_rounded : Icons.layers_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text('VISORES DEL MANGLAR', style: tt.labelSmall)),
                        const SizedBox(width: 6),
                        const SelloCra(),
                      ],
                    ),
                    Text(titulo, style: tt.titleSmall?.copyWith(color: hay ? color : null)),
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
