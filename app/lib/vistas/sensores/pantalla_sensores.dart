import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../datos/estado.dart';
import '../../datos/sensores/lecturas_sensor.dart';
import '../../datos/sensores/servicio_sensores.dart';
import '../../nucleo/base/esqueleto.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/anuncio.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/kit/ruta_borde.dart';
import '../../nucleo/kit/tirar_actualizar.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../admin/piezas_admin.dart' show BotonIcono;
import '../comun/zanky_mascota.dart';
import 'detalle_estacion.dart';
import 'graficas_sensor.dart';
import 'mapa_estaciones.dart';

/// Quién arma el servicio. Las pruebas lo cambian por uno sin red ni reloj real.
ServicioSensores Function(BuildContext context) crearServicioSensores =
    (context) => ServicioSensores(servidor: Zanky.leer(context).servidor);

/// Reloj de las vistas de sensores (las pruebas lo fijan).
DateTime Function() relojSensores = DateTime.now;

/// Abre «Sensores del manglar» con la ruta de borde del kit (deslizar desde el borde vuelve).
Future<void> abrirSensores(BuildContext context, {ServicioSensores? servicio}) {
  return Navigator.of(context).push(
    RutaBorde<void>(
      sinMovimiento: MediaQuery.disableAnimationsOf(context),
      settings: const RouteSettings(name: 'sensores'),
      builder: (_) => PantallaSensores(servicio: servicio),
    ),
  );
}

/// Las estaciones del manglar: última lectura de cada sonda, estado, mini gráfica, umbrales y
/// alerta. Refresca sola cada minuto mientras está abierta.
class PantallaSensores extends StatefulWidget {
  const PantallaSensores({super.key, this.servicio});
  final ServicioSensores? servicio;

  @override
  State<PantallaSensores> createState() => _PantallaSensoresState();
}

