import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/cra/modelos_cra.dart';
import '../../datos/cra/servicio_visores.dart';
import '../../datos/estado.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/kit/segmentado.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/tema.dart';
import '../admin/piezas_admin.dart' show BotonIcono;
import '../comunidad/alertas_diseno.dart' show verEnElMapa;
import '../comun/zanky_mascota.dart';
import 'piezas_visores.dart';

/// Quién arma el servicio. Las pruebas lo cambian por uno con las respuestas guardadas.
ServicioVisores Function(BuildContext context) crearServicioVisores = (context) =>
    ServicioVisores(servidor: Zanky.leer(context).servidor);

/// Reloj de los visores (las pruebas lo fijan).
DateTime Function() relojVisores = DateTime.now;

/// Distancia (m) de un punto al manglar 1:5.000 de la CRA. Sin la capa cargada (pruebas) cae a la
/// franja costera: 0 si está dentro, infinito si no.
double Function(BuildContext context, double lat, double lon) distanciaAlManglar = (context, lat, lon) {
  try {
    return Zanky.leer(context).manglar.ubicar(LatLng(lat, lon)).distanciaM;
  } catch (_) {
    return enFranjaManglar(lat, lon) ? 0 : double.infinity;
  }
};

enum PestanaVisor { riesgo, focos, agua, cifras }

const _etiquetas = ['Riesgos', 'Focos', 'Agua', 'Cifras'];

/// Abre «Visores del manglar» con la ruta de borde del kit (deslizar desde el borde vuelve).
Future<void> abrirVisores(
  BuildContext context, {
  ServicioVisores? servicio,
  PestanaVisor pestana = PestanaVisor.riesgo,
}) {
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'visores'),
      builder: (_) => PantallaVisores(servicio: servicio, inicial: pestana),
    ),
  );
}

/// Lo que la CRA publica del manglar, dentro de la app y sin señal: puntos críticos de riesgo,
/// focos de calor por satélite, calidad del agua por ciénaga y el manglar en cifras.
class PantallaVisores extends StatefulWidget {
  const PantallaVisores({super.key, this.servicio, this.inicial = PestanaVisor.riesgo});
  final ServicioVisores? servicio;
  final PestanaVisor inicial;

  @override
  State<PantallaVisores> createState() => _PantallaVisoresState();
}

