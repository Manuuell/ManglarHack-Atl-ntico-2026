import 'package:flutter/material.dart';

import '../../datos/tipos.dart';
import '../../datos/zonas.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/comunes.dart';
import '../biodiversidad/pantalla_biodiversidad.dart';
import 'capa_prioridad.dart';
import '../avisos_zona/pantalla_avisos_zona.dart';
import 'modelo.dart';

String _hectareas(double ha) => '${ha.toStringAsFixed(1).replaceAll('.', ',')} ha';

/// Datos de una zona de manglar. Los conteos son de lo que ve este teléfono.
Future<void> abrirHojaZona(
  BuildContext context, {
  required ZonaManglar zona,
  required int reportes,
  required int ultimas24h,
  required int mios,
  required VoidCallback alReportar,
  String textoVacio = 'Todavía no hay reportes en esta zona.',
}) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'zona_${zona.id}',
    contenido: (c) {
      final tt = Theme.of(c).textTheme;
      final cuantos = reportes == 0
          ? textoVacio
          : '$reportes ${reportes == 1 ? 'reporte' : 'reportes'} aquí'
              '${ultimas24h > 0 ? ' · $ultimas24h en las últimas 24 h' : ''}'
              '${mios > 0 ? ' · ${mios == 1 ? '1 es tuyo' : '$mios son tuyos'}' : ''}';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Zc.hojaClara, shape: BoxShape.circle),
                child: const Icon(Icons.eco_rounded, color: Zc.hoja, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zona.nombre, style: tt.headlineSmall),
                    Text(zona.municipio, style: tt.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Dato(titulo: 'Extensión', valor: _hectareas(zona.areaHa))),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _Dato(
                  titulo: 'Prioridad de conservación',
                  valor: '${zona.prioridadConservacion} de 5',
                  extra: _Medidor(zona.prioridadConservacion),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(Zr.s)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Zc.fango),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prioridad provisional, por validar con la CRA.',
                    style: tt.bodySmall?.copyWith(color: Zc.texto),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(zona.nota, style: tt.bodyLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                reportes == 0 ? Icons.sentiment_satisfied_alt_rounded : Icons.place_rounded,
                size: 20,
                color: reportes == 0 ? Zc.textoSuave : Zc.sol,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(cuantos, style: tt.titleSmall)),
            ],
          ),
          const SizedBox(height: 20),
          BotonZ(
            texto: 'Reportar aquí',
            icono: Icons.add_a_photo_rounded,
            onTap: () {
              Navigator.of(c).pop();
              alReportar();
            },
          ),
          const SizedBox(height: 10),
          BotonZ(
            texto: 'Especies vistas cerca y marea',
            icono: Icons.travel_explore_rounded,
            secundario: true,
            onTap: () {
              Navigator.of(c).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PantallaBiodiversidad(zona: zona)));
            },
          ),
          const SizedBox(height: 10),
          BotonZ(
            texto: 'Avisarme de esta zona',
            icono: Icons.notifications_active_outlined,
            secundario: true,
            onTap: () {
              Navigator.of(c).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PantallaAvisosZona(zonaInicial: zona.id),
              ));
            },
          ),
        ],
      );
    },
  );
}

class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor, this.extra});
  final String titulo;
  final String valor;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Zc.arena, borderRadius: BorderRadius.circular(Zr.s)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tt.labelSmall),
          const SizedBox(height: 3),
          Text(valor, style: tt.titleMedium),
          if (extra != null) ...[const SizedBox(height: 6), extra!],
        ],
      ),
    );
  }
}

/// Cinco rayitas, tantas llenas como la prioridad de conservación.
class _Medidor extends StatelessWidget {
  const _Medidor(this.valor);
  final int valor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 1; i <= 5; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i <= valor ? Zc.hoja : Zc.linea,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      );
}

