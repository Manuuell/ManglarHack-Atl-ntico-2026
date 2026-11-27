import 'package:flutter/material.dart';

import '../../datos/experiencia/entrada_evento.dart' hide EntradaEvento;
import '../../datos/experiencia/participacion.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas.dart';
import 'puerta_evento.dart';

/// Tarjeta para Inicio: entrada manual al modo evento (por si el QR no abrió la app) o regreso al último.
/// Alto aproximado: 92 px con letra normal (crece con la letra grande). Ancho: el que le dé el padre.
class EntradaEvento extends StatelessWidget {
  const EntradaEvento({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: entradaEvento,
      builder: (context, actual, _) => Presionable(
        onTap: () => actual != null ? abrirEvento(context, actual.codigo) : _pedirCodigo(context),
        etiqueta: actual != null ? 'Volver al evento ${actual.codigo}' : 'Entrar a un evento con Zanky',
        escala: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Zc.cienagaClara,
            borderRadius: BorderRadius.circular(Zr.l),
            border: Border.all(color: Zc.cienaga.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const ExcludeSemantics(child: ZankyMascota(tamano: 56, animo: Animo.curioso)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actual != null ? 'Tu evento sigue abierto' : '¿Estás en una jornada?', style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      actual != null
                          ? 'Toca para volver a «${actual.codigo}».'
                          : 'Escribe el código del cartel y entra al modo evento con Zanky.',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Zc.cienaga),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _pedirCodigo(BuildContext context) {
    return mostrarHojaZ<void>(
      context,
      nombre: 'evento_codigo',
      contenido: (c) => _HojaCodigo(alEntrar: (codigo) {
        Navigator.of(c).pop();
        abrirEvento(context, codigo);
      }),
    );
  }
}

class _HojaCodigo extends StatefulWidget {
  const _HojaCodigo({required this.alEntrar});
  final void Function(String codigo) alEntrar;
  @override
  State<_HojaCodigo> createState() => _HojaCodigoState();
}

class _HojaCodigoState extends State<_HojaCodigo> {
  final _c = TextEditingController();
  bool _mal = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _entrar() {
    // Acepta el código pelado o el enlace completo del QR.
    final crudo = _c.text.trim();
    final deEnlace = leerEntradaEvento(Uri.tryParse(crudo) ?? Uri());
    final codigo = deEnlace?.codigo ?? codigoEventoValido(crudo);
    if (codigo == null) {
      setState(() => _mal = true);
      return;
    }
    widget.alEntrar(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Código del evento', style: tt.titleLarge),
        const SizedBox(height: 4),
        Text('Está en el cartel o en el enlace del QR, por ejemplo jornada-1.', style: tt.bodyMedium),
        const SizedBox(height: 14),
        TextField(
          controller: _c,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _entrar(),
          onChanged: (_) => _mal ? setState(() => _mal = false) : null,
          decoration: InputDecoration(
            labelText: 'Código o enlace',
            errorText: _mal ? 'Solo letras, números, guion y guion bajo' : null,
            filled: true,
            fillColor: Zc.arena,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Zr.s), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        BotonEstado(texto: 'Entrar', icono: Icons.login_rounded, onTap: _entrar),
      ],
    );
  }
}

/// Resumen de participación para la pantalla de Guardián: puntos y eventos, aparte de los de reportes.
/// Alto aproximado: 88 px sin eventos y 88 + 36 px por evento mostrado (hasta 3), con letra normal.
class ResumenParticipacion extends StatefulWidget {
  const ResumenParticipacion({super.key, this.almacen});
  final AlmacenParticipacion? almacen;

  @override
  State<ResumenParticipacion> createState() => _ResumenParticipacionState();
}

class _ResumenParticipacionState extends State<ResumenParticipacion> {
  late final AlmacenParticipacion _a = widget.almacen ?? AlmacenParticipacion.instancia;

  @override
  void initState() {
    super.initState();
    _a.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _a,
      builder: (context, _) {
        final lista = _a.asistencias.take(3).toList();
        return Semantics(
          container: true,
          label: 'Participación en eventos: ${_a.puntos} puntos en ${_a.eventos} eventos',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Zc.superficie,
              borderRadius: BorderRadius.circular(Zr.l),
              border: Border.all(color: Zc.linea.withValues(alpha: 0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Zc.sol, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Participación en eventos', style: tt.titleSmall),
                          Text(
                            _a.eventos == 0
                                ? 'Aún no participas en un evento. Escanea el QR de una jornada.'
                                : '${_a.puntos} puntos · ${_a.eventos} ${_a.eventos == 1 ? 'evento' : 'eventos'}',
                            style: tt.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                for (final x in lista)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Zc.hoja, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(x.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
