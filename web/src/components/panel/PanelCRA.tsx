import { useEffect, useRef, useState } from 'react';
import { FileJson, FileSpreadsheet, Inbox, Siren, Sparkles, Trees, type LucideIcon } from 'lucide-react';
import type { CambioEstado, EstadoReporte, NivelPrioridad, Reporte, ZonasManglar } from '../../types/manglar';
import { ESTADOS, LISTA_ESTADOS, LISTA_PRIORIDADES, PRIORIDADES, UMBRAL_IA, esAbierto, nivelPrioridad, CANALES, LISTA_CANALES, TRANSICIONES } from '../../lib/catalogos';
import { cambiarEstado as registrarCambio, useHistorial, useReportes } from '../../lib/reportesStore';
import { exportarCSV, exportarGeoJSON, exportarKML } from '../../lib/exportar';
import { cn } from '../../lib/utils';
import type { Rol } from '../../types/plataforma';
import { puede } from '../../lib/plataforma/catalogos';
import ReportesPanel, { type CampoOrden, type Orden } from './ReportesPanel';
import ZankyImg from '../marca/ZankyImg';

function KpiCard({ etiqueta, valor, detalle, icono: Icono, acento }: {
  etiqueta: string; valor: number; detalle: string; icono: LucideIcon; acento: string;
}) {
  return <article className="rounded-sm bg-superficie p-5 shadow-[var(--c-sombra)]">
    <div className={cn('mb-4 inline-flex rounded-sm p-3', acento)}><Icono size={22} aria-hidden="true" /></div>
    <h3 className="text-sm font-medium text-suave">{etiqueta}</h3>
    <p className="mt-2 text-3xl font-bold tabular-nums text-texto">{valor.toLocaleString('es-CO')}</p>
    <p className="mt-2 text-xs text-tenue">{detalle}</p>
  </article>;
}

// Qué puede hacer cada rol de demostración con un reporte. En producción lo decide el servidor.
function motivoBloqueo(rol: Rol, a: EstadoReporte): string | null {
  if (puede(rol, 'gestionar_reportes')) return null;
  if (puede(rol, 'verificar_en_campo') && (a === 'en_verificacion' || a === 'verificado')) return null;
  return rol === 'vigia' ? 'El vigía comunitario solo inicia la verificación y marca verificado.' : 'Este rol no cambia estados de reportes.';
}