/// Un reporte del mapa. Los públicos solo muestran lo que el servidor publica.
Future<void> abrirHojaPunto(
  BuildContext context, {
  required PuntoMapa punto,
  required String zonaNombre,
  required VoidCallback alVerDetalle,
}) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'reporte_mapa',
    contenido: (c) {
      final tt = Theme.of(c).textTheme;
      final mio = punto.mio;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoTipo(punto.tipo, tamano: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(punto.tipo.nombre, style: tt.titleLarge),
                    Text(
                      mio != null ? 'Tu reporte · caso ${mio.caso}' : 'Reporte de otra persona',
                      style: tt.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Fila(Icons.place_rounded, zonaNombre),
          const SizedBox(height: 8),
          _Fila(Icons.schedule_rounded, haceCuanto(punto.capturadoEn)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PildoraPrioridad(punto.prioridad),
              if (mio != null)
                ChipEstado(mio)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ChipEstado.iconoDe(punto.estado), size: 15, color: ChipEstado.colorDe(punto.estado)),
                    const SizedBox(width: 5),
                    Text(
                      punto.estado.nombre,
                      style: tt.labelMedium?.copyWith(color: ChipEstado.colorDe(punto.estado)),
                    ),
                  ],
                ),
            ],
          ),
          if (punto.enCola) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(Zr.s)),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 18, color: Zc.fango),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aún no enviado: está guardado en tu teléfono y se envía cuando haya señal.',
                      style: tt.bodySmall?.copyWith(color: Zc.texto),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (mio == null) ...[
            const SizedBox(height: 12),
            Text(
              'Por privacidad solo se muestra el tipo, el lugar aproximado, la prioridad y el estado.',
              style: tt.bodySmall,
            ),
          ],
          if (mio != null) ...[
            const SizedBox(height: 20),
            BotonZ(
              texto: 'Ver detalle',
              icono: Icons.arrow_forward_rounded,
              onTap: () {
                Navigator.of(c).pop();
                alVerDetalle();
              },
            ),
          ],
        ],
      );
    },
  );
}

class _Fila extends StatelessWidget {
  const _Fila(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icono, size: 19, color: Zc.textoSuave),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      );
}

/// Qué mostrar: por tiempo y por tipo. Aplica al instante; [contar] dice cuántos
/// reportes quedan con cada combinación para que el resultado se vea junto al control.
Future<void> abrirHojaFiltro(
  BuildContext context, {
  required FiltroMapa inicial,
  required ValueChanged<FiltroMapa> alCambiar,
  required int Function(FiltroMapa) contar,
  required int total,
}) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'filtro_mapa',
    contenido: (c) {
      var filtro = inicial;
      return StatefulBuilder(
        builder: (c, setState) {
          final tt = Theme.of(c).textTheme;
          void poner(FiltroMapa f) {
            setState(() => filtro = f);
            alCambiar(f);
          }

          final n = contar(filtro);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qué ver en el mapa', style: tt.headlineSmall),
              const SizedBox(height: 4),
              Text(
                n == 0 ? 'Ningún reporte con este filtro.' : 'Mostrando $n de $total ${total == 1 ? 'reporte' : 'reportes'}.',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text('Cuándo', style: tt.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Opcion(
                    texto: 'Todos',
                    elegido: filtro.tiempo == FiltroTiempo.todas,
                    onTap: () => poner(filtro.conTiempo(FiltroTiempo.todas)),
                  ),
                  _Opcion(
                    texto: 'Últimas 24 h',
                    elegido: filtro.tiempo == FiltroTiempo.ultimas24h,
                    onTap: () => poner(filtro.conTiempo(FiltroTiempo.ultimas24h)),
                  ),
                  _Opcion(
                    texto: 'Solo míos',
                    elegido: filtro.tiempo == FiltroTiempo.mias,
                    onTap: () => poner(filtro.conTiempo(FiltroTiempo.mias)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Tipo de amenaza', style: tt.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TipoAmenaza.values)
                    _Opcion(
                      texto: t.corto,
                      icono: t.icono,
                      colorIcono: t.color,
                      elegido: filtro.tipos.contains(t),
                      onTap: () => poner(filtro.alternarTipo(t)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  if (filtro.activo) ...[
                    Expanded(
                      child: BotonZ(
                        texto: 'Quitar filtros',
                        secundario: true,
                        onTap: () => poner(const FiltroMapa()),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: BotonZ(texto: 'Listo', onTap: () => Navigator.of(c).pop())),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.texto,
    required this.elegido,
    required this.onTap,
    this.icono,
    this.colorIcono = Zc.hoja,
  });

  final String texto;
  final bool elegido;
  final VoidCallback onTap;
  final IconData? icono;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      etiqueta: elegido ? '$texto, elegido' : texto,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: elegido ? Zc.hoja : Zc.arena,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: elegido ? Zc.hoja : Zc.linea),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 18, color: elegido ? Colors.white : colorIcono),
              const SizedBox(width: 7),
            ],
            Text(
              texto,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: elegido ? Colors.white : Zc.texto),
            ),
          ],
        ),
      ),
    );
  }
}

