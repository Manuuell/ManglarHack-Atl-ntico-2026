// Zanky en una burbuja abajo a la derecha: se abre una charla para preguntar por el manglar, cómo reportar o las
// jornadas. Las respuestas las da el servidor del bot (POST /chat, con OpenAI); la clave nunca está en la web.
// La charla vive solo en esta pestaña (sessionStorage) y no se manda nada más que lo que la persona escribe.
import { Fragment, useEffect, useRef, useState, type FormEvent, type KeyboardEvent, type ReactNode } from 'react';
import { ArrowUp, X } from 'lucide-react';
import './burbuja.css';

interface Turno { rol: 'usuario' | 'zanky'; texto: string; error?: boolean }

const URL_CHAT = String(import.meta.env.PUBLIC_ZANKY_CHAT_URL ?? 'https://zanqui.sentralabs.co/chat');
const CLAVE = 'zanky-web:v1:charla';
const SALUDO: Turno = { rol: 'zanky', texto: '¡Hola! Soy Zanky 🌿. Pregúntame lo que quieras del manglar, cómo reportar algo raro o cuándo es la próxima jornada.' };
const SUGERENCIAS = ['¿Por qué es importante el manglar?', '¿Cómo reporto una quema?', '¿Cuándo es la próxima jornada?'];

