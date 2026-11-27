// Comportamiento de los menús de la barra (MenuDesplegable y MenuMovil):
// uno abierto a la vez; se cierran con Escape (el foco vuelve al botón), al hacer
// clic fuera, al salir el foco del menú y, en el teléfono, al elegir un enlace.

let montado = false;

function cerrarDesplegable(menu: HTMLElement, devolverFoco = false) {
  const boton = menu.querySelector<HTMLButtonElement>('.desplegable-boton');
  const panel = menu.querySelector<HTMLElement>('.desplegable-panel');
  if (!boton || !panel || boton.getAttribute('aria-expanded') !== 'true') return;
  boton.setAttribute('aria-expanded', 'false');
  panel.hidden = true;
  if (devolverFoco) boton.focus();
}

const desplegables = () => document.querySelectorAll<HTMLElement>('[data-desplegable]');
const menusMoviles = () => document.querySelectorAll<HTMLDetailsElement>('details[data-menu-movil]');

export function montarMenus() {
  if (montado) return;
  montado = true;

  desplegables().forEach((menu) => {
    const boton = menu.querySelector<HTMLButtonElement>('.desplegable-boton');
    const panel = menu.querySelector<HTMLElement>('.desplegable-panel');
    if (!boton || !panel) return;
    boton.addEventListener('click', () => {
      const abrir = boton.getAttribute('aria-expanded') !== 'true';
      desplegables().forEach((otro) => { if (otro !== menu) cerrarDesplegable(otro); });
      boton.setAttribute('aria-expanded', String(abrir));
      panel.hidden = !abrir;
    });
    menu.addEventListener('keydown', (evento) => {
      if (evento.key === 'Escape' && boton.getAttribute('aria-expanded') === 'true') {
        evento.stopPropagation();
        cerrarDesplegable(menu, true);
      }
    });
    menu.addEventListener('focusout', (evento) => {
      if (!menu.contains(evento.relatedTarget as Node | null)) cerrarDesplegable(menu);
    });
  });

  menusMoviles().forEach((menu) => {
    menu.addEventListener('keydown', (evento) => {
      if (evento.key === 'Escape' && menu.open) {
        evento.stopPropagation();
        menu.open = false;
        menu.querySelector('summary')?.focus();
      }
    });
    // Los enlaces a secciones de la misma página no recargan: hay que cerrar la hoja.
    menu.querySelectorAll('a').forEach((enlace) => enlace.addEventListener('click', () => { menu.open = false; }));
    menu.addEventListener('toggle', () => {
      const resumen = menu.querySelector('summary');
      resumen?.setAttribute('aria-label', menu.open ? 'Cerrar el menú' : 'Abrir el menú');
    });
  });

  document.addEventListener('click', (evento) => {
    const objetivo = evento.target as Node;
    desplegables().forEach((menu) => { if (!menu.contains(objetivo)) cerrarDesplegable(menu); });
    menusMoviles().forEach((menu) => { if (menu.open && !menu.contains(objetivo)) menu.open = false; });
  });
}
