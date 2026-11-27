import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Le dice algo al lector de pantalla (TalkBack / VoiceOver) sin mover el
/// foco: los avisos que aparecen y se van solos lo necesitan, porque nadie
/// los enfoca. Sin lector activo no hace nada visible.
///
/// ```dart
/// anunciar(context, 'Reporte enviado');
/// ```
void anunciar(BuildContext context, String mensaje) {
  final vista = View.maybeOf(context);
  if (vista == null) return;
  SemanticsService.sendAnnouncement(vista, mensaje, Directionality.of(context));
}