class _PantallaVisoresState extends State<PantallaVisores> {
  ServicioVisores? _s;
  late int _pestana = widget.inicial.index;
  ResultadoVisor<DatosRiesgo>? _riesgo;
  ResultadoVisor<List<FocoCalor>>? _focos;
  ResultadoVisor<List<MuestraAgua>>? _agua;
  ResultadoVisor<CifrasWorkflow>? _workflow;
  ResultadoVisor<EstadisticasReportes>? _estadisticas;
  bool _soloFranja = true;
  int? _tipo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s == null) {
      _s = widget.servicio ?? crearServicioVisores(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _iniciar();
      });
    }
  }

  Future<void> _iniciar() async {
    final s = _s!;
    final copias = await Future.wait([s.copiaRiesgo(), s.copiaFocos(), s.copiaAgua()]);
    if (!mounted) return;
    setState(() {
      _riesgo ??= copias[0] as ResultadoVisor<DatosRiesgo>?;
      _focos ??= copias[1] as ResultadoVisor<List<FocoCalor>>?;
      _agua ??= copias[2] as ResultadoVisor<List<MuestraAgua>>?;
    });
    await _actualizar();
  }

  Future<void> _actualizar() async {
    final s = _s!;
    await Future.wait([
      s.riesgo().then((r) => _poner(() => _riesgo = r)),
      s.focos().then((r) => _poner(() => _focos = r)),
      s.agua().then((r) => _poner(() => _agua = r)),
      s.workflow().then((r) => _poner(() => _workflow = r)),
      s.estadisticas().then((r) => _poner(() => _estadisticas = r)),
    ]);
  }

  void _poner(VoidCallback f) {
    if (mounted) setState(f);
  }

  @override
  void dispose() {
    if (widget.servicio == null) _s?.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = relojVisores();
    final ancho = MediaQuery.sizeOf(context).width;
    final ancha = ancho >= 900;
    final Widget cuerpo = switch (PestanaVisor.values[_pestana]) {
      PestanaVisor.riesgo => _visor(
        _riesgo,
        (r) => _Riesgo(
          datos: r.datos!,
          soloFranja: _soloFranja,
          tipo: _tipo,
          ancha: ancha,
          alFranja: (v) => setState(() => _soloFranja = v),
          alTipo: (t) => setState(() => _tipo = t == _tipo ? null : t),
        ),
      ),
      PestanaVisor.focos => _visor(_focos, (r) => _Focos(focos: r.datos!, ahora: ahora, ancha: ancha)),
      PestanaVisor.agua => _visor(_agua, (r) => _Agua(muestras: r.datos!, ancha: ancha)),
      PestanaVisor.cifras => _Cifras(
        workflow: _workflow,
        estadisticas: _estadisticas,
        ahora: ahora,
        alReintentar: _actualizar,
      ),
    };
    final resultado = switch (PestanaVisor.values[_pestana]) {
      PestanaVisor.riesgo => _riesgo,
      PestanaVisor.focos => _focos,
      PestanaVisor.agua => _agua,
      PestanaVisor.cifras => null,
    };
    final fuente = switch (PestanaVisor.values[_pestana]) {
      PestanaVisor.riesgo => 'API de gestión del riesgo de la CRA (visor de puntos críticos)',
      PestanaVisor.focos => 'API de la CRA, focos de calor detectados por satélite',
      PestanaVisor.agua => 'Monitoreos de calidad de agua de la CRA (ICA del IDEAM)',
      PestanaVisor.cifras => '',
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
              child: Row(
                children: [
                  BotonIcono(
                    icono: Icons.arrow_back_rounded,
                    etiqueta: 'Volver',
                    alTocar: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Visores del manglar',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SelloCra(),
                  const SizedBox(width: 6),
                  BotonIcono(icono: Icons.refresh_rounded, etiqueta: 'Actualizar los visores', alTocar: _actualizar),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SegmentadoZ(
                  valor: _pestana,
                  etiquetas: _etiquetas,
                  alCambiar: (i) => setState(() => _pestana = i),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                // Deslizar a los lados cambia de visor (como las pestañas de iOS).
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 300) return;
                  final i = (_pestana + (v < 0 ? 1 : -1)).clamp(0, PestanaVisor.values.length - 1);
                  if (i != _pestana) setState(() => _pestana = i);
                },
                child: TirarActualizar(
                  alActualizar: _actualizar,
                  child: ListView(
                    key: PageStorageKey('visor-$_pestana'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (resultado != null && resultado.origen != OrigenVisor.sinDatos) ...[
                                OrigenVisorBanda(
                                  origen: resultado.origen,
                                  leido: resultado.leido,
                                  fuente: fuente,
                                  ahora: ahora,
                                ),
                                const SizedBox(height: 12),
                              ],
                              AnimatedSwitcher(
                                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Zm.medio,
                                switchInCurve: Zm.entrar,
                                child: KeyedSubtree(
                                  key: ValueKey('cuerpo-$_pestana-${resultado?.origen}'),
                                  child: cuerpo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visor<T>(ResultadoVisor<T>? r, Widget Function(ResultadoVisor<T> r) contenido) {
    if (r == null) {
      return const Column(
        key: ValueKey('cargando'),
        children: [Esqueleto.tarjeta(), SizedBox(height: 12), Esqueleto.lista(3)],
      );
    }
    if (r.origen == OrigenVisor.sinDatos || r.datos == null) {
      return EstadoVacio(
        key: const ValueKey('error'),
        titulo: 'La CRA no respondió',
        texto: 'Prueba de nuevo en un momento. Cuando haya señal guardo una copia para verla también sin internet.',
        animo: Animo.preocupado,
        textoAccion: 'Intentar de nuevo',
        iconoAccion: Icons.refresh_rounded,
        alAccion: _actualizar,
      );
    }
    return contenido(r);
  }
}

// ───────────────────────────── Riesgos ─────────────────────────────

class _Riesgo extends StatelessWidget {
  const _Riesgo({
    required this.datos,
    required this.soloFranja,
    required this.tipo,
    required this.ancha,
    required this.alFranja,
    required this.alTipo,
  });
  final DatosRiesgo datos;
  final bool soloFranja;
  final int? tipo;
  final bool ancha;
  final ValueChanged<bool> alFranja;
  final ValueChanged<int> alTipo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final base = [
      for (final p in datos.puntos)
        if (!soloFranja || p.enFranja) p,
    ];
    final visibles = [
      for (final p in base)
        if (tipo == null || p.tipo.id == tipo) p,
    ];
    final cuenta = <int, int>{};
    for (final p in base) {
      cuenta[p.tipo.id] = (cuenta[p.tipo.id] ?? 0) + 1;
    }
    final tipos = [
      for (final t in datos.tipos)
        if ((cuenta[t.id] ?? 0) > 0) t,
    ];
    // Como la web: del más cercano al manglar al más lejano.
    final distancia = {for (final p in visibles) p.id: distanciaAlManglar(context, p.lat, p.lon)};
    visibles.sort((a, b) => distancia[a.id]!.compareTo(distancia[b.id]!));
    final lista = visibles.take(40).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaVisor(
          relleno: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              const Icon(Icons.forest_rounded, color: Zc.hoja),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solo la franja del manglar', style: tt.titleSmall),
                    Text(
                      soloFranja
                          ? '${base.length} puntos en la costa del manglar'
                          : '${base.length} puntos en todo el Atlántico',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              InterruptorIos(valor: soloFranja, alCambiar: alFranja, etiqueta: 'Solo dentro de la franja del manglar'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tipos)
              ChipTipo(
                key: ValueKey('chip-${t.id}'),
                texto: t.nombre,
                color: t.color,
                cuenta: cuenta[t.id] ?? 0,
                activo: tipo == t.id,
                alTocar: () => alTipo(t.id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MapaVisor(
          alto: ancha ? 320 : 230,
          descripcion: 'Mapa de ${visibles.length} puntos críticos de riesgo de la CRA',
          puntos: [
            for (final p in visibles)
              PuntoMapa(
                clave: 'riesgo-${p.id}',
                lat: p.lat,
                lon: p.lon,
                color: p.tipo.color,
                etiqueta: '${p.tipo.nombre} en ${p.municipio}',
                alTocar: () => abrirFichaPunto(context, p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          const EstadoVacio(
            titulo: 'Nada por aquí',
            texto: 'No hay puntos críticos registrados cerca del manglar con este filtro.',
            animo: Animo.feliz,
          )
        else ...[
          Text(
            'Puntos críticos (${visibles.length}). Del más cercano al manglar al más lejano'
            '${visibles.length > lista.length ? '; se ven los ${lista.length} primeros' : ''}. '
            'Mantén presionado para una vista previa.',
            style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
          ),
          const SizedBox(height: 8),
          _Rejilla(
            ancha: ancha,
            hijos: [for (final p in lista) _FilaPunto(punto: p, distanciaM: distancia[p.id]!)],
          ),
        ],
      ],
    );
  }
}

String textoDistancia(double m) => m <= 0
    ? 'dentro del manglar'
    : m.isInfinite
    ? 'fuera de la franja'
    : m < 1000
    ? 'a ${m.round()} m del manglar'
    : 'a ${decimal(m / 1000)} km del manglar';

class _FilaPunto extends StatelessWidget {
  const _FilaPunto({required this.punto, required this.distanciaM});
  final PuntoCritico punto;
  final double distanciaM;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final lugar = [punto.municipio, textoDistancia(distanciaM)].where((s) => s.isNotEmpty).join(' · ');
    return MenuMantenido(
      alTocar: () => abrirFichaPunto(context, punto),
      etiqueta: '${punto.tipo.nombre} en ${punto.municipio}',
      vistaPrevia: (_) => _VistaPreviaPunto(punto: punto, distanciaM: distanciaM),
      acciones: [
        AccionGesto(
          etiqueta: 'Ver ficha',
          icono: Icons.info_outline_rounded,
          alEjecutar: () => abrirFichaPunto(context, punto),
        ),
        AccionGesto(
          etiqueta: 'Ver en el mapa',
          icono: Icons.map_rounded,
          alEjecutar: () => verEnElMapa(context, LatLng(punto.lat, punto.lon)),
        ),
      ],
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '${punto.tipo.nombre}, $lugar, ${fechaCorta(punto.registradoEn)}. Ver ficha.',
        child: TarjetaVisor(
          relleno: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: punto.tipo.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(punto.tipo.nombre, style: tt.titleSmall),
                    Text(
                      '$lugar · ${fechaCorta(punto.registradoEn)}',
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (punto.confirmado)
                const Icon(Icons.verified_rounded, size: 18, color: Zc.hoja, semanticLabel: 'Confirmado'),
              const Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que se ve al mantener presionado un punto: tipo, lugar, fecha y lo que registró la CRA
class _VistaPreviaPunto extends StatelessWidget {
  const _VistaPreviaPunto({required this.punto, required this.distanciaM});
  final PuntoCritico punto;
  final double distanciaM;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return TarjetaVisor(
      borde: punto.tipo.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: punto.tipo.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(punto.tipo.nombre, style: tt.titleMedium)),
              if (punto.confirmado) Text('Confirmado', style: tt.labelMedium?.copyWith(color: Zc.hoja)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${punto.municipio} · ${textoDistancia(distanciaM)} · ${fechaCorta(punto.registradoEn)}',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            punto.descripcion.isEmpty ? punto.tipo.explicacion : punto.descripcion,
            style: tt.bodyMedium,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Ficha de un punto crítico: qué es, dónde, cuándo y si la Corporación lo confirmó.
Future<void> abrirFichaPunto(BuildContext context, PuntoCritico p) => mostrarHojaZ<void>(
  context,
  nombre: 'ficha-riesgo',
  contenido: (c) {
    final tt = Theme.of(c).textTheme;
    return Column(
      key: const ValueKey('ficha-riesgo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: p.tipo.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(header: true, child: Text(p.tipo.nombre, style: tt.titleLarge)),
            ),
            const SelloCra(),
          ],
        ),
        const SizedBox(height: 8),
        Text(p.tipo.explicacion, style: tt.bodyMedium),
        const SizedBox(height: 14),
        if (p.descripcion.isNotEmpty) ...[
          Text('LO QUE REGISTRÓ LA CRA', style: tt.labelSmall),
          const SizedBox(height: 4),
          Text(p.descripcion, style: tt.bodyMedium),
          const SizedBox(height: 14),
        ],
        _Dato('Municipio', p.municipio.isEmpty ? 'Sin dato' : p.municipio),
        _Dato('Zona', p.zona.isEmpty ? 'Sin dato' : p.zona),
        _Dato('Registrado', fechaCorta(p.registradoEn)),
        _Dato('Estado', p.confirmado ? 'Confirmado por la Corporación' : 'Sin confirmar'),
        _Dato('Franja del manglar', p.enFranja ? 'Dentro' : 'Fuera'),
        _Dato('Coordenadas', '${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}'),
        const SizedBox(height: 10),
        Text('Fuente: visor de puntos críticos de la CRA', style: tt.bodySmall),
      ],
    );
  },
);

class _Dato extends StatelessWidget {
  const _Dato(this.nombre, this.valor);
  final String nombre;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(nombre, style: tt.bodySmall)),
          Expanded(
            child: Text(valor, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.ancha, required this.hijos});
  final bool ancha;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    if (!ancha) {
      return Column(
        children: [for (final h in hijos) Padding(padding: const EdgeInsets.only(bottom: 8), child: h)],
      );
    }
    return LayoutBuilder(
      builder: (_, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [for (final h in hijos) SizedBox(width: w, child: h)],
        );
      },
    );
  }
}

// ───────────────────────────── Focos de calor ─────────────────────────────

class _Focos extends StatelessWidget {
  const _Focos({required this.focos, required this.ahora, required this.ancha});
  final List<FocoCalor> focos;
  final DateTime ahora;
  final bool ancha;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cerca = focosCercaDelManglar(focos, ahora, (la, lo) => distanciaAlManglar(context, la, lo));
    final n = cerca.fold<int>(0, (s, f) => s + (f.focos > 0 ? f.focos : 1));
    final hay = cerca.isNotEmpty;
    final color = hay ? Zc.dePrioridad(5) : Zc.hoja;
    final ultimo = focos.isEmpty ? null : focos.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: TarjetaVisor(
            key: const ValueKey('aviso-focos'),
            borde: color,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(hay ? Icons.local_fire_department_rounded : Icons.check_circle_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hay
                            ? '$n ${n == 1 ? 'foco' : 'focos'} a menos de 2 km del manglar'
                            : 'Sin focos a menos de 2 km del manglar',
                        style: tt.titleSmall?.copyWith(color: hay ? color : null),
                      ),
                      Text(
                        hay
                            ? 'En los últimos 7 días. Si ves humo, repórtalo con foto.'
                            : 'En los últimos 7 días. Último foco en la franja: ${ultimo == null ? 'ninguno registrado' : '${fechaCorta(ultimo.hasta)} en ${ultimo.municipio}'}.',
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        MapaVisor(
          alto: ancha ? 320 : 230,
          descripcion: 'Mapa de ${focos.length} focos de calor en la franja del manglar.',
          poligonos: [
            for (final f in focos)
              Polygon(
                points: [for (final (a, o) in f.anillo) LatLng(a, o)],
                color: const Color(0x55F97316),
                borderColor: const Color(0xFFEA580C),
                borderStrokeWidth: 1.5,
              ),
          ],
          puntos: [
            for (final f in focos)
              PuntoMapa(
                clave: 'foco-${f.id}',
                lat: f.lat,
                lon: f.lon,
                color: cerca.contains(f) ? Zc.dePrioridad(5) : const Color(0xFFEA580C),
                icono: Icons.local_fire_department_rounded,
                etiqueta: 'Foco de calor en ${f.municipio}, ${fechaCorta(f.hasta)}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (focos.isEmpty)
          const EstadoVacio(
            titulo: 'Sin focos de calor',
            texto: 'No hay focos de calor recientes cerca del manglar.',
            animo: Animo.feliz,
          )
        else ...[
          Text(
            'Focos de calor (${focos.length}), del más reciente al más viejo. Detectados por satélite y agrupados por la CRA '
            'Un foco de calor no siempre es un incendio.',
            style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
          ),
          const SizedBox(height: 8),
          _Rejilla(
            ancha: ancha,
            hijos: [
              for (final f in focos.take(30))
                _FilaFoco(foco: f, cerca: cerca.contains(f), distanciaM: distanciaAlManglar(context, f.lat, f.lon)),
            ],
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Calidad del agua ─────────────────────────────

class _Agua extends StatelessWidget {
  const _Agua({required this.muestras, required this.ancha});
  final List<MuestraAgua> muestras;
  final bool ancha;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // Como la web: de la peor a la mejor; las que no tienen medición, al final.
    final cienagas = agruparPorCienaga(muestras)..sort((a, b) => (a.ica ?? 9).compareTo(b.ica ?? 9));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Escala del ICA: ${escalaIca.map((c) => c.etiqueta).join(', ')}.',
          child: ExcludeSemantics(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final c in escalaIca)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(c.etiqueta, style: tt.labelMedium),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        MapaVisor(
          alto: ancha ? 300 : 210,
          descripcion: 'Mapa de ${muestras.length} estaciones de muestreo de agua.',
          puntos: [
            for (final m in muestras)
              PuntoMapa(
                clave: 'agua-${m.id}',
                lat: m.lat,
                lon: m.lon,
                color: m.categoria?.color ?? colorSinDato,
                icono: Icons.water_drop_rounded,
                etiqueta: '${m.cuerpo}, ICA ${m.categoria?.etiqueta ?? 'sin dato'}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Ciénagas y cuerpos de agua (${cienagas.length}). Índice de calidad del agua (ICA) del IDEAM, de 0 (muy mala) a 1 (buena): '
          'promedio de los puntos de muestreo de la CRA, de la peor a la mejor. El árbol marca las rodeadas de manglar.',
          style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
        ),
        const SizedBox(height: 8),
        if (cienagas.isEmpty)
          const EstadoVacio(
            titulo: 'Sin mediciones',
            texto: 'No hay mediciones de calidad del agua cerca del manglar.',
            animo: Animo.curioso,
          )
        else
          _Rejilla(
            ancha: ancha,
            hijos: [for (final c in cienagas) _TarjetaCienaga(cienaga: c)],
          ),
      ],
    );
  }
}

class _TarjetaCienaga extends StatelessWidget {
  const _TarjetaCienaga({required this.cienaga});
  final CienagaAgua cienaga;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cat = categoriaIca(cienaga.ica);
    final color = cat?.color ?? colorSinDato;
    final valores = <String, double?>{
      'od': cienaga.oxigeno,
      'ph': cienaga.ph,
      'coli': cienaga.coliformes,
      'temp': cienaga.temperatura,
    };
    return MenuMantenido(
      alTocar: () => abrirFichaCienaga(context, cienaga),
      etiqueta: 'Ciénaga ${cienaga.nombre}',
      vistaPrevia: (_) => _VistaPreviaCienaga(cienaga: cienaga),
      acciones: [
        AccionGesto(
          etiqueta: 'Ver ficha',
          icono: Icons.info_outline_rounded,
          alEjecutar: () => abrirFichaCienaga(context, cienaga),
        ),
        if (puntoCienaga(cienaga) case final p?)
          AccionGesto(
            etiqueta: 'Ver en el mapa',
            icono: Icons.map_rounded,
            alEjecutar: () => verEnElMapa(context, p),
          ),
        AccionGesto(
          etiqueta: 'Copiar resumen',
          icono: Icons.copy_rounded,
          alEjecutar: () => _copiar(context, textoCienaga(cienaga), 'Resumen copiado'),
        ),
      ],
      child: TarjetaVisor(
        key: ValueKey('cienaga-${cienaga.cuerpoId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label:
                  '${cienaga.nombre}. Calidad ${cat?.etiqueta ?? 'sin dato'}'
                  '${cienaga.ica == null ? '' : ', ICA ${decimal(cienaga.ica!, 2)}'}. Última medición ${fechaCorta(cienaga.ultimaFecha)}.',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Text(
                        cienaga.ica == null ? '—' : decimal(cienaga.ica!, 2),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cienaga.nombre,
                                  style: tt.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (cienaga.conManglar) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.forest_rounded, size: 16, color: Zc.hoja),
                              ],
                            ],
                          ),
                          Text(
                            '${cat?.etiqueta ?? 'Sin dato'} · medido el ${fechaCorta(cienaga.ultimaFecha)}',
                            style: tt.bodySmall?.copyWith(color: Zc.texto),
                          ),
                          if (cat != null) Text(cat.explicacion, style: tt.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final e in valores.entries) _FilaIndicador(indicador: indicadoresAgua[e.key]!, valor: e.value),
            const SizedBox(height: 4),
            Text(
              '${cienaga.muestras.length} ${cienaga.muestras.length == 1 ? 'estación' : 'estaciones'} de muestreo',
              style: tt.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaIndicador extends StatelessWidget {
  const _FilaIndicador({required this.indicador, required this.valor});
  final Indicador indicador;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final s = indicador.evaluar(valor);
    final texto = valor == null
        ? 'sin dato'
        : '${indicador.formato(valor!)}${indicador.unidad.isEmpty ? '' : ' ${indicador.unidad}'}';
    return Semantics(
      container: true,
      label: '${indicador.nombre}: $texto, ${textoSemaforo(s)}. ${indicador.explicacion}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorSemaforo(s), shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(indicador.nombre, style: tt.labelLarge)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            texto,
                            textAlign: TextAlign.end,
                            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    Text(indicador.explicacion, style: tt.bodySmall),
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

// ───────────────────────────── El manglar en cifras ─────────────────────────────

class _Cifras extends StatelessWidget {
  const _Cifras({required this.workflow, required this.estadisticas, required this.ahora, required this.alReintentar});
  final ResultadoVisor<CifrasWorkflow>? workflow;
  final ResultadoVisor<EstadisticasReportes>? estadisticas;
  final DateTime ahora;
  final Future<void> Function() alReintentar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final w = workflow, e = estadisticas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('EL MANGLAR DESDE EL SATÉLITE', style: tt.labelSmall),
        const SizedBox(height: 8),
        if (w == null)
          const Esqueleto.tarjeta()
        else if (w.datos == null)
          TarjetaVisor(
            child: Text(
              'No pude leer el workflow de la CRA y no hay copia guardada. Tira hacia abajo para intentar de nuevo.',
              style: tt.bodyMedium,
            ),
          )
        else ...[
          OrigenVisorBanda(origen: w.origen, leido: w.leido, fuente: fuenteWorkflow, ahora: ahora),
          const SizedBox(height: 10),
          _CifrasWorkflow(c: w.datos!),
        ],
        const SizedBox(height: 22),
        Text('LO QUE REPORTA LA GENTE (30 DÍAS)', style: tt.labelSmall),
        const SizedBox(height: 8),
        if (e == null)
          const Esqueleto.tarjeta()
        else if (e.datos == null)
          TarjetaVisor(
            child: Text(
              'Las cifras de reportes llegan del servidor de Zanky. Sin conexión todavía: vuelve a mirar con señal.',
              style: tt.bodyMedium,
            ),
          )
        else ...[
          OrigenVisorBanda(
            origen: e.origen,
            leido: e.leido,
            fuente: 'servidor de Zanky, solo totales sin datos personales',
            ahora: ahora,
          ),
          const SizedBox(height: 10),
          _CifrasReportes(e: e.datos!),
        ],
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.formato, required this.etiqueta, this.color = Zc.raiz});
  final double valor;
  final String Function(double) formato;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: TarjetaVisor(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NumeroQueCuenta(
              valor: valor,
              formato: formato,
              estilo: tt.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(etiqueta, style: tt.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Rejilla2 extends StatelessWidget {
  const _Rejilla2(this.hijos);
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final cols = c.maxWidth >= 700 ? 4 : 2;
      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final h in hijos) SizedBox(width: w, child: h)],
      );
    },
  );
}

class _CifrasWorkflow extends StatelessWidget {
  const _CifrasWorkflow({required this.c});
  final CifrasWorkflow c;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    String ha(double v) => '${miles(v)} ha';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rejilla2([
          _Cifra(valor: c.probableHa, formato: ha, etiqueta: 'de manglar probable en la costa'),
          _Cifra(valor: c.altaHa, formato: ha, etiqueta: 'con confianza alta', color: Zc.hoja),
          _Cifra(valor: c.carbonoTotalT, formato: (v) => '${miles(v)} t', etiqueta: 'de carbono guardado'),
          _Cifra(
            valor: c.perdidaHa - c.gananciaHa,
            formato: (v) => '${decimal(v)} ha',
            etiqueta: 'perdidas netas (${decimal(c.perdidaHa)} se fueron, ${decimal(c.gananciaHa)} volvieron)',
            color: Zc.dePrioridad(5),
          ),
        ]),
        const SizedBox(height: 12),
        TarjetaVisor(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Por sector', style: tt.titleSmall),
              const SizedBox(height: 6),
              for (final s in c.sectores)
                _FilaSector(s: s, maximo: c.sectores.map((x) => x.probableHa).fold(1.0, (a, b) => a > b ? a : b)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaSector extends StatelessWidget {
  const _FilaSector({required this.s, required this.maximo});
  final SectorCifras s;
  final double maximo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label:
          '${s.nombre}: ${miles(s.probableHa)} hectáreas, ${miles(s.carbonoT)} toneladas de carbono, '
          'perdió ${decimal(s.perdidaHa)} y ganó ${decimal(s.gananciaHa)} hectáreas.',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.nombre, style: tt.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${miles(s.probableHa)} ha', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: sinMovimiento ? s.probableHa / maximo : 0, end: s.probableHa / maximo),
                  duration: sinMovimiento ? Duration.zero : const Duration(milliseconds: 800),
                  curve: Zm.entrar,
                  builder: (_, v, _) =>
                      LinearProgressIndicator(value: v, minHeight: 8, color: Zc.hoja, backgroundColor: Zc.hojaClara),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${miles(s.carbonoT)} t de carbono · −${decimal(s.perdidaHa)} / +${decimal(s.gananciaHa)} ha · árboles de ${decimal(s.alturaMedianaM)} m',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CifrasReportes extends StatelessWidget {
  const _CifrasReportes({required this.e});
  final EstadisticasReportes e;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    String n(double v) => miles(v);
    final tipos = e.porTipo.entries.where((x) => x.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final maximo = tipos.isEmpty ? 1 : tipos.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Rejilla2([
          _Cifra(valor: e.total.toDouble(), formato: n, etiqueta: 'reportes recibidos'),
          _Cifra(valor: e.validados.toDouble(), formato: n, etiqueta: 'validados por la CRA', color: Zc.hoja),
          _Cifra(valor: e.pendientes.toDouble(), formato: n, etiqueta: 'en revisión', color: Zc.fango),
          if (e.pctDentroManglar != null)
            _Cifra(valor: e.pctDentroManglar!, formato: (v) => '${v.round()} %', etiqueta: 'dentro del manglar')
          else
            _Cifra(valor: e.descartados.toDouble(), formato: n, etiqueta: 'descartados'),
        ]),
        if (tipos.isNotEmpty) ...[
          const SizedBox(height: 12),
          TarjetaVisor(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Por tipo de amenaza', style: tt.titleSmall),
                const SizedBox(height: 6),
                for (final t in tipos)
                  Semantics(
                    label: '${EstadisticasReportes.nombresTipo[t.key] ?? t.key}: ${t.value}',
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(EstadisticasReportes.nombresTipo[t.key] ?? t.key, style: tt.labelLarge),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: t.value / maximo,
                                  minHeight: 8,
                                  color: Zc.cienaga,
                                  backgroundColor: Zc.cienagaClara,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text('${t.value}', textAlign: TextAlign.end, style: tt.labelLarge),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── Vista previa de focos y ciénagas ─────────────────────────

Future<void> _copiar(BuildContext context, String texto, String hecho) async {
  await Clipboard.setData(ClipboardData(text: texto));
  vibrar(Vibracion.ligera);
  if (context.mounted) avisar(context, hecho, tipo: TipoAviso.exito);
}

String _lugarFoco(FocoCalor f) => f.municipio.isEmpty ? 'Atlántico' : f.municipio;

String _fechasFoco(FocoCalor f) {
  final d = f.desde;
  final h = f.hasta;
  if (d == null || h == null || fechaCorta(d) == fechaCorta(h)) return fechaCorta(h ?? d);
  return 'del ${fechaCorta(d)} al ${fechaCorta(h)}';
}

/// Texto para copiar un foco: lo que publica la CRA, sin nada inventado.
String textoFoco(FocoCalor f) =>
    'Foco de calor en ${_lugarFoco(f)} (${f.focos} ${f.focos == 1 ? 'detección' : 'detecciones'}), ${_fechasFoco(f)}. '
    'Confianza ${f.confianzaTexto}. Coordenadas ${f.lat.toStringAsFixed(5)}, ${f.lon.toStringAsFixed(5)}. '
    'Fuente: visor de focos de calor de la CRA';

/// Texto para copiar el resumen de una ciénaga.
/// Centro de las estaciones de muestreo de la ciénaga (para «Ver en el mapa»); `null` si no hay ninguna con coordenadas.
LatLng? puntoCienaga(CienagaAgua c) {
  final con = [for (final m in c.muestras) if (m.lat != 0 || m.lon != 0) m];
  if (con.isEmpty) return null;
  final lat = con.fold<double>(0, (s, m) => s + m.lat) / con.length;
  final lon = con.fold<double>(0, (s, m) => s + m.lon) / con.length;
  return LatLng(lat, lon);
}

String textoCienaga(CienagaAgua c) {
  final cat = categoriaIca(c.ica);
  return 'Ciénaga ${c.nombre}: calidad del agua ${cat?.etiqueta.toLowerCase() ?? 'sin dato'}'
      '${c.ica == null ? '' : ' (ICA ${decimal(c.ica!, 2)})'}, medida el ${fechaCorta(c.ultimaFecha)} '
      'en ${c.muestras.length} ${c.muestras.length == 1 ? 'estación' : 'estaciones'}. Fuente: CRA';
}

class _FilaFoco extends StatelessWidget {
  const _FilaFoco({required this.foco, required this.cerca, required this.distanciaM});
  final FocoCalor foco;
  final bool cerca;
  final double distanciaM;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final f = foco;
    final color = cerca ? Zc.dePrioridad(5) : const Color(0xFFEA580C);
    return MenuMantenido(
      key: ValueKey('foco-${f.id}'),
      alTocar: () => abrirFichaFoco(context, f, distanciaM),
      etiqueta: 'Foco de calor en ${_lugarFoco(f)}',
      vistaPrevia: (_) => _VistaPreviaFoco(foco: f, color: color, distanciaM: distanciaM),
      acciones: [
        AccionGesto(
          etiqueta: 'Ver ficha',
          icono: Icons.info_outline_rounded,
          alEjecutar: () => abrirFichaFoco(context, f, distanciaM),
        ),
        AccionGesto(
          etiqueta: 'Ver en el mapa',
          icono: Icons.map_rounded,
          alEjecutar: () => verEnElMapa(context, LatLng(f.lat, f.lon)),
        ),
        AccionGesto(
          etiqueta: 'Copiar datos',
          icono: Icons.copy_rounded,
          alEjecutar: () => _copiar(context, textoFoco(f), 'Datos del foco copiados'),
        ),
      ],
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label:
            '${f.focos} ${f.focos == 1 ? 'foco' : 'focos'} en ${_lugarFoco(f)}, ${_fechasFoco(f)}, '
            '${textoDistancia(distanciaM)}. Ver ficha.',
        child: TarjetaVisor(
          relleno: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${f.focos} ${f.focos == 1 ? 'foco' : 'focos'} · ${_lugarFoco(f)}', style: tt.titleSmall),
                    Text(
                      '${fechaCorta(f.hasta)} · confianza ${f.confianzaTexto}${f.satelites.isEmpty ? '' : ' · ${f.satelites}'}',
                      style: tt.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que se ve al mantener presionado un foco: lugar, fechas, distancia y confianza.
class _VistaPreviaFoco extends StatelessWidget {
  const _VistaPreviaFoco({required this.foco, required this.color, required this.distanciaM});
  final FocoCalor foco;
  final Color color;
  final double distanciaM;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final f = foco;
    return TarjetaVisor(
      borde: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${f.focos} ${f.focos == 1 ? 'foco' : 'focos'} en ${_lugarFoco(f)}', style: tt.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${_fechasFoco(f)} · ${textoDistancia(distanciaM)}', style: tt.bodySmall),
          const SizedBox(height: 10),
          _Dato('Confianza', f.confianzaTexto),
          if (f.satelites.isNotEmpty) _Dato('Satélites', f.satelites),
          const SizedBox(height: 6),
          Text('Un foco de calor no siempre es un incendio. Si ves humo, repórtalo con foto.', style: tt.bodySmall),
        ],
      ),
    );
  }
}

/// Ficha de un foco de calor: mapa del polígono, fechas, confianza y satélites.
Future<void> abrirFichaFoco(BuildContext context, FocoCalor f, double distanciaM) => mostrarHojaZ<void>(
  context,
  nombre: 'ficha-foco',
  contenido: (c) {
    final tt = Theme.of(c).textTheme;
    return Column(
      key: const ValueKey('ficha-foco'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C)),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(header: true, child: Text('Foco de calor en ${_lugarFoco(f)}', style: tt.titleLarge)),
            ),
            const SelloCra(),
          ],
        ),
        const SizedBox(height: 12),
        if (f.anillo.length >= 3)
          MapaVisor(
            alto: 170,
            descripcion: 'Mapa del foco de calor en ${_lugarFoco(f)}.',
            poligonos: [
              Polygon(
                points: [for (final (a, o) in f.anillo) LatLng(a, o)],
                color: const Color(0x55F97316),
                borderColor: const Color(0xFFEA580C),
                borderStrokeWidth: 1.5,
              ),
            ],
            puntos: [
              PuntoMapa(
                clave: 'ficha-foco-${f.id}',
                lat: f.lat,
                lon: f.lon,
                color: const Color(0xFFEA580C),
                icono: Icons.local_fire_department_rounded,
                etiqueta: 'Foco de calor',
              ),
            ],
          ),
        const SizedBox(height: 12),
        _Dato('Detecciones', '${f.focos}'),
        _Dato('Fechas', _fechasFoco(f)),
        _Dato('Confianza', f.confianzaTexto),
        if (f.satelites.isNotEmpty) _Dato('Satélites', f.satelites),
        _Dato('Distancia', textoDistancia(distanciaM)),
        _Dato('Coordenadas', '${f.lat.toStringAsFixed(5)}, ${f.lon.toStringAsFixed(5)}'),
        const SizedBox(height: 10),
        Text('Fuente: visor de focos de calor de la CRA (detección por satélite).', style: tt.bodySmall),
      ],
    );
  },
);

/// Lo que se ve al mantener presionada una ciénaga: el ICA y qué significa.
class _VistaPreviaCienaga extends StatelessWidget {
  const _VistaPreviaCienaga({required this.cienaga});
  final CienagaAgua cienaga;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cat = categoriaIca(cienaga.ica);
    final color = cat?.color ?? colorSinDato;
    return TarjetaVisor(
      borde: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  cienaga.ica == null ? '—' : decimal(cienaga.ica!, 2),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cienaga.nombre, style: tt.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${cat?.etiqueta ?? 'Sin dato'} · ${fechaCorta(cienaga.ultimaFecha)}', style: tt.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (cat != null) ...[const SizedBox(height: 8), Text(cat.explicacion, style: tt.bodyMedium)],
        ],
      ),
    );
  }
}

/// Ficha de una ciénaga: indicadores y cada estación con su fecha.
Future<void> abrirFichaCienaga(BuildContext context, CienagaAgua c) => mostrarHojaZ<void>(
  context,
  nombre: 'ficha-cienaga',
  contenido: (ctx) {
    final tt = Theme.of(ctx).textTheme;
    final cat = categoriaIca(c.ica);
    final valores = <String, double?>{'od': c.oxigeno, 'ph': c.ph, 'coli': c.coliformes, 'temp': c.temperatura};
    return Column(
      key: const ValueKey('ficha-cienaga'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.water_drop_rounded, color: cat?.color ?? colorSinDato),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(header: true, child: Text(c.nombre, style: tt.titleLarge)),
            ),
            const SelloCra(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${cat?.etiqueta ?? 'Sin dato'}${c.ica == null ? '' : ' · ICA ${decimal(c.ica!, 2)}'}'
          '${c.conManglar ? ' · rodeada de manglar' : ''}',
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final e in valores.entries) _FilaIndicador(indicador: indicadoresAgua[e.key]!, valor: e.value),
        const SizedBox(height: 12),
        Text('ESTACIONES DE MUESTREO', style: tt.labelSmall),
        const SizedBox(height: 4),
        for (final m in c.muestras)
          _Dato(
            m.codigo.isEmpty ? 'Estación ${m.id}' : m.codigo,
            m.muestreadoEn == null ? 'Sin medición' : 'Medida el ${fechaCorta(m.muestreadoEn)}',
          ),
        const SizedBox(height: 10),
        Text('Fuente: puntos de muestreo de calidad del agua de la CRA (ICA del IDEAM).', style: tt.bodySmall),
      ],
    );
  },
);
