// Próximas jornadas de la comunidad, con los inscritos al día: vienen del servidor de Zanky (useJornadas).
import { useEffect, useMemo, useState } from 'react';
import { Users } from 'lucide-react';
import type { Jornada } from '../../types/plataforma';
import { useJornadas } from '../../lib/plataforma/estado';
import { TIPOS_JORNADA } from '../../lib/plataforma/catalogos';

const zona = { timeZone: 'America/Bogota' } as const;
const dia = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, day: 'numeric' }).format(new Date(iso));
const mes = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, month: 'short' }).format(new Date(iso)).replace('.', '');
const cuando = (iso: string) => new Intl.DateTimeFormat('es-CO', { ...zona, weekday: 'long', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
const BANDA: Record<string, string> = {
  siembra: 'linear-gradient(135deg,#22a061,#0b3a58)', limpieza: 'linear-gradient(135deg,#2b87be,#05243a)',
  recorrido_vigias: 'linear-gradient(135deg,#f2c63e,#b45309 60%,#0b3a58)', monitoreo: 'linear-gradient(135deg,#38bdf8,#0b3a58)',
};

export default function JornadasEnVivo({ jornadas: iniciales }: { jornadas: Jornada[] }) {
  const jornadas = useJornadas(iniciales);
  const [ahora, setAhora] = useState(() => Date.now());
  useEffect(() => { const r = window.setInterval(() => setAhora(Date.now()), 60_000); return () => clearInterval(r); }, []);
  const proximas = useMemo(() => jornadas.filter((j) => Date.parse(j.fin) > ahora).sort((a, b) => a.inicio.localeCompare(b.inicio)).slice(0, 3), [jornadas, ahora]);

  if (!proximas.length) {
    return <p className="jornadas-vacio">No hay jornadas próximas. <a href="/plataforma/jornadas">Mira la cartelera</a>: cuando la organización publique una, aparece aquí.</p>;
  }
  return (
    <div className="jornadas-grid">
      {proximas.map((j) => {
        const T = TIPOS_JORNADA[j.tipo];
        return (
          <a key={j.id} className="jornada-mini" href={`/plataforma/jornada?id=${encodeURIComponent(j.id)}`}>
            <span className="banda" style={{ display: 'block', ['--g' as string]: j.imagen_url ? `url("${j.imagen_url.replace(/"/g, '%22')}") center / cover no-repeat` : BANDA[j.tipo] ?? BANDA.siembra }}>
              <span className="fecha"><b>{dia(j.inicio)}</b><small>{mes(j.inicio)}</small></span>
            </span>
            <span className="cuerpo" style={{ display: 'block' }}>
              <small>{T.etiqueta}</small>
              <b>{j.titulo}</b>
              <span>{cuando(j.inicio)} · {j.punto_encuentro}</span>
              <span className="cupos"><Users className="inline size-3.5" aria-hidden="true" /> {j.inscritos} {j.inscritos === 1 ? 'inscrito' : 'inscritos'} · sin límite de cupos</span>
            </span>
          </a>
        );
      })}
    </div>
  );
}
