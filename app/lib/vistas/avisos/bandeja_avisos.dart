import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../datos/avisos/centro_avisos.dart';
import '../../datos/avisos/reglas_avisos.dart';
import '../../datos/comunidad/comunidad.dart';
import '../../datos/comunidad/feed.dart';
import '../../datos/estado.dart';
import '../../datos/experiencia/jornada.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/kit/accion_gesto.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/estado_vacio.dart';
import '../../nucleo/kit/fila_deslizable.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/kit/menu_mantenido.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import '../comunidad/piezas_comunidad.dart';
import '../configuracion/piezas_configuracion.dart';
import '../mis_reportes/detalle_reporte.dart';
import '../raiz.dart';

// ------------------------------------------------------------------ apariencia por tipo

IconData _icono(AvisoApp a) => switch (a.tipo) {
      TipoAvisoApp.alerta => Icons.warning_amber_rounded,
      TipoAvisoApp.jornada => Icons.event_available_rounded,
      TipoAvisoApp.reporte => Icons.mark_chat_read_rounded,
    };

Color _color(AvisoApp a) => switch (a.tipo) {
      TipoAvisoApp.alerta => a.nivel == 'roja' ? Cra.riesgoMuyAlto : Cra.recuperacion,
      TipoAvisoApp.jornada => Cra.azul,
      TipoAvisoApp.reporte => Zc.hoja,
    };

// ------------------------------------------------------------------ campana de Inicio

/// La campana de Inicio: contador de no leídos, se mece cuando llega algo y muestra la
/// píldora del aviso nuevo (con «Ver» que lleva al lugar exacto).
class CampanaAvisos extends StatefulWidget {
  const CampanaAvisos({super.key});

  @override
  State<CampanaAvisos> createState() => _CampanaAvisosState();
}

