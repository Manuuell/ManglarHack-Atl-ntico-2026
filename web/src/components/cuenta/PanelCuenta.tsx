// Botón de perfil de la cabecera y panel de cuenta (iniciar sesión, crear cuenta, recuperar la
// contraseña y perfil). También intercepta los enlaces con data-cuenta-reportar: si no hay sesión,
// antes de ir a «Reportar» ofrece entrar o crear cuenta, o «Seguir sin cuenta» (reportar nunca la exige).
// El panel es un <dialog> modal: va en la capa superior, por encima de la burbuja de Zanky y los avisos.
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { CircleUserRound, Eye, EyeOff, LogOut, X } from 'lucide-react';
import {
  ErrorCuenta, SECTORES_CUENTA, actualizarPerfil, cambiarClave, cerrarSesion, cuentasActivas, iniciarSesion,
  recuperarClave, registrarse, renovarSesion, sesionActual, tomarSesionDelEnlace, useSesion,
} from '../../lib/cuenta';
import '../../styles/cuenta.css';

type Modo = 'entrar' | 'crear' | 'olvido' | 'nueva_clave' | 'perfil';
type Aviso = { tipo: 'ok' | 'error'; texto: string } | null;
const CLAVE_SIN_CUENTA = 'zanky-web:v1:reportar-sin-cuenta';
const CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const fecha = (iso: string | null) => iso ? new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(iso)) : null;

function Campo({ id, etiqueta, error, children, ayuda }: { id: string; etiqueta: string; error?: string; ayuda?: string; children: ReactNode }) {
  return <div className="cuenta-campo">
    <label htmlFor={id}>{etiqueta}</label>
    {children}
    {ayuda && !error && <span className="cuenta-ayuda">{ayuda}</span>}
    {error && <span className="cuenta-error" id={`${id}-error`}>{error}</span>}
  </div>;
}

