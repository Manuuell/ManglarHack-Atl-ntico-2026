import 'dart:convert';

import '../servidor.dart';

class ColegioEnRanking {
  const ColegioEnRanking(this.puesto, this.nombre, this.validados, this.totales);

  final int puesto;
  final String nombre;
  final int validados;
  final int totales;

  factory ColegioEnRanking.deJson(Map<String, dynamic> json) => ColegioEnRanking(
        (json['puesto'] as num).toInt(),
        json['colegio'] as String,
        (json['validados'] as num).toInt(),
        (json['totales'] as num).toInt(),
      );
}

/// Reutiliza el cliente y el contrato PostgREST que usa el panel.
class RankingColegios {
  const RankingColegios(this.servidor);

  final Servidor servidor;

  Future<List<ColegioEnRanking>> cargar({int limite = 20}) async {
    if (!servidor.configurado) return const [];
    final respuesta = await servidor.pedir(
      'POST',
      Uri.parse('${servidor.base}/rest/v1/rpc/ranking_colegios'),
      {
        'apikey': servidor.anon,
        'Authorization': 'Bearer ${servidor.anon}',
        'Content-Type': 'application/json',
      },
      cuerpo: jsonEncode({'limite': limite.clamp(1, 100)}),
    );
    if (respuesta.statusCode >= 300) {
      throw ErrorServidor('ranking de colegios', respuesta.body, estadoHttp: respuesta.statusCode);
    }
    final datos = jsonDecode(respuesta.body) as List<dynamic>;
    return [
      for (final dato in datos)
        if (dato is Map<String, dynamic> && dato['puesto'] is num &&
            (dato['validados'] as num? ?? 0) > 0)
          ColegioEnRanking.deJson(dato),
    ];
  }
}
