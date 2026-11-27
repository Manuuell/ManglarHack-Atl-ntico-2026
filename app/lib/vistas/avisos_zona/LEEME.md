# Entrada de avisos por zona

`EntradaVoluntario` es la tarjeta autónoma para insertar en Inicio o Guardián. Importa `vistas/avisos_zona/entrada_voluntario.dart` y añade `const EntradaVoluntario()` donde corresponda. Abre `PantallaAvisosZona`, con inscripción, estado, baja y bandeja. No requiere alterar la navegación global.

La hoja permite elegir zona manualmente o detectarla con permiso de ubicación. Solo envía coordenadas redondeadas a tres decimales. Si se elige manualmente usa el centro aproximado de la zona, por lo que el radio también se calcula desde ese centro. Una mejora posterior puede permitir fijar un punto aproximado sobre el mapa.

La tarjeta ya está en Guardián, y la hoja de cada zona del mapa trae «Avisarme de esta zona». Sin configuración de servidor, la pantalla lleva la etiqueta visible «Demostración sin servidor» y usa un aviso de ejemplo. Correo figura desactivado hasta tener dirección de entrega y trabajador de correo.
