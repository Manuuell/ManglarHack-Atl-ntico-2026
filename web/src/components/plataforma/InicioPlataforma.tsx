// Inicio de la plataforma abierta (pestaña INICIO de la maqueta de la C.R.A.).
// Solo cliente: incluye el mapa.
import { ArrowRight, CalendarDays, MapPin } from 'lucide-react';
import type { ReportePublico, ZonasManglar } from '../../types/manglar';
import type { Accion, Jornada } from '../../types/plataforma';
import { useAcciones, useJornadas } from '../../lib/plataforma/estado';
import { ESTADOS_ACCION, SECTORES } from '../../lib/plataforma/catalogos';
import { CANALES, ESTADOS, TIPOS } from '../../lib/catalogos';
import { FUENTE_WORKFLOW } from '../../lib/workflow';
import { useWorkflowCRA } from '../../lib/useWorkflowCRA';
import { fechaCRA } from '../../lib/cra';
import { cn } from '../../lib/utils';
import MapaPlataforma from './MapaPlataforma';
import { enAreaDeReporte } from '../../lib/areaReporte';
import { textoInscritos } from '../jornadas/piezas';
import AvisoZanky from '../marca/AvisoZanky';

interface Props { zonas: ZonasManglar; acciones: Accion[]; reportes: ReportePublico[]; jornadas: Jornada[] }

const numero = (n: number) => n.toLocaleString('es-CO', { maximumFractionDigits: 1 });
const dia = (iso: string) => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric' }).format(new Date(iso));
const mes = (iso: string) => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', month: 'short' }).format(new Date(iso)).replace('.', '');
const hora = (iso: string) => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));

function Rotulo({ children, className }: { children: React.ReactNode; className?: string }) {
  return <h2 className={cn('rotulo border-b border-white pb-2 text-texto', className)}>{children}</h2>;
}

