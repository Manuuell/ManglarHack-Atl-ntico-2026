// Dobles compartidos por las pruebas de la capa de datos (cola, servidor, fotos).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zanky/datos/reporte.dart';
import 'package:zanky/datos/servidor.dart';
import 'package:zanky/datos/tipos.dart';

/// Un reporte mínimo y válido (dentro de Mallorquín).
Reporte reporteDePrueba(
  String id, {
  Envio envio = Envio.enCola,
  TipoAmenaza tipo = TipoAmenaza.tala,
  LatLng punto = const LatLng(11.05316, -74.85094),
  DateTime? capturado,
  EstadoReporte estado = EstadoReporte.recibido,
  String? fotoRef,
  String? idPublico,
  bool anonimo = false,
  String? reportanteId = 'yo',
  int prioridad = 3,
  int confianza = 60,
}) =>
    Reporte(
      id: id,
      tipo: tipo,
      descripcion: 'Prueba',
      punto: punto,
      precisionM: 8,
      metodo: MetodoUbicacion.gps,
      capturadoEn: capturado ?? DateTime(2026, 11, 27, 10),
      momento: Momento.ahora,
      magnitud: Magnitud.pequena,
      zonaId: 'mallorquin',
      zonaNombre: 'Ciénaga de Mallorquín',
      municipio: 'Barranquilla',
      dentroPoligono: true,
      distanciaM: 0,
      prioridad: prioridad,
      prioridadLocal: prioridad,
      motivosPrioridad: const ['x'],
      confianza: confianza,
      anonimo: anonimo,
      reportanteId: reportanteId,
      fotoRef: fotoRef,
      envio: envio,
      estado: estado,
      idPublico: idPublico,
    );

/// UUID de prueba con el número [n] (distintos entre sí y con caso distinto).
String idDePrueba(int n) => '${n.toRadixString(16).padLeft(8, '0')}-0000-4000-8000-000000000000';

/// Un servidor falso que anota cada llamada. [alCrear] decide la respuesta de
/// crear_reporte (por defecto: lo acepta y le da el id público «pub-ID»).
class ServidorFalso {
  ServidorFalso({this.alCrear, this.alEstados, this.alSubirFoto});

  Future<http.Response> Function(Map<String, dynamic> p)? alCrear;
  Future<http.Response> Function(List<String> ids)? alEstados;
  Future<http.Response> Function(http.Request r)? alSubirFoto;

  final creados = <String>[];
  final tandasDeEstados = <List<String>>[];
  final fotos = <List<int>>[];
  final pedidos = <http.Request>[];
  var publicosPedidos = 0;
  List<Map<String, dynamic>> publicos = [];

  late final cliente = MockClient((req) async {
    pedidos.add(req);
    final ruta = req.url.path;
    if (ruta.endsWith('/rpc/crear_reporte')) {
      final p = (jsonDecode(req.body) as Map<String, dynamic>)['p'] as Map<String, dynamic>;
      creados.add(p['id'] as String);
      if (alCrear != null) return alCrear!(p);
      return http.Response(jsonEncode({'id': p['id'], 'nuevo': true, 'id_publico': 'pub-${p['id']}'}), 200);
    }
    if (ruta.endsWith('/rpc/estado_de_reportes')) {
      final ids = ((jsonDecode(req.body) as Map)['ids'] as List).cast<String>();
      tandasDeEstados.add(ids);
      if (alEstados != null) return alEstados!(ids);
      return http.Response('[]', 200);
    }
    if (ruta.contains('/storage/v1/object/')) {
      fotos.add(req.bodyBytes);
      if (alSubirFoto != null) return alSubirFoto!(req);
      return http.Response('{"Key":"evidencias/x.jpg"}', 200);
    }
    if (ruta.endsWith('/reportes_publicos')) {
      publicosPedidos++;
      return http.Response(jsonEncode(publicos), 200);
    }
    return http.Response('no existe', 404);
  });

  Servidor get servidor => Servidor(base: 'https://zanky.test', anon: 'clave-anon-de-prueba', cliente: cliente);
}

/// Un cliente que nunca responde, pero sí atiende la orden de cancelar (como IOClient y
/// BrowserClient). Sirve para comprobar que un plazo vencido CANCELA la petición.
class ClienteMudo extends http.BaseClient {
  var enviadas = 0;
  var canceladas = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    enviadas++;
    final c = Completer<http.StreamedResponse>();
    if (request is http.Abortable) {
      request.abortTrigger?.whenComplete(() {
        canceladas++;
        if (!c.isCompleted) c.completeError(http.RequestAbortedException(request.url));
      });
    }
    return c.future;
  }
}

/// localStorage de mentira: se puede escribir «desde otra pestaña» (directo, sin pasar
/// por la caché de shared_preferences) y hacer que la escritura falle por cuota.
class AlmacenDePrueba extends InMemorySharedPreferencesStore {
  AlmacenDePrueba() : super.empty();

  /// Si no es null, toda escritura de una clave que empiece así falla por cuota.
  String? fallarCon;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fallarCon != null && key.startsWith(fallarCon!)) {
      throw Exception('QuotaExceededError: The quota has been exceeded.');
    }
    return super.setValue(valueType, key, value);
  }

  /// Lo que escribe otra pestaña: va directo al almacén.
  Future<void> escribirDesdeOtraPestana(String clave, List<String> valor) =>
      super.setValue('StringList', 'flutter.$clave', valor);

  Future<List<String>> leerLista(String clave) async =>
      ((await getAll())['flutter.$clave'] as List?)?.cast<String>() ?? const [];
}
