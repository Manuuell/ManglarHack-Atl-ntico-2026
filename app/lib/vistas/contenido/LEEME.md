# Integración de contenido editable

1. Cargar `backend/supabase/schema.sql` y después `backend/supabase/contenido.sql` en Supabase. El segundo archivo es aditivo e idempotente. `contenido_app` conserva el estado en edición, `contenido_versiones` registra cada guardado y `contenido_publicado` conserva la última publicación. El RPC `guardar_contenido` exige la versión esperada para evitar sobrescribir otra edición.
2. Desde el panel autenticado, construir `RepositorioContenido(panel: controladorAdmin)` y abrir `EditorContenido(ambito: 'global', repositorio: repo)` para portada, `EditorContenido(ambito: 'evento:<codigo>', repositorio: repo)` para evento o `EditorContenido(ambito: 'punto:<codigo>', repositorio: repo)` para punto. El panel proporciona el token actualizado; RLS decide los permisos, no la interfaz.
3. Poner `BloquesContenido(ambito: 'global')` en la portada y `BloquesContenido(ambito: 'evento:<codigo>')` dentro de `PantallaEvento`, con el código del evento actual. Se deja esta inserción explícita para no cambiar `inicio.dart` ni `pantalla_guardian.dart`. El mismo pintor sirve en la vista previa y en público; los bloques ocultos no se muestran.
4. Para biodiversidad, abrir `PantallaBiodiversidad(zona: zonaManglar)` desde la ficha de zona o el mapa. No se agrega navegación global en este cambio.

La base actual no tiene una columna de creador en eventos ni puntos y `panel_roles` no incluye `organizador`. La tabla privada `contenido_organizadores` asigna el rol `organizador` a un usuario autenticado y un ámbito concreto. El administrador la completa desde SQL Editor después de verificar al responsable: `insert into public.contenido_organizadores (ambito, user_id) values ('evento:CODIGO', 'UUID_DEL_USUARIO') on conflict do nothing;`. RLS admite ese usuario solo en el ámbito asignado. Para un flujo de acceso de organizador fuera del panel, pasar al repositorio `tokenEditor: () async => tokenActual`; la pantalla de inicio de sesión de ese rol se integra al implementar la gestión de eventos. Conocer el código del evento no concede escritura. Cuando exista una columna de creador verificable, se puede reemplazar esta asignación por la relación directa.

Sin servidor, el editor rotula **Demostración** y guarda contenido/versiones en `SharedPreferences` del dispositivo. La publicación local solo se ve en ese dispositivo. Guardar un borrador conserva la última versión publicada, tanto localmente como en Supabase. El historial permite recuperar los bloques de una versión y guardarlos como una nueva versión.

Pruebas escritas: `app/test/contenido_editor_test.dart` (bloques, orden, deshacer, JSON), `app/test/contenido_repositorio_test.dart` (publicación y borrador local) y `app/test/contenido_widgets_test.dart` (360×800 y 390×844). No se ejecutó Flutter en este worktree.

Después de cargar el SQL, comprobar manualmente con tres sesiones: anónima lee `contenido_publicado` pero no un borrador en `contenido_app`; organizador asignado edita solo su `evento:<codigo>`; otro usuario autenticado recibe denegación. Guardar borrador después de publicar debe mantener la copia pública, y un segundo guardado con versión obsoleta debe fallar.

## Integrado (27-nov)

- Panel CRA (rol admin): botón «Editar contenido de la app» abre `abrirEditorContenido` (portada o evento por código) y de ahí `EditorContenido`.
- `EditorContenido` es por pasos (Bloques, Vista previa, Versiones) con barra de guardado fija; en pantallas de 900 px o más la vista previa queda al lado.
- Portada (`inicio.dart`) y `PantallaEvento` muestran `BloquesContenido` publicado; la ficha de zona del mapa abre `PantallaBiodiversidad`.
- Edita solo `admin` (por `panel_roles`) o el organizador asignado a ese ámbito en `contenido_organizadores`. `moderador_cra` ya no edita.
- Aún sin integrar: acceso del organizador fuera del panel (necesita su propio inicio de sesión).
