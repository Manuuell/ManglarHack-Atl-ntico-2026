// Ficha de una jornada, con la forma de la ficha de un evento de Innvita: a la izquierda el título,
// quién publica, la acción a la que pertenece y los detalles; a la derecha la imagen y los datos duros
// (cuándo, dónde, entrada, inscritos y compartir), pegados al bajar; abajo «Te puede interesar» y una
// barra fija con «Asistir». Las jornadas no tienen límite de cupos.
// Se abre en /plataforma/jornada?id=<id> (urlInvitacion); las jornadas salen del servidor de Zanky.
import { useEffect, useRef, useState, type FormEvent, type MouseEvent, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import {
  ArrowLeft, ArrowRight, CalendarDays, CalendarPlus, Check, ChevronRight, Copy, Download, MapPin, MessageCircle,
  Navigation, Printer, Share2, SquareArrowOutUpRight, Ticket, Users, type LucideIcon,
} from 'lucide-react';
import type { Accion, Jornada } from '../../types/plataforma';
import { useAcciones, useInscripciones, useJornadas } from '../../lib/plataforma/estado';
import { inscribirseEnServidor, normalizarCelular, useOrigenJornadas, type OrigenJornadas } from '../../lib/plataforma/jornadasApi';
import { useSesion } from '../../lib/cuenta';
import { TIPOS_ACCION, TIPOS_JORNADA } from '../../lib/plataforma/catalogos';
import { copiarEnlace, descargarICS, enlaceInvitacionWhatsApp } from '../../lib/plataforma/calendario';
import { enlaceComoLlegar, enlaceGoogleCalendar, fmt, urlEventoZanky, urlInvitacion } from '../../lib/plataforma/jornadas';
import { cn } from '../../lib/utils';
import L from 'leaflet';
import { MapContainer, Marker, TileLayer, ZoomControl } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import '../../styles/mapa.css';
import AvisoZanky from '../marca/AvisoZanky';
import { Banner, BotonCompartir, TarjetaJornada, capital, estaPasada, textoInscritos, useQr } from './piezas';
import '../../styles/cartel-jornada.css';

interface Props { jornadas: Jornada[]; acciones: Accion[]; aviso: string }

const RECOMENDADAS = 3;

/** Distancia aproximada en km (para saber si dos puntos de encuentro quedan cerca). */
function distanciaKm(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const k = Math.cos(((a.lat + b.lat) / 2) * Math.PI / 180);
  return Math.hypot((a.lat - b.lat) * 111.32, (a.lon - b.lon) * 111.32 * k);
}

/** Las próximas jornadas que más se parecen a esta: misma acción, mismo tipo y punto cercano; empata la fecha. */
function recomendar(j: Jornada, lista: Jornada[]): Jornada[] {
  return lista
    .filter((o) => o.id !== j.id && !estaPasada(o))
    .map((o) => {
      let afinidad = 0;
      if (o.accion_id && o.accion_id === j.accion_id) afinidad += 4;
      if (o.tipo === j.tipo) afinidad += 2;
      if (distanciaKm(o, j) <= 5) afinidad += 1;
      return { o, afinidad };
    })
    .sort((a, b) => b.afinidad - a.afinidad || a.o.inicio.localeCompare(b.o.inicio))
    .slice(0, RECOMENDADAS)
    .map((x) => x.o);
}

const PIN_ENCUENTRO = L.divIcon({
  className: 'pin-encuentro', iconSize: [34, 34], iconAnchor: [17, 34],
  html: '<span style="display:grid;place-items:center;width:34px;height:34px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:var(--color-dorado-500);border:3px solid #fff;box-shadow:0 3px 8px rgb(0 0 0 / .45)"><span style="transform:rotate(45deg);font-size:15px">🌱</span></span>',
});

/** Mapa pequeño del punto de encuentro (sin rueda del ratón, para no atrapar el desplazamiento de la página). */
function MapaPunto({ j }: { j: Jornada }) {
  return (
    <MapContainer center={[j.lat, j.lon]} zoom={15} scrollWheelZoom={false} zoomControl={false} className="h-72 w-full">
      <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} attribution='&copy; <a href="https://www.openstreetmap.org/copyright">colaboradores de OpenStreetMap</a>' />
      <ZoomControl position="bottomright" zoomInTitle="Acercar" zoomOutTitle="Alejar" />
      <Marker position={[j.lat, j.lon]} icon={PIN_ENCUENTRO} title={`Punto de encuentro: ${j.punto_encuentro}`} alt={`Punto de encuentro: ${j.punto_encuentro}`} />
    </MapContainer>
  );
}