/** Texto con enlaces tocables, sin insertar HTML. */
function conEnlaces(texto: string): ReactNode {
  const partes = texto.split(/(https?:\/\/[^\s)»"]+)/g);
  return partes.map((p, i) => {
    if (!/^https?:\/\//.test(p)) return <Fragment key={i}>{p}</Fragment>;
    const limpio = p.replace(/[.,;:]+$/, '');
    const resto = p.slice(limpio.length);
    return <Fragment key={i}><a href={limpio} target={limpio.includes('mimanglar.sentralabs.co') ? undefined : '_blank'} rel="noopener noreferrer">{limpio.replace(/^https?:\/\//, '')}</a>{resto}</Fragment>;
  });
}

function leerCharla(): Turno[] {
  try {
    const datos = JSON.parse(window.sessionStorage.getItem(CLAVE) ?? '[]') as Turno[];
    return Array.isArray(datos) && datos.length ? datos.slice(-30) : [SALUDO];
  } catch {
    return [SALUDO];
  }
}

export default function BurbujaZanky() {
  const [abierta, setAbierta] = useState(false);
  const [charla, setCharla] = useState<Turno[]>([SALUDO]);
  const [texto, setTexto] = useState('');
  const [pensando, setPensando] = useState(false);
  const [invita, setInvita] = useState(false);
  const lista = useRef<HTMLDivElement>(null);
  const campo = useRef<HTMLTextAreaElement>(null);
  const boton = useRef<HTMLButtonElement>(null);

  useEffect(() => { setCharla(leerCharla()); }, []);
  useEffect(() => { try { window.sessionStorage.setItem(CLAVE, JSON.stringify(charla.slice(-30))); } catch { /* sin almacenamiento */ } }, [charla]);

  // Una invitación corta la primera vez que se ve la página en esta pestaña.
  useEffect(() => {
    let visto = false;
    try { visto = window.sessionStorage.getItem(`${CLAVE}:invitado`) === '1'; window.sessionStorage.setItem(`${CLAVE}:invitado`, '1'); } catch { /* nada */ }
    if (visto) return;
    const a = window.setTimeout(() => setInvita(true), 2500);
    const b = window.setTimeout(() => setInvita(false), 11_000);
    return () => { window.clearTimeout(a); window.clearTimeout(b); };
  }, []);

  useEffect(() => {
    if (!abierta) return;
    setInvita(false);
    campo.current?.focus();
    const tecla = (e: globalThis.KeyboardEvent) => { if (e.key === 'Escape') { setAbierta(false); boton.current?.focus(); } };
    document.addEventListener('keydown', tecla);
    return () => document.removeEventListener('keydown', tecla);
  }, [abierta]);

  useEffect(() => { lista.current?.scrollTo({ top: lista.current.scrollHeight, behavior: 'smooth' }); }, [charla, pensando, abierta]);

  async function preguntar(pregunta: string) {
    const limpia = pregunta.trim().slice(0, 600);
    if (!limpia || pensando) return;
    const nueva = [...charla.filter((t) => !t.error), { rol: 'usuario' as const, texto: limpia }];
    setCharla(nueva);
    setTexto('');
    setPensando(true);
    try {
      const res = await fetch(URL_CHAT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // El saludo es de la página, no de la conversación: no se manda.
        body: JSON.stringify({ mensajes: nueva.filter((t) => t !== SALUDO && t.texto !== SALUDO.texto).slice(-12).map(({ rol, texto: t }) => ({ rol, texto: t })) }),
        signal: AbortSignal.timeout(30_000),
      });
      const datos = (await res.json().catch(() => ({}))) as { respuesta?: string; mensaje?: string };
      if (!res.ok || !datos.respuesta) throw new Error(datos.mensaje || 'Se me enredó la respuesta. ¿Me lo preguntas otra vez?');
      setCharla((c) => [...c, { rol: 'zanky', texto: datos.respuesta! }]);
    } catch (err) {
      const mensaje = err instanceof Error && err.name !== 'TimeoutError' && err.name !== 'TypeError' ? err.message : 'No pude conectarme. Revisa tu internet e inténtalo otra vez.';
      setCharla((c) => [...c, { rol: 'zanky', texto: mensaje, error: true }]);
    } finally {
      setPensando(false);
    }
  }

  function enviar(e: FormEvent) { e.preventDefault(); void preguntar(texto); }
  function alTeclear(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); void preguntar(texto); }
  }

  const soloSaludo = charla.length === 1;

  return (
    <div className="zk-burbuja">
      {abierta && (
        <section className="zk-panel" role="dialog" aria-label="Charla con Zanky" id="zk-panel">
          <header className="zk-cab">
            <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={44} height={44} />
            <div className="zk-cab-texto">
              <strong>Zanky</strong>
              <span>Pregúntame del manglar</span>
            </div>
            <button type="button" className="zk-cerrar" aria-label="Cerrar la charla" onClick={() => { setAbierta(false); boton.current?.focus(); }}><X className="size-5" aria-hidden="true" /></button>
          </header>

          <div className="zk-lista" ref={lista} aria-live="polite">
            {charla.map((t, i) => (
              <div key={i} className={`zk-msg ${t.rol === 'usuario' ? 'zk-yo' : 'zk-el'}${t.error ? ' zk-error' : ''}`}>{conEnlaces(t.texto)}</div>
            ))}
            {pensando && <div className="zk-msg zk-el zk-pensando" aria-label="Zanky está escribiendo"><i /><i /><i /></div>}
            {soloSaludo && !pensando && (
              <div className="zk-sugerencias">
                {SUGERENCIAS.map((s) => <button key={s} type="button" onClick={() => void preguntar(s)}>{s}</button>)}
              </div>
            )}
          </div>

          <form className="zk-form" onSubmit={enviar}>
            <textarea ref={campo} rows={1} value={texto} maxLength={600} placeholder="Escríbele a Zanky…" aria-label="Tu pregunta para Zanky"
              onChange={(e) => setTexto(e.target.value)} onKeyDown={alTeclear} />
            <button type="submit" aria-label="Enviar" disabled={!texto.trim() || pensando}><ArrowUp className="size-5" aria-hidden="true" /></button>
          </form>
          <div className="zk-nota">Respuestas generadas con IA: pueden equivocarse. No compartas datos personales.</div>
        </section>
      )}

      {invita && !abierta && <button type="button" className="zk-invita" onClick={() => setAbierta(true)}>¿Hablamos del manglar? 🌱</button>}

      <button ref={boton} type="button" className={`zk-boton${abierta ? ' zk-activo' : ''}`} aria-expanded={abierta} aria-controls="zk-panel"
        aria-label={abierta ? 'Cerrar la charla con Zanky' : 'Hablar con Zanky'} onClick={() => setAbierta((a) => !a)}>
        {abierta ? <X className="size-7" aria-hidden="true" /> : <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={56} height={56} />}
      </button>
    </div>
  );
}
