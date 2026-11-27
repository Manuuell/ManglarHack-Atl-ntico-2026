import 'package:flutter/material.dart';

import '../../datos/admin/controlador_admin.dart';
import '../../datos/admin/repositorio_admin.dart';
import '../../nucleo/base/movimiento.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/kit/boton_estado.dart';
import '../../nucleo/identidad.dart';
import '../../nucleo/tema.dart';
import '../comun/zanky_mascota.dart';
import 'piezas_admin.dart';

/// La puerta del panel: correo y contraseña de la cuenta del equipo (Supabase Auth).
/// Sin servidor configurado no hay cuenta a la que entrar: solo se ofrece la demostración,
/// con datos de ejemplo guardados en el teléfono y claramente rotulada.
class AccesoAdmin extends StatefulWidget {
  const AccesoAdmin({super.key, required this.controlador});
  final ControladorAdmin controlador;

  @override
  State<AccesoAdmin> createState() => _AccesoAdminState();
}

class _AccesoAdminState extends State<AccesoAdmin> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _focoCorreo = FocusNode();
  final _focoClave = FocusNode();
  bool _ver = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _focoCorreo.dispose();
    _focoClave.dispose();
    super.dispose();
  }

  bool get _completo => _correo.text.contains('@') && _clave.text.isNotEmpty;

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    try {
      await widget.controlador.entrar(_correo.text, _clave.text);
    } on ErrorPanel catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
      rethrow; // el botón lo muestra como error
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controlador;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const Center(child: ZankyMascota(tamano: 110, animo: Animo.curioso)),
        const SizedBox(height: 8),
        Text('Panel de la CRA', textAlign: TextAlign.center, style: tt.headlineSmall),
        const SizedBox(height: 6),
        Text(
          c.configurado
              ? 'Solo para el equipo que verifica los reportes. Entra con tu cuenta; el servidor confirma tu rol.'
              : 'Este teléfono no está conectado a un servidor, así que no hay cuentas a las que entrar.',
          textAlign: TextAlign.center,
          style: tt.bodyMedium,
        ),
        const SizedBox(height: 22),
        if (c.configurado) ...[
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CampoAdmin(
                  etiqueta: 'Correo',
                  icono: Icons.alternate_email_rounded,
                  controlador: _correo,
                  foco: _focoCorreo,
                  teclado: TextInputType.emailAddress,
                  pistas: const [AutofillHints.email],
                  alEnviar: _focoClave.requestFocus,
                ),
                const SizedBox(height: 14),
                CampoAdmin(
                  etiqueta: 'Contraseña',
                  icono: Icons.lock_outline_rounded,
                  controlador: _clave,
                  foco: _focoClave,
                  oculto: !_ver,
                  accion: TextInputAction.done,
                  pistas: const [AutofillHints.password],
                  alEnviar: _completo ? () => _entrar().catchError((_) {}) : null,
                  sufijo: Presionable(
                    etiqueta: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    onTap: () => setState(() => _ver = !_ver),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(_ver ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 22, color: Cra.textoSuave),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: context.resolveDuration(Zm.corto),
            curve: Zm.entrar,
            child: (_error ?? c.error) == null
                ? const SizedBox(width: double.infinity)
                : Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: Cra.prioridad[5]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error ?? c.error!, style: tt.bodySmall?.copyWith(color: Cra.prioridad[5])),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          ListenableBuilder(
            listenable: Listenable.merge([_correo, _clave]),
            builder: (context, _) => BotonEstado(
              texto: 'Entrar al panel',
              textoCargando: 'Entrando',
              textoHecho: 'Dentro',
              textoError: 'No se pudo entrar',
              icono: Icons.login_rounded,
              alPresionar: _completo ? _entrar : null,
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Cra.solClaro,
              borderRadius: BorderRadius.circular(Zr.m),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.science_rounded, color: Cra.fango, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La demostración usa reportes de ejemplo que viven solo en este teléfono. '
                    'Sirve para ver la bandeja, las decisiones y los avisos; nada llega a la CRA.',
                    style: tt.bodyMedium?.copyWith(color: Cra.texto),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BotonEstado(
            texto: 'Ver la demostración',
            textoHecho: 'Listo',
            icono: Icons.play_circle_outline_rounded,
            alPresionar: () async => c.entrarDemo(),
          ),
        ],
      ],
    );
  }
}
