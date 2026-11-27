import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../datos/roles.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/tema.dart';
import '../comun/burbuja.dart';

/// Todo lo que la persona escribe o marca en la última página, en un solo lugar.
/// La cédula ya no se pide en la bienvenida (hoy no tiene ningún uso): es opcional en
/// «Editar mi perfil». Los límites de cédula viven aquí para que ambas pantallas usen los mismos.
class DatosPerfil extends ChangeNotifier {
  DatosPerfil({String nombre = '', String colegio = '', this.anonimo = false, this.rol = RolUsuario.ciudadano})
      : nombre = TextEditingController(text: nombre),
        colegio = TextEditingController(text: colegio);

  static const maxNombre = 60;
  static const maxColegio = 80;
  static const minCedula = 6;
  static const maxCedula = 10;

  final TextEditingController nombre;
  final TextEditingController colegio;
  final FocusNode focoNombre = FocusNode();
  final FocusNode focoColegio = FocusNode();

  bool anonimo;
  bool acepto = false;
  RolUsuario rol;

  void elegirRol(RolUsuario r) {
    if (r == rol) return;
    rol = r;
    notifyListeners();
  }

  /// Tras un intento fallido de enviar, todos los errores se muestran de una vez.
  bool forzar = false;
  String? errorGuardar;

  static String? validarNombre(String v) =>
      v.trim().length > maxNombre ? 'El nombre admite hasta $maxNombre letras.' : null;

  static String? validarColegio(String v) =>
      v.trim().length > maxColegio ? 'El colegio o grupo admite hasta $maxColegio letras.' : null;

  static String soloDigitos(String v) => v.replaceAll(RegExp(r'\D'), '');

  static String? validarCedula(String v) {
    final d = soloDigitos(v);
    if (d.isEmpty) return null;
    if (d.length < minCedula || d.length > maxCedula) {
      return 'La cédula tiene entre $minCedula y $maxCedula dígitos.';
    }
    return null;
  }

  bool get valido =>
      validarNombre(nombre.text) == null &&
      validarColegio(colegio.text) == null;

  void alternarAnonimo() {
    anonimo = !anonimo;
    notifyListeners();
  }

  void alternarAcepto() {
    acepto = !acepto;
    if (acepto) resaltarAcepto = false;
    notifyListeners();
  }

  /// Casilla de aceptación: el botón apagado la busca y la resalta para que se
  /// entienda por qué no deja empezar.
  final GlobalKey claveAcepto = GlobalKey();
  bool resaltarAcepto = false;

  void pedirAcepto() {
    resaltarAcepto = true;
    notifyListeners();
    final ctx = claveAcepto.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  void mostrarErrores() {
    forzar = true;
    notifyListeners();
    if (validarNombre(nombre.text) != null) {
      focoNombre.requestFocus();
    } else if (validarColegio(colegio.text) != null) {
      focoColegio.requestFocus();
    }
  }

  void ponerErrorGuardar(String? mensaje) {
    errorGuardar = mensaje;
    notifyListeners();
  }

  @override
  void dispose() {
    nombre.dispose();
    colegio.dispose();
    focoNombre.dispose();
    focoColegio.dispose();
    super.dispose();
  }
}

/// La última página: nombre, colegio, anonimato y aviso de privacidad.
class PaginaPerfil extends StatelessWidget {
  const PaginaPerfil({super.key, required this.datos, required this.burbuja});

