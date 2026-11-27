import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/estado.dart';
import '../../datos/guardian.dart';
import '../../nucleo/base/hoja.dart';
import '../../nucleo/kit/interruptor.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../bienvenida/formulario.dart' show DatosPerfil;
import 'borrar_datos.dart';

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
  String? _errorNombre;
  String? _errorColegio;
  String? _errorCedula;
  String? _errorGuardar;
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

  /// Mismos límites y validación que la bienvenida (DatosPerfil). Nada se recorta en
  /// silencio: si algo no cumple, se dice cuál campo y por qué.
  Future<void> _guardar() async {
    if (_guardando) return;
    final errNombre = DatosPerfil.validarNombre(_nombre.text);
    final errColegio = DatosPerfil.validarColegio(_colegio.text);
    final errCedula = _vinculada ? null : DatosPerfil.validarCedula(_cedula.text);
    if (errNombre != null || errColegio != null || errCedula != null) {
      setState(() {
        _errorNombre = errNombre;
        _errorColegio = errColegio;
        _errorCedula = errCedula;
        _errorGuardar = null;
      });
      vibrar(Vibracion.fuerte);
      return;
    }
    setState(() {
      _guardando = true;
      _errorGuardar = null;
    });
    final estado = Zanky.leer(context);
    try {
      final base = estado.perfil ?? estado.perfilNuevo();
      final digitos = DatosPerfil.soloDigitos(_cedula.text);
      // Se arma un perfil nuevo con el mismo id y la misma sal: si guardar falla, el
      // que está en memoria no cambia sin estar en el disco.
      final nuevo = Perfil(
        id: base.id,
        creado: base.creado,
        sal: base.sal,
        consentimiento: base.consentimiento,
        nombre: _nombre.text.trim(),
        colegio: _colegio.text.trim(),
        anonimoPorDefecto: _anonimo,
        rol: base.rol,
        cedulaHash: !_vinculada && digitos.isNotEmpty
            ? base.huellaCedula(digitos)
            : (_vinculada ? base.cedulaHash : null),
      );
      await estado.guardarPerfil(nuevo);
    } catch (_) {
      if (!mounted) return;
      vibrar(Vibracion.fuerte);
      setState(() {
        _guardando = false;
        _errorGuardar = 'No pudimos guardar tu perfil. Revisa que tu teléfono tenga espacio y vuelve a intentarlo.';
      });
      return;
    }
    if (!mounted) return;
    vibrar(Vibracion.ligera);
    Navigator.of(context).pop();
  }

  Future<void> _borrar() async {
    final navegador = Navigator.of(context);
    final borrado = await confirmarYBorrarDatos(context);
    if (borrado && mounted) navegador.pop();
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
        Text('Tu nombre, tu colegio y tu cédula se quedan solo en este teléfono. Nada es obligatorio.',
            style: tt.bodyMedium),
        const SizedBox(height: 18),
        _Campo(
          controlador: _nombre,
          etiqueta: 'Tu nombre',
          ayuda: 'Es el que sale en tu tarjeta.',
          maximo: DatosPerfil.maxNombre,
          capitalizar: TextCapitalization.words,
          icono: Icons.person_rounded,
          error: _errorNombre,
          alCambiar: () {
            if (_errorNombre != null) setState(() => _errorNombre = null);
          },
        ),
        const SizedBox(height: 12),
        _Campo(
          controlador: _colegio,
          etiqueta: 'Tu colegio (si estudias)',
          ayuda: 'Para tu servicio social y el ranking de colegios.',
          maximo: DatosPerfil.maxColegio,
          capitalizar: TextCapitalization.words,
          icono: Icons.school_rounded,
          error: _errorColegio,
          alCambiar: () {
            if (_errorColegio != null) setState(() => _errorColegio = null);
          },
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
                Expanded(child: Text('Cédula guardada en este teléfono ✓', style: tt.titleSmall)),
                Presionable(
                  etiqueta: 'Quitar mi cédula',
                  onTap: () => setState(() => _vinculada = false),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Quitar', style: tt.labelMedium?.copyWith(color: Zc.prioridad[5])),
                  ),
                ),
              ],
            ),
          )
        else
          _Campo(
            controlador: _cedula,
            etiqueta: 'Cédula (opcional)',
            ayuda: 'Se guarda solo en este teléfono, como una huella (nunca tu número). Hoy no se envía a nadie: '
                'servirá, cuando exista, para que la CRA enlace tu WhatsApp con tu perfil.',
            maximo: DatosPerfil.maxCedula,
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
                      Text('No se envía tu identificador de guardián con el reporte. Pesan un poco menos, pero te protegen.',
                          style: tt.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // El toque lo recibe la fila entera (arriba); el interruptor solo se mueve.
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: InterruptorIos(valor: _anonimo, alCambiar: (_) {}),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorGuardar != null) ...[
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(_errorGuardar!, style: tt.bodyMedium?.copyWith(color: Zc.prioridad[5])),
          ),
        ],
        const SizedBox(height: 20),
        BotonZ(texto: 'Guardar', cargando: _guardando, onTap: _guardar),
        if (Zanky.leer(context).perfil != null) ...[
          const SizedBox(height: 10),
          BotonZ(
            texto: 'Borrar mis datos de este teléfono',
            icono: Icons.delete_outline_rounded,
            secundario: true,
            color: Zc.prioridad[5]!,
            onTap: _guardando ? null : _borrar,
          ),
        ],
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
