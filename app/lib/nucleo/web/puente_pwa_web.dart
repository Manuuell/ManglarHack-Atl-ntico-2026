import 'dart:js_interop';

@JS('zankyVersionNueva')
external JSBoolean _hayVersionNueva();

@JS('zankyEstadoConexion')
external JSString _estadoConexion();

@JS('zankyActualizar')
external void actualizarVersion();

bool hayVersionNueva() => _hayVersionNueva().toDart;
String estadoConexion() => _estadoConexion().toDart;