class _CampanaAvisosState extends State<CampanaAvisos> with SingleTickerProviderStateMixin {
  final _centro = CentroAvisos.compartido;
  late final _meneo = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    _centro.nuevo.addListener(_alNuevo);
    _centro.pedido.addListener(_alPedido);
    // La app se abrió desde un aviso del navegador: se abre en cuanto haya pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _alPedido());
  }

  /// Tocaron un aviso del navegador: lleva al lugar exacto (si ya cargó la bandeja).
  void _alPedido() {
    final clave = _centro.pedido.value;
    if (clave == null || !mounted || !_centro.cargado) return;
    _centro.pedido.value = null;
    final a = _centro.avisos.where((x) => x.clave == clave).firstOrNull;
    if (a == null) return;
    _centro.marcarLeido(a);
    unawaited(abrirAviso(context, a));
  }

  @override
  void dispose() {
    _centro.nuevo.removeListener(_alNuevo);
    _centro.pedido.removeListener(_alPedido);
    _meneo.dispose();
    super.dispose();
  }

  void _alNuevo() {
    final a = _centro.nuevo.value;
    if (a == null || !mounted) return;
    if (!MediaQuery.disableAnimationsOf(context)) _meneo.forward(from: 0);
    // «Mis reportes» ya anuncia sus novedades con su propia píldora: aquí no se repite.
    if (a.tipo == TipoAvisoApp.reporte) return;
    vibrar(a.nivel == 'roja' ? Vibracion.fuerte : Vibracion.media);
    avisar(
      context,
      a.titulo,
      tipo: a.tipo == TipoAvisoApp.alerta ? TipoAviso.aviso : TipoAviso.info,
      accion: AccionAviso('Ver', () {
        _centro.marcarLeido(a);
        unawaited(abrirAviso(context, a));
      }),
      vida: const Duration(seconds: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _centro,
      builder: (context, _) {
        final n = _centro.noLeidos;
        return Presionable(
          etiqueta: n == 0 ? 'Avisos' : 'Avisos, $n sin leer',
          onTap: () => abrirBandejaAvisos(context),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Zc.superficie,
                  shape: BoxShape.circle,
                  border: Border.all(color: n > 0 ? Cra.dorado : Zc.linea, width: n > 0 ? 1.5 : 1),
                ),
                child: AnimatedBuilder(
                  animation: _meneo,
                  builder: (_, child) => Transform.rotate(
                    alignment: Alignment.topCenter,
                    // Vaivén que se apaga: como una campana de verdad.
                    angle: math.sin(_meneo.value * math.pi * 5) * 0.35 * (1 - _meneo.value),
                    child: child,
                  ),
                  child: Icon(n > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      size: 23, color: Zc.raiz),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: AnimatedScale(
                  scale: n > 0 ? 1 : 0,
                  duration: Zm.medio,
                  curve: Curves.easeOutBack,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cra.dorado,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(n > 9 ? '9+' : '$n',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900, color: Cra.azul, height: 1)),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

Future<void> abrirBandejaAvisos(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'avisos'),
      builder: (_) => const PantallaAvisos(),
    ));

// ------------------------------------------------------------------ ir al lugar exacto

/// Abre lo que avisa: la alerta en el mapa (con su hoja), la jornada o el reporte.
Future<void> abrirAviso(BuildContext context, AvisoApp a) async {
  switch (a.tipo) {
    case TipoAvisoApp.reporte:
      final estado = Zanky.leer(context);
      final r = estado.reportes.where((x) => x.id == a.destino).firstOrNull;
      if (r == null) {
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        Raiz.irA(context, 2);
        return;
      }
      return abrirDetalleReporte(context, r);
    case TipoAvisoApp.jornada:
      return _hojaJornada(context, a);
    case TipoAvisoApp.alerta:
      final nav = Navigator.of(context);
      // La caché de Comunidad: no se pide nada nuevo para abrir la alerta.
      final lote = await FuenteComunidad.compartida.alertas();
      final alerta = lote.datos.alertas.where((x) => x.id == a.destino).firstOrNull;
      final punto = alerta?.punto ?? (a.lat != null && a.lon != null ? LatLng(a.lat!, a.lon!) : null);
      if (punto != null) puntoPedidoMapa.value = punto;
      if (!nav.mounted) return;
      nav.popUntil((ruta) => ruta.isFirst);
      Raiz.irA(nav.context, 1);
      if (alerta != null) {
        // La hoja sale cuando el mapa ya está delante.
        await Future<void>.delayed(const Duration(milliseconds: 380));
        if (nav.mounted) await abrirHojaAlerta(nav.context, alerta, generado: lote.datos.generado);
      } else if (nav.mounted) {
        avisar(nav.context, 'Esa alerta ya terminó. Te dejamos en el mapa.', tipo: TipoAviso.info);
      }
  }
}

Future<void> _hojaJornada(BuildContext context, AvisoApp a) {
  final j = CentroAvisos.compartido.inscritas.where((x) => x.id == a.destino).firstOrNull;
  return mostrarHojaZ<void>(context,
      nombre: 'aviso-jornada',
      contenido: (c) {
        final tt = Theme.of(c).textTheme;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(j?.titulo ?? a.titulo, style: tt.headlineSmall?.copyWith(color: Zc.texto)),
          const SizedBox(height: 10),
          if (j != null) ...[
            _Dato(Icons.calendar_month_rounded, '${fechaLarga(j.inicio)[0].toUpperCase()}${fechaLarga(j.inicio).substring(1)}'),
            _Dato(Icons.schedule_rounded, '${horaCorta(j.inicio)} a ${horaCorta(j.fin)}'),
            if (j.puntoEncuentro.isNotEmpty) _Dato(Icons.place_rounded, j.puntoEncuentro),
            if (j.queLlevar.isNotEmpty) _Dato(Icons.backpack_rounded, 'Lleva: ${j.queLlevar.join(', ')}'),
          ] else
            Text(a.cuerpo, style: tt.bodyLarge),
          const SizedBox(height: 16),
          if (a.lat != null && a.lon != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Cra.azul),
              onPressed: () {
                puntoPedidoMapa.value = LatLng(a.lat!, a.lon!);
                Navigator.of(c).popUntil((ruta) => ruta.isFirst);
                Raiz.irA(c, 1);
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Ver el punto de encuentro'),
            ),
        ]);
      });
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, size: 20, color: Cra.azul),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Zc.texto))),
        ]),
      );
}

// ------------------------------------------------------------------ bandeja

class PantallaAvisos extends StatelessWidget {
  const PantallaAvisos({super.key});

