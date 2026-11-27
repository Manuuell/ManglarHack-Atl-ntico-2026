import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/prioridad.dart';
import '../../datos/reporte_canal.dart';
import '../../datos/reporte.dart' show maxDescripcionServidor, recortarPuntosDeCodigo;
import '../../datos/tipos.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import 'borrador.dart';

/// Paso 4: detalles. Cada respuesta cambia la prioridad en vivo, con sus motivos a
/// la vista (pregunta 1 del reto: «¿con qué nivel de prioridad coincide?»).
class PasoDetalles extends StatefulWidget {
  const PasoDetalles({super.key, required this.borrador});
  final Borrador borrador;

  @override
  State<PasoDetalles> createState() => _PasoDetallesState();
}

class _PasoDetallesState extends State<PasoDetalles> {
  late final _texto = TextEditingController(text: widget.borrador.descripcion);
  final _foco = FocusNode();

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final b = widget.borrador;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _Titulo('¿Cuándo?'),
          _Segmentado<Momento>(
            valores: Momento.values,
            elegido: b.momento,
            texto: (m) => switch (m) {
              Momento.ahora => 'Ahora',
              Momento.hoy => 'Hoy',
              Momento.antes => 'Antes',
            },
            onCambio: (m) => b.cambiar(() => b.momento = m),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(b.momento.nombre, style: tt.bodySmall),
          ),
          const SizedBox(height: 18),
          _Titulo('¿Qué tan grande?'),
          Row(
            children: [
              for (final m in Magnitud.values) ...[
                if (m != Magnitud.values.first) const SizedBox(width: 8),
                Expanded(
                  child: _Opcion(
                    titulo: m.nombre,
                    detalle: m.ejemplo,
                    elegida: b.magnitud == m,
                    onTap: () => b.cambiar(() => b.magnitud = m),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _Titulo('Cuéntalo con tus palabras'),
          AnimatedBuilder(
            animation: _foco,
            builder: (_, _) => AnimatedContainer(
              duration: Zm.corto,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Zr.m),
                border: Border.all(color: _foco.hasFocus ? Zc.hoja : Zc.linea, width: _foco.hasFocus ? 2 : 1),
              ),
              child: TextField(
                controller: _texto,
                focusNode: _foco,
                minLines: 3,
                maxLines: 6,
                // El servidor cuenta puntos de código (un emoji de familia son 7): se corta igual.
                inputFormatters: const [LimitadorPuntosDeCodigo()],
                textCapitalization: TextCapitalization.sentences,
                onChanged: (t) => b.cambiar(() => b.descripcion = t),
                style: tt.bodyLarge,
                decoration: InputDecoration(
                  hintText: b.tipo?.pregunta ?? 'Qué viste, cuántos, hacia dónde va…',
                  hintStyle: tt.bodyLarge?.copyWith(color: Zc.textoTenue),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Interruptor(
            titulo: 'Reportar en anónimo',
            detalle: b.anonimo
                ? 'La CRA no sabrá quién eres. Pesa un poco menos en la confianza.'
                : 'Va con tu código de guardián, no con tu nombre. Ayuda a la CRA a confiar en el reporte.',
            valor: b.anonimo,
            onCambio: (v) => b.cambiar(() => b.anonimo = v),
          ),
          const SizedBox(height: 18),
          // Lo que pasa ahora y es de lo más grave (fuego, tala): primero la vida, como en el bot.
          AnimatedSize(
            duration: Zm.medio,
            curve: Zm.entrar,
            alignment: Alignment.topCenter,
            child: b.tipo != null && TextosCanal.pideEmergencia(b.tipo!, b.momento)
                ? const Padding(padding: EdgeInsets.only(bottom: 14), child: AvisoEmergencia())
                : const SizedBox(width: double.infinity),
          ),
          if (b.prioridad != null) _TarjetaPrioridad(prioridad: b.prioridad!, solidez: b.solidez.valor),
          if (b.tipo != null && b.ubicacion != null) ...[
            const SizedBox(height: 14),
            _Resumen(
              filas: TextosCanal.resumen(
                tipo: b.tipo!,
                dentro: b.ubicacion!.dentro,
                distanciaM: b.ubicacion!.distanciaM,
                zona: b.ubicacion!.zona.nombre,
                conFoto: b.foto != null,
                descripcion: b.descripcion,
                momento: b.momento,
                magnitud: b.magnitud,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// Segmentado propio: el fondo blanco se desliza con resorte hasta la opción elegida.
class _Segmentado<T> extends StatelessWidget {
  const _Segmentado({required this.valores, required this.elegido, required this.texto, required this.onCambio});
  final List<T> valores;
  final T elegido;
  final String Function(T) texto;
  final ValueChanged<T> onCambio;

  @override
  Widget build(BuildContext context) {
    final i = valores.indexOf(elegido);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE9E3D6), borderRadius: BorderRadius.circular(Zr.m)),
      child: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth / valores.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: Zm.medio,
              curve: Curves.easeOutBack,
              left: ancho * i,
              top: 0,
              bottom: 0,
              width: ancho,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Zr.s),
                  boxShadow: const [BoxShadow(color: Color(0x1A0B2E24), blurRadius: 8, offset: Offset(0, 2))],
                ),
              ),
            ),
            Row(
              children: [
                for (final v in valores)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: v == elegido,
                      label: texto(v),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (v == elegido) return;
                          vibrar(Vibracion.seleccion);
                          onCambio(v);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Zm.corto,
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                  color: v == elegido ? Zc.texto : Zc.textoSuave,
                                ),
                            child: Text(texto(v)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.titulo, required this.detalle, required this.elegida, required this.onTap});
  final String titulo;
  final String detalle;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Presionable(
      onTap: onTap,
      etiqueta: '$titulo, $detalle${elegida ? ', elegida' : ''}',
      child: AnimatedContainer(
        duration: Zm.corto,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: elegida ? Zc.hojaClara : Colors.white,
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: elegida ? Zc.hoja : Zc.linea, width: elegida ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(titulo, style: tt.labelLarge?.copyWith(color: elegida ? const Color(0xFF1E7A50) : Zc.texto)),
            const SizedBox(height: 2),
            Text(detalle, textAlign: TextAlign.center, style: tt.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.titulo, required this.detalle, required this.valor, required this.onCambio});
  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      toggled: valor,
      label: titulo,
      child: Presionable(
        escala: 0.99,
        onTap: () => onCambio(!valor),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Zr.m)),
          child: Row(
            children: [
              Icon(valor ? Icons.visibility_off_rounded : Icons.person_rounded, color: Zc.textoSuave),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Zm.corto,
                      child: Text(detalle, key: ValueKey(valor), style: tt.bodySmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Interruptor estilo iOS: perilla que se desliza con rebote corto.
              AnimatedContainer(
                duration: Zm.medio,
                width: 50,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: valor ? Zc.hoja : const Color(0xFFD9D4C8),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: AnimatedAlign(
                  duration: Zm.medio,
                  curve: Curves.easeOutBack,
                  alignment: valor ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x330B2E24), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Revisa tu reporte»: el mismo resumen que el bot muestra antes de «Enviar», fila por
/// fila. Cada valor se cruza con un fundido cuando la persona cambia una respuesta.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.filas});
  final List<(String, String)> filas;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Revisa tu reporte',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Zr.l),
          border: Border.all(color: Zc.linea),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REVISA TU REPORTE', style: tt.seccion),
            const SizedBox(height: 6),
            for (final (i, (k, v)) in filas.indexed) ...[
              if (i > 0) const Divider(height: 1, color: Zc.linea),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 92, child: Text(k, style: tt.labelMedium?.copyWith(color: Zc.textoSuave))),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Zm.corto,
                        layoutBuilder: (actual, previos) =>
                            Stack(alignment: Alignment.topLeft, children: [...previos, ?actual]),
                        child: Text(v, key: ValueKey(v), style: tt.bodyMedium?.copyWith(color: Zc.texto)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Recordatorio de la línea de emergencias (123), con el texto del bot.
class AvisoEmergencia extends StatelessWidget {
  const AvisoEmergencia({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(Zc.dePrioridad(5).withValues(alpha: 0.08), Colors.white),
          borderRadius: BorderRadius.circular(Zr.m),
          border: Border.all(color: Zc.dePrioridad(5).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Zc.dePrioridad(5), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('No te arriesgues. ${TextosCanal.emergencia}',
                  style: tt.bodyMedium?.copyWith(color: Zc.texto)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPrioridad extends StatelessWidget {
  const _TarjetaPrioridad({required this.prioridad, required this.solidez});
  final Prioridad prioridad;
  final int solidez;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = Zc.dePrioridad(prioridad.valor);
    return AnimatedContainer(
      duration: Zm.medio,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.08), Colors.white),
        borderRadius: BorderRadius.circular(Zr.l),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cinco barras que se llenan hasta la prioridad: se lee sin conocer la escala.
              for (var i = 1; i <= 5; i++)
                AnimatedContainer(
                  duration: Duration(milliseconds: 160 + i * 40),
                  margin: const EdgeInsets.only(right: 4),
                  width: 9,
                  height: 8.0 + i * 4,
                  decoration: BoxDecoration(
                    color: i <= prioridad.valor ? c : Zc.linea,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Zm.corto,
                  child: Text('Prioridad ${prioridad.nombre}',
                      key: ValueKey(prioridad.valor), style: tt.titleMedium?.copyWith(color: Color.lerp(c, Zc.texto, 0.3))),
                ),
              ),
              Text('Solidez $solidez', style: tt.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final m in prioridad.motivos)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m, style: tt.bodySmall?.copyWith(color: Zc.texto))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Es una estimación: la CRA la confirma al revisar.',
              style: tt.bodySmall?.copyWith(fontSize: 11.5, color: Zc.textoTenue)),
        ],
      ),
    );
  }
}

/// Corta el texto a [maximo] puntos de código (no letras visibles ni unidades UTF-16),
/// como lo cuenta el servidor, sin partir un par sustituto.
class LimitadorPuntosDeCodigo extends TextInputFormatter {
  const LimitadorPuntosDeCodigo([this.maximo = maxDescripcionServidor]);
  final int maximo;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    if (nuevo.text.runes.length <= maximo) return nuevo;
    final texto = recortarPuntosDeCodigo(nuevo.text, maximo);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
