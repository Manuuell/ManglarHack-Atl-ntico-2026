// Zanky abajo a la derecha: un toque abre WhatsApp con Zanky BOT, donde se reporta (con foto y ubicación),
// se ven las jornadas y se le pregunta lo que sea. De vez en cuando Zanky dice algo en un globo
// («¿Tienes un reporte?…»); tocar el globo abre WhatsApp con ese mensaje ya escrito.
import { useEffect, useRef, useState } from 'react';
import { MessageCircle, X } from 'lucide-react';
import './burbuja.css';

const NUMERO = String(import.meta.env.PUBLIC_ZANKY_WHATSAPP ?? '573104432501');
const enlaceWhatsApp = (mensaje: string) => `https://wa.me/${NUMERO}?text=${encodeURIComponent(mensaje)}`;

interface Globo { texto: string; mensaje: string }
const GLOBOS: Globo[] = [
  { texto: '¿Tienes un reporte? Mándamelo por WhatsApp 📲', mensaje: 'Hola Zanky, quiero reportar algo en el manglar' },
  { texto: '¿Viste una quema, tala o basura? Cuéntamelo aquí', mensaje: 'Hola Zanky, quiero reportar algo en el manglar' },
  { texto: '¿Te sumas a la próxima jornada? 🌱', mensaje: 'Hola Zanky, quiero ver las jornadas' },
  { texto: 'Pregúntame lo que quieras del manglar', mensaje: 'Hola Zanky' },
];
const PRIMERO_MS = 4_000;
const VISIBLE_MS = 8_000;
const ENTRE_MS = 45_000;
const MAXIMO = 4;
const CALLADO = 'zanky-web:v1:globos-callados';

export default function BurbujaZanky() {
  const [globo, setGlobo] = useState<Globo | null>(null);
  const mostrados = useRef(0);

  useEffect(() => {
    let callado = false;
    try { callado = window.sessionStorage.getItem(CALLADO) === '1'; } catch { /* sin almacenamiento */ }
    if (callado) return;
    let indice = Math.floor(Math.random() * GLOBOS.length);
    let ocultar = 0;
    const mostrar = () => {
      if (document.visibilityState !== 'visible' || mostrados.current >= MAXIMO) return;
      setGlobo(GLOBOS[indice % GLOBOS.length]);
      indice += 1;
      mostrados.current += 1;
      window.clearTimeout(ocultar);
      ocultar = window.setTimeout(() => setGlobo(null), VISIBLE_MS);
    };
    const primero = window.setTimeout(mostrar, PRIMERO_MS);
    const ciclo = window.setInterval(mostrar, ENTRE_MS);
    return () => { window.clearTimeout(primero); window.clearTimeout(ocultar); window.clearInterval(ciclo); };
  }, []);

  function callar() {
    setGlobo(null);
    mostrados.current = MAXIMO;
    try { window.sessionStorage.setItem(CALLADO, '1'); } catch { /* nada */ }
  }

  return (
    <div className="zk-burbuja">
      {globo && (
        <div className="zk-globo" role="status">
          <a href={enlaceWhatsApp(globo.mensaje)} target="_blank" rel="noopener noreferrer">{globo.texto}</a>
          <button type="button" aria-label="No mostrar más mensajes de Zanky" onClick={callar}><X className="size-4" aria-hidden="true" /></button>
        </div>
      )}
      <a className="zk-boton" href={enlaceWhatsApp('Hola Zanky')} target="_blank" rel="noopener noreferrer"
        aria-label="Escribirle a Zanky por WhatsApp: reportar, ver jornadas o preguntar" title="Escríbele a Zanky por WhatsApp">
        <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={56} height={56} />
        <span className="zk-wa" aria-hidden="true"><MessageCircle className="size-4" strokeWidth={2.5} /></span>
      </a>
    </div>
  );
}