export default function PanelCuenta({ contexto = 'plataforma' }: { contexto?: 'portada' | 'plataforma' }) {
  const sesion = useSesion();
  const dialogo = useRef<HTMLDialogElement>(null);
  const [modo, setModo] = useState<Modo>('entrar');
  const [destino, setDestino] = useState<string | null>(null);
  const [aviso, setAviso] = useState<Aviso>(null);
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [ocupado, setOcupado] = useState(false);
  const [verClave, setVerClave] = useState(false);
  const [nombre, setNombre] = useState('');
  const [correo, setCorreo] = useState('');
  const [clave, setClave] = useState('');
  const [sector, setSector] = useState('');
  const [acepta, setAcepta] = useState(false);

  const vista: Modo = sesion ? (modo === 'nueva_clave' ? 'nueva_clave' : 'perfil') : (modo === 'perfil' || modo === 'nueva_clave' ? 'entrar' : modo);

  function abrir(m: Modo, d: string | null = null, a: Aviso = null) {
    setModo(m); setDestino(d); setAviso(a); setErrores({}); setClave(''); setVerClave(false);
    if (m === 'perfil') { const s = sesionActual(); setNombre(s?.usuario.nombre ?? ''); setSector(s?.usuario.sector ?? ''); }
    if (!dialogo.current?.open) dialogo.current?.showModal();
  }
  const cerrar = () => dialogo.current?.close();
  function cambiar(m: Modo) { setModo(m); setAviso(null); setErrores({}); setClave(''); }

  function irADestino() {
    const d = destino;
    cerrar();
    if (!d) return;
    const url = new URL(d, location.href);
    if (url.pathname === location.pathname && url.hash) {
      document.querySelector(url.hash)?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
      history.replaceState(null, '', url.hash);
    } else location.assign(url.href);
  }
  function seguirSinCuenta() {
    try { sessionStorage.setItem(CLAVE_SIN_CUENTA, '1'); } catch { /* sin almacenamiento: se vuelve a ofrecer */ }
    irADestino();
  }

  // Al volver del enlace del correo (confirmar cuenta o recuperar contraseña) y para renovar el token.
  useEffect(() => {
    tomarSesionDelEnlace().then((r) => {
      if (!r) return;
      if ('error' in r) abrir('entrar', null, { tipo: 'error', texto: r.error });
      else if (r.tipo === 'recovery') abrir('nueva_clave', null, { tipo: 'ok', texto: 'Escribe tu contraseña nueva.' });
      else abrir('perfil', null, { tipo: 'ok', texto: '¡Listo! Tu correo quedó confirmado y ya tienes cuenta.' });
    }).catch((e: unknown) => abrir('entrar', null, { tipo: 'error', texto: e instanceof Error ? e.message : 'No se pudo usar el enlace del correo.' }));
    void renovarSesion();
    const reloj = window.setInterval(() => { void renovarSesion(); }, 60_000);
    return () => window.clearInterval(reloj);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // «Reportar»: sin sesión, antes de ir se ofrece la cuenta (una vez por visita si eligen seguir sin ella).
  useEffect(() => {
    const alClic = (e: MouseEvent) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const enlace = (e.target as Element | null)?.closest?.('a[data-cuenta-reportar]') as HTMLAnchorElement | null;
      if (!enlace || !cuentasActivas || sesionActual()) return;
      try { if (sessionStorage.getItem(CLAVE_SIN_CUENTA) === '1') return; } catch { /* se ofrece igual */ }
      e.preventDefault();
      enlace.closest('details')?.removeAttribute('open');
      abrir('entrar', enlace.href);
    };
    document.addEventListener('click', alClic);
    return () => document.removeEventListener('click', alClic);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function ejecutar(accion: () => Promise<void>) {
    setOcupado(true); setAviso(null);
    try { await accion(); } catch (e) {
      setAviso({ tipo: 'error', texto: e instanceof ErrorCuenta ? e.message : 'Algo falló. Inténtalo de nuevo.' });
    } finally { setOcupado(false); }
  }

  function validar(campos: ('nombre' | 'correo' | 'clave' | 'acepta')[]): boolean {
    const e: Record<string, string> = {};
    if (campos.includes('nombre') && nombre.trim().length < 2) e.nombre = 'Escribe tu nombre.';
    if (campos.includes('correo') && !CORREO.test(correo.trim())) e.correo = 'Escribe un correo válido.';
    if (campos.includes('clave') && clave.length < (vista === 'entrar' ? 1 : 8)) e.clave = vista === 'entrar' ? 'Escribe tu contraseña.' : 'Usa al menos 8 caracteres.';
    if (campos.includes('acepta') && !acepta) e.acepta = 'Para crear la cuenta hay que aceptar el tratamiento de datos.';
    setErrores(e);
    return Object.keys(e).length === 0;
  }

  function enviar(e: FormEvent) {
    e.preventDefault();
    if (vista === 'entrar' && validar(['correo', 'clave'])) void ejecutar(async () => {
      await iniciarSesion(correo, clave);
      setClave('');
      if (destino) irADestino();
      else { const s = sesionActual(); setNombre(s?.usuario.nombre ?? ''); setSector(s?.usuario.sector ?? ''); setAviso({ tipo: 'ok', texto: `¡Hola, ${s?.usuario.nombre ?? ''}!` }); }
    });
    if (vista === 'crear' && validar(['nombre', 'correo', 'clave', 'acepta'])) void ejecutar(async () => {
      const r = await registrarse({ nombre, correo, clave, sector: sector || null });
      setClave('');
      if (r === 'sesion') { if (destino) irADestino(); else setAviso({ tipo: 'ok', texto: `¡Bienvenido, ${nombre.trim()}! Ya tienes cuenta.` }); }
      else { setModo('entrar'); setAviso({ tipo: 'ok', texto: `Te enviamos un correo a ${correo.trim()}. Abre el enlace para activar la cuenta y luego inicia sesión.` }); }
    });
    if (vista === 'olvido' && validar(['correo'])) void ejecutar(async () => {
      await recuperarClave(correo);
      setAviso({ tipo: 'ok', texto: 'Si hay una cuenta con ese correo, te llegará un enlace para crear una contraseña nueva.' });
    });
    if (vista === 'nueva_clave' && validar(['clave'])) void ejecutar(async () => {
      await cambiarClave(clave);
      setClave(''); setModo('perfil');
      setAviso({ tipo: 'ok', texto: 'Contraseña cambiada.' });
    });
    if (vista === 'perfil' && validar(['nombre'])) void ejecutar(async () => {
      await actualizarPerfil({ nombre, sector: sector || null });
      setAviso({ tipo: 'ok', texto: 'Perfil guardado.' });
    });
  }

  const salir = () => void ejecutar(async () => { await cerrarSesion(); setModo('entrar'); setAviso({ tipo: 'ok', texto: 'Cerraste la sesión.' }); });

  const inicial = (sesion?.usuario.nombre || sesion?.usuario.correo || '?').trim().charAt(0).toLocaleUpperCase('es-CO');
  const titulo = { entrar: 'Inicia sesión', crear: 'Crea tu cuenta', olvido: 'Recupera tu contraseña', nueva_clave: 'Contraseña nueva', perfil: sesion?.usuario.nombre ?? 'Tu perfil' }[vista];
  const campoClave = (autocompletar: string) => <Campo id="cuenta-clave" etiqueta={vista === 'nueva_clave' ? 'Contraseña nueva' : 'Contraseña'} error={errores.clave} ayuda={vista === 'entrar' ? undefined : 'Al menos 8 caracteres.'}>
    <div className="cuenta-clave">
      <input id="cuenta-clave" name="password" type={verClave ? 'text' : 'password'} autoComplete={autocompletar} value={clave} onChange={(e) => setClave(e.target.value)} aria-invalid={Boolean(errores.clave)} aria-describedby={errores.clave ? 'cuenta-clave-error' : undefined} />
      <button type="button" className="cuenta-ver" onClick={() => setVerClave((v) => !v)} aria-label={verClave ? 'Ocultar la contraseña' : 'Mostrar la contraseña'} aria-pressed={verClave}>{verClave ? <EyeOff aria-hidden="true" /> : <Eye aria-hidden="true" />}</button>
    </div>
  </Campo>;
  const campoCorreo = <Campo id="cuenta-correo" etiqueta="Correo" error={errores.correo}>
    <input id="cuenta-correo" name="email" type="email" inputMode="email" autoComplete="email" value={correo} onChange={(e) => setCorreo(e.target.value)} aria-invalid={Boolean(errores.correo)} aria-describedby={errores.correo ? 'cuenta-correo-error' : undefined} />
  </Campo>;
  const campoNombre = <Campo id="cuenta-nombre" etiqueta="Nombre" error={errores.nombre}>
    <input id="cuenta-nombre" name="name" autoComplete="name" value={nombre} onChange={(e) => setNombre(e.target.value)} aria-invalid={Boolean(errores.nombre)} aria-describedby={errores.nombre ? 'cuenta-nombre-error' : undefined} />
  </Campo>;
  const campoSector = <Campo id="cuenta-sector" etiqueta="Tu sector del manglar (opcional)">
    <select id="cuenta-sector" value={sector} onChange={(e) => setSector(e.target.value)}>
      <option value="">Sin elegir</option>
      {SECTORES_CUENTA.map((s) => <option key={s} value={s}>{s}</option>)}
    </select>
  </Campo>;

  return <>
    <button type="button" className={`cuenta-boton cuenta-${contexto}`} onClick={() => abrir(sesion ? 'perfil' : 'entrar')} aria-haspopup="dialog"
      aria-label={sesion ? `Mi cuenta: ${sesion.usuario.nombre}` : 'Iniciar sesión o crear cuenta'} title={sesion ? `Mi cuenta: ${sesion.usuario.nombre}` : 'Iniciar sesión o crear cuenta'}>
      {sesion ? <span className="cuenta-inicial" aria-hidden="true">{inicial}</span> : <CircleUserRound aria-hidden="true" />}
    </button>

    <dialog ref={dialogo} className="cuenta-dialogo" aria-labelledby="cuenta-titulo" onClick={(e) => { if (e.target === e.currentTarget) cerrar(); }}>
      <div className="cuenta-caja">
        <button type="button" className="cuenta-cerrar" onClick={cerrar} aria-label="Cerrar"><X aria-hidden="true" /></button>
        <div className="cuenta-cab">
          {vista === 'perfil' ? <span className="cuenta-avatar" aria-hidden="true">{inicial}</span> : <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={56} height={56} />}
          <div>
            <p className="cuenta-kicker">{vista === 'perfil' ? 'Tu perfil' : destino ? 'Antes de reportar' : 'Tu cuenta'}</p>
            <h2 id="cuenta-titulo" className="cuenta-titulo">{titulo}</h2>
            {vista === 'perfil' && sesion && <p className="cuenta-sub">{sesion.usuario.correo}{sesion.usuario.creado_en ? ` · desde el ${fecha(sesion.usuario.creado_en)}` : ''}</p>}
          </div>
        </div>

        {destino && !sesion && <div className="cuenta-reportar">
          <p>No necesitas cuenta para reportar. Con una, sigues tus reportes y sumas como guardián del manglar.</p>
          <button type="button" className="cuenta-btn cuenta-btn-claro" onClick={seguirSinCuenta}>Seguir sin cuenta <span aria-hidden="true">→</span></button>
        </div>}

        {!cuentasActivas && <p className="cuenta-aviso cuenta-aviso-error">Las cuentas se activan cuando la web está conectada al servidor. Mientras tanto puedes reportar sin cuenta.</p>}

        {(vista === 'entrar' || vista === 'crear') && <div className="cuenta-pestanas" role="tablist" aria-label="Iniciar sesión o crear cuenta">
          <button type="button" role="tab" aria-selected={vista === 'entrar'} onClick={() => cambiar('entrar')}>Iniciar sesión</button>
          <button type="button" role="tab" aria-selected={vista === 'crear'} onClick={() => cambiar('crear')}>Crear cuenta</button>
        </div>}

        <form className="cuenta-form" onSubmit={enviar} noValidate>
          {vista === 'entrar' && <>{campoCorreo}{campoClave('current-password')}
            <button type="button" className="cuenta-enlace" onClick={() => cambiar('olvido')}>¿Olvidaste tu contraseña?</button></>}
          {vista === 'crear' && <>{campoNombre}{campoCorreo}{campoClave('new-password')}{campoSector}
            <div className="cuenta-campo">
              <label className="cuenta-check"><input type="checkbox" checked={acepta} onChange={(e) => setAcepta(e.target.checked)} aria-invalid={Boolean(errores.acepta)} aria-describedby={errores.acepta ? 'cuenta-acepta-error' : undefined} />
                <span>Acepto que la C.R.A. y el equipo Zanky traten mi nombre, correo y sector para gestionar mi cuenta y mis reportes, según la Ley 1581 de 2012. No se publican; puedo consultarlos y corregirlos en mi perfil.</span></label>
              {errores.acepta && <span className="cuenta-error" id="cuenta-acepta-error">{errores.acepta}</span>}
            </div></>}
          {vista === 'olvido' && <>{campoCorreo}<button type="button" className="cuenta-enlace" onClick={() => cambiar('entrar')}>← Volver a iniciar sesión</button></>}
          {vista === 'nueva_clave' && campoClave('new-password')}
          {vista === 'perfil' && <>{campoNombre}{campoSector}</>}

          {aviso && <p className={`cuenta-aviso cuenta-aviso-${aviso.tipo}`} role={aviso.tipo === 'error' ? 'alert' : 'status'}>{aviso.texto}</p>}

          <button type="submit" className="cuenta-btn cuenta-btn-dorado" disabled={ocupado || !cuentasActivas}>
            {ocupado ? 'Un momento…' : { entrar: 'Entrar', crear: 'Crear mi cuenta', olvido: 'Enviar el enlace', nueva_clave: 'Guardar contraseña', perfil: 'Guardar cambios' }[vista]}
          </button>
        </form>

        {vista === 'perfil' && <div className="cuenta-perfil">
          <nav aria-label="Atajos de tu cuenta" className="cuenta-atajos">
            <a href="/#reportar" onClick={cerrar}>Reportar un problema</a>
            <a href="/plataforma/jornadas">Jornadas de tu comunidad</a>
            <a href="/plataforma/registro">¿Representas una organización? Regístrala como actor</a>
          </nav>
          <button type="button" className="cuenta-btn cuenta-btn-claro" onClick={() => cambiar('nueva_clave')}>Cambiar contraseña</button>
          <button type="button" className="cuenta-btn cuenta-btn-salir" onClick={salir} disabled={ocupado}><LogOut aria-hidden="true" />Cerrar sesión</button>
        </div>}
      </div>
    </dialog>
  </>;
}