export default function InicioPlataforma({ zonas, acciones: accionesIniciales, reportes, jornadas: jornadasIniciales }: Props) {
  const acciones = useAcciones(accionesIniciales);
  const { workflow: { cifras: CIFRAS }, espejo, estado: estadoDatos } = useWorkflowCRA();
  const jornadas = useJornadas(jornadasIniciales);
  const enCurso = acciones.filter((a) => a.estado !== 'cerrada');
  const recientes = reportes.filter(enAreaDeReporte).sort((a, b) => b.capturado_en.localeCompare(a.capturado_en)).slice(0, 3);
  const ahora = new Date().toISOString();
  const proximas = [...jornadas].filter((j) => j.fin >= ahora).sort((a, b) => a.inicio.localeCompare(b.inicio)).slice(0, 2);

  const estado = [
    { valor: CIFRAS.manglar_probable_ha, etiqueta: 'ha de manglar probable' },
    { valor: CIFRAS.prob_alta_ha, etiqueta: 'ha con probabilidad alta' },
    { valor: CIFRAS.por_revisar_ha, etiqueta: 'ha por revisar' },
    { valor: CIFRAS.dosel_seco_2026_ha, etiqueta: 'ha con dosel más seco en 2026' },
  ];

  return (
    <div className="grid gap-10 lg:grid-cols-[minmax(0,1.45fr)_minmax(0,1fr)]">
      <section aria-labelledby="titulo-mapa">
        <Rotulo><span id="titulo-mapa">Mapa del manglar y de las acciones</span></Rotulo>
        <div className="mt-4">
          <MapaPlataforma zonas={zonas} acciones={acciones} reportes={reportes} alto="min(68vh, 600px)" />
        </div>
      </section>

      <div className="grid content-start gap-10">
        <section aria-labelledby="titulo-estado">
          <Rotulo><span id="titulo-estado">Estado del manglar, última actualización trimestral</span></Rotulo>
          <dl className="mt-4 grid grid-cols-2 gap-x-6 gap-y-5">
            {estado.map((c) => (
              <div key={c.etiqueta} className="flex flex-col-reverse border-t-2 border-white pt-2">
                <dt className="rotulo mt-1 text-suave">{c.etiqueta}</dt>
                <dd className="titular text-4xl tabular-nums">{numero(c.valor)}</dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-xs text-tenue">Manglar probable, no confirmado: requiere verificación en campo. Fuente: {FUENTE_WORKFLOW}{estadoDatos === 'en_vivo' && espejo ? ` (datos revisados el ${fechaCRA(espejo.revisado_en)})` : estadoDatos === 'respaldo' ? ' (cifras del 27 de noviembre de 2026: no se pudo leer la copia en vivo)' : ''}.</p>
          <a href="/plataforma/acerca" className="mt-3 inline-flex min-h-11 items-center text-sm font-semibold text-dorado-300 underline underline-offset-4">Acerca de la plataforma: plan de manejo, qué hará y condiciones para la fase 2</a>
        </section>

        <section aria-labelledby="titulo-acciones">
          <Rotulo><span id="titulo-acciones">Acciones en curso</span></Rotulo>
          {enCurso.length === 0 ? (
            <AvisoZanky animo="curioso" className="mt-3 text-suave"><p>No hay acciones en curso. <a className="text-dorado-300 underline" href="/plataforma/proponer">Proponga la primera</a>.</p></AvisoZanky>
          ) : (
            <table className="mt-2 w-full text-left text-[13px]">
              <thead>
                <tr className="border-b border-white text-[11px] font-bold uppercase tracking-[0.06em] text-suave">
                  <th scope="col" className="py-2 pr-2">Acción</th><th scope="col" className="py-2 pr-2">Sector</th><th scope="col" className="py-2">Estado</th>
                </tr>
              </thead>
              <tbody>
                {enCurso.map((a) => (
                  <tr key={a.id} className="border-b border-white/25">
                    <td className="py-2 pr-2"><a href={`/plataforma/seguimiento?accion=${a.id}`} className="hover:text-dorado-300 hover:underline">{a.nombre}</a></td>
                    <td className="py-2 pr-2 text-suave">{SECTORES[a.sector].nombre}</td>
                    <td className="py-2"><span className={cn('inline-block whitespace-nowrap px-2 py-0.5 text-[10px] font-black tracking-[0.1em]', ESTADOS_ACCION[a.estado].clase)}>{ESTADOS_ACCION[a.estado].etiqueta}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </section>

        <section aria-labelledby="titulo-reportes">
          <Rotulo><span id="titulo-reportes">Reportes ciudadanos recientes · Zanky</span></Rotulo>
          <ul className="mt-2">
            {recientes.map((r) => {
              const Canal = CANALES[r.canal].icono;
              return (
                <li key={r.id} className="flex items-start justify-between gap-3 border-b border-white/25 py-2 text-[13px]">
                  <span><strong className="font-bold">{TIPOS[r.tipo].etiquetaLarga}</strong><br /><span className="text-suave">{r.zona ?? 'Fuera de sector'} · {ESTADOS[r.estado].etiqueta}</span></span>
                  <span className="flex shrink-0 items-center gap-1 text-xs text-tenue"><Canal className="size-3.5" aria-hidden="true" />{CANALES[r.canal].etiqueta}</span>
                </li>
              );
            })}
          </ul>
          <a href="/#monitoreo" className="rotulo mt-3 inline-flex min-h-11 items-center gap-1 text-dorado-300 hover:underline">Ver monitoreo comunitario <ArrowRight className="size-3.5" aria-hidden="true" /></a>
        </section>

        <section aria-labelledby="titulo-jornadas">
          <Rotulo><span id="titulo-jornadas">Próximas jornadas</span></Rotulo>
          {proximas.length === 0 ? (
            <AvisoZanky animo="curioso" className="mt-3 text-suave"><p>No hay jornadas programadas. <a className="text-dorado-300 underline" href="/plataforma/jornadas">Crea una</a>.</p></AvisoZanky>
          ) : (
            <ul className="mt-3 grid gap-3">
              {proximas.map((j) => (
                <li key={j.id}>
                  <a href={`/plataforma/seguimiento?jornada=${j.id}`} className="group flex gap-4 border border-linea-suave bg-superficie p-3 hover:border-dorado-300">
                    <span className="flex w-14 shrink-0 flex-col items-center justify-center border-r border-white/25 pr-3">
                      <span className="titular text-3xl">{dia(j.inicio)}</span>
                      <span className="rotulo text-dorado-300">{mes(j.inicio)}</span>
                    </span>
                    <span className="min-w-0 text-[13px]">
                      <strong className="block font-bold group-hover:text-dorado-300">{j.titulo}</strong>
                      <span className="flex items-center gap-1 text-suave"><CalendarDays className="size-3.5" aria-hidden="true" />{hora(j.inicio)} – {hora(j.fin)}</span>
                      <span className="flex items-center gap-1 text-suave"><MapPin className="size-3.5" aria-hidden="true" />{j.punto_encuentro}</span>
                      <span className="text-tenue">{textoInscritos(j.inscritos)} · gratis, sin límite de cupos</span>
                    </span>
                  </a>
                </li>
              ))}
            </ul>
          )}
        </section>
        <p className="text-xs text-tenue">Acciones, jornadas y reportes son datos de ejemplo; lo que registre en esta demostración se guarda en su navegador.</p>
      </div>
    </div>
  );
}
