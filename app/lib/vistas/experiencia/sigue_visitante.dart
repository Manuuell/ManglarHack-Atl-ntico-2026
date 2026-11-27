import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../datos/experiencia/instalar_web.dart';
import '../../datos/experiencia/jornada.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas.dart';
import 'puerta_evento.dart';

/// La jornada que sigue después de [actual] (la primera futura que no sea esa ni esté cancelada).
Jornada? proximaJornada(List<Jornada> todas, {String? actual, DateTime? ahora}) {
  final t = ahora ?? DateTime.now();
  final futuras = [
    for (final j in todas)
      if (j.id != actual && !j.cancelada && j.fin.isAfter(t)) j,
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  return futuras.isEmpty ? null : futuras.first;
}

/// Tarjeta «Próximo evento»: foto, fecha y lugar, con lo que ya está en el teléfono (sirve sin señal).
/// Al tocarla abre su modo evento. Si no hay próximo evento no ocupa espacio.
class ProximoEvento extends StatefulWidget {
  const ProximoEvento({super.key, required this.fuente, this.actual});
  final FuenteJornadas fuente;
  final String? actual;

  @override
  State<ProximoEvento> createState() => _ProximoEventoState();
}

class _ProximoEventoState extends State<ProximoEvento> {
  late final Future<List<Jornada>> _lista = widget.fuente.cargarLocal();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<List<Jornada>>(
      future: _lista,
      builder: (context, s) {
        final j = s.hasData ? proximaJornada(s.data!, actual: widget.actual) : null;
        return AnimatedSize(
          duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
          curve: Zm.entrar,
          alignment: Alignment.topCenter,
          child: j == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Próximo evento', style: tt.labelSmall),
                      const SizedBox(height: 8),
                      Presionable(
                        etiqueta: 'Próximo evento: ${j.titulo}, ${fechaLarga(j.inicio)}',
                        escala: 0.97,
                        onTap: () => abrirEvento(context, j.id),
                        child: _TarjetaJornada(j),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _TarjetaJornada extends StatelessWidget {
  const _TarjetaJornada(this.j);
  final Jornada j;

  static const _respaldo = AssetImage('assets/fotos/sendero-mallorquin.webp');

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final img = j.imagen;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Zr.m),
        boxShadow: const [BoxShadow(color: Color(0x140B2E24), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 116,
            child: img == null
                ? const Image(image: _respaldo, fit: BoxFit.cover)
                : Image.network(
                    img.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Image(image: _respaldo, fit: BoxFit.cover),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    j.esEjemplo ? '${j.tipoLegible} · Ejemplo' : j.tipoLegible,
                    style: tt.labelSmall?.copyWith(color: Zc.hoja),
                  ),
                  const SizedBox(height: 2),
                  Text(j.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                  const SizedBox(height: 4),
                  _Linea(Icons.event_rounded, '${fechaLarga(j.inicio)} · ${horaCorta(j.inicio)}'),
                  _Linea(Icons.place_rounded, j.puntoEncuentro),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.chevron_right_rounded, color: Zc.textoTenue),
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    if (texto.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icono, size: 14, color: Zc.textoSuave),
          const SizedBox(width: 4),
          Expanded(
            child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Cierre del recorrido: instalar la app web (PWA) o seguir en Zanky.
class SigueConZanky extends StatefulWidget {
  const SigueConZanky({super.key});

  @override
  State<SigueConZanky> createState() => _SigueConZankyState();
}

class _SigueConZankyState extends State<SigueConZanky> {
  FaseBoton _fase = FaseBoton.reposo;

  /// El navegador ofreció instalar (Chrome/Edge). Llega cuando el navegador decide, a veces segundos
  /// después de abrir: se revisa cada segundo durante medio minuto, sin pedir nada a la red.
  bool _puede = puedeInstalarApp();
  final bool _ios = esIos();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_puede && !_ios && !appInstalada()) {
      var vueltas = 0;
      _espera = Timer.periodic(const Duration(seconds: 1), (t) {
        if (++vueltas >= 30) t.cancel();
        if (puedeInstalarApp()) {
          t.cancel();
          if (mounted) setState(() => _puede = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _instalar() async {
    if (!puedeInstalarApp()) {
      // iPhone: Safari no tiene aviso; se muestran los pasos. Si el aviso ya se usó, también.
      await _explicarInstalar(context, ios: _ios);
      if (!_ios && mounted) setState(() => _puede = false);
      return;
    }
    setState(() => _fase = FaseBoton.cargando);
    final ok = await instalarApp();
    if (mounted) setState(() => _fase = ok ? FaseBoton.hecho : FaseBoton.reposo);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final instalada = appInstalada();
    // El botón solo aparece cuando sirve: aviso del navegador disponible, o iPhone (con los pasos a mano).
    final mostrarInstalar = kIsWeb && !instalada && (_puede || _ios);
    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Zc.hojaClara, borderRadius: BorderRadius.circular(Zr.l)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ZankyMascota(tamano: 64, animo: Animo.celebrando),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sigue con Zanky', style: tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      instalada
                          ? 'Ya me tienes en tu pantalla de inicio. Cuéntame lo que veas en el manglar.'
                          : mostrarInstalar
                              ? 'Llévame en tu teléfono: funciono sin señal y casi no ocupo espacio.'
                              : 'Cuéntame lo que veas en el manglar: aquí te espero.',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (mostrarInstalar) ...[
            BotonEstado(
              texto: _ios ? 'Agregar Zanky a inicio' : 'Instalar Zanky',
              icono: _ios ? Icons.ios_share_rounded : Icons.install_mobile_rounded,
              textoHecho: 'Zanky instalada',
              fase: _fase,
              onTap: _instalar,
            ),
            const SizedBox(height: 10),
          ],
          BotonEstado(
            texto: 'Seguir en Zanky',
            icono: Icons.arrow_forward_rounded,
            secundario: true,
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }
}

/// iPhone y navegadores sin aviso de instalación: los pasos a mano.
Future<void> _explicarInstalar(BuildContext context, {bool ios = false}) => mostrarHojaZ<void>(
      context,
      nombre: 'instalar_zanky',
      contenido: (c) {
        final tt = Theme.of(c).textTheme;
        Widget paso(IconData i, String t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(i, color: Zc.hoja),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: tt.bodyMedium)),
                ],
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ZankyMascota(tamano: 84, animo: Animo.feliz)),
            const SizedBox(height: 10),
            Text(ios ? 'Agrega Zanky a tu inicio' : 'Instala Zanky en dos toques',
                textAlign: TextAlign.center, style: tt.titleLarge),
            const SizedBox(height: 14),
            if (ios) ...[
              paso(Icons.ios_share_rounded, '1. Abajo en Safari, toca Compartir (el cuadro con la flecha hacia arriba).'),
              paso(Icons.add_box_outlined, '2. Desliza y toca «Agregar a inicio».'),
              paso(Icons.check_circle_outline_rounded, '3. Toca «Agregar». Zanky queda con su ícono y abre sin señal.'),
              paso(Icons.info_outline_rounded, 'Si abriste el enlace desde otra app (WhatsApp, Instagram), primero ábrelo en Safari.'),
            ] else
              paso(Icons.more_vert_rounded, 'Abre el menú del navegador y toca «Instalar app» o «Agregar a la pantalla principal».'),
            const SizedBox(height: 6),
            BotonEstado(texto: 'Entendido', onTap: () => Navigator.of(c).pop()),
          ],
        );
      },
    );
