// Portada: la cabecera se integra al hero y pasa a cápsula al bajar, y cada bloque entra una sola vez
// al aparecer en pantalla. El mapa, el formulario, las jornadas y los avisos son islas de React.

const reducir = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function montarCabeceraFlotante(): void {
  const cabecera = document.getElementById('cab');
  if (!cabecera) return;
  const actualizar = () => cabecera.classList.toggle('flotante', window.scrollY > 24);
  actualizar();
  window.addEventListener('scroll', actualizar, { passive: true });
}

function montarRevelados(): void {
  const elementos = [...document.querySelectorAll<HTMLElement>('[data-reveal]')];
  if (!elementos.length) return;
  if (reducir() || !('IntersectionObserver' in window)) {
    elementos.forEach((e) => e.classList.add('is-in'));
    return;
  }
  elementos.forEach((e) => { if (e.dataset.revealDelay) e.style.transitionDelay = `${e.dataset.revealDelay}ms`; });
  const observador = new IntersectionObserver((entradas) => {
    for (const entrada of entradas) {
      if (!entrada.isIntersecting) continue;
      entrada.target.classList.add('is-in');
      observador.unobserve(entrada.target);
    }
  }, { threshold: 0.12, rootMargin: '0px 0px -10% 0px' });
  elementos.forEach((e) => observador.observe(e));
}

export function montarPortada(): void {
  montarCabeceraFlotante();
  montarRevelados();
}
