import React, { useState } from 'react';
import { Box, CircularProgress, IconButton, TextField, Tooltip } from '@mui/material';
import { Check as ValiderIcon, Close as AnnulerIcon, Edit as EditerIcon } from '@mui/icons-material';

import api from '../../services/api';

// Date de derniere execution d'une gamme PE Tools, modifiable sur place (liste et detail).
// PUT /maintenance/pe-tools/<raw_id>/date-derniere-execution : la saisie est enregistree pour le
// plan (a defaut le poste d'entretien) de la gamme et prime sur le fichier ; champ vide = retour a
// la date du fichier. La reponse porte les dates recalculees (derniere execution + IFS).
export interface ResultatSaisieDate {
  date_derniere_execution: string | null;
  ifs_date_execution: string | null;
  saisie_manuelle: boolean;
  nb_gammes: number;
  id_type: 'PLAN' | 'POSTE';
  identifiant: string;
}

export const fmtDateIso = (d?: string | null) => (d ? String(d).slice(0, 10).split('-').reverse().join('/') : '');

interface Props {
  rawId: number;
  valeur: string | null;
  onSaved: (r: ResultatSaisieDate) => void;
  onError: (message: string) => void;
}

const DateExecutionEditable: React.FC<Props> = ({ rawId, valeur, onSaved, onError }) => {
  const [edition, setEdition] = useState(false);
  const [saisie, setSaisie] = useState('');
  const [envoi, setEnvoi] = useState(false);

  const ouvrir = (e: React.MouseEvent) => {
    e.stopPropagation();
    setSaisie(valeur ? String(valeur).slice(0, 10) : '');
    setEdition(true);
  };

  const enregistrer = async () => {
    setEnvoi(true);
    try {
      const res = await api.put(`/maintenance/pe-tools/${rawId}/date-derniere-execution`, { date: saisie || null });
      onSaved(res.data);
      setEdition(false);
    } catch (e: any) {
      onError(e?.response?.data?.error || 'Enregistrement de la date impossible');
    } finally {
      setEnvoi(false);
    }
  };

  if (!edition) {
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, whiteSpace: 'nowrap' }}>
        {fmtDateIso(valeur) || '—'}
        <Tooltip title="Saisir la date de dernière exécution">
          <IconButton size="small" onClick={ouvrir}><EditerIcon sx={{ fontSize: 16 }} /></IconButton>
        </Tooltip>
      </Box>
    );
  }
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }} onClick={(e) => e.stopPropagation()}>
      <TextField
        type="date" size="small" autoFocus value={saisie} disabled={envoi}
        onChange={(e) => setSaisie(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') enregistrer();
          if (e.key === 'Escape') setEdition(false);
        }}
        helperText="Vide = date du fichier"
        sx={{ width: 170 }}
      />
      {envoi ? <CircularProgress size={18} /> : (
        <>
          <Tooltip title="Enregistrer"><IconButton size="small" color="primary" onClick={enregistrer}><ValiderIcon fontSize="small" /></IconButton></Tooltip>
          <Tooltip title="Annuler"><IconButton size="small" onClick={() => setEdition(false)}><AnnulerIcon fontSize="small" /></IconButton></Tooltip>
        </>
      )}
    </Box>
  );
};

export default DateExecutionEditable;
