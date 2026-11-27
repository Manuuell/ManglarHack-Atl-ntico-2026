// Panel de la Corporación (pestaña PANEL DE LA CORPORACIÓN de la maqueta de la C.R.A.)
// con roles de demostración. En producción los permisos y la auditoría los
// decide el servidor en un solo lugar; aquí solo cambia lo que ofrece la interfaz.
import { useMemo, useState } from 'react';
import { AlertTriangle, History, RotateCcw, ShieldAlert } from 'lucide-react';
import type { CambioEstado, Reporte, ZonasManglar } from '../../types/manglar';
import type { Accion, Actor, CambioAccion, EstadoAccion, Jornada, ReporteMonitoreo, Rol } from '../../types/plataforma';
import { cambiarEstadoAccion, rolDemo, restablecerDemostracion, useAcciones, useActores, useCambiosAccion, useJornadas, useMonitoreos, useRolDemo } from '../../lib/plataforma/estado';
import { ESTADOS_ACCION, LISTA_ESTADOS_ACCION, ROLES, SECTORES, TRANSICIONES_ACCION, puede } from '../../lib/plataforma/catalogos';
import { ESTADOS, TIPOS, nivelPrioridad } from '../../lib/catalogos';
import { reemplazarReportes, useHistorial, useReportes } from '../../lib/reportesStore';
import { CIFRAS, FUENTE_WORKFLOW } from '../../lib/workflow';
import { cn } from '../../lib/utils';
import PanelCRA from '../panel/PanelCRA';
import AvisoZanky from '../marca/AvisoZanky';
import { RADIO_INFLUENCIA_M, enAreaDeReporte } from '../../lib/areaReporte';

interface Props {
  acciones: Accion[]; actores: Actor[]; cambiosAccion: CambioAccion[]; jornadas: Jornada[]; monitoreos: ReporteMonitoreo[];
  reportes: Reporte[]; historial: CambioEstado[]; zonas: ZonasManglar;
}
type Pestana = 'acciones' | 'reportes' | 'auditoria';