  @override
  Widget build(BuildContext context) {
    final centro = CentroAvisos.compartido;
    return ListenableBuilder(
      listenable: centro,
      builder: (context, _) {
        final tt = Theme.of(context).textTheme;
        final nuevos = [for (final a in centro.avisos) if (!a.leido) a];
        final viejos = [for (final a in centro.avisos) if (a.leido) a];
        final nav = centro.navegador;
        final ofrecerNavegador = nav.disponible && !nav.activo && !nav.bloqueado && centro.avisos.isNotEmpty;
        return Scaffold(
          backgroundColor: Zc.arena,
          appBar: AppBar(
            backgroundColor: Zc.arena,
            title: const Text('Avisos'),
            actions: [
              if (nuevos.isNotEmpty)
                TextButton(
                  onPressed: () {
                    vibrar(Vibracion.ligera);
                    centro.marcarTodoLeido();
                  },
                  child: const Text('Leer todo'),
                ),
              IconButton(
                tooltip: 'Qué avisos recibir',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => mostrarHojaZ<void>(context,
                    nombre: 'preferencias-avisos', contenido: (_) => const SeccionPreferenciasAvisos(enHoja: true)),
              ),
            ],
          ),
          body: centro.avisos.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EstadoVacio(
                      titulo: 'Todo tranquilo',
                      texto: 'Aquí llegan las alertas naranja y roja del manglar, los recordatorios de tus '
                          'jornadas (la víspera y 2 horas antes) y las novedades de tus reportes.',
                      animo: Animo.feliz,
                      tamanoZanky: 120,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
                  children: [
                    if (ofrecerNavegador) const _OfertaNavegador(),
                    if (nuevos.isNotEmpty) ...[
                      _Titulo('Nuevos · ${nuevos.length}', tt),
                      for (final a in nuevos) _FilaAviso(key: ValueKey(a.clave), a: a),
                    ],
                    if (viejos.isNotEmpty) ...[
                      _Titulo('Anteriores', tt),
                      for (final a in viejos) _FilaAviso(key: ValueKey(a.clave), a: a),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                      child: Text(
                        'Desliza a la derecha para marcar leído y a la izquierda para borrar. '
                        'Mantén presionado para ver el aviso completo.',
                        textAlign: TextAlign.center,
                        style: tt.labelMedium?.copyWith(color: Zc.textoSuave),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, this.tt);
  final String texto;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Semantics(header: true, child: Text(texto.toUpperCase(), style: tt.seccion.copyWith(color: Zc.textoSuave))),
      );
}

/// En la web: pedir el permiso del navegador aquí, cuando la persona ya ve para qué sirve.
class _OfertaNavegador extends StatelessWidget {
  const _OfertaNavegador();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Cra.dorado.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Zr.m),
        border: Border.all(color: Cra.dorado.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Cra.azul),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Recibe estos avisos aunque tengas otra pestaña delante.',
              style: tt.bodyMedium?.copyWith(color: Zc.texto)),
        ),
        TextButton(
          onPressed: () async {
            final ok = await CentroAvisos.compartido.activarNavegador(true);
            if (!context.mounted) return;
            avisar(context, ok ? 'Listo: el navegador te avisará.' : 'El navegador no dio permiso. Puedes cambiarlo en su candado.',
                tipo: ok ? TipoAviso.exito : TipoAviso.aviso);
          },
          child: const Text('Activar'),
        ),
      ]),
    );
  }
}

class _FilaAviso extends StatelessWidget {
  const _FilaAviso({super.key, required this.a});
  final AvisoApp a;

  void _borrar(BuildContext context) {
    final centro = CentroAvisos.compartido;
    final i = centro.borrar(a);
    vibrar(Vibracion.media);
    avisar(context, 'Aviso borrado', accion: AccionAviso('Deshacer', () => centro.restaurar(a, i)));
  }

  void _abrir(BuildContext context) {
    CentroAvisos.compartido.marcarLeido(a);
    unawaited(abrirAviso(context, a));
  }