/** Aviso de la ficha: «Datos de ejemplo» en las jornadas de ejemplo del servidor; sin servidor, el del respaldo. */
const avisoDeJornada = (j: Jornada, aviso: string, origen: OrigenJornadas) => (origen === 'servidor' ? (j.ejemplo ? 'Datos de ejemplo de la demostración.' : '') : origen === 'respaldo' ? `${aviso}. Sin conexión con el servidor de jornadas: lo que hagas queda solo en este navegador.` : '');

export default function FichaJornada(props: Props) {
  const lista = useJornadas(props.jornadas);
  const acciones = useAcciones(props.acciones);
  const inscripciones = useInscripciones();
  const { origen } = useOrigenJornadas();
  const [id] = useState(() => new URLSearchParams(window.location.search).get('id'));
  const j = lista.find((x) => x.id === id);

  useEffect(() => { if (j) document.title = `${j.titulo} · Jornadas del manglar`; }, [j]);

  if (!j) {
    if (id && origen === 'cargando') return <p role="status" className="mx-auto max-w-6xl px-4 py-24 text-center text-suave sm:px-6">Cargando la jornada…</p>;
    return (
      <div className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
        <AvisoZanky animo="preocupado" forma="bloque" className="rounded-3xl border border-dashed border-linea p-10" titulo="No encontramos esta jornada">
          <p>Puede que el enlace esté incompleto o que la jornada ya no esté publicada.</p>
          <a href="/plataforma/jornadas" className="mt-4 inline-flex min-h-11 items-center gap-2 rounded-full bg-dorado-500 px-5 font-bold text-cra-950 hover:bg-dorado-300">Ver todas las jornadas<ArrowRight className="size-4" aria-hidden="true" /></a>
        </AvisoZanky>
      </div>
    );
  }
  const inscrito = (otra: string) => inscripciones.some((i) => i.jornada_id === otra);
  return <Ficha j={j} accion={acciones.find((a) => a.id === j.accion_id)} inscrito={inscrito(j.id)} inscritoEn={inscrito}
    aviso={avisoDeJornada(j, props.aviso, origen)} origen={origen} recomendadas={recomendar(j, lista)} />;
}

function Titulo({ id, children }: { id?: string; children: ReactNode }) {
  return <>
    <h2 id={id} className="titular text-2xl sm:text-3xl">{children}</h2>
    <span className="mt-2 block h-1 w-14 rounded-full bg-dorado-500" aria-hidden="true" />
  </>;
}

function Fila({ icono: Icono, titulo, detalle, accion }: { icono: LucideIcon; titulo: ReactNode; detalle?: ReactNode; accion?: ReactNode }) {
  return (
    <div className="flex items-start gap-4 p-5">
      <span className="grid size-11 shrink-0 place-items-center rounded-full bg-dorado-500/15 text-dorado-300"><Icono className="size-5" aria-hidden="true" /></span>
      <div className="min-w-0 flex-1">
        <p className="font-semibold text-texto">{titulo}</p>
        {detalle && <p className="text-sm text-suave">{detalle}</p>}
      </div>
      {accion}
    </div>
  );
}

const botonIcono = 'grid size-11 shrink-0 place-items-center rounded-full text-tenue transition-colors hover:bg-white/10 hover:text-texto';

