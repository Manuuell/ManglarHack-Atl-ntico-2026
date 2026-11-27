# Etiquetas NFC de asistencia

1. Abre el modo evento con el código correcto y toca **Para organizadores**.
2. En Android con Chrome y HTTPS, toca **Grabar etiqueta NFC del evento**, acepta el permiso del navegador y acerca una etiqueta NDEF escribible a la parte posterior del teléfono. Espera el mensaje de éxito.
3. Comprueba la etiqueta con otro teléfono: debe abrir `https://mimanglar.sentralabs.co/app/?evento=<id>&accion=asistencia` y mostrar directamente la hoja de asistencia. La asistencia se guarda en el teléfono incluso sin señal.

En iPhone, PC u otro navegador sin escritura Web NFC, copia el enlace que aparece en la misma sección. Abre cualquier app para **escribir etiquetas NFC** que permita crear un registro **URL/URI**, pega el enlace, escribe la etiqueta y compruébala. Una etiqueta NDEF con ese enlace puede abrirse con cualquier teléfono que admita lectura NFC; la capacidad de escritura desde esta web solo está disponible donde Chrome ofrece `NDEFReader` en un contexto seguro.

La etiqueta solo contiene el enlace público del evento; no guarda nombres ni datos de asistencia. Si se cambia el código del evento, hay que volver a grabarla. Para usarla sin señal, cada participante debe haber abierto Zanky al menos una vez con conexión para instalar la copia local.
