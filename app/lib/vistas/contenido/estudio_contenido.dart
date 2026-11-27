import 'dart:convert';

import 'package:flutter/material.dart';

import '../../nucleo/base/movimiento.dart';
import '../../nucleo/tema.dart';
import 'bloques_contenido.dart';
import 'modelo_contenido.dart';

/// Estado del editor: el borrador que se toca, lo último guardado y si hay
/// cambios sin guardar.
///
/// Portado de `useBrandDraft` / `BrandDraftProvider` (FastFood
/// `src/components/admin/brand-studio.tsx`): una sola fuente de lo que se
/// está editando, SIN guardar, que alimenta la vista previa en vivo.
class EstudioContenido extends ChangeNotifier {
  EstudioContenido(DocumentoContenido inicial)
      : _guardado = inicial, borrador = BorradorContenido(inicial);

  final BorradorContenido borrador;
  DocumentoContenido _guardado;

  DocumentoContenido get actual => borrador.actual;
  DocumentoContenido get guardado => _guardado;

  static String _huella(DocumentoContenido d) =>
      jsonEncode(d.bloques.map((b) => b.toJson()).toList());

  /// Hay cambios sin guardar (la barra de guardado aparece con este dato).
  bool get sucio => _huella(actual) != _huella(_guardado);

  void cargar(DocumentoContenido d) {
    _guardado = d;
    borrador.guardado(d);
    notifyListeners();
  }

  void alGuardar(DocumentoContenido d) => cargar(d);

  /// Descartar: vuelve a lo último guardado.
  void descartar() => cargar(_guardado);

  void cambio(void Function(BorradorContenido b) f) {
    f(borrador);
    notifyListeners();
  }

  void deshacer() => cambio((b) => b.deshacer());
}

/// Lo que ve quien edita: el estudio se lee con [EnVivoContenido.de].
class EnVivoContenido extends InheritedNotifier<EstudioContenido> {
  const EnVivoContenido({super.key, required EstudioContenido estudio, required super.child})
      : super(notifier: estudio);

  static EstudioContenido? maybeDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EnVivoContenido>()?.notifier;
}

/// Vista previa en vivo dentro de un marco de celular. Portado de
/// `BrandPreviewStage` (FastFood `brand-preview-stage.tsx`): se ve lo que
/// verá el ciudadano mientras se toca, sin guardar.
class VistaPreviaContenido extends StatelessWidget {
  const VistaPreviaContenido({super.key});

  @override
  Widget build(BuildContext context) {
    final estudio = EnVivoContenido.maybeDe(context);
    final bloques = estudio?.actual.bloques ?? const <Bloque>[];
    final visibles = bloques.where((b) => !b.oculto).length;
    return Semantics(
      container: true,
      label: 'Vista previa en vivo: $visibles bloques visibles',
      child: Center(child: Container(
        width: 320, constraints: const BoxConstraints(minHeight: 320),
        margin: const EdgeInsets.symmetric(vertical: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
          border: Border.all(color: Zc.raiz, width: 6), borderRadius: BorderRadius.circular(34)),
        child: bloques.isEmpty
          ? const Center(child: Text('Aún no hay bloques. Agrega uno para verlo aquí.',
              textAlign: TextAlign.center))
          : AnimatedSwitcher(duration: AppMotion.fast,
              child: PintarBloques(key: ValueKey(bloques.hashCode ^ visibles), bloques: bloques, previa: true)),
      )),
    );
  }
}

/// Barra de guardado fija abajo. Portada de `SettingsSaveBar` (FastFood
/// `settings-save-bar.tsx`): «Tienes cambios sin guardar · Descartar ·
/// Guardar», confirma con «Guardado» y no ocupa lugar de más.
class BarraGuardado extends StatelessWidget {
  const BarraGuardado({super.key, required this.sucio, required this.guardando,
    required this.mensaje, required this.error, required this.alDescartar,
    required this.alGuardar, required this.alPublicar});
  final bool sucio, guardando, error;
  final String? mensaje;
  final VoidCallback alDescartar;
  final Future<void> Function() alGuardar, alPublicar;

  @override
  Widget build(BuildContext context) {
    final estado = error ? (mensaje ?? 'No se pudo guardar')
      : sucio ? 'Tienes cambios sin guardar'
      : (mensaje ?? 'Todo guardado');
    final color = error ? Zc.prioridad[5]! : sucio ? Zc.sol : Zc.hoja;
    return Material(color: Colors.white, elevation: 8, child: SafeArea(top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(liveRegion: true, container: true, child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Row(key: ValueKey(estado), children: [
              Icon(error ? Icons.error_outline : sucio ? Icons.circle : Icons.check_circle_outline,
                size: sucio && !error ? 10 : 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(estado, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: error ? color : Zc.texto, fontWeight: FontWeight.w600))),
            ]),
          )),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
            if (sucio && !guardando) OutlinedButton(onPressed: alDescartar,
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Descartar')),
            SizedBox(height: 44, child: OutlinedButton(
              onPressed: guardando || !sucio ? null : () { alGuardar().catchError((_) {}); },
              child: const Text('Guardar borrador'))),
            SizedBox(height: 44, child: FilledButton(
              onPressed: guardando ? null : () { alPublicar().catchError((_) {}); },
              child: Text(guardando ? 'Guardando…' : 'Publicar'))),
          ]),
        ])),
    ));
  }
}