function Ficha({ j, accion, inscrito, inscritoEn, aviso, origen, recomendadas }: {
  j: Jornada; accion?: Accion; inscrito: boolean; inscritoEn: (id: string) => boolean; aviso: string; origen: OrigenJornadas; recomendadas: Jornada[];
}) {
  const T = TIPOS_JORNADA[j.tipo];
  const pasada = estaPasada(j);
  const url = urlInvitacion(j.id);
  const urlZanky = urlEventoZanky(j.id);
  const qr = useQr(url);
  const qrZanky = useQr(urlZanky);
  const sesion = useSesion();
  const [nombre, setNombre] = useState(() => sesion?.usuario.nombre ?? '');
  const [celular, setCelular] = useState(() => sesion?.usuario.telefono ?? '');
  const [conWhatsapp, setConWhatsapp] = useState(() => Boolean(sesion?.usuario.whatsapp_ok));
  const [acepta, setAcepta] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  const [mensaje, setMensaje] = useState<{ ok: boolean; texto: string } | null>(null);
  const [copiado, setCopiado] = useState(false);
  const campoNombre = useRef<HTMLInputElement>(null);
  const puedeCompartir = typeof navigator !== 'undefined' && typeof navigator.share === 'function';
  const va = inscrito || Boolean(mensaje?.ok);
  const tipoAccion = accion ? TIPOS_ACCION[accion.tipo] : null;

  async function confirmar(e: FormEvent) {
    e.preventDefault();
    if (ocupado) return;
    if (nombre.trim().length < 3) { setMensaje({ ok: false, texto: 'Escribe tu nombre para la lista (al menos 3 letras).' }); return; }
    const telefono = normalizarCelular(celular);
    if (telefono === 'invalido') { setMensaje({ ok: false, texto: 'Revisa el celular: escribe los 10 dígitos, por ejemplo 300 123 4567.' }); return; }
    if (!acepta) { setMensaje({ ok: false, texto: 'Para inscribirte, acepta el tratamiento de tus datos (Ley 1581).' }); return; }
    setOcupado(true);
    const r = await inscribirseEnServidor(j, { nombre, telefono, acepta_whatsapp: conWhatsapp });
    setOcupado(false);
    if (!r.ok) { setMensaje({ ok: false, texto: Object.values(r.errores)[0] ?? 'No se pudo inscribir.' }); return; }
    setMensaje({ ok: true, texto: r.enServidor ? '¡Listo! Quedaste en la lista. Te esperamos.' : '¡Listo! Quedaste en la lista de este navegador (sin conexión con el servidor).' });
  }

  async function copiar() {
    setCopiado(await copiarEnlace(url));
    setTimeout(() => setCopiado(false), 2200);
  }
  function compartir() {
    if (puedeCompartir) navigator.share({ title: j.titulo, text: `Te invito: ${j.titulo}`, url }).catch(() => {});
    else void copiar();
  }
  /** «Asistir» de la barra: lleva a la inscripción y pone el cursor en el nombre. */
  function irAInscribirse(e: MouseEvent) {
    e.preventDefault();
    const reducido = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    document.getElementById('inscribirse')?.scrollIntoView({ behavior: reducido ? 'auto' : 'smooth', block: 'start' });
    window.setTimeout(() => campoNombre.current?.focus({ preventScroll: true }), reducido ? 0 : 450);
  }

  return (
    <>
      <div className="mx-auto max-w-6xl px-4 pt-6 pb-16 sm:px-6">
        <a href="/plataforma/jornadas" className="inline-flex min-h-11 items-center gap-1.5 text-sm font-semibold text-suave hover:text-texto"><ArrowLeft className="size-4" aria-hidden="true" />Todas las jornadas</a>

        {/* En el teléfono es una columna: título, imagen y datos, detalles. En escritorio, la columna derecha se pega al bajar. */}
        <div className="mt-4 grid grid-cols-1 gap-x-12 gap-y-10 lg:grid-cols-12 lg:grid-rows-[auto_1fr]">
          <header className="min-w-0 lg:order-1 lg:col-span-7">
            <p className={cn('rotulo flex items-center gap-1.5', T.clase)}><T.icono className="size-3.5" aria-hidden="true" />{T.etiqueta} · Jornada comunitaria</p>
            <h1 className="titular mt-3 text-4xl sm:text-5xl">{j.titulo}</h1>
            {aviso && <p className="mt-4 rounded-2xl border border-white/15 bg-white/5 px-4 py-2 text-xs text-suave">{aviso}</p>}

            <div className="mt-6 flex items-center gap-3">
              <img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={44} height={44} className="size-11 shrink-0 rounded-full bg-dorado-500/15 object-contain p-0.5" />
              <div className="min-w-0">
                <p className="text-xs text-tenue">Publicado por</p>
                <p className="font-semibold text-texto">Zanky · plataforma del manglar del Atlántico</p>
              </div>
            </div>

            {accion && tipoAccion && (
              <a href={`/plataforma/seguimiento?accion=${accion.id}`} className="mt-5 flex items-center gap-4 rounded-2xl border border-linea bg-superficie p-3 transition-colors hover:border-dorado-300">
                <span className={cn('grid size-14 shrink-0 place-items-center rounded-xl', tipoAccion.clase)}><tipoAccion.icono className="size-6" aria-hidden="true" /></span>
                <span className="min-w-0 flex-1">
                  <span className="block text-xs text-tenue">Hace parte de la acción</span>
                  <span className="block truncate font-semibold text-texto">{accion.nombre}</span>
                </span>
                <ChevronRight className="size-5 shrink-0 text-tenue" aria-hidden="true" />
              </a>
            )}
          </header>

          <aside className="min-w-0 lg:order-2 lg:col-span-5 lg:row-span-2" aria-label="Datos de la jornada">
            <div className="lg:sticky lg:top-24">
              <Banner j={j} grande className="aspect-[16/9] rounded-3xl shadow-[var(--c-sombra)]" />
              <div className="mt-5 overflow-hidden rounded-3xl border border-linea bg-superficie shadow-[var(--c-sombra-alta)]">
                <Fila icono={CalendarDays} titulo={capital(fmt.larga(j.inicio))} detalle={`${fmt.hora(j.inicio)} – ${fmt.hora(j.fin)} (hora de Colombia)`}
                  accion={<a href={enlaceGoogleCalendar(j, url)} target="_blank" rel="noopener noreferrer" aria-label="Añadir a Google Calendar" title="Añadir a Google Calendar" className={botonIcono}><CalendarPlus className="size-5" aria-hidden="true" /></a>} />
                <div className="mx-5 h-px bg-linea-suave" />
                <Fila icono={MapPin} titulo={j.punto_encuentro} detalle="Punto de encuentro"
                  accion={<a href={enlaceComoLlegar(j)} target="_blank" rel="noopener noreferrer" aria-label="Cómo llegar" title="Cómo llegar" className={botonIcono}><SquareArrowOutUpRight className="size-[18px]" aria-hidden="true" /></a>} />
                <div className="mx-5 h-px bg-linea-suave" />
                <Fila icono={Ticket} titulo="Gratis" detalle="Sin límite de cupos: entre más gente, mejor." />
                <div className="mx-5 h-px bg-linea-suave" />
                <Fila icono={Users} titulo={textoInscritos(j.inscritos)} />
                <div className="border-t border-linea bg-fondo-alt p-5">
                  <p className="rotulo text-dorado-300">Invita a tu gente</p>
                  <div className="mt-3 grid grid-cols-2 gap-2">
                    <BotonCompartir href={enlaceInvitacionWhatsApp(j, url)} externo icono={<MessageCircle className="size-4" aria-hidden="true" />}>WhatsApp</BotonCompartir>
                    <BotonCompartir onClick={copiar} icono={copiado ? <Check className="size-4" aria-hidden="true" /> : <Copy className="size-4" aria-hidden="true" />}>{copiado ? '¡Copiado!' : 'Copiar enlace'}</BotonCompartir>
                    {puedeCompartir && <BotonCompartir onClick={compartir} icono={<Share2 className="size-4" aria-hidden="true" />}>Compartir</BotonCompartir>}
                    <BotonCompartir onClick={() => descargarICS(j, url)} icono={<Download className="size-4" aria-hidden="true" />}>Calendario (.ics)</BotonCompartir>
                  </div>
                </div>
              </div>
            </div>
          </aside>

          {/* Detalles, dónde, inscripción y Zanky en un solo bloque de la rejilla: así no quedan huecos junto a la columna derecha. */}
          <div className="min-w-0 space-y-12 lg:order-3 lg:col-span-7">
            <section aria-labelledby="titulo-detalles">
              <Titulo id="titulo-detalles">Detalles</Titulo>
              <p className="mt-6 leading-relaxed whitespace-pre-line text-texto">{j.descripcion || 'La organización todavía no agregó la descripción de esta jornada.'}</p>
              {j.que_llevar.length > 0 && (
                <div className="mt-8 border-t border-linea pt-6">
                  <p className="rotulo text-tenue">Qué llevar</p>
                  <ul className="mt-3 flex flex-wrap gap-2">{j.que_llevar.map((x) => <li key={x} className="rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-sm text-suave">{x}</li>)}</ul>
                </div>
              )}
            </section>

            <section aria-labelledby="titulo-donde">
              <Titulo id="titulo-donde">Dónde</Titulo>
              <p className="mt-6 flex items-start gap-2 text-texto"><MapPin className="mt-1 size-4 shrink-0 text-dorado-300" aria-hidden="true" />{j.punto_encuentro}</p>
              <div role="region" aria-label={`Mapa del punto de encuentro: ${j.punto_encuentro}`} className="relative isolate mt-4 overflow-hidden rounded-3xl border border-linea bg-superficie shadow-[var(--c-sombra)]">
                <MapaPunto j={j} />
              </div>
              <a href={enlaceComoLlegar(j)} target="_blank" rel="noopener noreferrer" className="mt-3 inline-flex min-h-11 items-center gap-1.5 text-sm font-semibold text-dorado-300 hover:underline"><Navigation className="size-4" aria-hidden="true" />Cómo llegar</a>
            </section>

            <section id="inscribirse" aria-labelledby="titulo-inscribirse" className="scroll-mt-28 rounded-3xl border border-dorado-500/40 bg-dorado-500/10 p-5 sm:p-7">
              <Titulo id="titulo-inscribirse">¿Vas a ir?</Titulo>
              {va ? (
                <div role="status"><AvisoZanky animo="celebrando" className="mt-5" titulo={mensaje?.ok ? mensaje.texto : 'Ya estás inscrito en esta jornada.'}>
                  <p className="flex items-center gap-1.5 text-sm text-emerald-200"><Check className="size-4 shrink-0" aria-hidden="true" />{mensaje?.ok ? 'Invita a tu gente con WhatsApp o el enlace.' : 'Te inscribiste desde este navegador.'}</p>
                </AvisoZanky></div>
              ) : pasada ? (
                <p className="mt-5 text-suave">Esta jornada ya se realizó. Mira abajo otras que te pueden interesar.</p>
              ) : (
                <form onSubmit={confirmar} className="mt-5 grid gap-3" noValidate>
                  <p className="text-sm text-suave">Es gratis y no hay límite de cupos: deja tu nombre para que la organización sepa cuánta gente va.</p>
                  <label className="grid gap-1.5">
                    <span className="text-sm font-semibold text-suave">Tu nombre</span>
                    <input ref={campoNombre} value={nombre} onChange={(e) => setNombre(e.target.value)} autoComplete="name" maxLength={80} placeholder="Como quieres aparecer en la lista" className="min-h-12 rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none" />
                  </label>
                  <label className="grid gap-1.5">
                    <span className="text-sm font-semibold text-suave">Celular (WhatsApp, opcional)</span>
                    <input value={celular} onChange={(e) => { setCelular(e.target.value); if (!e.target.value.trim()) setConWhatsapp(false); }} type="tel" inputMode="tel" autoComplete="tel" maxLength={20} placeholder="300 123 4567" className="min-h-12 rounded-2xl border border-white/20 bg-white/5 px-4 text-base text-texto placeholder:text-tenue focus:border-dorado-300 focus:outline-none" />
                  </label>
                  <label className={cn('flex items-start gap-3 text-sm', celular.trim() ? 'text-suave' : 'text-tenue')}>
                    <input type="checkbox" checked={conWhatsapp} disabled={!celular.trim()} onChange={(e) => setConWhatsapp(e.target.checked)} className="mt-0.5 size-5 shrink-0 accent-dorado-500" />
                    <span>Acepto recibir por WhatsApp recordatorios de esta jornada e invitaciones a otras.</span>
                  </label>
                  <label className="flex items-start gap-3 text-sm text-suave">
                    <input type="checkbox" checked={acepta} onChange={(e) => setAcepta(e.target.checked)} className="mt-0.5 size-5 shrink-0 accent-dorado-500" />
                    <span>Acepto que la organización use mi nombre (y mi celular, si lo dejo) solo para la lista de esta jornada, según la Ley 1581 de 2012. No se publica.</span>
                  </label>
                  <button type="submit" disabled={ocupado} className="inline-flex min-h-12 items-center justify-center rounded-full bg-dorado-500 px-6 font-bold text-cra-950 transition-colors hover:bg-dorado-300 disabled:opacity-60">{ocupado ? 'Inscribiendo…' : 'Confirmar asistencia'}</button>
                  {mensaje && !mensaje.ok && <p role="alert" className="text-sm font-semibold text-alta-texto">{mensaje.texto}</p>}
                  <p className="text-xs text-tenue">{origen === 'servidor' ? 'La inscripción queda en el servidor de la plataforma: la organización ve tu nombre y, si lo dejas, tu celular.' : 'Sin conexión con el servidor de jornadas: la inscripción se guarda solo en este navegador.'}</p>
                </form>
              )}
            </section>

            {!pasada && (
              <section aria-labelledby="titulo-zanky" className="flex flex-col items-center gap-6 rounded-3xl border border-white/15 bg-superficie p-5 sm:flex-row sm:p-6">
                {/* El QR va limpio, sin nada encima, para que se lea a la primera. */}
                <div className="size-36 shrink-0 overflow-hidden rounded-2xl bg-white p-1.5" role="img" aria-label="Código QR para interactuar con Zanky en la jornada" dangerouslySetInnerHTML={{ __html: qrZanky }} />
                <div className="text-center sm:text-left">
                  <h2 id="titulo-zanky" className="titular flex items-center justify-center gap-2 text-xl sm:justify-start sm:text-2xl"><img src="/marca/zanky/zanky-feliz-256.webp" alt="" width={44} height={44} className="size-9 shrink-0 sm:size-11" />Interactúa con Zanky</h2>
                  <p className="mt-1.5 text-sm leading-relaxed text-suave">El día de la jornada, escanéalo en el punto de encuentro: registras tu asistencia, hablas con Zanky, haces el reto del manglar y reportas lo que veas.</p>
                  <a href={urlZanky} className="mt-3 inline-flex min-h-11 items-center gap-2 rounded-full bg-dorado-500 px-5 text-sm font-bold text-cra-950 transition-colors hover:bg-dorado-300">Abrir con Zanky<ArrowRight className="size-4" aria-hidden="true" /></a>
                </div>
              </section>
            )}

            <section aria-labelledby="titulo-cartel" className="flex flex-col items-center gap-5 rounded-3xl bg-white p-5 text-cra-950 sm:flex-row">
              <div className="size-36 shrink-0" aria-label="Código QR de la invitación" role="img" dangerouslySetInnerHTML={{ __html: qr }} />
              <div className="text-center sm:text-left">
                <h2 id="titulo-cartel" className="font-[family-name:var(--font-titulo)] text-lg font-extrabold">Código QR de la invitación</h2>
                <p className="mt-1 text-sm text-cra-900/80">Para carteles en el colegio, la junta o el punto de encuentro: quien lo escanea abre esta jornada.</p>
                <button type="button" onClick={() => window.print()} className="mt-3 inline-flex min-h-11 items-center gap-2 rounded-full bg-cra-950 px-5 text-sm font-bold text-white hover:bg-cra-800"><Printer className="size-4" aria-hidden="true" />Imprimir cartel</button>
              </div>
            </section>
          </div>
        </div>
      </div>

      {recomendadas.length > 0 && (
        <section aria-labelledby="titulo-interesar" className="mx-auto max-w-6xl px-4 pb-10 sm:px-6">
          <div className="flex items-end justify-between gap-4">
            <h2 id="titulo-interesar" className="titular text-2xl sm:text-3xl">Te puede interesar</h2>
            <a href="/plataforma/jornadas" className="inline-flex min-h-11 shrink-0 items-center text-sm font-semibold text-dorado-300 hover:underline">Ver todas</a>
          </div>
          <ul className="mt-6 grid gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-3">
            {recomendadas.map((o) => <li key={o.id} className="min-w-0"><TarjetaJornada j={o} inscrito={inscritoEn(o.id)} /></li>)}
          </ul>
        </section>
      )}

      {/* Barra de la jornada, siempre a la vista. Es sticky (no fixed): al llegar al final se asienta antes del pie.
          A la derecha deja sitio para la burbuja de Zanky, que va fija en la esquina. */}
      <div className="pointer-events-none sticky bottom-0 z-40 isolate px-3 pr-[88px] pb-3 sm:px-5 sm:pr-[100px] sm:pb-4 2xl:pr-5 print:hidden">
        <div aria-hidden="true" className="pointer-events-none absolute inset-x-0 -top-16 bottom-0 -z-10 bg-linear-to-t from-fondo via-fondo/80 to-transparent" />
        <div className="pointer-events-auto mx-auto flex max-w-6xl items-center gap-3 rounded-full bg-superficie/95 py-2 pr-2 pl-5 shadow-[var(--c-sombra-alta)] backdrop-blur sm:gap-4 sm:py-2.5 sm:pr-2.5 sm:pl-6">
          <div className="min-w-0 flex-1">
            <p className="truncate text-xs text-suave sm:text-sm">{capital(fmt.diaSemana(j.inicio))} {fmt.dia(j.inicio)} {fmt.mes(j.inicio)} · {fmt.hora(j.inicio)}</p>
            <p className="truncate font-bold text-texto sm:text-lg">{j.titulo}</p>
          </div>
          <span className="hidden shrink-0 rounded-full bg-dorado-500/15 px-4 py-1.5 text-sm font-semibold text-dorado-300 lg:inline">Gratis · sin límite de cupos</span>
          <p className="hidden shrink-0 text-sm text-suave xl:block">{textoInscritos(j.inscritos)}</p>
          <button type="button" onClick={compartir} aria-label="Compartir la jornada" title="Compartir la jornada" className="hidden size-11 shrink-0 place-items-center rounded-full bg-fondo-alt text-suave transition-colors hover:text-texto sm:grid">
            {copiado ? <Check className="size-[18px] text-dorado-300" aria-hidden="true" /> : <Share2 className="size-[18px]" aria-hidden="true" />}
          </button>
          {pasada ? (
            <span className="inline-flex h-12 shrink-0 items-center rounded-full bg-fondo-alt px-6 text-sm font-semibold text-suave">Terminó</span>
          ) : va ? (
            <a href="#inscribirse" className="inline-flex h-12 shrink-0 items-center gap-2 rounded-full bg-emerald-500/20 px-5 font-bold text-emerald-200 sm:px-6"><Check className="size-5" aria-hidden="true" />Vas a ir</a>
          ) : (
            <a href="#inscribirse" onClick={irAInscribirse} className="inline-flex h-12 shrink-0 items-center rounded-full bg-dorado-500 px-6 font-bold text-cra-950 transition-colors hover:bg-dorado-300 sm:px-8">Asistir</a>
          )}
        </div>
      </div>

      {/* Cartel imprimible: va directo en <body> y solo aparece al imprimir (styles/cartel-jornada.css). */}
      {createPortal(
        <div id="cartel-jornada" className="hidden">
          <img className="cartel-zanky" src="/marca/zanky/zanky-feliz-512.webp" alt="" />
          <p className="cartel-rotulo">{T.etiqueta} · Jornada comunitaria del manglar</p>
          <h1 className="cartel-titulo">{j.titulo}</h1>
          <p className="cartel-dato">{capital(fmt.larga(j.inicio))} · {fmt.hora(j.inicio)} – {fmt.hora(j.fin)}</p>
          <p className="cartel-dato">Punto de encuentro: {j.punto_encuentro}</p>
          {j.que_llevar.length > 0 && <p className="cartel-dato">Qué llevar: {j.que_llevar.join(', ')}</p>}
          <div className="cartel-qrs">
            <figure>
              <div className="cartel-qr" dangerouslySetInnerHTML={{ __html: qr }} />
              <figcaption><b>Inscríbete</b>Gratis y sin límite de cupos</figcaption>
            </figure>
            <figure>
              <div className="cartel-qr" dangerouslySetInnerHTML={{ __html: qrZanky }} />
              <figcaption><b>Interactúa con Zanky</b>El día de la jornada: asistencia, reto del manglar y reportes</figcaption>
            </figure>
          </div>
          <p className="cartel-pie">Corporación Autónoma Regional del Atlántico · Monitoreo comunitario con Zanky</p>
        </div>,
        document.body,
      )}
    </>
  );
}
