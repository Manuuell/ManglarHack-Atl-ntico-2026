import { useEffect, useState } from 'react';
import { cargarCRA, type EspejoCRA } from './cra';
import { construirWorkflow, RESPALDO_WORKFLOW, type Workflow } from './workflowVivo';

export type EstadoDatosCRA = 'cargando' | 'en_vivo' | 'respaldo';

/** Cifras del workflow de la C.R.A.: las de respaldo al montar y las de la copia en vivo cuando llegan. */
export function useWorkflowCRA(): { workflow: Workflow; espejo: EspejoCRA | null; estado: EstadoDatosCRA } {
  const [valor, setValor] = useState<{ workflow: Workflow; espejo: EspejoCRA | null; estado: EstadoDatosCRA }>({ workflow: RESPALDO_WORKFLOW, espejo: null, estado: 'cargando' });
  useEffect(() => {
    let vigente = true;
    cargarCRA()
      .then(({ resumen, espejo }) => { if (vigente) setValor({ workflow: construirWorkflow(resumen), espejo, estado: 'en_vivo' }); })
      .catch(() => { if (vigente) setValor((v) => ({ ...v, estado: 'respaldo' })); });
    return () => { vigente = false; };
  }, []);
  return valor;
}
