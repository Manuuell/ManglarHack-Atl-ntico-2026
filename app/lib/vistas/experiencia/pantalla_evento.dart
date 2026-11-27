import 'package:flutter/material.dart';

import '../../datos/experiencia/jornada.dart';
import '../../datos/experiencia/participacion.dart';
import '../../nucleo/base/entrada_escalonada.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/zanky_mascota.dart';
import 'asistencia.dart';
import 'atajos_evento.dart';
import 'charla_zanky.dart';
import 'piezas.dart';
import 'reto_zanky.dart';

/// El modo evento: Zanky da la bienvenida a la jornada y ofrece asistencia, charla, reto y atajos.
class PantallaEvento extends StatefulWidget {
  const PantallaEvento({super.key, required this.codigo, this.fuente, this.almacen});
  final String codigo;
  final FuenteJornadas? fuente;
  final AlmacenParticipacion? almacen;

  @override
  State<PantallaEvento> createState() => _PantallaEventoState();
}

class _PantallaEventoState extends State<PantallaEvento> {
  late final AlmacenParticipacion _almacen = widget.almacen ?? AlmacenParticipacion.instancia;
  late final FuenteJornadas _fuente = widget.fuente ?? FuenteJornadas();
  // Primero lo que hay en el teléfono (caché o respaldo, al instante) y luego la red: con mala señal en el manglar
  // la pantalla ya no se queda en blanco hasta 6 s esperando.
  EventoZanky? _e;
  Animo _animo = Animo.feliz;

  @override
  void initState() {
    super.initState();
    _almacen.cargar();
    _fuente.eventoLocal(widget.codigo).then((e) {
      if (mounted && _e == null) setState(() => _e = e);
    });
    _fuente.evento(widget.codigo).then((e) {
      if (mounted) setState(() => _e = e);
    });
  }

  Future<void> _registrar(EventoZanky e) async {
    final ok = await abrirAsistencia(context, e, almacen: _almacen);
    if (ok && mounted) setState(() => _animo = Animo.celebrando);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Zc.arena,
      body: SafeArea(
        child: Column(
          children: [
            const BarraEvento(titulo: 'Modo evento'),
            Expanded(
              child: Builder(
                builder: (context) {
                  final e = _e;
                  return AnimatedSwitcher(
                    duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
                    switchInCurve: Zm.entrar,
                    child: e == null
                        ? const _Cargando(key: ValueKey('carga'))
                        : ListenableBuilder(
                            key: const ValueKey('listo'),
                            listenable: _almacen,
                            builder: (_, _) => _contenido(context, e),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, EventoZanky e) {
    final tt = Theme.of(context).textTheme;
    final j = e.jornada;
    final asistio = _almacen.asistio(e.codigo);
    final saludo = j == null
        ? '¡Hola! Soy Zanky. Qué bueno verte por aquí. Hoy el manglar tiene un evento con nosotros.'
        : '¡Hola! Soy Zanky. Bienvenido a «${j.titulo}». ¡Vamos a cuidar el manglar juntos!';
    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        EntradaEscalonada(
          index: i++,
          child: Center(child: ZankyMascota(tamano: 150, animo: _animo, onTap: () {})),
        ),
        const SizedBox(height: 6),
        EntradaEscalonada(index: i++, child: BurbujaZanky(texto: saludo, colaIzquierda: false)),
        const SizedBox(height: 18),
        EntradaEscalonada(index: i++, child: j == null ? _TarjetaGenerica(e) : _TarjetaJornada(j)),
        const SizedBox(height: 14),
        EntradaEscalonada(
          index: i++,
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Zc.sol, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tus puntos de eventos: ${_almacen.puntos}',
                  style: tt.titleSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EntradaEscalonada(
          index: i++,
          child: BotonEstado(
            texto: 'Registrar mi asistencia (+${AlmacenParticipacion.puntosAsistencia})',
            textoHecho: 'Asistencia registrada',
            icono: Icons.how_to_reg_rounded,
            fase: asistio ? FaseBoton.hecho : FaseBoton.reposo,
            onTap: asistio ? null : () => _registrar(e),
          ),
        ),
        const SizedBox(height: 10),
        EntradaEscalonada(
          index: i++,
          child: BotonEstado(
            texto: 'Hablar con Zanky',
            icono: Icons.chat_bubble_rounded,
            color: Zc.cienaga,
            onTap: () => abrirCharlaZanky(context, e),
          ),
        ),
        const SizedBox(height: 10),
        EntradaEscalonada(
          index: i++,
          child: BotonEstado(
            texto: _almacen.mejorReto(e.codigo) > 0
                ? 'Reto del manglar (mejor: ${_almacen.mejorReto(e.codigo)} de 5)'
                : 'Reto del manglar',
            icono: Icons.emoji_events_rounded,
            color: Zc.sol,
            onTap: () => abrirRetoZanky(context, e),
          ),
        ),
        const SizedBox(height: 22),
        EntradaEscalonada(index: i++, child: Text('Atajos', style: tt.labelSmall)),
        const SizedBox(height: 8),
        EntradaEscalonada(index: i++, child: const AtajosEvento()),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando el evento',
        child: const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      );
}

class _TarjetaGenerica extends StatelessWidget {
  const _TarjetaGenerica(this.e);
  final EventoZanky e;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Pildora('Evento', icono: Icons.qr_code_2_rounded),
          const SizedBox(height: 10),
          Text(e.titulo, style: tt.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Entraste con un código de evento. Aquí puedes hablar con Zanky, hacer el reto del manglar, '
            'registrar tu asistencia y reportar amenazas.',
            style: tt.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TarjetaJornada extends StatelessWidget {
  const _TarjetaJornada(this.j);
  final Jornada j;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fraccion = j.cupos <= 0 ? 0.0 : (j.inscritos / j.cupos).clamp(0.0, 1.0);
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pildora(j.tipoLegible, icono: Icons.eco_rounded),
            if (j.esEjemplo) Pildora('Datos de ejemplo', color: Zc.sol, icono: Icons.science_rounded),
          ]),
          const SizedBox(height: 10),
          Semantics(header: true, child: Text(j.titulo, style: tt.titleLarge)),
          const SizedBox(height: 6),
          DatoFila(
            icono: Icons.event_rounded,
            texto: fechaLarga(j.inicio),
            detalle: '${horaCorta(j.inicio)} a ${horaCorta(j.fin)}',
          ),
          DatoFila(icono: Icons.place_rounded, texto: 'Punto de encuentro', detalle: j.puntoEncuentro),
          if (j.cupos > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 20, color: Zc.hoja),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          j.llena ? 'Cupos llenos (${j.inscritos} de ${j.cupos})' : '${j.cuposLibres} cupos libres de ${j.cupos}',
                          style: tt.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: fraccion),
                      duration: sinMovimiento(context) ? Duration.zero : Zm.largo,
                      curve: Zm.entrar,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: Zc.linea,
                        color: j.llena ? Zc.prioridad[4] : Zc.hoja,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (j.queLlevar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Qué llevar', style: tt.labelSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final q in j.queLlevar) _Etiqueta(q)]),
          ],
          if (j.esEjemplo) ...[
            const SizedBox(height: 12),
            Text('Datos de ejemplo: confirma la convocatoria con la organización.', style: tt.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Zc.arena, borderRadius: BorderRadius.circular(99)),
        child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Zc.texto)),
      );
}

class _Caja extends StatelessWidget {
  const _Caja({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Zc.superficie,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
          boxShadow: const [BoxShadow(color: Color(0x0F0B2E24), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: child,
      );
}