class _PantallaSensoresState extends State<PantallaSensores> {
  ServicioSensores? _servicio;
  ResultadoSensores? _r;
  bool _cargando = true;
  Timer? _reloj;
  Set<String> _alertasVistas = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicio == null) {
      _servicio = widget.servicio ?? crearServicioSensores(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _iniciar();
      });
    }
  }

  Future<void> _iniciar() async {
    final copia = await _servicio!.copia();
    if (mounted && copia != null && _r == null) setState(() => _r = copia);
    await _actualizar();
    _reloj = Timer.periodic(ServicioSensores.refresco, (_) => _actualizar());
  }

  Future<void> _actualizar() async {
    final r = await _servicio!.cargar();
    if (!mounted) return;
    setState(() {
      _r = r;
      _cargando = false;
    });
    // El lector de pantalla oye la alerta cuando aparece, no en cada refresco.
    final ahora = relojSensores();
    final alertas = {for (final l in r.lecturas) if (l.estado(ahora) == EstadoLectura.alerta) l.sensorId};
    final nuevas = alertas.difference(_alertasVistas);
    _alertasVistas = alertas;
    if (nuevas.isNotEmpty) {
      final l = r.lecturas.firstWhere((l) => nuevas.contains(l.sensorId));
      anunciar(context, 'Alerta: ${l.tipo.nombre} en ${l.zonaNombre} pasó el umbral.');
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    if (widget.servicio == null) _servicio?.cerrar();
    super.dispose();
  }

  void _abrirDetalle(Estacion e) {
    final r = _r;
    if (r == null) return;
    abrirDetalleEstacion(context, estacion: e, resultado: r, alActualizar: () async {
      await _actualizar();
      return _r!;
    });
  }

  Future<void> _compartir(Estacion e) async {
    final ahora = relojSensores();
    final r = _r;
    final lineas = [
      for (final l in e.lecturas)
        if (l.valor != null) '${l.tipo.nombre}: ${l.tipo.formatear(l.valor!)} (${haceCuanto(l.medidoEn, ahora)})',
    ];
    try {
      await SharePlus.instance.share(ShareParams(
        text: [
          'Sensores del manglar · ${e.zonaNombre}',
          ...lineas,
          if (r?.esDemostracion ?? false) 'DEMOSTRACIÓN: lecturas simuladas, no son mediciones reales.',
          'Visto en Zanky.',
        ].join('\n'),
        subject: 'Zanky · sensores',
      ));
    } catch (_) {
      if (mounted) avisar(context, 'No pude abrir el menú de compartir.', tipo: TipoAviso.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ahora = relojSensores();
    final r = _r;
    final estaciones = r == null ? const <Estacion>[] : agruparEstaciones(r.lecturas, ahora);
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho >= 900 ? 2 : 1;
    final Widget cuerpo;
    if (r == null && _cargando) {
      cuerpo = ListView(
        key: const ValueKey('cargando'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [Esqueleto.cabecera(), SizedBox(height: 12), Esqueleto.lista(3)],
      );
    } else if (estaciones.isEmpty) {
      cuerpo = EstadoVacio(
        key: const ValueKey('vacio'),
        titulo: 'Aún no hay estaciones',
        texto: 'Cuando la CRA instale una estación, aquí verás el agua del caño cada 10 minutos.',
        animo: Animo.curioso,
        textoAccion: 'Volver a mirar',
        iconoAccion: Icons.refresh_rounded,
        alAccion: _actualizar,
      );
    } else {
      final alertas = [for (final e in estaciones) ...e.enAlerta(ahora)];
      cuerpo = TirarActualizar(
        key: const ValueKey('lista'),
        alActualizar: _actualizar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Origen(resultado: r!, ahora: ahora),
                    for (final a in alertas) ...[const SizedBox(height: 10), _AlertaSensor(lectura: a, ahora: ahora)],
                    const SizedBox(height: 12),
                    _Resumen(estaciones: estaciones, ahora: ahora),
                    const SizedBox(height: 12),
                    MapaEstaciones(
                      estaciones: estaciones,
                      ahora: ahora,
                      alto: columnas > 1 ? 280 : 210,
                      alTocar: _abrirDetalle,
                    ),
                    const SizedBox(height: 12),
                    _Rejilla(
                      columnas: columnas,
                      hijos: [
                        for (final e in estaciones)
                          MenuMantenido(
                            etiqueta: 'Estación ${e.zonaNombre}',
                            acciones: [
                              AccionGesto(
                                etiqueta: 'Ver detalle',
                                icono: Icons.insights_rounded,
                                alEjecutar: () => _abrirDetalle(e),
                              ),
                              AccionGesto(
                                etiqueta: 'Compartir lectura',
                                icono: Icons.ios_share_rounded,
                                alEjecutar: () => _compartir(e),
                              ),
                            ],
                            child: TarjetaEstacion(
                              estacion: e,
                              series: r.series,
                              ahora: ahora,
                              alTocar: () => _abrirDetalle(e),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const UmbralesExplicados(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Cabecera(alActualizar: _actualizar),
            Expanded(child: cuerpo),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.alActualizar});
  final Future<void> Function() alActualizar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          BotonIcono(icono: Icons.arrow_back_rounded, etiqueta: 'Volver', alTocar: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              header: true,
              child: Text('Sensores del manglar', style: tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          BotonIcono(icono: Icons.refresh_rounded, etiqueta: 'Actualizar lecturas', alTocar: alActualizar),
        ],
      ),
    );
  }
}

/// Dice de dónde salen los números: en vivo, copia sin señal o demostración.
class _Origen extends StatelessWidget {
  const _Origen({required this.resultado, required this.ahora});
  final ResultadoSensores resultado;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (IconData icono, Color color, String titulo, String texto) = switch (resultado.origen) {
      OrigenSensores.enVivo => (
          Icons.wifi_tethering_rounded,
          Zc.hoja,
          'En vivo',
          'Leído a las ${horaColombia(resultado.leido)}. Se actualiza solo cada minuto.',
        ),
      OrigenSensores.copia => (
          Icons.cloud_off_rounded,
          Zc.fango,
          'Sin señal: última copia',
          'Lecturas guardadas a las ${horaColombia(resultado.leido)} (${haceCuanto(resultado.leido, ahora)}). '
              'Se actualizan solas al volver la señal.',
        ),
      OrigenSensores.demostracion => (
          Icons.science_rounded,
          Zc.sol,
          'DEMOSTRACIÓN · datos de ejemplo',
          'Lecturas simuladas para mostrar cómo funciona. No son mediciones reales del manglar.',
        ),
    };
    return Semantics(
      container: true,
      label: '$titulo. $texto',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color == Zc.sol ? Zc.fango : color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(texto, style: tt.bodySmall),
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

/// La alerta visible: qué pasó, dónde, cuánto y qué hacer. Color de riesgo 5.
class _AlertaSensor extends StatelessWidget {
  const _AlertaSensor({required this.lectura, required this.ahora});
  final LecturaSensor lectura;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final rojo = Zc.dePrioridad(5);
    final l = lectura;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: ValueKey('alerta-${l.sensorId}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rojo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: rojo, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded, color: rojo, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alerta: ${l.tipo.nombre.toLowerCase()} en ${l.zonaNombre}', style: tt.titleSmall?.copyWith(color: rojo)),
                  const SizedBox(height: 2),
                  Text(
                    '${l.tipo.formatear(l.valor!)} · umbral ${l.tipo.formatear(l.umbral)} · ${haceCuanto(l.medidoEn, ahora)}. '
                    '${l.tipo.explicacion} Un vigía debe revisarlo; no es una alerta oficial.',
                    style: tt.bodySmall?.copyWith(color: Zc.texto),
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

class _Resumen extends StatelessWidget {
  const _Resumen({required this.estaciones, required this.ahora});
  final List<Estacion> estaciones;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final sondas = [for (final e in estaciones) ...e.lecturas];
    int cuenta(EstadoLectura s) => sondas.where((l) => l.estado(ahora) == s).length;
    final datos = [
      ('${estaciones.length}', estaciones.length == 1 ? 'estación' : 'estaciones', Zc.raiz),
      ('${cuenta(EstadoLectura.enLinea) + cuenta(EstadoLectura.alerta)}', 'sondas en línea', Zc.hoja),
      ('${cuenta(EstadoLectura.alerta)}', 'en alerta', Zc.dePrioridad(5)),
      ('${cuenta(EstadoLectura.vieja) + cuenta(EstadoLectura.sinDatos)}', 'sin datos recientes', Zc.textoSuave),
    ];
    final tt = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (n, t, c) in datos)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Zc.superficie,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Zc.linea),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$n ',
                  style: tt.titleSmall?.copyWith(color: c, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                TextSpan(text: t, style: tt.bodySmall),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Rejilla extends StatelessWidget {
  const _Rejilla({required this.columnas, required this.hijos});
  final int columnas;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    if (columnas <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < hijos.length; i++) ...[if (i > 0) const SizedBox(height: 12), hijos[i]],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
        );
      },
    );
  }
}

Color colorEstado(EstadoLectura e, int riesgo) => switch (e) {
      EstadoLectura.alerta => Zc.dePrioridad(5),
      EstadoLectura.enLinea => riesgo >= 3 ? Zc.dePrioridad(3) : Zc.hoja,
      EstadoLectura.vieja => Zc.fango,
      EstadoLectura.sinDatos => Zc.textoTenue,
    };

IconData iconoEstado(EstadoLectura e) => switch (e) {
      EstadoLectura.alerta => Icons.warning_rounded,
      EstadoLectura.enLinea => Icons.wifi_tethering_rounded,
      EstadoLectura.vieja => Icons.schedule_rounded,
      EstadoLectura.sinDatos => Icons.remove_circle_outline_rounded,
    };

/// Pastilla de estado: ícono y texto además del color (daltonismo).
class PastillaEstado extends StatelessWidget {
  const PastillaEstado({super.key, required this.estado, required this.riesgo, required this.texto});
  final EstadoLectura estado;
  final int riesgo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = colorEstado(estado, riesgo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoEstado(estado), size: 14, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c == Zc.textoTenue ? Zc.textoSuave : c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una estación: zona, estado y una fila por sonda con valor y chispa de las últimas horas.
class TarjetaEstacion extends StatelessWidget {
  const TarjetaEstacion({super.key, required this.estacion, required this.series, required this.ahora, this.alTocar});
  final Estacion estacion;
  final Map<String, List<PuntoSerie>> series;
  final DateTime ahora;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final e = estacion;
    final estado = e.estado(ahora);
    final riesgo = e.riesgo(ahora);
    return Presionable(
      escala: 0.985,
      etiqueta: 'Estación ${e.zonaNombre}. ${textoEstado(estado, e.ultimaLectura, ahora)}. Toca para ver el detalle.',
      onTap: alTocar,
      child: Container(
        key: ValueKey('estacion-${e.zonaId}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(
            color: estado == EstadoLectura.alerta ? Zc.dePrioridad(5) : Zc.linea,
            width: estado == EstadoLectura.alerta ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Zc.cienagaClara, shape: BoxShape.circle),
                  child: const Icon(Icons.sensors_rounded, color: Zc.cienaga, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.zonaNombre, style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      PastillaEstado(estado: estado, riesgo: riesgo, texto: textoEstado(estado, e.ultimaLectura, ahora)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
              ],
            ),
            for (final l in e.lecturas) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Zc.linea),
              const SizedBox(height: 10),
              FilaSonda(lectura: l, serie: series[l.sensorId] ?? const [], ahora: ahora),
            ],
          ],
        ),
      ),
    );
  }
}

class FilaSonda extends StatelessWidget {
  const FilaSonda({super.key, required this.lectura, required this.serie, required this.ahora});
  final LecturaSensor lectura;
  final List<PuntoSerie> serie;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = lectura;
    final estado = l.estado(ahora);
    final color = colorEstado(estado, l.riesgo(ahora));
    final valor = l.valor == null ? '—' : l.tipo.formatear(l.valor!);
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.tipo.nombre, style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                valor,
                style: tt.titleLarge?.copyWith(
                  color: estado == EstadoLectura.alerta ? color : Zc.texto,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                l.valor == null ? 'Sin lecturas aún' : 'Umbral ${l.tipo.formatear(l.umbral)}',
                style: tt.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: ChispaSensor(
            valores: [for (final p in serie) p.valor],
            color: color,
            umbral: l.valor == null ? null : l.umbral,
            etiqueta: serie.length < 2
                ? '${l.tipo.nombre}: aún sin historia para la gráfica'
                : '${l.tipo.nombre}: ${serie.length} lecturas, de ${l.tipo.formatear(serie.first.valor)} a ${l.tipo.formatear(serie.last.valor)}',
          ),
        ),
      ],
    );
  }
}

/// Los umbrales en lenguaje simple: qué mide cada sonda y qué pasa si se pasa.
class UmbralesExplicados extends StatelessWidget {
  const UmbralesExplicados({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: Zc.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('¿Qué significa cada umbral?', style: tt.titleMedium)),
          const SizedBox(height: 4),
          Text(
            'Cuando una lectura llega al umbral, la tarjeta se pone roja para que un vigía de la CRA vaya a mirar. '
            'Son valores de referencia; la CRA fija el umbral de cada estación.',
            style: tt.bodySmall,
          ),
          for (final t in TipoSensor.values) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Zc.cienagaClara, borderRadius: BorderRadius.circular(99)),
                  child: Text(t.formatear(t.umbralReferencia), style: tt.labelSmall?.copyWith(color: Zc.raiz)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${t.nombre}. ', style: tt.titleSmall),
                    TextSpan(text: t.explicacion, style: tt.bodySmall),
                  ])),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
