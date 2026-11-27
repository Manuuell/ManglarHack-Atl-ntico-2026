import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../datos/estado.dart';
import '../../nucleo/presionable.dart';
import '../../nucleo/kit/aviso.dart';
import '../../nucleo/tema.dart';

/// Borra TODO lo que Zanky guarda en este teléfono: perfil (con su sal y la huella de la
/// cédula), reportes, fotos locales, caché del clima y las insignias ya celebradas.
///
/// Lo que ya llegó a la CRA no está en el teléfono: se pide borrar por los canales de
/// atención de la CRA (el aviso de privacidad lo dice).
class BorradoDatos {
  /// Frase que la persona debe escribir para confirmar (sin importar mayúsculas).
  static const palabra = 'BORRAR';

  static const clavesFijas = ['perfil.v1', 'reportes.v1', 'guardian.celebradas.v1'];
  static const prefijosDeClaves = ['clima:', 'foto:'];

  static bool confirma(String escrito) => escrito.trim().toUpperCase() == palabra;

  /// Quita las claves de SharedPreferences y la carpeta de fotos. Si algo falla lanza la
  /// excepción: quien llama debe avisar y NO dar el borrado por hecho.
  static Future<void> borrarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().toList()) {
      if (clavesFijas.contains(k) || prefijosDeClaves.any(k.startsWith)) {
        await prefs.remove(k);
      }
    }
    if (!kIsWeb) {
      // Es la carpeta que usa Fotos.guardar: <soporte>/fotos.
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/fotos');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }
}

/// Pide confirmación escrita y borra. Devuelve `true` si se borró.
Future<bool> confirmarYBorrarDatos(BuildContext context) async {
  final estado = Zanky.leer(context);
  final sinEnviar = estado.pendientes;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoBorrar(sinEnviar: sinEnviar),
  );
  if (ok != true) return false;
  try {
    await BorradoDatos.borrarTodo();
  } catch (_) {
    if (context.mounted) {
      avisar(context, 'No pude borrar todo; puede haber quedado algo. Vuelve a intentarlo.', tipo: TipoAviso.error);
    }
    return false;
  }
  estado.olvidarTodo();
  return true;
}

class _DialogoBorrar extends StatefulWidget {
  const _DialogoBorrar({required this.sinEnviar});
  final int sinEnviar;

  @override
  State<_DialogoBorrar> createState() => _DialogoBorrarState();
}

class _DialogoBorrarState extends State<_DialogoBorrar> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final listo = BorradoDatos.confirma(_texto.text);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Zr.l)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('¿Borrar mis datos de este teléfono?', style: tt.titleLarge)),
            const SizedBox(height: 8),
            Text(
              'Se borran tu perfil, tus reportes, las fotos guardadas aquí y la clave local de tu cédula. '
              'No se puede deshacer y la app vuelve a la bienvenida.',
              style: tt.bodyMedium,
            ),
            if (widget.sinEnviar > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Tienes ${widget.sinEnviar} ${widget.sinEnviar == 1 ? 'reporte' : 'reportes'} sin enviar: se perderían.',
                style: tt.bodyMedium?.copyWith(color: Zc.prioridad[5], fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Lo que ya enviaste a la CRA no está en tu teléfono: para pedir que lo borren, escribe a la CRA por '
              'sus canales de atención.',
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _texto,
              autofocus: false,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Escribe ${BorradoDatos.palabra} para confirmar',
                filled: true,
                fillColor: Zc.arena,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Zr.m), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            BotonZ(
              texto: 'Borrar mis datos',
              color: Zc.prioridad[5]!,
              onTap: listo ? () => Navigator.pop(context, true) : null,
            ),
            const SizedBox(height: 8),
            BotonZ(texto: 'Cancelar', secundario: true, onTap: () => Navigator.pop(context, false)),
          ],
        ),
      ),
    );
  }
}
