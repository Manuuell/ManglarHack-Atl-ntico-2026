# Entrada del gestor de puntos

`EntradaGestor` está en `entrada_gestor.dart`. En la sección del equipo (por ejemplo, junto a `EntradaPanelCra` en Guardián), importar `../gestion/entrada_gestor.dart` y colocar `const EntradaGestor()`. Esta rama no modifica `inicio.dart` ni `pantalla_guardian.dart` porque se integran por separado.

Con servidor, la entrada muestra un formulario de Supabase Auth. `mi_rol()` y las RPC del servidor admiten únicamente `admin`, `moderador_cra`, `investigador` y `organizador`. La sesión del gestor vive en memoria. Sin servidor, el gestor abre una **DEMOSTRACIÓN** explícita con datos locales de esa sesión. El botón de entrada puede ocultarse desde la pantalla que lo integre si desea mostrarse únicamente dentro del área del equipo; la autorización real siempre está en SQL.

El cartel usa el QR de `qr_flutter`, `share_plus` y el grabador NFC del modo evento. En web, imprimir abre una página A4 con el QR y llama al diálogo de impresión. En demostración, el QR de ejemplo queda rotulado y se desactivan compartir, imprimir y grabar NFC. Los navegadores que bloquean ventanas emergentes pueden requerir permitirlas.