const fecha = (iso: string) => new Intl.DateTimeFormat('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(iso.length === 10 ? `${iso}T12:00:00-05:00` : iso));
const ha = (n: number) => n.toLocaleString('es-CO', { maximumFractionDigits: 1 });
const DIAS_MONITOREO = 90;

export default function PanelCorporacion(props: Props) {
  const acciones = useAcciones(props.acciones);
  const actores = useActores(props.actores);
  const cambios = useCambiosAccion(props.cambiosAccion);
  const jornadas = useJornadas(props.jornadas);
  const monitoreos = useMonitoreos(props.monitoreos);
  const reportes = useReportes(props.reportes);
  const historial = useHistorial(props.historial);
  const rol = useRolDemo();
  const [pestana, setPestana] = useState<Pestana>('acciones');
  const [nota, setNota] = useState<{ id: string; texto: string; error?: string } | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  const [confirmar, setConfirmar] = useState(false);

  const conteo = useMemo(() => Object.fromEntries(LISTA_ESTADOS_ACCION.map((e) => [e, acciones.filter((a) => a.estado === e).length])) as Record<EstadoAccion, number>, [acciones]);
  const hectareas = acciones.reduce((s, a) => s + a.hectareas, 0);
  const actor = (a: Accion) => a.proponente || actores.find((item) => item.id === a.actor_id)?.nombre || 'Actor no disponible';

  const alertas = useMemo(() => {
    const hoy = Date.now();
    const lista: string[] = [];
    for (const a of acciones.filter((x) => x.estado === 'en_ejecucion')) {
      const ultimo = monitoreos.filter((m) => m.accion_id === a.id).map((m) => Date.parse(m.fecha)).sort((x, y) => y - x)[0];
      if (!ultimo || hoy - ultimo > DIAS_MONITOREO * 86400000) lista.push(`Reporte de monitoreo vencido: ${a.nombre} (último hace más de ${DIAS_MONITOREO} días).`);
    }
    for (const a of acciones.filter((x) => x.estado === 'aprobada')) {
      if (!jornadas.some((j) => j.accion_id === a.id && Date.parse(j.fin) >= hoy)) lista.push(`${a.nombre}: aprobada y sin jornada próxima programada.`);
    }
    for (const a of acciones.filter((x) => x.estado === 'propuesta' || x.estado === 'en_revision')) {
      const pendientes = a.requerimientos.filter((r) => !r.cumplido).length;
      if (pendientes) lista.push(`${a.nombre}: ${pendientes} requerimiento${pendientes === 1 ? '' : 's'} pendiente${pendientes === 1 ? '' : 's'} para la revisión.`);
    }
    for (const a of acciones.filter((x) => x.accion_plan === 'fuera_zonificacion' && x.estado !== 'cerrada')) lista.push(`${a.nombre}: el sitio queda fuera de la zonificación de prioridades de la Corporación.`);
    const altas = reportes.filter((r) => nivelPrioridad(r.prioridad) === 'alta' && (r.estado === 'recibido' || r.estado === 'en_verificacion'));
    if (altas.length) lista.push(`${altas.length} reporte${altas.length === 1 ? '' : 's'} ciudadano${altas.length === 1 ? '' : 's'} de prioridad alta sin verificar: ${altas.map((r) => `${TIPOS[r.tipo].etiqueta} en ${r.zona ?? 'zona sin sector'}`).join('; ')}.`);
    const fuera = reportes.filter((r) => !enAreaDeReporte(r) && r.estado !== 'descartado');
    if (fuera.length) lista.push(`${fuera.length} reporte${fuera.length === 1 ? '' : 's'} fuera del área de reporte (más de ${RADIO_INFLUENCIA_M} m del manglar): revisar y descartar si no afecta al manglar.`);
    const vigilancia = acciones.filter((x) => x.tipo === 'conservacion_vigilancia' && x.estado !== 'cerrada').length;
    lista.push(`${ha(CIFRAS.por_revisar_ha)} ha por revisar según el workflow; ${vigilancia} acción${vigilancia === 1 ? '' : 'es'} de vigilancia en campo en curso. (Fuente: ${FUENTE_WORKFLOW}.)`);
    return lista;
  }, [acciones, monitoreos, jornadas, reportes]);

  function decidir(a: Accion, destino: EstadoAccion, textoNota = '') {
    const r = cambiarEstadoAccion(a.id, destino, { usuario_id: `${rol}-demo`, rol, nota: textoNota || `${TRANSICIONES_ACCION[a.estado].find((t) => t.a === destino)?.etiqueta ?? 'Cambio'} (demostración).` });
    if (!r.ok) {
      if (r.errores.nota && nota) setNota({ ...nota, error: r.errores.nota });
      else setAviso(Object.values(r.errores)[0] ?? 'No se pudo cambiar el estado.');
      return;
    }
    setNota(null);
    setAviso(`${a.nombre}: ${ESTADOS_ACCION[destino].etiqueta}`);
  }

  const auditoria = useMemo(() => [
    ...cambios.map((c) => ({ id: c.id, fecha: c.fecha, tipo: 'Acción' as const, que: `${acciones.find((a) => a.id === c.accion_id)?.nombre ?? 'Acción'} → ${ESTADOS_ACCION[c.estado].etiqueta}`, quien: c.rol === 'sistema' ? 'Sistema / actor proponente' : `${ROLES[c.rol].etiqueta} (${c.usuario_id})`, nota: c.nota })),
    ...historial.map((c) => ({ id: c.id, fecha: c.fecha, tipo: 'Reporte' as const, que: `Reporte ${c.reporte_id.slice(0, 8)} → ${ESTADOS[c.estado].etiqueta}`, quien: c.usuario_id, nota: c.nota })),
  ].sort((x, y) => y.fecha.localeCompare(x.fecha)), [cambios, historial, acciones]);
  const [filtroAuditoria, setFiltroAuditoria] = useState<'todo' | 'Acción' | 'Reporte'>('todo');

  const pestanas: { id: Pestana; etiqueta: string }[] = [
    { id: 'acciones', etiqueta: 'Acciones' },
    { id: 'reportes', etiqueta: 'Reportes ciudadanos' },
    { id: 'auditoria', etiqueta: 'Auditoría' },
  ];

  return (
    <div className="grid gap-6">
      <div className="flex flex-col gap-3 border border-dorado-300/40 bg-white/5 p-4 lg:flex-row lg:items-center lg:justify-between">
        <p className="flex items-start gap-2 text-sm text-suave"><ShieldAlert className="mt-0.5 size-4 shrink-0 text-dorado-300" aria-hidden="true" />Modo demostración con datos de ejemplo: los permisos y la auditoría los decide el servidor en producción.</p>
        <div className="flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <span className="etiqueta-campo">Ver como</span>
            <select value={rol} onChange={(e) => rolDemo.establecer(() => e.target.value as Rol)} className="min-h-11 border-0 border-b border-white/60 bg-white/5 px-3 text-texto focus:border-dorado-300 focus:outline-none">
              {Object.entries(ROLES).map(([k, v]) => <option key={k} value={k} className="bg-cra-900">{v.etiqueta}</option>)}
            </select>
          </label>
          {rol === 'administrador' && (confirmar ? (
            <span className="flex items-center gap-2 text-sm" role="alertdialog" aria-label="Confirmar restablecimiento">
              ¿Borrar todo lo hecho en la demostración?
              <button type="button" className="min-h-11 bg-dorado-500 px-3 text-xs font-black uppercase text-cra-950" onClick={() => { restablecerDemostracion(); reemplazarReportes(props.reportes); setConfirmar(false); setAviso('Demostración restablecida.'); }}>Sí, restablecer</button>
              <button type="button" className="min-h-11 px-3 text-xs font-bold uppercase text-suave hover:text-texto" onClick={() => setConfirmar(false)}>Cancelar</button>
            </span>
          ) : (
            <button type="button" onClick={() => setConfirmar(true)} className="inline-flex min-h-11 items-center gap-2 border border-white/60 px-3 text-xs font-bold uppercase tracking-wider hover:border-dorado-300 hover:text-dorado-300"><RotateCcw className="size-4" aria-hidden="true" />Restablecer demostración</button>
          ))}
        </div>
      </div>
      <p className="-mt-3 text-xs text-tenue">{ROLES[rol].descripcion}</p>

      <div role="tablist" aria-label="Secciones del panel" className="flex gap-6 overflow-x-auto border-b border-linea">
        {pestanas.map((p) => (
          <button key={p.id} role="tab" type="button" aria-selected={pestana === p.id} aria-controls={`panel-${p.id}`} id={`tab-${p.id}`} onClick={() => setPestana(p.id)}
            className={cn('rotulo min-h-11 shrink-0 border-b-[3px] px-1', pestana === p.id ? 'border-dorado-300 text-texto' : 'border-transparent text-suave hover:text-texto')}>{p.etiqueta}</button>
        ))}
        <a href="#capas" className="rotulo inline-flex min-h-11 shrink-0 items-center border-b-[3px] border-transparent px-1 text-suave hover:text-texto">Capas de la Corporación</a>
      </div>

      <div aria-live="polite">{aviso && <p className="border-l-4 border-dorado-300 bg-white/5 p-3 text-sm">{aviso}</p>}</div>

      {pestana === 'acciones' && (
        <section id="panel-acciones" role="tabpanel" aria-labelledby="tab-acciones" className="grid gap-8">
          <div className="grid grid-cols-3 gap-4 sm:grid-cols-4 lg:grid-cols-7">
            {LISTA_ESTADOS_ACCION.map((e) => (
              <div key={e} className="flex flex-col-reverse border-t-2 border-white pt-2"><span className="rotulo mt-1 text-suave">{ESTADOS_ACCION[e].etiqueta}</span><span className="titular text-4xl tabular-nums">{conteo[e]}</span></div>
            ))}
            <div className="flex flex-col-reverse border-t-2 border-dorado-300 pt-2"><span className="rotulo mt-1 text-dorado-300">hectáreas propuestas</span><span className="titular text-4xl tabular-nums">{ha(hectareas)}</span></div>
          </div>

          {acciones.length === 0 ? (
            <AvisoZanky animo="curioso" forma="bloque" titulo="Todavía no hay acciones" className="rounded-3xl border border-dashed border-linea p-8">
              <p>Cuando un actor proponga una acción, llegará aquí para revisarla.</p>
            </AvisoZanky>
          ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[860px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-white text-[11px] font-bold uppercase tracking-[0.06em] text-suave">
                  <th scope="col" className="py-2 pr-3">Acción</th><th scope="col" className="py-2 pr-3">Actor</th><th scope="col" className="py-2 pr-3">Sector</th><th scope="col" className="py-2 pr-3 text-right">Hectáreas</th><th scope="col" className="py-2 pr-3">Estado</th><th scope="col" className="py-2">Decisión</th>
                </tr>
              </thead>
              <tbody>
                {acciones.map((a) => {
                  const puedeRevisar = puede(rol, 'revisar_acciones');
                  return (
                    <tr key={a.id} className="border-b border-white/25 align-top">
                      <td className="py-3 pr-3"><a href={`/plataforma/seguimiento?accion=${a.id}`} className="font-bold hover:text-dorado-300 hover:underline">{a.nombre}</a></td>
                      <td className="py-3 pr-3 text-suave">{actor(a)}</td>
                      <td className="py-3 pr-3 text-suave">{a.sector ? SECTORES[a.sector].nombre : 'Sin sector confirmado'}</td>
                      <td className="py-3 pr-3 text-right tabular-nums">{a.canal === 'whatsapp' ? 'Sin informar' : ha(a.hectareas)}</td>
                      <td className="py-3 pr-3"><span className={cn('inline-block whitespace-nowrap px-2 py-0.5 text-[10px] font-black tracking-[0.1em]', ESTADOS_ACCION[a.estado].clase)}>{ESTADOS_ACCION[a.estado].etiqueta}</span></td>
                      <td className="py-2">
                        {TRANSICIONES_ACCION[a.estado].length === 0 ? <span className="text-xs text-tenue">Sin decisiones pendientes</span> : (
                          <div className="flex flex-wrap gap-2">
                            {TRANSICIONES_ACCION[a.estado].map((t) => (
                              <button key={t.a} type="button" disabled={!puedeRevisar} title={puedeRevisar ? undefined : 'Solo el moderador de la C.R.A. o el administrador deciden sobre acciones.'}
                                onClick={() => (t.a === 'con_observaciones' ? setNota({ id: a.id, texto: '' }) : decidir(a, t.a))}
                                className={cn('min-h-11 px-3 text-xs font-black uppercase tracking-[0.06em] disabled:cursor-not-allowed disabled:opacity-40', t.a === 'con_observaciones' ? 'border border-capa-recuperacion text-orange-200 hover:bg-white/10' : 'bg-dorado-500 text-cra-950 hover:bg-dorado-300')}>
                                {t.etiqueta}
                              </button>
                            ))}
                          </div>
                        )}
                        {nota?.id === a.id && (
                          <div className="mt-2 grid gap-2">
                            <label className="etiqueta-campo" htmlFor={`nota-${a.id}`}>Observaciones para el actor</label>
                            <textarea id={`nota-${a.id}`} rows={3} value={nota.texto} onChange={(e) => setNota({ id: a.id, texto: e.target.value })} className="w-full border-0 border-b border-white/60 bg-white/5 p-2 text-texto focus:border-dorado-300 focus:outline-none" aria-invalid={!!nota.error} aria-describedby={nota.error ? `error-nota-${a.id}` : undefined} />
                            {nota.error && <p id={`error-nota-${a.id}`} className="text-sm text-alta-texto">{nota.error}</p>}
                            <div className="flex gap-2">
                              <button type="button" onClick={() => decidir(a, 'con_observaciones', nota.texto)} className="min-h-11 bg-dorado-500 px-3 text-xs font-black uppercase text-cra-950">Enviar observaciones</button>
                              <button type="button" onClick={() => setNota(null)} className="min-h-11 px-3 text-xs font-bold uppercase text-suave hover:text-texto">Cancelar</button>
                            </div>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          )}

          <section aria-labelledby="titulo-alertas">
            <h3 id="titulo-alertas" className="rotulo border-b border-white pb-2">Alertas de seguimiento</h3>
            <ul className="mt-3 grid gap-2">
              {alertas.map((t) => <li key={t} className="flex gap-2 text-sm"><AlertTriangle className="mt-0.5 size-4 shrink-0 text-dorado-300" aria-hidden="true" />{t}</li>)}
            </ul>
            <p className="mt-3 text-xs text-tenue">Calculadas a partir de las acciones, los monitoreos, las jornadas y los reportes de la plataforma. En la versión conectada también cruzan las acciones con la actualización trimestral del workflow.</p>
          </section>
        </section>
      )}

      {pestana === 'reportes' && (
        <section id="panel-reportes" role="tabpanel" aria-labelledby="tab-reportes">
          <PanelCRA reportes={props.reportes} poligonos={props.zonas} historial={props.historial} rol={rol} />
        </section>
      )}

      {pestana === 'auditoria' && (
        <section id="panel-auditoria" role="tabpanel" aria-labelledby="tab-auditoria" className="grid gap-4">
          {!puede(rol, 'ver_auditoria') ? (
            <p className="text-suave">La auditoría solo la ven el moderador de la C.R.A. y el administrador.</p>
          ) : (
            <>
              <div className="flex flex-wrap items-center gap-2">
                {(['todo', 'Acción', 'Reporte'] as const).map((f) => (
                  <button key={f} type="button" aria-pressed={filtroAuditoria === f} onClick={() => setFiltroAuditoria(f)} className={cn('min-h-11 px-3 text-xs font-bold uppercase tracking-wider', filtroAuditoria === f ? 'bg-dorado-500 text-cra-950' : 'border border-white/40 text-suave hover:text-texto')}>{f === 'todo' ? 'Todo' : f === 'Acción' ? 'Acciones' : 'Reportes'}</button>
                ))}
              </div>
              <ol className="grid gap-0 border-l-2 border-linea">
                {auditoria.filter((e) => filtroAuditoria === 'todo' || e.tipo === filtroAuditoria).map((e) => (
                  <li key={e.id} className="relative py-2 pl-5 text-sm">
                    <span aria-hidden="true" className="absolute -left-[5px] top-3.5 size-2 bg-dorado-300" />
                    <p className="font-bold"><History className="mr-1 inline size-3.5 text-tenue" aria-hidden="true" />{e.que}</p>
                    <p className="text-xs text-suave">{fecha(e.fecha)} · {e.quien}{e.nota ? ` · ${e.nota}` : ''}</p>
                  </li>
                ))}
              </ol>
              <p className="text-xs text-tenue">En producción es un registro inmutable en el servidor e incluye también lo que se mira (fotos, datos de quien denuncia), no solo lo que se cambia.</p>
            </>
          )}
        </section>
      )}
    </div>
  );
}
