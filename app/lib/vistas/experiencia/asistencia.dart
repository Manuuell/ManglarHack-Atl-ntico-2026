import 'package:flutter/material.dart';

import '../../datos/estado.dart';
import '../../datos/experiencia/jornada.dart';
import '../../datos/experiencia/participacion.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas.dart';

/// Abre la hoja para registrar la asistencia. Devuelve true si quedó registrada.
Future<bool> abrirAsistencia(BuildContext context, EventoZanky evento, {AlmacenParticipacion? almacen}) async {
  final perfil = Zanky.leer(context).perfil;
  final ok = await mostrarHojaZ<bool>(
    context,
    nombre: 'evento_asistencia',
    contenido: (c) => HojaAsistencia(
      evento: evento,
      almacen: almacen ?? AlmacenParticipacion.instancia,
      nombreInicial: perfil?.nombre ?? '',
      grupoInicial: perfil?.colegio ?? '',
    ),
  );
  return ok ?? false;
}

class HojaAsistencia extends StatefulWidget {
  const HojaAsistencia({
    super.key,
    required this.evento,
    required this.almacen,
    this.nombreInicial = '',
    this.grupoInicial = '',
  });
  final EventoZanky evento;
  final AlmacenParticipacion almacen;
  final String nombreInicial, grupoInicial;

  @override
  State<HojaAsistencia> createState() => _HojaAsistenciaState();
}

class _HojaAsistenciaState extends State<HojaAsistencia> {
  late final _nombre = TextEditingController(text: widget.nombreInicial);
  late final _grupo = TextEditingController(text: widget.grupoInicial);
  bool _consiente = false;
  FaseBoton _fase = FaseBoton.reposo;
  bool _celebrando = false;
  bool _yaEstaba = false;
  bool _intento = false;

  bool get _valido => _nombre.text.trim().length >= 2 && _consiente;

  @override
  void dispose() {
    _nombre.dispose();
    _grupo.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_valido) {
      setState(() => _intento = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _fase = FaseBoton.cargando);
    final espera = Future<void>.delayed(const Duration(milliseconds: 650)); // que se vea que trabaja
    final nuevo = await widget.almacen.registrarAsistencia(
      evento: widget.evento,
      nombre: _nombre.text,
      grupo: _grupo.text,
    );
    await espera;
    if (!mounted) return;
    setState(() {
      _fase = FaseBoton.hecho;
      _yaEstaba = !nuevo;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _celebrando = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
      curve: Zm.entrar,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: sinMovimiento(context) ? Duration.zero : Zm.medio,
        switchInCurve: Zm.entrar,
        child: _celebrando ? _celebracion(context) : _formulario(context),
      ),
    );
  }

  Widget _celebracion(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('celebracion'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: ZankyMascota(tamano: 130, animo: Animo.celebrando)),
        const SizedBox(height: 8),
        Text(_yaEstaba ? 'Ya estabas registrado' : '¡Asistencia registrada!',
            textAlign: TextAlign.center, style: tt.headlineSmall),
        const SizedBox(height: 6),
        Text(
          _yaEstaba
              ? 'Tu asistencia a ${widget.evento.titulo} ya estaba guardada, así que no se suma dos veces.'
              : 'Sumaste ${AlmacenParticipacion.puntosAsistencia} puntos de participación. ¡Gracias por cuidar el manglar!',
          textAlign: TextAlign.center,
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 18),
        BotonEstado(texto: 'Listo', onTap: () => Navigator.of(context).pop(!_yaEstaba)),
      ],
    );
  }

  Widget _formulario(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final enCurso = _fase != FaseBoton.reposo;
    final falta = _intento && !_valido;
    return Column(
      key: const ValueKey('formulario'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Registrar mi asistencia', style: tt.titleLarge),
        const SizedBox(height: 4),
        Text(widget.evento.titulo, style: tt.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _nombre,
          enabled: !enCurso,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          maxLength: 60,
          onChanged: (_) => setState(() {}),
          decoration: _decoracion('Tu nombre', error: falta && _nombre.text.trim().length < 2 ? 'Escribe tu nombre' : null),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _grupo,
          enabled: !enCurso,
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
          decoration: _decoracion('Grupo o colegio (opcional)'),
        ),
        const SizedBox(height: 4),
        Semantics(
          container: true,
          checked: _consiente,
          label: 'Autorizo el tratamiento de mis datos, Ley 1581 de 2012',
          excludeSemantics: true,
          onTap: enCurso ? null : () => setState(() => _consiente = !_consiente),
          child: Presionable(
            onTap: enCurso ? null : () => setState(() => _consiente = !_consiente),
            escala: 0.99,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: Zm.corto,
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: BoxDecoration(
                      color: _consiente ? Zc.hoja : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: falta && !_consiente ? Zc.prioridad[5]! : Zc.hoja, width: 2),
                    ),
                    child: _consiente ? const Padding(padding: EdgeInsets.all(3), child: CheckDibujado(tamano: 18, grosor: 2.6)) : null,
                  ),
                  Expanded(
                    child: Text(
                      'Autorizo guardar mi nombre y mi grupo en este teléfono para registrar mi asistencia, '
                      'según la Ley 1581 de 2012 de protección de datos personales. Puedo borrarlos cuando quiera.',
                      style: tt.bodySmall?.copyWith(color: falta && !_consiente ? Zc.prioridad[5] : Zc.textoSuave),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        BotonEstado(
          texto: 'Registrar asistencia (+${AlmacenParticipacion.puntosAsistencia})',
          textoHecho: 'Registrada',
          icono: Icons.how_to_reg_rounded,
          fase: _fase,
          onTap: _registrar,
        ),
      ],
    );
  }

  InputDecoration _decoracion(String etiqueta, {String? error}) => InputDecoration(
        labelText: etiqueta,
        errorText: error,
        counterText: '',
        filled: true,
        fillColor: Zc.arena,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Zr.s), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
