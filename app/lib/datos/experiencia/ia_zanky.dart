import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../servidor.dart';
import 'jornada.dart';

/// La IA de Zanky vive en el servidor (una función de Supabase); en el teléfono no va ninguna clave de IA.
/// Está «lista, sin conectar» hasta que haya servidor Y se compile con `--dart-define=ZANKY_IA=true`.
class IaZanky {
  IaZanky({Servidor? servidor, this._cliente, bool? activa})
      : _servidor = servidor ?? Servidor(),
        _activa = activa ?? const bool.fromEnvironment('ZANKY_IA');

  final Servidor _servidor;
  final http.Client? _cliente;
  final bool _activa;

  bool get conectada => _activa && _servidor.configurado;

  /// Texto de la respuesta, o null si no está conectada o falla (quien llama usa las respuestas sin conexión).
  Future<String?> preguntar(String pregunta, {EventoZanky? evento}) async {
    if (!conectada) return null;
    final c = _cliente ?? http.Client();
    try {
      final r = await c
          .post(
            Uri.parse('${_servidor.base}/functions/v1/zanky-chat'),
            headers: {
              'apikey': _servidor.anon,
              'Authorization': 'Bearer ${_servidor.anon}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'pregunta': pregunta, 'evento': evento?.titulo}),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final t = j is Map ? j['respuesta'] : null;
      return t is String && t.trim().isNotEmpty ? t.trim() : null;
    } catch (_) {
      return null;
    } finally {
      if (_cliente == null) c.close();
    }
  }
}
