import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';

/// Abre la hoja para editar nombre, colegio, cédula (opcional) y anonimato.
Future<void> mostrarEditarPerfil(BuildContext context) {
  return mostrarHojaZ<void>(
    context,
    nombre: 'editar_perfil',
    contenido: (_) => const _FormularioPerfil(),
  );
}

class _FormularioPerfil extends StatefulWidget {
  const _FormularioPerfil();

  @override
  State<_FormularioPerfil> createState() => _FormularioPerfilState();
}

class _FormularioPerfilState extends State<_FormularioPerfil> {
  late final TextEditingController _nombre;
  late final TextEditingController _colegio;
  final _cedula = TextEditingController();
  late bool _anonimo;
  late bool _vinculada;
  String? _errorCedula;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = Zanky.leer(context).perfil;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _colegio = TextEditingController(text: p?.colegio ?? '');
    _anonimo = p?.anonimoPorDefecto ?? false;
    _vinculada = p?.cedulaHash != null;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _colegio.dispose();
    _cedula.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final texto = _cedula.text.trim();
    String? huella;
    if (texto.isNotEmpty) {
      final digitos = texto.replaceAll(RegExp(r'\D'), '');
      if (digitos.length < 5 || digitos.length > 12) {
        setState(() => _errorCedula = 'Revisa el número: debe tener entre 5 y 12 dígitos.');
        vibrar(Vibracion.fuerte);
        return;
      }
      huella = Perfil.huellaCedula(digitos);
    }
    setState(() => _guardando = true);
    final estado = Zanky.leer(context);
    final p = estado.perfil ?? estado.perfilNuevo();
    p
      ..nombre = _nombre.text.trim()
      ..colegio = _colegio.text.trim()
      ..anonimoPorDefecto = _anonimo;
    if (huella != null) {
      p.cedulaHash = huella;
    } else if (!_vinculada) {
      p.cedulaHash = null;
    }
    await estado.guardarPerfil(p);
    if (!mounted) return;
    vibrar(Vibracion.ligera);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mi perfil de guardián', style: tt.headlineSmall),
        const SizedBox(height: 4),
        Text('Todo se guarda solo en este teléfono. Nada es obligatorio.', style: tt.bodyMedium),
        const SizedBox(height: 18),
        _Campo(
          controlador: _nombre,
          etiqueta: 'Tu nombre',
          ayuda: 'Es el que sale en tu tarjeta.',
          maximo: 40,
          capitalizar: TextCapitalization.words,
          icono: Icons.person_rounded,
        ),
        const SizedBox(height: 12),
        _Campo(
          controlador: _colegio,
          etiqueta: 'Tu colegio (si estudias)',
          ayuda: 'Para tu servicio social y el ranking de colegios.',
          maximo: 60,
          capitalizar: TextCapitalization.words,
          icono: Icons.school_rounded,
        ),
        const SizedBox(height: 12),
        if (_vinculada)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(color: Zc.hojaClara, borderRadius: BorderRadius.circular(Zr.m)),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Zc.hoja, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('Cédula vinculada ✓', style: tt.titleSmall)),
                Presionable(
                  etiqueta: 'Desvincular mi cédula',
                  onTap: () => setState(() => _vinculada = false),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Desvincular', style: tt.labelMedium?.copyWith(color: Zc.prioridad[5])),
                  ),
                ),
              ],
            ),
          )
        else
          _Campo(
            controlador: _cedula,
            etiqueta: 'Cédula (opcional)',
            ayuda: 'No se guarda tu número: solo una huella que permite reconocerte en la app y en WhatsApp.',
            maximo: 12,
            teclado: TextInputType.number,
            filtro: FilteringTextInputFormatter.digitsOnly,
            error: _errorCedula,
            icono: Icons.badge_rounded,
            alCambiar: () {
              if (_errorCedula != null) setState(() => _errorCedula = null);
            },
          ),
        const SizedBox(height: 14),
        Presionable(
          etiqueta: 'Reportar de forma anónima por defecto',
          escala: 0.99,
          onTap: () => setState(() => _anonimo = !_anonimo),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Zc.arena, borderRadius: BorderRadius.circular(Zr.m)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reportar en anónimo', style: tt.titleSmall),
                      const SizedBox(height: 2),
                      Text('Tu nombre no viaja con tus reportes. Pesan un poco menos, pero te protegen.',
                          style: tt.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IgnorePointer(
                  child: Switch(
                    value: _anonimo,
                    onChanged: (_) {},
                    activeTrackColor: Zc.hoja,
                    activeThumbColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        BotonZ(texto: 'Guardar', cargando: _guardando, onTap: _guardar),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.ayuda,
    required this.maximo,
    required this.icono,
    this.capitalizar = TextCapitalization.none,
    this.teclado,
    this.filtro,
    this.error,
    this.alCambiar,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final String ayuda;
  final int maximo;
  final IconData icono;
  final TextCapitalization capitalizar;
  final TextInputType? teclado;
  final TextInputFormatter? filtro;
  final String? error;
  final VoidCallback? alCambiar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    OutlineInputBorder borde(Color c, [double ancho = 0]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Zr.m),
          borderSide: ancho == 0 ? BorderSide.none : BorderSide(color: c, width: ancho),
        );
    return TextField(
      controller: controlador,
      textCapitalization: capitalizar,
      keyboardType: teclado,
      inputFormatters: [LengthLimitingTextInputFormatter(maximo), ?filtro],
      style: tt.bodyLarge,
      cursorColor: Zc.hoja,
      onChanged: alCambiar == null ? null : (_) => alCambiar!(),
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 3,
        errorText: error,
        errorMaxLines: 2,
        prefixIcon: Icon(icono, color: Zc.textoSuave, size: 22),
        filled: true,
        fillColor: Zc.arena,
        floatingLabelStyle: tt.labelMedium?.copyWith(color: Zc.hoja),
        labelStyle: tt.bodyMedium,
        helperStyle: tt.bodySmall,
        border: borde(Zc.hoja),
        enabledBorder: borde(Zc.hoja),
        focusedBorder: borde(Zc.hoja, 2),
        errorBorder: borde(Zc.prioridad[5]!, 2),
        focusedErrorBorder: borde(Zc.prioridad[5]!, 2),
      ),
    );
  }
}
