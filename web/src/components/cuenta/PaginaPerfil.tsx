// Página del perfil (/perfil). Dos columnas: la tarjeta de identidad a la izquierda (acompaña al bajar en
// pantalla ancha) y a la derecha lo que se viene a mirar o cambiar: las próximas jornadas, los datos de la
// cuenta (#datos) y la seguridad (#seguridad). Sin sesión, invita a entrar con el panel de la cabecera.
import { useEffect, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { CalendarDays, Check, Eye, EyeOff, LogOut, MapPin, MessageCircle, ShieldCheck, Users } from 'lucide-react';
import type { Jornada } from '../../types/plataforma';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { useJornadas } from '../../lib/plataforma/estado';
import {
  ErrorCuenta, SECTORES_CUENTA, actualizarPerfil, cambiarClave, celularLegible, cerrarSesion, cuentasActivas,
  normalizarCelular, rolDeAdmin, useSesion,
} from '../../lib/cuenta';
import { cn } from '../../lib/utils';

const zona = { timeZone: 'America/Bogota' } as const;
const capital = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
const mesAnio = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, month: 'long', year: 'numeric' }).format(new Date(iso));
const fechaJornada = (iso: string) => capital(new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', day: 'numeric', month: 'long', hour: 'numeric', minute: '2-digit' }).format(new Date(iso)));

const campo = 'min-h-12 w-full rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none aria-[invalid=true]:border-alta';
const boton = (tono: 'dorado' | 'claro' | 'salir' = 'claro') => cn(
  'inline-flex min-h-12 items-center justify-center gap-2 rounded-full px-6 text-sm font-bold transition-colors disabled:cursor-not-allowed disabled:opacity-55',
  tono === 'dorado' && 'bg-dorado-500 text-cra-950 hover:bg-dorado-300',
  tono === 'claro' && 'border border-linea bg-white/5 text-texto hover:border-dorado-300 hover:text-dorado-300',
  tono === 'salir' && 'border border-alta/40 text-alta-texto hover:bg-alta/10',
);

type Aviso = { tipo: 'ok' | 'error'; texto: string } | null;
function Aviso({ aviso }: { aviso: Aviso }) {
  if (!aviso) return null;
  return <p role={aviso.tipo === 'error' ? 'alert' : 'status'} className={cn('rounded-2xl px-4 py-3 text-sm', aviso.tipo === 'ok' ? 'bg-baja/15 text-baja-texto' : 'bg-alta/15 text-alta-texto')}>{aviso.texto}</p>;
}

function Seccion({ id, titulo, descripcion, children }: { id: string; titulo: string; descripcion?: string; children: ReactNode }) {
  return <section id={id} aria-labelledby={`${id}-titulo`} className="scroll-mt-28">
    <h2 id={`${id}-titulo`} className="titular text-2xl sm:text-3xl">{titulo}</h2>
    {descripcion && <p className="mt-1 max-w-2xl text-suave">{descripcion}</p>}
    <div className="mt-5">{children}</div>
  </section>;
}

function Etiqueta({ id, texto, error, ayuda, children }: { id: string; texto: string; error?: string; ayuda?: string; children: ReactNode }) {
  return <div className="grid gap-1.5">
    <label htmlFor={id} className="text-sm font-semibold text-suave">{texto}</label>
    {children}
    {ayuda && !error && <span className="text-xs text-tenue">{ayuda}</span>}
    {error && <span id={`${id}-error`} className="text-sm font-semibold text-alta-texto">{error}</span>}
  </div>;
}

export default function PaginaPerfil({ jornadas: iniciales }: { jornadas: Jornada[] }) {
  const sesion = useSesion();
  const jornadas = useJornadas(iniciales);
  const [admin, setAdmin] = useState<{ correo: string; rol: string } | null>(null);
  const [bienvenida, setBienvenida] = useState(false);
  // Tus datos
  const [nombre, setNombre] = useState('');
  const [celular, setCelular] = useState('');
  const [whatsappOk, setWhatsappOk] = useState(false);
  const [sector, setSector] = useState('');
  const [errores, setErrores] = useState<Record<string, string>>({});
  const [avisoDatos, setAvisoDatos] = useState<Aviso>(null);
  const [guardando, setGuardando] = useState(false);
  // Seguridad
  const [clave, setClave] = useState('');
  const [verClave, setVerClave] = useState(false);
  const [errorClave, setErrorClave] = useState('');
  const [avisoClave, setAvisoClave] = useState<Aviso>(null);
  const [cambiando, setCambiando] = useState(false);

  const usuario = sesion?.usuario ?? null;

  // El formulario arranca con lo que hay en la cuenta (y se rehace si cambia de cuenta).
  useEffect(() => {
    if (!usuario) return;
    setNombre(usuario.nombre); setSector(usuario.sector ?? '');
    setCelular(celularLegible(usuario.telefono)); setWhatsappOk(usuario.whatsapp_ok);
    setErrores({}); setAvisoDatos(null);
    let vigente = true;
    void rolDeAdmin().then((r) => { if (vigente) setAdmin(r); }).catch(() => { if (vigente) setAdmin(null); });
    return () => { vigente = false; };
  }, [usuario?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  // ?bienvenida=1 llega del enlace que confirma el correo; el #datos del menú se respeta al cargar.
  useEffect(() => {
    const p = new URLSearchParams(location.search);
    if (p.get('bienvenida') === '1') { setBienvenida(true); history.replaceState(null, '', location.pathname + location.hash); }
    if (location.hash) requestAnimationFrame(() => document.querySelector(location.hash)?.scrollIntoView());
  }, []);

  const proximas = useMemo(() => jornadas.filter((j) => Date.parse(j.fin) > Date.now()).sort((a, b) => a.inicio.localeCompare(b.inicio)), [jornadas]);

  if (!usuario) {
    return <div className="mx-auto grid max-w-xl justify-items-center gap-5 rounded-[2rem] border border-linea-suave bg-superficie p-8 text-center sm:p-12">
      <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={112} height={112} className="size-28 object-contain" />
      <h1 className="titular text-3xl sm:text-4xl">Tu perfil en Zanky</h1>
      <p className="text-suave">Inicia sesión para ver tus datos, las jornadas de tu comunidad y, si administras la plataforma, el panel de administración.</p>
      {cuentasActivas
        ? <button type="button" onClick={() => window.dispatchEvent(new Event('zanky-cuenta:abrir'))} className={boton('dorado')}>Iniciar sesión o crear cuenta</button>
        : <p className="text-sm text-tenue">Las cuentas se activan cuando la web está conectada al servidor.</p>}
      <a href="/#reportar" className="text-sm font-semibold text-dorado-300 hover:underline">Reportar un problema sin cuenta →</a>
    </div>;
  }

  const inicial = (usuario.nombre || usuario.correo || '?').trim().charAt(0).toLocaleUpperCase('es-CO');
  const dias = usuario.creado_en ? Math.max(1, Math.ceil((Date.now() - Date.parse(usuario.creado_en)) / 86_400_000)) : null;
  const cupos = proximas.reduce((n, j) => n + Math.max(0, j.cupos - j.inscritos), 0);
  const cifras = [
    { valor: proximas.length, etiqueta: proximas.length === 1 ? 'jornada próxima' : 'jornadas próximas' },
    { valor: cupos, etiqueta: cupos === 1 ? 'cupo libre' : 'cupos libres' },
    { valor: dias ?? '—', etiqueta: dias === 1 ? 'día en Zanky' : 'días en Zanky' },
  ];

  function guardarDatos(e: FormEvent) {
    e.preventDefault();
    const er: Record<string, string> = {};
    if (nombre.trim().length < 2) er.nombre = 'Escribe tu nombre.';
    const tel = normalizarCelular(celular);
    if (tel === 'invalido') er.celular = 'Revisa el celular: escribe los 10 dígitos, por ejemplo 300 123 4567.';
    else if (whatsappOk && !tel) er.celular = 'Para recibir invitaciones por WhatsApp, escribe tu celular.';
    setErrores(er); setAvisoDatos(null);
    if (Object.keys(er).length) return;
    setGuardando(true);
    actualizarPerfil({ nombre, sector: sector || null, telefono: tel === 'invalido' ? null : tel, whatsappOk })
      .then(() => setAvisoDatos({ tipo: 'ok', texto: 'Cambios guardados.' }))
      .catch((err: unknown) => setAvisoDatos({ tipo: 'error', texto: err instanceof ErrorCuenta ? err.message : 'No se pudieron guardar los cambios. Inténtalo de nuevo.' }))
      .finally(() => setGuardando(false));
  }

  function guardarClave(e: FormEvent) {
    e.preventDefault();
    setAvisoClave(null);
    if (clave.length < 8) { setErrorClave('Usa al menos 8 caracteres.'); return; }
    setErrorClave(''); setCambiando(true);
    cambiarClave(clave)
      .then(() => { setClave(''); setAvisoClave({ tipo: 'ok', texto: 'Contraseña cambiada.' }); })
      .catch((err: unknown) => setAvisoClave({ tipo: 'error', texto: err instanceof ErrorCuenta ? err.message : 'No se pudo cambiar la contraseña. Inténtalo de nuevo.' }))
      .finally(() => setCambiando(false));
  }

  return <div className="grid gap-8 lg:grid-cols-[340px_minmax(0,1fr)] lg:gap-12">
    <aside className="lg:sticky lg:top-28 lg:self-start">
      <div className="rounded-[2rem] border border-linea-suave bg-superficie p-6 shadow-[var(--c-sombra-alta)]">
        <span aria-hidden="true" className="grid size-28 place-items-center rounded-full bg-dorado-500 font-titulo text-5xl font-extrabold text-cra-950">{inicial}</span>
        <h1 className="titular mt-5 text-3xl break-words">{usuario.nombre}</h1>
        <p className="mt-1 text-sm break-all text-suave">{usuario.correo}</p>
        <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1">
          <a href="#datos" className="inline-flex min-h-11 items-center text-sm font-semibold text-dorado-300 hover:underline">Editar perfil</a>
          {admin && <a href="/admin" className="inline-flex min-h-11 items-center gap-1.5 text-sm font-semibold text-suave hover:text-texto"><ShieldCheck className="size-4 text-dorado-500" aria-hidden="true" />Administración</a>}
        </div>
        <ul className="mt-3 grid gap-2.5 text-sm text-suave">
          {usuario.creado_en && <li className="flex items-center gap-2"><CalendarDays className="size-4 shrink-0" aria-hidden="true" />Se unió en {mesAnio(usuario.creado_en)}</li>}
          <li className="flex items-center gap-2"><MapPin className="size-4 shrink-0" aria-hidden="true" />{usuario.sector ? `Sector ${usuario.sector}` : 'Sin sector elegido'}</li>
          <li className="flex items-start gap-2"><MessageCircle className="mt-0.5 size-4 shrink-0" aria-hidden="true" />{usuario.whatsapp_ok ? `Recibe invitaciones por WhatsApp al ${celularLegible(usuario.telefono)}` : 'No recibe invitaciones por WhatsApp'}</li>
          {admin && <li className="flex items-center gap-2"><ShieldCheck className="size-4 shrink-0" aria-hidden="true" />Rol: {admin.rol.replace(/_/g, ' ')}</li>}
        </ul>
        <div className="mt-6 grid grid-cols-3 gap-2 border-t border-linea-suave pt-5 text-center">
          {cifras.map((c) => <div key={c.etiqueta} className="min-w-0">
            <p className="titular text-2xl tabular-nums">{c.valor}</p>
            <p className="mt-0.5 text-xs leading-tight text-tenue">{c.etiqueta}</p>
          </div>)}
        </div>
      </div>
    </aside>

    <div className="grid min-w-0 content-start gap-12">
      {bienvenida && <Aviso aviso={{ tipo: 'ok', texto: `¡Bienvenido, ${usuario.nombre}! Tu correo quedó confirmado y ya tienes cuenta.` }} />}

      <Seccion id="jornadas" titulo="Próximas jornadas" descripcion="Lo que organiza tu comunidad en el manglar. Inscríbete desde la invitación.">
        {proximas.length === 0 ? <p className="rounded-3xl border border-dashed border-linea p-8 text-center text-suave">No hay jornadas próximas por ahora.</p> : <ul className="grid gap-3">
          {proximas.slice(0, 4).map((j) => {
            const libres = Math.max(0, j.cupos - j.inscritos);
            return <li key={j.id}>
              <a href={`/plataforma/jornadas?jornada=${encodeURIComponent(j.id)}`} className="group flex items-center gap-4 rounded-3xl border border-linea-suave bg-superficie p-3 transition-colors hover:border-dorado-300/60">
                <div className="size-20 shrink-0 overflow-hidden rounded-2xl bg-white/5">
                  {j.imagen_url ? <img src={j.imagen_url} alt="" loading="lazy" className="size-full object-cover" /> : <div className="grid size-full place-items-center text-tenue"><CalendarDays className="size-7" aria-hidden="true" /></div>}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm text-dorado-300">{fechaJornada(j.inicio)}</p>
                  <p className="mt-0.5 truncate font-bold text-texto group-hover:text-dorado-300">{j.titulo}</p>
                  <p className="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 text-sm text-suave">
                    <span className="inline-flex min-w-0 items-center gap-1"><MapPin className="size-3.5 shrink-0" aria-hidden="true" /><span className="truncate">{j.punto_encuentro}</span></span>
                    <span className="inline-flex items-center gap-1"><Users className="size-3.5 shrink-0" aria-hidden="true" />{libres === 0 ? 'Sin cupos' : `${libres} ${libres === 1 ? 'cupo' : 'cupos'}`}</span>
                    <span>{TIPOS_JORNADA[j.tipo]?.etiqueta ?? j.tipo}</span>
                  </p>
                </div>
              </a>
            </li>;
          })}
        </ul>}
        <a href="/plataforma/jornadas" className="mt-4 inline-flex min-h-11 items-center text-sm font-semibold text-dorado-300 hover:underline">Ver todas las jornadas →</a>
      </Seccion>

      <Seccion id="datos" titulo="Tus datos" descripcion="Tu nombre y tu sector ayudan a la C.R.A. a ordenar los reportes. El celular es solo para invitaciones y no se publica.">
        <form onSubmit={guardarDatos} noValidate className="grid gap-5 rounded-[2rem] border border-linea-suave bg-superficie p-5 sm:p-7">
          <div className="grid gap-5 sm:grid-cols-2">
            <Etiqueta id="perfil-nombre" texto="Nombre" error={errores.nombre}>
              <input id="perfil-nombre" autoComplete="name" className={campo} value={nombre} onChange={(e) => setNombre(e.target.value)} aria-invalid={Boolean(errores.nombre)} aria-describedby={errores.nombre ? 'perfil-nombre-error' : undefined} />
            </Etiqueta>
            <Etiqueta id="perfil-correo" texto="Correo" ayuda="El correo de la cuenta no se cambia desde aquí.">
              <input id="perfil-correo" className={cn(campo, 'cursor-not-allowed opacity-70')} value={usuario.correo} readOnly />
            </Etiqueta>
            <Etiqueta id="perfil-celular" texto="Celular (WhatsApp, opcional)" error={errores.celular} ayuda="Solo para invitaciones a jornadas. No se publica.">
              <input id="perfil-celular" type="tel" inputMode="tel" autoComplete="tel" maxLength={20} placeholder="300 123 4567" className={campo} value={celular}
                onChange={(e) => { setCelular(e.target.value); if (!e.target.value.trim()) setWhatsappOk(false); }}
                aria-invalid={Boolean(errores.celular)} aria-describedby={errores.celular ? 'perfil-celular-error' : undefined} />
            </Etiqueta>
            <Etiqueta id="perfil-sector" texto="Tu sector del manglar (opcional)">
              <select id="perfil-sector" className={campo} value={sector} onChange={(e) => setSector(e.target.value)}>
                <option value="">Sin elegir</option>
                {SECTORES_CUENTA.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </Etiqueta>
          </div>
          <label className={cn('flex cursor-pointer items-start gap-3 text-sm text-suave', !celular.trim() && 'cursor-not-allowed opacity-55')}>
            <input type="checkbox" className="mt-0.5 size-5 shrink-0 accent-dorado-500" checked={whatsappOk} disabled={!celular.trim()} onChange={(e) => setWhatsappOk(e.target.checked)} />
            <span>Acepto recibir por WhatsApp invitaciones a jornadas e información del manglar. Puedo retirarlo aquí cuando quiera.</span>
          </label>
          <Aviso aviso={avisoDatos} />
          <button type="submit" disabled={guardando || !cuentasActivas} className={cn(boton('dorado'), 'justify-self-start')}><Check className="size-4" aria-hidden="true" />{guardando ? 'Guardando…' : 'Guardar cambios'}</button>
        </form>
      </Seccion>

      <Seccion id="seguridad" titulo="Seguridad">
        <div className="grid gap-5 rounded-[2rem] border border-linea-suave bg-superficie p-5 sm:p-7">
          <form onSubmit={guardarClave} noValidate className="grid gap-4 sm:max-w-md">
            <Etiqueta id="perfil-clave" texto="Contraseña nueva" error={errorClave} ayuda="Al menos 8 caracteres.">
              <div className="relative">
                <input id="perfil-clave" type={verClave ? 'text' : 'password'} autoComplete="new-password" className={cn(campo, 'pr-14')} value={clave} onChange={(e) => setClave(e.target.value)}
                  aria-invalid={Boolean(errorClave)} aria-describedby={errorClave ? 'perfil-clave-error' : undefined} />
                <button type="button" onClick={() => setVerClave((v) => !v)} aria-label={verClave ? 'Ocultar la contraseña' : 'Mostrar la contraseña'} aria-pressed={verClave}
                  className="absolute top-0.5 right-0.5 grid size-11 place-items-center rounded-2xl text-tenue hover:text-texto">{verClave ? <EyeOff className="size-5" aria-hidden="true" /> : <Eye className="size-5" aria-hidden="true" />}</button>
              </div>
            </Etiqueta>
            <Aviso aviso={avisoClave} />
            <button type="submit" disabled={cambiando} className={cn(boton(), 'justify-self-start')}>{cambiando ? 'Cambiando…' : 'Cambiar contraseña'}</button>
          </form>
          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-linea-suave pt-5">
            <p className="text-sm text-suave">¿Usas un computador compartido? Cierra la sesión al terminar.</p>
            <button type="button" onClick={() => void cerrarSesion()} className={boton('salir')}><LogOut className="size-4" aria-hidden="true" />Cerrar sesión</button>
          </div>
        </div>
      </Seccion>
    </div>
  </div>;
}
