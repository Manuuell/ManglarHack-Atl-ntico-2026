/// Confirmar en una hoja de abajo (no un diálogo) y, si hace falta, dejar
/// **Deshacer** en un aviso después.
///
/// - [confirmarEnHoja]: pregunta, devuelve `true` solo si se confirmó. Vibra
///   al abrir (pide decidir). El botón de cancelar es el principal visual
///   cuando la acción destruye algo: lo seguro queda a mano.
/// - [accionConDeshacer]: confirma, hace la acción y deja un aviso con
///   «Deshacer» durante [AppMotion.plazoDeshacer]. Si se toca, llama a
///   [deshacer].
library;

import 'package:flutter/material.dart';

import '../base/hoja.dart';
import '../presionable.dart';
import '../tema.dart';
import '../../vistas/comun/zanky_mascota.dart';
import 'aviso.dart';

Future<bool> confirmarEnHoja(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String textoConfirmar,
  String textoCancelar = 'Cancelar',
  bool destructivo = false,
  bool seguroPrimero = false,
  Animo animo = Animo.preocupado,
}) async {
  vibrar(Vibracion.media);
  final r = await mostrarHojaZ<bool>(
    context,
    nombre: 'Confirmar',
    contenido: (ctx) => _ContenidoConfirmar(
      titulo: titulo,
      texto: texto,
      textoConfirmar: textoConfirmar,
      textoCancelar: textoCancelar,
      destructivo: destructivo,
      seguroPrimero: seguroPrimero,
      animo: animo,
    ),
  );
  return r ?? false;
}

/// Confirma, ejecuta [hacer] y ofrece «Deshacer» ([deshacer]) en un aviso.
/// Devuelve si la acción se hizo.
Future<bool> accionConDeshacer(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String textoConfirmar,
  required String avisoHecho,
  required Future<void> Function() hacer,
  required Future<void> Function() deshacer,
  String textoDeshacer = 'Deshacer',
  bool confirmar = true,
}) async {
  if (confirmar) {
    final ok = await confirmarEnHoja(
      context,
      titulo: titulo,
      texto: texto,
      textoConfirmar: textoConfirmar,
      destructivo: true,
    );
    if (!ok || !context.mounted) return false;
  }
  // La acción cambia lo visible al instante; el aviso no espera a que termine de guardarse.
  final hecho = hacer();
  if (context.mounted) {
    avisar(
      context,
      avisoHecho,
      accion: AccionAviso(textoDeshacer, () => deshacer()),
    );
  }
  await hecho;
  return true;
}

class _ContenidoConfirmar extends StatelessWidget {
  const _ContenidoConfirmar({
    required this.titulo,
    required this.texto,
    required this.textoConfirmar,
    required this.textoCancelar,
    required this.destructivo,
    required this.seguroPrimero,
    required this.animo,
  });
  final String titulo;
  final String texto;
  final String textoConfirmar;
  final String textoCancelar;
  final bool destructivo;

  /// `true`: lo seguro (cancelar) es el botón principal y lo que destruye va
  /// debajo, en rojo y más discreto. Para lo que se pierde de verdad.
  final bool seguroPrimero;
  final Animo animo;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final rojo = Zc.dePrioridad(5);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZankyMascota(tamano: 76, animo: animo),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(titulo, style: tt.titleLarge, textAlign: TextAlign.center)),
        const SizedBox(height: 6),
        Text(texto, style: tt.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (seguroPrimero) ...[
          BotonZ(texto: textoCancelar, onTap: () => Navigator.pop(context, false)),
          const SizedBox(height: 8),
          BotonZ(
            texto: textoConfirmar,
            secundario: true,
            color: rojo,
            onTap: () => Navigator.pop(context, true),
          ),
        ] else ...[
          BotonZ(
            texto: textoConfirmar,
            color: destructivo ? rojo : Zc.hoja,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          BotonZ(
            texto: textoCancelar,
            secundario: true,
            color: destructivo ? Zc.hoja : Zc.textoSuave,
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ],
    );
  }
}