  @override
  Widget build(BuildContext context) {
    final centro = CentroAvisos.compartido;
    final leer = AccionGesto(
      etiqueta: a.leido ? 'No leído' : 'Leído',
      icono: a.leido ? Icons.mark_email_unread_rounded : Icons.done_all_rounded,
      color: Cra.azul,
      alEjecutar: () {
        vibrar(Vibracion.ligera);
        centro.marcarLeido(a, !a.leido);
      },
    );
    final borrar = AccionGesto(
      etiqueta: 'Borrar',
      icono: Icons.delete_rounded,
      destructiva: true,
      alEjecutar: () => _borrar(context),
    );
    final abrir = AccionGesto(
      etiqueta: switch (a.tipo) {
        TipoAvisoApp.alerta => 'Ver en el mapa',
        TipoAvisoApp.jornada => 'Ver la jornada',
        TipoAvisoApp.reporte => 'Ver el reporte',
      },
      icono: switch (a.tipo) {
        TipoAvisoApp.alerta => Icons.map_rounded,
        TipoAvisoApp.jornada => Icons.event_rounded,
        TipoAvisoApp.reporte => Icons.description_rounded,
      },
      alEjecutar: () => _abrir(context),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MenuMantenido(
        etiqueta: '${a.leido ? '' : 'Sin leer. '}${a.tipo.nombre}. ${a.titulo}. ${a.cuerpo}. '
            '${haceCuantoAviso(a.creado, DateTime.now())}',
        radio: BorderRadius.circular(Zr.m),
        alTocar: () => _abrir(context),
        vistaPrevia: (_) => _Vista(a: a, completa: true),
        acciones: [abrir, leer, borrar],
        child: FilaDeslizable(
          radio: BorderRadius.circular(Zr.m),
          accionesInicio: [leer],
          accionesFin: [borrar],
          hijo: _Vista(a: a),
        ),
      ),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({required this.a, this.completa = false});
  final AvisoApp a;
  final bool completa;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = _color(a);
    return AnimatedContainer(
      duration: Zm.medio,
      constraints: BoxConstraints(minHeight: 72, maxWidth: completa ? 420 : double.infinity),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Zc.superficie,
        borderRadius: BorderRadius.circular(Zr.m),
        border: Border.all(color: a.leido ? Zc.linea : color.withValues(alpha: 0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(_icono(a), size: 21, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text(a.tipo.nombre.toUpperCase(),
                    style: tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
              ),
              Text(haceCuantoAviso(a.creado, DateTime.now()), style: tt.labelSmall?.copyWith(color: Zc.textoTenue)),
              if (!a.leido) ...[
                const SizedBox(width: 6),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Cra.dorado, shape: BoxShape.circle)),
              ],
            ]),
            const SizedBox(height: 3),
            Text(a.titulo,
                maxLines: completa ? null : 2,
                overflow: completa ? null : TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(color: Zc.texto, fontWeight: a.leido ? FontWeight.w600 : FontWeight.w800)),
            if (a.cuerpo.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(a.cuerpo,
                  maxLines: completa ? null : 2,
                  overflow: completa ? null : TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: Zc.textoSuave, height: 1.35)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ preferencias

/// «Avisos» en Configuración (y en la hoja de la bandeja): un interruptor por tipo y, en la
/// web, los avisos del navegador (el permiso se pide al encenderlo, nunca al abrir la app).
class SeccionPreferenciasAvisos extends StatelessWidget {
  const SeccionPreferenciasAvisos({super.key, this.enHoja = false});
  final bool enHoja;

  @override
  Widget build(BuildContext context) {
    final centro = CentroAvisos.compartido;
    return ListenableBuilder(
      listenable: centro,
      builder: (context, _) {
        final p = centro.preferencias;
        final nav = centro.navegador;
        FilaAjustes fila(TipoAvisoApp t, IconData icono, Color color, String detalle) => FilaAjustes(
              icono: icono,
              color: color,
              titulo: switch (t) {
                TipoAvisoApp.alerta => 'Alertas naranja y roja',
                TipoAvisoApp.jornada => 'Recordatorios de mis jornadas',
                TipoAvisoApp.reporte => 'Novedades de mis reportes',
              },
              detalle: detalle,
              fin: InterruptorIos(
                etiqueta: 'Avisos de ${t.nombre.toLowerCase()}',
                valor: p.permite(t),
                alCambiar: (v) => centro.cambiarPreferencia(t, v),
              ),
            );
        final grupo = GrupoAjustes(
          titulo: 'Avisos',
          nota: 'Se revisan al abrir la app y cada 10 minutos mientras está abierta, con los datos ya guardados '
              'si no hay señal. El mismo aviso nunca se repite.',
          filas: [
            fila(TipoAvisoApp.alerta, Icons.warning_amber_rounded, Cra.recuperacion,
                'Cuando una alerta sube a naranja o roja: lugar y qué hacer'),
            fila(TipoAvisoApp.jornada, Icons.event_available_rounded, Cra.azul,
                'La víspera (6:00 p. m.) y 2 horas antes de tus jornadas'),
            fila(TipoAvisoApp.reporte, Icons.mark_chat_read_rounded, Zc.hoja,
                'Cuando tu reporte llega a la CRA o cambia de estado'),
            if (nav.disponible)
              FilaAjustes(
                icono: Icons.notifications_active_rounded,
                color: Cra.dorado,
                titulo: 'Avisos del navegador',
                detalle: nav.bloqueado
                    ? 'El navegador los tiene bloqueados: actívalos en el candado de la barra de direcciones'
                    : 'También fuera de la pestaña, mientras Zanky siga abierto',
                fin: InterruptorIos(
                  etiqueta: 'Avisos del navegador',
                  valor: nav.activo,
                  alCambiar: nav.bloqueado ? null : (v) => unawaited(centro.activarNavegador(v)),
                ),
              ),
          ],
        );
        return enHoja ? Padding(padding: const EdgeInsets.only(top: 4), child: grupo) : grupo;
      },
    );
  }
}
