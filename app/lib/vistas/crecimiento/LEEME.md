# Integrar «Mi manglar»

Este módulo usa el arte oficial de `ZankyEtapa`, los puntos de `Progreso` y las insignias de Guardián. No suma puntos por visitas, envíos pendientes ni toques.

## Inicio

En la sección de Inicio que ya recibe `EstadoZanky`, insertar la tarjeta:

```dart
ZankyCreceCompacto(
  puntos: estado.progreso.puntos,
  alAbrir: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PantallaMiManglar()),
  ),
)
```

Importar `vistas/crecimiento/zanky_crece.dart` y `vistas/crecimiento/pantalla_mi_manglar.dart` con las rutas relativas correspondientes. La tarjeta compacta no registra etapas: la evolución se presenta en la pantalla completa.

## Guardián

Añadir una entrada «Mi manglar» cerca de `SeccionNivel` en `pantalla_guardian.dart`. Su acción abre `const PantallaMiManglar()` con `Navigator.push`. La pantalla toma `progreso`, reportes, perfil y servidor desde `Zanky.de(context)`, así que no necesita copiar estado ni crear otro cliente. Evitar celebrar dos veces la misma subida: el módulo guarda su propia última etapa vista (`crecimiento.etapa.v1.<id>`) para la transformación del árbol, mientras Guardián conserva su celebración de nivel e insignias.

## Datos y alcance

- Etapas visuales: 0, 60, 180, 400 y 800 puntos. El nivel 6 conserva el arte de mangle rojo y muestra su rango en texto.
- Cada reporte validado aporta 50 puntos base, con bonificaciones según `Progreso.puntosDe`. Por eso el texto expresa «hasta N reportes»; los puntos que faltan son exactos.
- La primera visita registra la etapa actual sin reproducir evoluciones antiguas. Una subida posterior se marca en preferencias antes de animar, para no repetirla al reabrir.
- Con servidor configurado se consulta `POST /rest/v1/rpc/ranking_colegios` mediante `Servidor.pedir`. Sin servidor, se ve una demostración rotulada sin puestos ficticios. Un fallo remoto ofrece reintento.
- La pantalla usa una columna hasta 899 px y dos columnas desde 900 px. Las pruebas cubren 360×800, 390×844, 768×800 y 1280×800, con escala de texto 1 y 1,3.

## Verificación pendiente del orquestador

Ejecutar `flutter test test/crecimiento_datos_test.dart test/crecimiento_vistas_test.dart` y `flutter analyze` desde `app/`; revisar visualmente el arte y la evolución en teléfono y navegador de escritorio. Este worktree no ejecutó Flutter.