export default function PanelCRA({ reportes: iniciales, poligonos, historial: historialInicial, rol = 'moderador' }: { reportes: Reporte[]; poligonos: ZonasManglar; historial: CambioEstado[]; rol?: Rol }) {
  const reportes = useReportes(iniciales);
  const historial = useHistorial(historialInicial);
  const [estado, setEstado] = useState<EstadoReporte | 'todos' | 'abiertos'>('abiertos');
  const [prioridad, setPrioridad] = useState<NivelPrioridad | 'todas'>('todas');
  const [orden, setOrden] = useState<Orden>({ campo: 'capturado_en', direccion: 'desc' });
  const [aviso, setAviso] = useState('');
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timeout.current !== null) clearTimeout(timeout.current); }, []);

  function cambiarEstado(id: string, nuevoEstado: EstadoReporte) {
    const reporte = reportes.find((r) => r.id === id);
    const transicion = reporte && TRANSICIONES[reporte.estado].find((t) => t.a === nuevoEstado);
    if (!transicion || motivoBloqueo(rol, nuevoEstado) !== null || !registrarCambio(id, nuevoEstado, { usuario_id: `${rol}-demo`, nota: `${transicion.accion}. Acción de demostración.` })) return;
    if (timeout.current !== null) clearTimeout(timeout.current);
    setAviso(`Estado: ${ESTADOS[nuevoEstado].etiqueta} · ${id.slice(0, 8)}`);
    timeout.current = setTimeout(() => { setAviso(''); timeout.current = null; }, 3000);
  }
  function ordenar(campo: CampoOrden) {
    setOrden((actual) => ({ campo, direccion: actual.campo === campo && actual.direccion === 'desc' ? 'asc' : 'desc' }));
  }
  function limpiarFiltros() { setEstado('todos'); setPrioridad('todas'); }

  const filtrados = reportes.filter((reporte) => (estado === 'todos' || (estado === 'abiertos' ? esAbierto(reporte) : reporte.estado === estado)) && (prioridad === 'todas' || nivelPrioridad(reporte.prioridad) === prioridad)).sort((a, b) => {
    const diferencia = orden.campo === 'capturado_en' ? Date.parse(a.capturado_en) - Date.parse(b.capturado_en) : a.confianza - b.confianza;
    return (orden.direccion === 'asc' ? diferencia : -diferencia) || a.id.localeCompare(b.id);
  });
  const altas = reportes.filter((r) => nivelPrioridad(r.prioridad) === 'alta' && esAbierto(r));
  const conteo = (opcion: EstadoReporte | 'todos' | 'abiertos') => reportes.filter((r) => opcion === 'todos' || (opcion === 'abiertos' ? esAbierto(r) : r.estado === opcion)).length;
  const humanos = reportes.filter((r) => ['verificado', 'alerta_oficial', 'en_atencion', 'cerrado'].includes(r.estado)).length;
  const boton = 'inline-flex min-h-11 shrink-0 items-center justify-center gap-2 rounded-xl px-3 py-2 text-xs font-medium transition-colors';

  return <div className="space-y-6">
    <div className="rounded-sm bg-white/10 p-4 text-sm text-cra-100"><span className="mb-2 inline-block rounded-full bg-superficie px-3 py-1 text-xs font-semibold">Datos de ejemplo</span><p>Modo demostración: actúas como Moderador C.R.A. sin iniciar sesión. En producción los permisos y la auditoría los decide el servidor.</p></div>
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <KpiCard etiqueta="Reportes recibidos" valor={reportes.length} detalle={LISTA_CANALES.map((canal) => `${reportes.filter((r) => r.canal === canal).length} ${CANALES[canal].etiqueta}`).join(' · ')} icono={Inbox} acento="bg-fondo-alt text-dorado-300" />
      <KpiCard etiqueta="Prioridad alta abiertos" valor={altas.length} detalle={`${altas.filter((r) => r.estado === 'recibido' || r.estado === 'en_verificacion').length} sin verificar`} icono={Siren} acento={PRIORIDADES.alta.chip} />
      <KpiCard etiqueta={`Confianza IA ≥ ${UMBRAL_IA} %`} valor={reportes.filter((r) => r.confianza >= UMBRAL_IA).length} detalle={`${humanos} verificados por una persona`} icono={Sparkles} acento="bg-white/10 text-cra-100" />
      <KpiCard etiqueta="Zonas de trabajo" valor={poligonos.features.length} detalle="polígonos aproximados · KMZ C.R.A. pendiente" icono={Trees} acento="bg-white/10 text-dorado-300" />
    </div>

    <div className="overflow-hidden rounded-sm bg-superficie shadow-[var(--c-sombra)]">
      <div className="space-y-4 border-b border-linea-suave p-5">
        <div className="flex flex-wrap items-start justify-between gap-5">
          <div className="min-w-0 w-full space-y-4">
            <fieldset className="min-w-0"><legend className="mb-2 text-xs font-medium text-suave">Estado</legend>
              <div className="flex gap-1 overflow-x-auto rounded-sm bg-fondo-alt p-1">{(['abiertos', 'todos', ...LISTA_ESTADOS] as const).map((opcion) => <button key={opcion} type="button" aria-pressed={estado === opcion} onClick={() => setEstado(opcion)} className={cn(boton, estado === opcion ? 'bg-dorado-500 text-cra-950' : 'text-suave hover:bg-superficie')}>
                {opcion === 'todos' ? 'Todos' : opcion === 'abiertos' ? 'Abiertos' : ESTADOS[opcion].etiqueta}<span className="tabular-nums">{conteo(opcion)}</span>
              </button>)}</div>
            </fieldset>
            <fieldset className="min-w-0"><legend className="mb-2 text-xs font-medium text-suave">Prioridad</legend>
              <div className="flex flex-wrap gap-1 rounded-sm bg-fondo-alt p-1">{(['todas', ...LISTA_PRIORIDADES] as const).map((opcion) => <button key={opcion} type="button" aria-pressed={prioridad === opcion} onClick={() => setPrioridad(opcion)} className={cn(boton, prioridad === opcion ? 'bg-superficie text-texto shadow-sm ring-1 ring-linea' : 'text-suave hover:bg-superficie')}>
                {opcion !== 'todas' && <span aria-hidden="true" className={cn('h-2 w-2 rounded-full', PRIORIDADES[opcion].punto)} />}{opcion === 'todas' ? 'Todas' : PRIORIDADES[opcion].etiqueta}
              </button>)}</div>
            </fieldset>
          </div>
          <div className="ml-auto"><p className="mb-2 text-xs font-medium text-suave">Exportación de datos abiertos</p>
            <div className="flex flex-wrap gap-2">{[
              { formato: 'CSV', icono: FileSpreadsheet, descargar: exportarCSV },
              { formato: 'GeoJSON', icono: FileJson, descargar: exportarGeoJSON },
              { formato: 'KML', icono: FileJson, descargar: exportarKML },
            ].map(({ formato, icono: Icono, descargar }) => <button key={formato} type="button" disabled={filtrados.length === 0} onClick={() => descargar(filtrados)} title={`Descargar ${filtrados.length} reportes filtrados en ${formato}`} aria-label={`Descargar ${filtrados.length} reportes filtrados en ${formato}`} className={cn(boton, 'text-texto ring-1 ring-inset ring-linea hover:bg-fondo disabled:cursor-not-allowed disabled:opacity-40')}><Icono size={16} aria-hidden="true" />Exportar {formato}</button>)}</div>
          </div>
        </div>
        <p className="text-xs text-tenue">Mostrando {filtrados.length} de {reportes.length} reportes · la exportación descarga la vista filtrada con campos públicos y coordenadas aproximadas · CC BY 4.0</p>
      </div>
      {filtrados.length > 0 ? <ReportesPanel historial={historial} reportes={filtrados} orden={orden} ordenar={ordenar} cambiarEstado={cambiarEstado} permitido={(a) => motivoBloqueo(rol, a)} /> : <div className="flex flex-col items-center gap-4 px-5 py-14 text-center">
        <ZankyImg animo="curioso" decorativo sizes="96px" className="size-24" /><p className="font-medium text-suave">No hay reportes con estos filtros</p>
        <button type="button" onClick={limpiarFiltros} className={cn(boton, 'bg-dorado-500 text-cra-950 hover:bg-dorado-300')}>Limpiar filtros</button>
      </div>}
    </div>
    <div role="status" aria-live="polite" aria-atomic="true" className="pointer-events-none fixed bottom-6 right-6 z-[1200] max-w-[calc(100vw-3rem)]">
      {aviso && <p className="rounded-sm bg-cra-950 px-5 py-3 text-sm text-white shadow-[var(--c-sombra-alta)]">{aviso}</p>}
    </div>
  </div>;
}
