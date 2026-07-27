/**
 * Rechargement du module Maintenance depuis SAP.
 *
 * Deux modes :
 *   - Fusionner    : les lignes modifiees dans l'application et les ajouts
 *                    manuels sont conserves, le reste est rafraichi depuis SAP ;
 *   - Réinitialiser: la partie SAP est reconstruite integralement (les
 *                    modifications faites sur des objets SAP sont perdues).
 *
 * Dans les deux cas le backend sauvegarde l'etat courant avant de commencer.
 */
import {
  Alert,
  AlertTitle,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Radio,
  RadioGroup,
  Typography,
} from '@mui/material';
import CloudSyncIcon from '@mui/icons-material/CloudSync';
import React, { useState } from 'react';

import {
  MaintenanceJob,
  ReloadMode,
  errorMessage,
  startReload,
} from '../../services/maintenanceSnapshotService';

interface Props {
  open: boolean;
  onClose: () => void;
  /** Appele quand le rechargement a ete lance (job a suivre). */
  onStarted: (job: MaintenanceJob) => void;
}

const ReloadSapDialog: React.FC<Props> = ({ open, onClose, onStarted }) => {
  const [mode, setMode] = useState<ReloadMode>('merge');
  const [withExtraction, setWithExtraction] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleStart = async () => {
    setSubmitting(true);
    setError(null);
    try {
      const job = await startReload({ mode, withExtraction });
      onStarted(job);
      onClose();
    } catch (e) {
      setError(errorMessage(e, 'Impossible de lancer le rechargement.'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onClose={submitting ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Recharger depuis SAP</DialogTitle>
      <DialogContent dividers>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        <Typography variant="subtitle2" sx={{ mb: 1 }}>
          Que faire de vos modifications ?
        </Typography>
        <RadioGroup value={mode} onChange={(e) => setMode(e.target.value as ReloadMode)}>
          <FormControlLabel
            value="merge"
            control={<Radio />}
            disabled={submitting}
            label={
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                  Fusionner (recommandé)
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Vos renommages, déplacements et ajouts sont conservés. Seuls les objets
                  jamais modifiés dans l'application sont rafraîchis, et les nouveautés SAP
                  sont ajoutées.
                </Typography>
              </Box>
            }
          />
          <FormControlLabel
            value="reset"
            control={<Radio />}
            disabled={submitting}
            label={
              <Box>
                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                  Réinitialiser depuis SAP
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  L'arborescence SAP est reconstruite à l'identique. Vos modifications sur
                  les objets SAP sont perdues (les objets créés manuellement sont conservés).
                </Typography>
              </Box>
            }
          />
        </RadioGroup>

        {mode === 'reset' && (
          <Alert severity="warning" sx={{ mt: 1 }}>
            Ce mode écrase le travail effectué sur les objets venant de SAP.
          </Alert>
        )}

        <Box sx={{ mt: 2 }}>
          <FormControlLabel
            control={
              <Checkbox
                checked={withExtraction}
                onChange={(e) => setWithExtraction(e.target.checked)}
                disabled={submitting}
              />
            }
            label="Extraire au préalable les données depuis SAP"
          />
          <Typography variant="caption" color="text.secondary" component="div" sx={{ ml: 4 }}>
            {withExtraction
              ? "Les tables SAP sont ré-extraites avant la reconstruction (opération longue, plusieurs minutes)."
              : 'La reconstruction utilise les données SAP déjà présentes en base (rapide).'}
          </Typography>
        </Box>

        {withExtraction && (
          <Alert severity="info" sx={{ mt: 2 }}>
            <AlertTitle>À savoir</AlertTitle>
            La ré-extraction écrase les tables SAP brutes : les modifications faites depuis
            les écrans Équipements et Articles seront remplacées par les données de SAP. Le
            mode Fusionner ne protège que l'arborescence IH02.
          </Alert>
        )}

        <Alert severity="success" sx={{ mt: 2 }}>
          L'état actuel est sauvegardé automatiquement avant l'opération : vous pourrez
          revenir en arrière depuis « États sauvegardés ».
        </Alert>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={submitting}>
          Annuler
        </Button>
        <Button
          variant="contained"
          color={mode === 'reset' ? 'warning' : 'primary'}
          startIcon={<CloudSyncIcon />}
          onClick={handleStart}
          disabled={submitting}
        >
          {submitting ? 'Lancement…' : 'Lancer le rechargement'}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default ReloadSapDialog;
