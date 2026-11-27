# Pronóstico del manglar

`const TarjetaPronostico()` se puede insertar como hijo de la lista de Inicio. Lee las cuatro zonas y los reportes del `Zanky` heredado, consulta Open-Meteo y abre su propia pantalla de detalle. No requiere cambios en `inicio.dart`.

La tarjeta no impone altura fija: a 360 px de ancho con letra x1 se debe reservar aproximadamente 480 px; con letra x1,3, hasta unos 620 px por los rótulos de hora que pueden envolver varias líneas. El alto real depende de los nombres y del estado de cada zona; conviene dejarla dentro de una lista desplazable. Cada fila tocable mide al menos 50 px y el botón de actualización 44 px.

Las reglas son indicadores orientativos, no predicciones de incendios, taponamientos, erosión ni vertimientos observados. Los días secos se infieren de precipitación modelada por Open-Meteo, incluso para fechas pasadas; no son mediciones de estación. La copia local conserva la fecha de lectura y se rotula cuando falla la red. Si ya venció, no indica riesgo actual. Si no hay copia, se muestra una explicación sin inventar un nivel.

Se usan las APIs públicas [Forecast](https://open-meteo.com/en/docs) y [Marine](https://open-meteo.com/en/docs/marine-weather-api), sin clave. Los umbrales de esta función son heurísticos propios y aún no están calibrados con observaciones del Atlántico. Un reporte de tipo «Otro» solo eleva oleaje si menciona explícitamente erosión, oleaje, olas o playa; el texto libre no es una verificación.
