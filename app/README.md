# Zanky · app móvil (Flutter)

App de ciencia ciudadana para reportar **en tiempo real y con ubicación** las amenazas al manglar del Atlántico.
Funciona **sin internet**: el reporte se guarda en el teléfono y se envía solo cuando vuelve la señal.

## Qué hace

- **Reportar** en cuatro pasos: qué viste, dónde (GPS del teléfono, punto en el mapa o enlace de Google Maps),
  la foto tomada en el sitio y los detalles. El punto se cruza **en el teléfono** con los polígonos del manglar:
  dice si está dentro, a qué distancia y en qué zona (Mallorquín, Tubará, Juan de Acosta o Piojó).
- **Prioridad 1-5 con sus motivos a la vista** (tipo, zona de conservación, si pasa ahora, tamaño, viento
  de Open-Meteo para incendios, otros reportes cerca).
- **Solidez del reporte 0-100**: guía al ciudadano (la foto en el sitio y la ubicación precisa la suben). La alerta
  oficial siempre la decide una persona.
- **Mis reportes** con su estado en la CRA y la línea de tiempo, **mapa** con las zonas y los reportes,
  **Zanky** como guía y **tarjeta del guardián** con niveles e insignias que solo suben con reportes validados.

## Cómo correrla

```bash
cd app
flutter pub get
flutter test
# Modo demostración (sin servidor: todo queda en el teléfono y la app lo dice):
flutter run
# Con el backend común (ver ../backend/supabase/README.md):
flutter run --dart-define=ZANKY_API=https://TU-PROYECTO.supabase.co --dart-define=ZANKY_ANON=CLAVE_ANON
```

La clave `anon` de Supabase es pública por diseño; lo que protege los datos son las reglas del servidor.
La clave `service_role` **nunca** va en la app.

## Estructura

| Carpeta | Qué hay |
|---|---|
| `lib/datos/` | Modelo y contrato con el servidor (`reporte.dart` → `aServidor()`), zonas y punto en polígono, prioridad, cola sin señal, clima, guardián |
| `lib/nucleo/` | Tema (colores del manglar), toque con resorte y vibración, piezas de movimiento medidas (`base/`) |
| `lib/vistas/` | Pantallas. Plan y reglas en [`PLAN_PANTALLAS.md`](PLAN_PANTALLAS.md) |
| `assets/datos/manglar_zonas.json`, `prioridades_cra.json` | Polígonos del manglar y capa de prioridades de conservación dentro de la app (sin internet). Se generan con `node tool/preparar_capas_cra.mjs` |

## Datos

Polígonos: capa oficial de la CRA, manglar a escala 1:5.000 agrupado en las cuatro zonas de la CRA, y su capa de
«Prioridades de conservación» (alta, media, baja) que la app usa para la prioridad de cada reporte. Cómo se prepara está
en `tool/preparar_capas_cra.mjs`. La asignación de cada polígono a su zona se valida con los mentores ambientales.