/// Antes de pedir el permiso del sistema, se dice para qué es. Devuelve true si la
/// persona quiere seguir.
Future<bool> explicarUbicacion(BuildContext context) async {
  final r = await mostrarHojaZ<bool>(
    context,
    nombre: 'permiso_ubicacion',
    contenido: (c) {
      final tt = Theme.of(c).textTheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Zc.cienagaClara, shape: BoxShape.circle),
            child: const Icon(Icons.my_location_rounded, color: Zc.cienaga, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Para mostrarte dónde estás', style: tt.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Necesito la ubicación de tu teléfono solo mientras usas la app, para poner un punto azul en el '
            'mapa y decirte si estás cerca del manglar. No la envío ni la guardo en ningún servidor.',
            style: tt.bodyLarge,
          ),
          const SizedBox(height: 22),
          BotonZ(texto: 'Continuar', icono: Icons.check_rounded, onTap: () => Navigator.of(c).pop(true)),
          const SizedBox(height: 10),
          BotonZ(texto: 'Ahora no', secundario: true, onTap: () => Navigator.of(c).pop(false)),
        ],
      );
    },
  );
  return r ?? false;
}

/// «Cerca del manglar» o el nombre de la zona, para marcadores públicos.
String nombreDeZona(Manglar m, String id) => m.zonaPorId(id)?.nombre ?? 'Cerca del manglar del Atlántico';

/// Un polígono de la capa oficial de prioridades de conservación de la CRA: nivel, acción,
/// escenario, sector y superficie, con la nota honesta de la fuente.
Future<void> abrirHojaPrioridad(BuildContext context, {required PoligonoPrioridad poligono}) {
  final plan = poligono.plan;
  final color = colorPrioridadCra(plan.prioridad);
  return mostrarHojaZ<void>(
    context,
    nombre: 'prioridad_cra',
    contenido: (c) {
      final tt = Theme.of(c).textTheme;
      final sector = plan.areaProtegida ?? plan.unidad;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.shield_rounded, color: Color.lerp(color, Zc.raiz, 0.35), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prioridad ${plan.prioridad.nombre.toLowerCase()}', style: tt.headlineSmall),
                    Text('Conservación · CRA', style: tt.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Dato(titulo: 'Acción', valor: plan.accion)),
              const SizedBox(width: 12),
              Expanded(child: _Dato(titulo: 'Escenario', valor: plan.escenario)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sector != null) ...[
                Expanded(
                  child: _Dato(
                    titulo: plan.areaProtegida != null ? 'Área protegida' : 'Sector (unidad hidrográfica)',
                    valor: sector,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: _Dato(titulo: 'Superficie de este polígono', valor: '≈ ${_hectareas(poligono.hectareas)}')),
            ],
          ),
          if (plan.figura.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Figura legal: ${plan.figura}', style: tt.bodyMedium),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Zc.solClaro, borderRadius: BorderRadius.circular(Zr.s)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline_rounded, size: 18, color: Zc.fango),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$notaFuentePrioridad Las hectáreas las calcula Zanky sobre el polígono que ves.',
                    style: tt.bodySmall?.copyWith(color: Zc.texto),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