  final DatosPerfil datos;
  final String burbuja;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: datos,
      builder: (context, _) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BurbujaZanky(texto: burbuja),
            const SizedBox(height: 20),
            Semantics(header: true, child: Text('¿Cómo te llamamos?', style: tema.headlineMedium)),
            const SizedBox(height: 8),
            Text(
              'Nombre y colegio son opcionales y se quedan en tu teléfono. Sin ellos eres un «Guardián del manglar» igual de valioso.',
              style: tema.bodyLarge?.copyWith(color: Zc.textoSuave),
            ),
            const SizedBox(height: 22),
            CampoZ(
              etiqueta: 'Nombre',
              icono: Icons.person_rounded,
              pista: 'Como quieres que te digan',
              controlador: datos.nombre,
              foco: datos.focoNombre,
              mayusculas: TextCapitalization.words,
              formateadores: [LengthLimitingTextInputFormatter(DatosPerfil.maxNombre)],
              validar: DatosPerfil.validarNombre,
              forzar: datos.forzar,
            ),
            const SizedBox(height: 16),
            CampoZ(
              etiqueta: 'Colegio o grupo',
              icono: Icons.school_rounded,
              pista: 'Tu colegio, PRAE o grupo ambiental',
              controlador: datos.colegio,
              foco: datos.focoColegio,
              mayusculas: TextCapitalization.words,
              formateadores: [LengthLimitingTextInputFormatter(DatosPerfil.maxColegio)],
              validar: DatosPerfil.validarColegio,
              forzar: datos.forzar,
            ),
            const SizedBox(height: 22),
            InterruptorZ(
              titulo: 'Reportar en anónimo por defecto',
              detalle: 'No se envía tu identificador de guardián con el reporte. Un reporte anónimo pesa un poco menos '
                  'en la confianza, pero protege tu identidad.',
              valor: datos.anonimo,
              alCambiar: datos.alternarAnonimo,
            ),
            const SizedBox(height: 16),
            const _AvisoPrivacidad(),
            const SizedBox(height: 16),
            AnimatedContainer(
              key: datos.claveAcepto,
              duration: context.resolveDuration(Zm.corto),
              curve: Zm.entrar,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Zr.m),
                border: Border.all(
                  color: datos.resaltarAcepto && !datos.acepto ? Zc.hoja : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CasillaZ(
                texto: 'Acepto el tratamiento de mis datos para el monitoreo del manglar',
                valor: datos.acepto,
                alCambiar: datos.alternarAcepto,
              ),
            ),
            AnimatedSize(
              duration: context.resolveDuration(Zm.corto),
              curve: Zm.entrar,
              alignment: Alignment.topCenter,
              child: datos.errorGuardar == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Zc.prioridad[5]!.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Zr.s),
                          ),
                          child: Text(
                            datos.errorGuardar!,
                            style: tema.bodyMedium?.copyWith(color: Zc.prioridad[5]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto con estilo propio: fondo blanco, borde suave y, al enfocar, el borde
/// se pinta de hoja con un resplandor. El error aparece debajo cuando la persona sale
/// del campo (o al intentar enviar), nunca mientras todavía escribe.
class CampoZ extends StatefulWidget {
  const CampoZ({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.controlador,
    required this.foco,
    this.pista,
    this.teclado = TextInputType.text,
    this.accion = TextInputAction.next,
    this.mayusculas = TextCapitalization.none,
    this.formateadores = const [],
    this.validar,
    this.forzar = false,
    this.ayuda,
    this.sensible = false,
  });

  final String etiqueta;
  final IconData icono;
  final TextEditingController controlador;
  final FocusNode foco;
  final String? pista;
  final TextInputType teclado;
  final TextInputAction accion;
  final TextCapitalization mayusculas;
  final List<TextInputFormatter> formateadores;
  final String? Function(String)? validar;
  final bool forzar;
  final String? ayuda;

  /// Sin corrector ni sugerencias (la cédula no debe quedar en el diccionario del teclado).
  final bool sensible;

  @override
  State<CampoZ> createState() => _CampoZState();
}

class _CampoZState extends State<CampoZ> {
  bool _tocado = false;
  bool _tuvoFoco = false;

  @override
  void initState() {
    super.initState();
    widget.foco.addListener(_alCambiarFoco);
  }

  @override
  void didUpdateWidget(CampoZ old) {
    super.didUpdateWidget(old);
    if (old.foco != widget.foco) {
      old.foco.removeListener(_alCambiarFoco);
      widget.foco.addListener(_alCambiarFoco);
    }
  }

  @override
  void dispose() {
    widget.foco.removeListener(_alCambiarFoco);
    super.dispose();
  }

  void _alCambiarFoco() {
    if (widget.foco.hasFocus) {
      _tuvoFoco = true;
    } else if (_tuvoFoco && !_tocado) {
      setState(() => _tocado = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final rojo = Zc.prioridad[5]!;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.foco, widget.controlador]),
      builder: (context, _) {
        final enfocado = widget.foco.hasFocus;
        final error = (_tocado || widget.forzar) ? widget.validar?.call(widget.controlador.text) : null;
        final borde = error != null ? rojo : (enfocado ? Zc.hoja : Zc.linea);
        final tinta = error != null ? rojo : (enfocado ? Zc.hoja : Zc.textoTenue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 7),
                child: Text.rich(
                  TextSpan(
                    text: widget.etiqueta,
                    style: tema.labelMedium?.copyWith(color: Zc.texto),
                    children: [
                      TextSpan(
                        text: '  opcional',
                        style: tema.bodySmall?.copyWith(color: Zc.textoTenue, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.foco.requestFocus,
              child: AnimatedContainer(
                duration: context.resolveDuration(Zm.corto),
                curve: Zm.entrar,
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Zr.m),
                  border: Border.all(color: borde, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: borde.withValues(alpha: enfocado || error != null ? 0.16 : 0),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: context.resolveDuration(Zm.corto),
                      child: Icon(widget.icono, key: ValueKey(tinta), size: 22, color: tinta),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: widget.etiqueta,
                        textField: true,
                        child: TextField(
                          controller: widget.controlador,
                          focusNode: widget.foco,
                          keyboardType: widget.teclado,
                          textInputAction: widget.accion,
                          textCapitalization: widget.mayusculas,
                          inputFormatters: widget.formateadores,
                          autocorrect: !widget.sensible,
                          enableSuggestions: !widget.sensible,
                          cursorColor: Zc.hoja,
                          cursorWidth: 2,
                          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                          style: tema.bodyLarge,
                          onTapOutside: (_) => widget.foco.unfocus(),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: widget.pista,
                            hintStyle: tema.bodyLarge?.copyWith(color: Zc.textoTenue),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: context.resolveDuration(Zm.corto),
              curve: Zm.entrar,
              alignment: Alignment.topCenter,
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_rounded, size: 16, color: rojo),
                            const SizedBox(width: 6),
                            Expanded(child: Text(error, style: tema.bodySmall?.copyWith(color: rojo))),
                          ],
                        ),
                      ),
                    ),
            ),
            if (widget.ayuda != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.lock_rounded, size: 14, color: Zc.textoTenue),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(widget.ayuda!, style: tema.bodySmall?.copyWith(fontSize: 12))),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Interruptor propio (píldora con perilla), con su explicación al lado.
class InterruptorZ extends StatelessWidget {
  const InterruptorZ({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.alCambiar,
  });

  final String titulo;
  final String detalle;
  final bool valor;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final dur = context.resolveDuration(Zm.corto);
    return Semantics(
      toggled: valor,
      label: titulo,
      hint: detalle,
      onTap: alCambiar,
      excludeSemantics: true,
      child: Presionable(
        escala: 0.985,
        onTap: alCambiar,
        child: AnimatedContainer(
          duration: dur,
          curve: Zm.entrar,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: valor ? Zc.hojaClara.withValues(alpha: 0.75) : Colors.white,
            borderRadius: BorderRadius.circular(Zr.m),
            border: Border.all(color: valor ? Zc.hoja.withValues(alpha: 0.5) : Zc.linea, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tema.titleMedium),
                    const SizedBox(height: 4),
                    Text(detalle, style: tema.bodySmall?.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedContainer(
                  duration: dur,
                  curve: Zm.entrar,
                  width: 54,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  alignment: valor ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: valor ? Zc.hoja : const Color(0xFFD9D4C8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1.5))],
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

/// Casilla propia: cuadro con borde que se llena de hoja y dibuja la palomita con un
/// pequeño rebote. Toda la fila se toca (más de 44 px).
class CasillaZ extends StatelessWidget {
  const CasillaZ({super.key, required this.texto, required this.valor, required this.alCambiar});

  final String texto;
  final bool valor;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final dur = context.resolveDuration(Zm.corto);
    return Semantics(
      checked: valor,
      label: texto,
      onTap: alCambiar,
      excludeSemantics: true,
      child: Presionable(
        escala: 0.985,
        onTap: alCambiar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AnimatedContainer(
                  duration: dur,
                  curve: Zm.entrar,
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: valor ? Zc.hoja : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: valor ? Zc.hoja : Zc.textoTenue, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: valor ? 1 : 0,
                    duration: context.resolveDuration(Zm.medio),
                    curve: AppMotion.emergente,
                    child: const Icon(Icons.check_rounded, size: 22, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(texto, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El aviso de privacidad (Ley 1581 de 2012) en tres viñetas.
class _AvisoPrivacidad extends StatelessWidget {
  const _AvisoPrivacidad();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return TarjetaZ(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, size: 22, color: Zc.hoja),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Tus datos, en claro', style: tema.titleMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text('Aviso de privacidad · Ley 1581 de 2012', style: tema.bodySmall),
          ),
          const SizedBox(height: 14),
          const _Vineta(
            icono: Icons.business_rounded,
            titulo: 'Responsable. ',
            texto: 'La entidad que opere Zanky. En el piloto, la Corporación Autónoma Regional del Atlántico (CRA).',
          ),
          const SizedBox(height: 12),
          const _Vineta(
            icono: Icons.folder_open_rounded,
            titulo: 'Qué se envía. ',
            texto: 'A la CRA llegan tus reportes (foto, ubicación exacta, hora y descripción) y, si no reportas en '
                'anónimo, un identificador al azar de tu teléfono. Tu nombre, tu colegio y tu cédula (si la pones) '
                'se quedan solo en este teléfono.',
          ),
          const SizedBox(height: 12),
          const _Vineta(
            icono: Icons.eco_rounded,
            titulo: 'Para qué. ',
            texto: 'Solo para verificar y atender las amenazas al manglar. Una IA revisa la foto (sin identificar personas) para ayudar a la CRA a confirmarla. No los vendemos ni los usamos para publicidad.',
          ),
          const SizedBox(height: 12),
          const _Vineta(
            icono: Icons.verified_user_rounded,
            titulo: 'Tus derechos. ',
            texto: 'Puedes borrar lo guardado en este teléfono cuando quieras: Guardián, Editar mi perfil, '
                '«Borrar mis datos de este teléfono». Para conocer, corregir o pedir que se borre lo que ya llegó a '
                'la CRA, escribe por los canales de atención de la CRA. Ley 1581 de 2012.',
          ),
        ],
      ),
    );
  }
}

class _Vineta extends StatelessWidget {
  const _Vineta({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: Zc.hojaClara, borderRadius: BorderRadius.circular(10)),
          child: Icon(icono, size: 18, color: Zc.hoja),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text.rich(
              TextSpan(
                text: titulo,
                style: tema.titleSmall?.copyWith(color: Zc.texto),
                children: [TextSpan(text: texto, style: tema.bodyMedium?.copyWith(fontSize: 14))],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
