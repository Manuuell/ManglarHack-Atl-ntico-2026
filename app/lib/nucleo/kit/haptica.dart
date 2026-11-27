/// Gramática háptica del kit: una sola respuesta por tipo de evento, sobre el
/// `vibrar` de `presionable.dart` (que ya calla en la web).
///
/// | Evento | Respuesta |
/// |---|---|
/// | Tocar un botón | `Vibracion.ligera` (lo hace `Presionable`) |
/// | Elegir (segmento, casilla, interruptor, paso) | `Vibracion.seleccion` |
/// | Abrir algo que pide decidir (hoja de confirmar) | `Vibracion.media` |
/// | Éxito (✓ aterriza, celebración) | [vibrarExito] |
/// | Aviso | [vibrarAviso] |
/// | Error (sacudida) | [vibrarError] |
///
/// Flutter solo ofrece cinco golpes (selección, ligero, medio, fuerte y el
/// zumbido largo de Android), así que éxito/aviso/error se distinguen por
/// intensidad: aviso suave, éxito medio, error fuerte.
library;

import '../presionable.dart';

/// Éxito: el ✓ acaba de aterrizar.
void vibrarExito() => vibrar(Vibracion.media);

/// Aviso: algo a medias o que conviene mirar.
void vibrarAviso() => vibrar(Vibracion.ligera);

/// Error: algo no salió (va con la sacudida).
void vibrarError() => vibrar(Vibracion.fuerte);
