// Las ventanas (popups) de los mapas siempre caben completas dentro del mapa.
// Leaflet intenta desplazar el mapa para mostrar una ventana entera (autoPan), pero los mapas de la web
// no se salen de la zona del manglar (maxBounds): cerca del borde norte no puede desplazarse y la parte
// de arriba de la ventana quedaba cortada por el borde del mapa.
// Aquí, después de abrirse (y de cada desplazamiento o zoom), se mide la ventana:
//  - si cabe encima de su punto, no se toca;
//  - si no cabe y debajo hay más espacio, se abre hacia abajo del punto;
//  - si aun así no cabe, su contenido se acorta al espacio disponible y se desplaza por dentro.
// Basta importar este módulo una vez antes de crear el mapa: se engancha a todos los L.Map.
import L from 'leaflet';

const MARGEN = 10;
const CLASE_ABAJO = 'leaflet-popup-abajo';

function ajustar(mapa: L.Map, popup: L.Popup): void {
  const el = popup.getElement();
  const contenido = el?.querySelector<HTMLElement>('.leaflet-popup-content');
  const lugar = popup.getLatLng();
  if (!el || !contenido || !lugar) return;
  // Se parte de la posición normal de Leaflet (encima del punto).
  el.classList.remove(CLASE_ABAJO);
  el.style.marginBottom = '';
  contenido.style.maxHeight = '';
  contenido.style.overflowY = '';

  const mapaCaja = mapa.getContainer().getBoundingClientRect();
  const caja = el.getBoundingClientRect();
  const punto = mapaCaja.top + mapa.latLngToContainerPoint(lugar).y;
  const arriba = caja.bottom - mapaCaja.top - MARGEN; // alto disponible encima (hasta la punta)
  const abajo = mapaCaja.bottom - punto - MARGEN * 2; // alto disponible debajo del punto
  if (caja.height <= arriba) return;

  let disponible = arriba;
  if (abajo > arriba) {
    // Hacia abajo: la ventana se ancla por abajo (style.bottom), así que un margen inferior
    // negativo la baja hasta quedar justo debajo del punto.
    el.classList.add(CLASE_ABAJO);
    el.style.marginBottom = `${-Math.round(punto + MARGEN - caja.top)}px`;
    disponible = abajo;
  }
  if (caja.height > disponible) {
    const resto = caja.height - contenido.offsetHeight;
    contenido.style.maxHeight = `${Math.max(120, Math.floor(disponible - resto))}px`;
    contenido.style.overflowY = 'auto';
    if (el.classList.contains(CLASE_ABAJO)) {
      // Al acortarla cambia su alto: se recoloca para que siga empezando justo debajo del punto.
      const nueva = el.getBoundingClientRect();
      const actual = parseFloat(el.style.marginBottom) || 0;
      el.style.marginBottom = `${Math.round(actual - (punto + MARGEN - nueva.top))}px`;
    }
  }
}

L.Map.addInitHook(function (this: L.Map) {
  let abierta: L.Popup | null = null;
  const revisar = () => { if (abierta) requestAnimationFrame(() => { if (abierta) ajustar(this, abierta); }); };
  this.on('popupopen', (e: L.PopupEvent) => { abierta = e.popup; revisar(); });
  this.on('popupclose', (e: L.PopupEvent) => { if (abierta === e.popup) abierta = null; });
  // Después del desplazamiento automático, del zoom o de un cambio de tamaño, se vuelve a medir.
  this.on('moveend zoomend resize', revisar);
});
