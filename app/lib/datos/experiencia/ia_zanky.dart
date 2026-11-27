import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../servidor.dart';
import 'jornada.dart';

/// Un turno de la charla, con el mismo formato que usa la burbuja de la web.
typedef TurnoZanky = ({bool esZanky, String texto});

/// La IA de Zanky vive en el servidor; en el teléfono no va ninguna clave de IA.
///
/// Primero pregunta al mismo servidor que la burbuja de la web (`POST https://zanqui.sentralabs.co/chat`,
/// cuerpo `{mensajes: [{rol: 'usuario'|'zanky', texto}]}`, respuesta `{respuesta}`). Si no responde (sin red,
/// chat apagado, límite), prueba la función de Supabase cuando se compiló con `--dart-define=ZANKY_IA=true`.
/// Si todo falla devuelve null y quien llama usa las respuestas sin conexión.
class IaZanky {
  IaZanky({Servidor? servidor, this._cliente, bool? activa, String? urlChat, this.espera = const Duration(seconds: 8)})
      : _servidor = servidor ?? Servidor(),
        _activa = activa ?? const bool.fromEnvironment('ZANKY_IA'),
        _urlChat = urlChat ?? const String.fromEnvironment('ZANKY_CHAT_URL', defaultValue: 'https://zanqui.sentralabs.co/chat');

  final Servidor _servidor;
  final http.Client? _cliente;
  final bool _activa;
  final String _urlChat;

  /// Tope por intento: sin señal no se espera más que esto antes de responder sin conexión.
  final Duration espera;

  bool get _supabase => _activa && _servidor.configurado;

  /// Hay al menos un camino a la IA (si de verdad responde se sabe al preguntar).
  bool get conectada => _urlChat.isNotEmpty || _supabase;

  /// Texto de la respuesta, o null si no hay IA o falla (quien llama usa las respuestas sin conexión).
  Future<String?> preguntar(String pregunta, {EventoZanky? evento, List<TurnoZanky> historial = const []}) async {
    if (!conectada) return null;
    final c = _cliente ?? http.Client();
    try {
      if (_urlChat.isNotEmpty) {
        final r = await _delBot(c, pregunta, evento, historial);
        if (r != null) return r;
      }
      return _supabase ? await _deSupabase(c, pregunta, evento) : null;
    } finally {
      if (_cliente == null) c.close();
    }
  }

  /// Los turnos que se mandan al bot: contexto del evento, últimos 10 turnos y la pregunta.
  static List<Map<String, String>> mensajesPara(String pregunta, EventoZanky? evento, List<TurnoZanky> historial) {
    final previos = historial.length > 10 ? historial.sublist(historial.length - 10) : historial;
    return [
      if (evento != null && evento.titulo != EventoZanky.tituloGenerico)
        {'rol': 'zanky', 'texto': 'Hola, soy Zanky. Veo que escaneaste el QR de «${evento.titulo}». ¿Qué quieres saber?'},
      for (final t in previos) {'rol': t.esZanky ? 'zanky' : 'usuario', 'texto': t.texto},
      {'rol': 'usuario', 'texto': pregunta},
    ];
  }

  Future<String?> _delBot(http.Client c, String pregunta, EventoZanky? evento, List<TurnoZanky> historial) async {
    try {
      final r = await c
          .post(
            Uri.parse(_urlChat),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mensajes': mensajesPara(pregunta, evento, historial)}),
          )
          .timeout(espera);
      return r.statusCode == 200 ? _texto(r.bodyBytes) : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _deSupabase(http.Client c, String pregunta, EventoZanky? evento) async {
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
          .timeout(espera);
      return r.statusCode == 200 ? _texto(r.bodyBytes) : null;
    } catch (_) {
      return null;
    }
  }

  static String? _texto(List<int> cuerpo) {
    try {
      final j = jsonDecode(utf8.decode(cuerpo));
      final t = j is Map ? j['respuesta'] : null;
      return t is String && t.trim().isNotEmpty ? t.trim() : null;
    } catch (_) {
      return null;
    }
  }
}
