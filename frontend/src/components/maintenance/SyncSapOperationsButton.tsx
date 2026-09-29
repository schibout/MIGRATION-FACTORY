import React, { useEffect, useRef, useState } from 'react';
import {
  Alert, Box, Button, Dialog, DialogActions, DialogContent, DialogTitle, LinearProgress, Typography,
} from '@mui/material';
import { Sync as SyncIcon } from '@mui/icons-material';

import extractionService from '../../services/extractionService';

// Tables SAP lues par les ecrans Operations / detail d'ordre (toutes cataloguees
// dans sap_table_properties).
const TABLES = [
  'AUFK', 'AFKO', 'AFIH', 'AFVC', 'AFVV', 'ILOA', 'JEST', 'RESB', 'PMCO', 'OBJK',
  'CRHD', 'CRTX', 'MAKT', 'EQKT', 'IFLOTX', 'T001', 'T001W', 'TGSBT', 'CSKT', 'CEPCT',
  'TJ02T', 'T356_T', 'T353I_T',
];
const FIN_OK = ['completed', 'success', 'done', 'finished'];
const FIN_KO = ['failed', 'error', 'stopped', 'cancelled', 'canceled'];

// Relance l'extraction SAP de ces tables (meme mode que le rechargement maintenance)
// puis previent la page (onDone) pour qu'elle relise ses donnees.
// Tables lues par les ecrans Avis / detail d'un avis.
export const TABLES_AVIS = [
  'QMEL', 'QMIH', 'QMFE', 'QMUR', 'QMSM', 'QMMA', 'JEST', 'ILOA', 'CRHD', 'IFLOTX', 'EQKT', 'TJ02T', 'T356_T',
];

const SyncSapOperationsButton: React.FC<{ onDone?: () => void; tables?: string[]; ecran?: string }> = (
  { onDone, tables = TABLES, ecran = 'Opérations' },
) => {
  const [confirmer, setConfirmer] = useState(false);
  const [jobId, setJobId] = useState<string | null>(null);
  const [progression, setProgression] = useState(0);
  const [message, setMessage] = useState<{ ok: boolean; texte: string } | null>(null);
  const timer = useRef<number>();

  useEffect(() => () => window.clearInterval(timer.current), []);

  const suivre = (id: string) => {
    timer.current = window.setInterval(async () => {
      try {
        const s: any = await extractionService.getExtractionStatus(id);
        const statut = String(s.status || 'running').toLowerCase();
        setProgression(Number(s.progress_percentage ?? s.progress ?? 0));
        if (FIN_OK.includes(statut) || FIN_KO.includes(statut)) {
          window.clearInterval(timer.current);
          setJobId(null);
          const ok = FIN_OK.includes(statut);
          setMessage({ ok, texte: ok ? 'Synchronisation SAP terminée.' : `Synchronisation SAP en échec : ${s.error_message || s.error || statut}` });
          if (ok) onDone?.();
        }
      } catch { /* statut momentanement indisponible : on reessaie au tick suivant */ }
    }, 3000);
  };

  const lancer = async () => {
    setConfirmer(false);
    setMessage(null);
    setProgression(0);
    try {
      const { extraction_id } = await extractionService.startExtraction({
        tables, options: { mode: 'standard', clean: false },
      } as any);
      setJobId(extraction_id);
      suivre(extraction_id);
    } catch (e: any) {
      setMessage({ ok: false, texte: e?.response?.data?.error || 'Impossible de lancer la synchronisation SAP' });
    }
  };

  return (
    <Box>
      <Button variant="outlined" startIcon={<SyncIcon />} disabled={!!jobId} onClick={() => setConfirmer(true)}>
        {jobId ? 'Synchronisation en cours…' : 'Synchroniser avec SAP'}
      </Button>
      {jobId && <LinearProgress variant="determinate" value={progression} sx={{ mt: 1 }} />}
      {message && <Alert severity={message.ok ? 'success' : 'error'} sx={{ mt: 1 }} onClose={() => setMessage(null)}>{message.texte}</Alert>}

      <Dialog open={confirmer} onClose={() => setConfirmer(false)}>
        <DialogTitle>Synchroniser avec SAP</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 1 }}>
            Recharge depuis SAP les {tables.length} tables utilisées par les écrans {ecran} :
          </Typography>
          <Typography variant="body2" sx={{ fontFamily: 'monospace', mb: 1 }}>{tables.join(', ')}</Typography>
          <Typography variant="body2" color="text.secondary">
            L'extraction peut durer plusieurs dizaines de minutes (JEST notamment). Ces tables
            servent aussi à d'autres modules (ETL Opérations, maintenance).
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmer(false)}>Annuler</Button>
          <Button variant="contained" onClick={lancer}>Lancer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default SyncSapOperationsButton;
