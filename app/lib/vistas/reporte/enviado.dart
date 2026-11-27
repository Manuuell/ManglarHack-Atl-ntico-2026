import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/estado.dart';
import '../../datos/reporte.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/kit/celebracion.dart';
import '../../nucleo/kit/haptica.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';
import '../comun/comunes.dart';
import '../comun/zanky_mascota.dart';
import '../raiz.dart';

/// Qué decirle a la persona sobre dónde está su reporte. Separa los casos que antes se
/// confundían: sin red, el servidor falló, el servidor lo rechazó, en cola con red y
/// modo demostración. Solo habla de «señal» cuando de verdad no hay red.
(String, String, Color) textoEnvio({
  required Reporte r,
  required bool servidorConfigurado,
  required bool enLinea,
}) {
  const guardado = 'Guardado en tu teléfono';
  if (r.envio == Envio.enviado) {
    return ('¡Llegó a la CRA!', 'Cuando la CRA lo revise, lo verás en «Mis reportes».', Zc.hoja);
  }
  if (r.envio == Envio.enviando) {
    return ('Enviando…', 'Un momento: lo estoy subiendo con la foto.', Zc.cienaga);
  }
  if (r.envio == Envio.rechazado) {
    // Definitivo: se dice aunque no haya señal ahora (reintentar tal cual no lo arregla).
    return ('No se pudo enviar', r.motivoRechazo ?? 'El servidor no aceptó este reporte.', Zc.sol);
  }
  if (!servidorConfigurado) {
    return (guardado, 'Modo demostración: en la versión conectada se envía solo a la CRA.', Zc.textoSuave);
  }
  if (!enLinea) {
    return (
      guardado,
      'No hay señal ahora. Lo envío solo apenas vuelva, con la hora en que lo viste.',
      Zc.fango,
    );
  }
  if (r.envio == Envio.error) {
    final codigo = int.tryParse(RegExp(r'(\d{3})\)').firstMatch(r.ultimoError ?? '')?.group(1) ?? '');
    if (codigo != null && codigo >= 400 && codigo < 500) {
      return (guardado, 'El servidor no aceptó el reporte. Sigue guardado y lo reintento solo.', Zc.sol);
    }
    if (codigo != null) {
      return (guardado, 'El servidor falló. No se perdió nada: lo reintento solo.', Zc.sol);
    }
    return (guardado, 'No se pudo enviar todavía; lo reintento solo.', Zc.sol);
  }
  return (guardado, 'Hay señal: se envía en un momento.', Zc.cienaga);
}

/// Confirmación. Dice la verdad sobre dónde está el reporte (en el teléfono, enviándose
/// o ya en la CRA) y se actualiza sola cuando cambia.
class ReporteEnviado extends StatefulWidget {
  const ReporteEnviado({super.key, required this.reporteId});
  final String reporteId;

  @override
  State<ReporteEnviado> createState() => _ReporteEnviadoState();
}

class _ReporteEnviadoState extends State<ReporteEnviado> {
  /// El ✓ y el confeti arrancan cuando la pantalla ya se ve (la entrada es un fundido
  /// de [Zm.largo]); antes no se verían.
  bool _celebrando = false;
  Timer? _arranque;

  @override
  void initState() {
    super.initState();
    _arranque = Timer(Zm.corto, () {
      if (!mounted) return;
      setState(() => _celebrando = true);
      // Un solo ✓: el de esta pantalla. El overlay pone solo el confeti (conCheck: false).
      celebrar(context, etiqueta: 'Reporte guardado', conCheck: false);
    });
  }

  @override
  void dispose() {
    _arranque?.cancel();
    super.dispose();
  }

  void _verMisReportes() {
    final nav = Navigator.of(context);
    nav.pop();
    // La raíz queda debajo: se cambia a «Mis reportes».
    Raiz.irA(nav.context, 2);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final estado = Zanky.de(context);
    final r = estado.reportes.where((x) => x.id == widget.reporteId).firstOrNull;
    if (r == null) return const Scaffold(backgroundColor: Zc.arena);
    final (titulo, detalle, color) = textoEnvio(
        r: r, servidorConfigurado: estado.servidor.configurado, enLinea: estado.enLinea);
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Zc.arena,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Center(
                    child: SizedBox.square(
                      dimension: 108,
                      // El ✓ se dibuja una sola vez (el del kit); la vibración de éxito llega
                      // cuando el trazo termina.
                      child: _celebrando
                          ? CheckDibujado(tamano: 108, etiqueta: 'Reporte guardado', alTerminar: vibrarExito)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: Zm.medio,
                    child: Text(titulo, key: ValueKey(titulo), textAlign: TextAlign.center, style: tt.headlineMedium),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: Zm.medio,
                    child: Text(detalle,
                        key: ValueKey(detalle), textAlign: TextAlign.center, style: tt.bodyLarge?.copyWith(color: color)),
                  ),
                  const SizedBox(height: 22),
                  // Número de caso: grande, copiable, para decirlo por teléfono o WhatsApp.
                  Presionable(
                    etiqueta: 'Número de caso ${r.caso}. Toca para copiar',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: r.caso));
                      avisar(context, 'Copiado: ${r.caso}', tipo: TipoAviso.exito);
                    },
                    child: TarjetaZ(
                      child: Column(
                        children: [
                          Text('NÚMERO DE CASO', style: tt.labelSmall),
                          const SizedBox(height: 4),
                          Text(r.caso,
                              style: tt.displaySmall?.copyWith(letterSpacing: 2, fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ])),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              PildoraPrioridad(r.prioridad),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration:
                                    BoxDecoration(color: Zc.cienagaClara, borderRadius: BorderRadius.circular(99)),
                                child: Text(r.zonaNombre, style: tt.labelMedium?.copyWith(color: Zc.cienaga)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ChipEstado(r),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const ZankyMascota(tamano: 86, animo: Animo.celebrando),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BurbujaZanky(
                          texto: r.anonimo
                              ? '¡Gracias! Lo enviaste en anónimo: nadie sabrá que fuiste tú.'
                              : '¡Gracias, ${estado.perfil?.nombre.trim().split(' ').first.isNotEmpty == true ? estado.perfil!.nombre.trim().split(' ').first : 'guardián'}! Si la CRA lo verifica, sumas puntos.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, abajo + 16),
              child: Column(
                children: [
                  SizedBox(width: double.infinity, child: BotonZ(texto: 'Ver mis reportes', onTap: _verMisReportes)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: BotonZ(texto: 'Listo', secundario: true, onTap: () => Navigator.of(context).pop()),
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
