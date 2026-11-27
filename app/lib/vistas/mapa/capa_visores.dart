import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/cra/modelos_cra.dart';
import '../../datos/cra/servicio_visores.dart';
import '../../nucleo/presionable.dart';
import '../visores/pantalla_visores.dart' show abrirFichaFoco, abrirFichaPunto, crearServicioVisores;

/// Lo que la capa «Riesgos CRA» del mapa principal muestra: los puntos críticos dentro de la
/// franja del manglar y los focos de calor de los últimos 7 días a menos de 2 km. Es lo mismo
/// que los visores (misma API, misma copia sin señal), sin pedir nada dos veces.
class DatosCapaVisores {
  const DatosCapaVisores({required this.puntos, required this.focos, required this.copia, this.leido});
  final List<PuntoCritico> puntos;
  final List<FocoCalor> focos;

  /// Vino de la copia guardada (sin señal).
  final bool copia;
  final DateTime? leido;

  bool get vacia => puntos.isEmpty && focos.isEmpty;

  String get resumen {
    final p = '${puntos.length} ${puntos.length == 1 ? 'punto crítico' : 'puntos críticos'}';
    final f = '${focos.length} ${focos.length == 1 ? 'foco de calor' : 'focos de calor'}';
    final h = leido?.toLocal();
    final cuando = copia && h != null
        ? ' (copia de las ${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')})'
        : '';
    return 'Riesgos de la CRA en el manglar: $p y $f$cuando.';
  }
}

/// Trae la capa (con la copia si no hay señal). `null` si no hay ni red ni copia.
Future<DatosCapaVisores?> cargarCapaVisores(
  BuildContext context,
  double Function(double lat, double lon) distanciaM,
) async {
  final s = crearServicioVisores(context);
  try {
    final r = await s.riesgo();
    final f = await s.focos();
    if (r.datos == null && f.datos == null) return null;
    return DatosCapaVisores(
      puntos: [for (final p in r.datos?.puntos ?? const <PuntoCritico>[]) if (p.enFranja) p],
      focos: focosCercaDelManglar(f.datos ?? const [], DateTime.now(), distanciaM),
      copia: r.origen != OrigenVisor.enVivo || f.origen != OrigenVisor.enVivo,
      leido: r.leido ?? f.leido,
    );
  } catch (_) {
    return null;
  } finally {
    s.cerrar();
  }
}

/// Marcadores de la capa: rombos del color del tipo de evento y llamas para los focos.
List<Marker> marcadoresVisores(
  BuildContext context,
  DatosCapaVisores d,
  double Function(double lat, double lon) distanciaM,
) => [
  for (final p in d.puntos)
    Marker(
      key: ValueKey('cra-${p.id}'),
      point: LatLng(p.lat, p.lon),
      width: 44,
      height: 44,
      child: _MarcaVisor(
        color: p.tipo.color,
        icono: Icons.warning_amber_rounded,
        etiqueta: '${p.tipo.nombre} en ${p.municipio}, punto crítico de la CRA. Toca para ver la ficha',
        alTocar: () => abrirFichaPunto(context, p),
      ),
    ),
  for (final f in d.focos)
    Marker(
      key: ValueKey('cra-foco-${f.id}'),
      point: LatLng(f.lat, f.lon),
      width: 44,
      height: 44,
      child: _MarcaVisor(
        color: const Color(0xFFEA580C),
        icono: Icons.local_fire_department_rounded,
        etiqueta: 'Foco de calor en ${f.municipio}. Toca para ver la ficha',
        alTocar: () => abrirFichaFoco(context, f, distanciaM(f.lat, f.lon)),
      ),
    ),
];

class _MarcaVisor extends StatelessWidget {
  const _MarcaVisor({required this.color, required this.icono, required this.etiqueta, required this.alTocar});
  final Color color;
  final IconData icono;
  final String etiqueta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      onTap: alTocar,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrar(Vibracion.seleccion);
          alTocar();
        },
        child: Center(
          child: RepaintBoundary(
            child: Transform.rotate(
              angle: 0.785398, // 45°: el rombo distingue lo oficial de los reportes (círculos)
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x400B2E24), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Transform.rotate(
                  angle: -0.785398,
                  child: Icon(icono, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
