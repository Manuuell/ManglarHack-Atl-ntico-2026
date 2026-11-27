import { useEffect, useRef, useState } from 'react';
import { FileJson, FileSpreadsheet, Inbox, SearchX, Siren, Sparkles, Trees, type LucideIcon } from 'lucide-react';
import type { EstadoReporte, PrioridadReporte, Reporte, ZonasManglar } from '../../types/manglar';
import { ESTADOS, LISTA_ESTADOS, LISTA_PRIORIDADES, PRIORIDADES, UMBRAL_IA, esAmenazaCritica, esValidadoPorIA } from '../../lib/catalogos';
import { actualizarEstado, useReportes } from '../../lib/reportesStore';
import { exportarCSV, exportarGeoJSON } from '../../lib/exportar';
import { cn } from '../../lib/utils';
import ReportesPanel, { type CampoOrden, type Orden } from './ReportesPanel';

function KpiCard({ etiqueta, valor, detalle, icono: Icono, acento }: {
  etiqueta: string; valor: number; detalle: string; icono: LucideIcon; acento: string;
}) {
  return <article className="rounded-3xl bg-superficie p-5 shadow-[var(--c-sombra)]">
    <div className={cn('mb-4 inline-flex rounded-2xl p-3', acento)}><Icono size={22} aria-hidden="true" /></div>
    <h3 className="text-sm font-medium text-suave">{etiqueta}</h3>
    <p className="mt-2 text-3xl font-bold tabular-nums text-texto">{valor.toLocaleString('es-CO')}</p>
    <p className="mt-2 text-xs text-tenue">{detalle}</p>
  </article>;
}

