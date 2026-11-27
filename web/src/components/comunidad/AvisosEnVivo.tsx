// Avisos en tiempo real: cuando alguien reporta un problema o se inscribe en una jornada
// (en esta pestaña o en otra), aparece un aviso que se va solo.
import { useEffect, useRef, useState } from 'react';
import { X } from 'lucide-react';
import type { Jornada } from '../../types/plataforma';
import { jornadas as almacenJornadas } from '../../lib/plataforma/estado';
import { leerLocales, numeroDeCaso, suscribirLocales } from '../../lib/comunidad/reportesLocales';
import { estadoDelServidor, obtenerPublicosActuales, suscribir as suscribirReportes } from '../../lib/reportesStore';
import { backendActivo } from '../../lib/backend/supabase';
import { TIPOS } from '../../lib/catalogos';

interface Aviso { id: string; icono: string; texto: string; enlace?: { href: string; texto: string } }

export default function AvisosEnVivo({ jornadas }: { jornadas: Jornada[] }) {
  const [avisos, setAvisos] = useState<Aviso[]>([]);
  const vistos = useRef(new Set(leerLocales().map((r) => r.id)));
  const inscritos = useRef(new Map<string, number>());

  const mostrar = (a: Aviso) => {
    setAvisos((prev) => [...prev.filter((x) => x.id !== a.id), a].slice(-3));
    window.setTimeout(() => setAvisos((prev) => prev.filter((x) => x.id !== a.id)), 7000);
  };

  useEffect(() => {
    // Con el servidor, los reportes nuevos de cualquier persona llegan en la lectura periódica; la primera
    // lectura es la base (no se avisa lo que ya estaba). En demostración, los de este navegador y sus pestañas.
    let base: Set<string> | null = null;
    const revisarServidor = () => {
      if (estadoDelServidor() !== 'listo') return;
      const lista = obtenerPublicosActuales();
      if (base === null) { base = new Set(lista.map((r) => r.id)); return; }
      for (const r of [...lista].reverse()) {
        if (base.has(r.id)) continue;
        base.add(r.id);
        mostrar({ id: r.id, icono: '🚨', texto: `Nuevo reporte: ${TIPOS[r.tipo].etiquetaLarga} en ${r.zona ?? r.municipio}.`, enlace: { href: '#mapa', texto: 'Ver en el mapa' } });
      }
    };
    const quitarReportes = backendActivo
      ? (revisarServidor(), suscribirReportes(revisarServidor))
      : suscribirLocales(() => {
        for (const r of leerLocales()) {
          if (vistos.current.has(r.id)) continue;
          vistos.current.add(r.id);
          mostrar({ id: r.id, icono: '🚨', texto: `Nuevo reporte ${numeroDeCaso(r.id)}: ${TIPOS[r.tipo].etiquetaLarga} en ${r.zona ?? 'el Atlántico'}.`, enlace: { href: '#mapa', texto: 'Ver en el mapa' } });
        }
      });
    almacenJornadas.inicializar(jornadas);
    for (const j of almacenJornadas.obtener()) inscritos.current.set(j.id, j.inscritos);
    const quitarJornadas = almacenJornadas.suscribir(() => {
      for (const j of almacenJornadas.obtener()) {
        const antes = inscritos.current.get(j.id);
        if (antes === undefined) mostrar({ id: `nueva-${j.id}`, icono: '🌱', texto: `Nueva jornada: ${j.titulo}.`, enlace: { href: `/plataforma/jornadas?jornada=${j.id}`, texto: 'Ver la invitación' } });
        else if (j.inscritos > antes) mostrar({ id: `insc-${j.id}-${j.inscritos}`, icono: '🙌', texto: `Alguien se sumó a «${j.titulo}» (${j.inscritos}/${j.cupos}).`, enlace: { href: `/plataforma/jornadas?jornada=${j.id}`, texto: 'Sumarme' } });
        inscritos.current.set(j.id, j.inscritos);
      }
    });
    return () => { quitarReportes(); quitarJornadas(); };
  }, [jornadas]);

  return (
    <div className="avisos" aria-live="polite" aria-relevant="additions">
      {avisos.map((a) => (
        <div key={a.id} className="aviso" role="status">
          <span className="aviso-icono" aria-hidden="true">{a.icono}</span>
          <p>{a.texto}{a.enlace && <> <a href={a.enlace.href} onClick={() => a.enlace?.href === '#mapa' && window.dispatchEvent(new CustomEvent('zanky:ver-reporte', { detail: a.id }))}>{a.enlace.texto}</a></>}</p>
          <button type="button" aria-label="Cerrar aviso" onClick={() => setAvisos((prev) => prev.filter((x) => x.id !== a.id))}><X className="size-4" aria-hidden="true" /></button>
        </div>
      ))}
    </div>
  );
}
