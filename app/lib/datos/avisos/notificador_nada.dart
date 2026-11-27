import '../admin/aviso_navegador.dart';
import '../experiencia/jornada.dart';

// Sin web ni dart:io (no pasa en la práctica): avisan solo la campana y la píldora.
bool concedido() => false;

Future<void> mostrar(String titulo, String cuerpo, String clave, void Function(String) alTocar) async {}

void escucharToques(void Function(String) alTocar) {}

String? avisoDeLaDireccion() => null;

/// Avisos del sistema de esta plataforma: aquí, los del navegador.
AvisoNavegador crearAvisoSistema() => AvisoNavegador();

/// Solo el APK programa recordatorios con la app cerrada.
Future<List<String>> programarJornada(Jornada j) async => const [];

Future<void> cancelarJornada(String id) async {}