export default function PanelCRA({ reportes: iniciales, poligonos }: { reportes: Reporte[]; poligonos: ZonasManglar }) {
  const reportes = useReportes(iniciales);
  const [estado, setEstado] = useState<EstadoReporte | 'todos'>('todos');
  const [prioridad, setPrioridad] = useState<PrioridadReporte | 'todas'>('todas');
  const [orden, setOrden] = useState<Orden>({ campo: 'fecha', direccion: 'desc' });
  const [aviso, setAviso] = useState('');
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timeout.current !== null) clearTimeout(timeout.current); }, []);

  function cambiarEstado(id: string, nuevoEstado: EstadoReporte) {
    actualizarEstado(id, nuevoEstado);
    if (timeout.current !== null) clearTimeout(timeout.current);
    setAviso(`${id} · ${ESTADOS[nuevoEstado].etiqueta}`);
    timeout.current = setTimeout(() => { setAviso(''); timeout.current = null; }, 3000);
  }
  function ordenar(campo: CampoOrden) {
    setOrden((actual) => ({ campo, direccion: actual.campo === campo && actual.direccion === 'desc' ? 'asc' : 'desc' }));
  }
  function limpiarFiltros() { setEstado('todos'); setPrioridad('todas'); }

  const filtrados = reportes.filter((reporte) => (estado === 'todos' || reporte.estado === estado) && (prioridad === 'todas' || reporte.prioridad === prioridad)).sort((a, b) => {
    const diferencia = orden.campo === 'fecha' ? Date.parse(a.fecha) - Date.parse(b.fecha) : a.confianza_ia - b.confianza_ia;
    return (orden.direccion === 'asc' ? diferencia : -diferencia) || a.id.localeCompare(b.id);
  });
  const amenazas = reportes.filter(esAmenazaCritica);
  const whatsapp = reportes.filter((reporte) => reporte.origen === 'whatsapp').length;
  const conteos = { todos: reportes.length, pendiente: 0, validado: 0, escalado: 0 };
  reportes.forEach((reporte) => { conteos[reporte.estado] += 1; });
  const area = poligonos.features.reduce((total, zona) => total + zona.properties.area_ha, 0);
  const boton = 'inline-flex items-center justify-center gap-2 rounded-xl px-3 py-2 text-xs font-medium transition-colors';

  return <div className="space-y-6">
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <KpiCard etiqueta="Total de reportes" valor={reportes.length} detalle={`${whatsapp} por WhatsApp · ${reportes.filter((reporte) => reporte.origen === 'app').length} desde la app`} icono={Inbox} acento="bg-fondo-alt text-manglar-700" />
      <KpiCard etiqueta="Amenazas críticas activas" valor={amenazas.length} detalle={`${amenazas.filter((reporte) => reporte.estado !== 'escalado').length} sin escalar a expediente`} icono={Siren} acento={PRIORIDADES.alta.chip} />
      <KpiCard etiqueta="Reportes validados por IA" valor={reportes.filter(esValidadoPorIA).length} detalle={`Confianza ≥ ${UMBRAL_IA} % · ${conteos.validado} confirmados por la C.R.A.`} icono={Sparkles} acento="bg-agua-50 text-agua-700" />
      <KpiCard etiqueta="Zonas monitoreadas" valor={poligonos.features.length} detalle={`${poligonos.features.filter((zona) => zona.properties.prioridad === 'critica').length} en prioridad crítica · ${area.toLocaleString('es-CO')} ha`} icono={Trees} acento="bg-manglar-50 text-manglar-700" />
    </div>

    <div className="overflow-hidden rounded-3xl bg-superficie shadow-[var(--c-sombra)]">
      <div className="space-y-4 border-b border-linea-suave p-5">
        <div className="flex flex-wrap items-start justify-between gap-5">
          <div className="flex flex-wrap gap-5">
            <fieldset className="min-w-0"><legend className="mb-2 text-xs font-medium text-suave">Estado</legend>
              <div className="flex flex-wrap gap-1 rounded-2xl bg-fondo-alt p-1">{(['todos', ...LISTA_ESTADOS] as const).map((opcion) => <button key={opcion} type="button" aria-pressed={estado === opcion} onClick={() => setEstado(opcion)} className={cn(boton, estado === opcion ? 'bg-manglar-900 text-white' : 'text-suave hover:bg-superficie')}>
                {opcion === 'todos' ? 'Todos' : opcion === 'escalado' ? 'Escalado' : ESTADOS[opcion].etiqueta}<span className="tabular-nums">{conteos[opcion]}</span>
              </button>)}</div>
            </fieldset>
            <fieldset className="min-w-0"><legend className="mb-2 text-xs font-medium text-suave">Prioridad</legend>
              <div className="flex flex-wrap gap-1 rounded-2xl bg-fondo-alt p-1">{(['todas', ...LISTA_PRIORIDADES] as const).map((opcion) => <button key={opcion} type="button" aria-pressed={prioridad === opcion} onClick={() => setPrioridad(opcion)} className={cn(boton, prioridad === opcion ? 'bg-superficie text-texto shadow-sm ring-1 ring-linea' : 'text-suave hover:bg-superficie')}>
                {opcion !== 'todas' && <span aria-hidden="true" className={cn('h-2 w-2 rounded-full', PRIORIDADES[opcion].punto)} />}{opcion === 'todas' ? 'Todas' : PRIORIDADES[opcion].etiqueta}
              </button>)}</div>
            </fieldset>
          </div>
          <div className="ml-auto"><p className="mb-2 text-xs font-medium text-suave">Exportación de datos abiertos</p>
            <div className="flex flex-wrap gap-2">{[
              { formato: 'CSV', icono: FileSpreadsheet, descargar: exportarCSV },
              { formato: 'GeoJSON', icono: FileJson, descargar: exportarGeoJSON },
            ].map(({ formato, icono: Icono, descargar }) => <button key={formato} type="button" disabled={filtrados.length === 0} onClick={() => descargar(filtrados)} title={`Descargar ${filtrados.length} reportes filtrados en ${formato}`} aria-label={`Descargar ${filtrados.length} reportes filtrados en ${formato}`} className={cn(boton, 'text-manglar-900 ring-1 ring-inset ring-linea hover:bg-fondo disabled:cursor-not-allowed disabled:opacity-40')}><Icono size={16} aria-hidden="true" />Exportar {formato}</button>)}</div>
          </div>
        </div>
        <p className="text-xs text-tenue">Mostrando {filtrados.length} de {reportes.length} reportes · la exportación descarga la vista filtrada</p>
      </div>
      {filtrados.length > 0 ? <ReportesPanel reportes={filtrados} orden={orden} ordenar={ordenar} cambiarEstado={cambiarEstado} /> : <div className="flex flex-col items-center gap-4 px-5 py-14 text-center">
        <SearchX size={32} className="text-tenue" aria-hidden="true" /><p className="font-medium text-suave">No hay reportes con estos filtros</p>
        <button type="button" onClick={limpiarFiltros} className={cn(boton, 'bg-manglar-900 text-white hover:bg-manglar-800')}>Limpiar filtros</button>
      </div>}
    </div>
    <div role="status" aria-live="polite" aria-atomic="true" className="pointer-events-none fixed bottom-6 right-6 z-[1200] max-w-[calc(100vw-3rem)]">
      {aviso && <p className="rounded-2xl bg-manglar-950 px-5 py-3 text-sm text-white shadow-[var(--c-sombra-alta)]">{aviso}</p>}
    </div>
  </div>;
}
