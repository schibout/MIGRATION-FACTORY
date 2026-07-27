/**
 * Rechargement du module Maintenance depuis SAP.
 *
 * Deux modes :
 *   - Fusionner     : les lignes modifiees dans l'application et les ajouts
 *                     manuels sont conserves, le reste est rafraichi depuis SAP ;
 *   - Reinitialiser : la partie SAP est reconstruite integralement (les
 *                     modifications faites sur des objets SAP sont perdues).
 *
 * Design — le choix engage des semaines de saisie, et la difference entre les
 * deux modes tient a trois consequences precises. Plutot que de la decrire en
 * prose (que personne ne lit avant de cliquer), chaque mode expose la MEME
 * grille d'impact : « vos modifications / vos ajouts / les nouveautes SAP ».
 * La comparaison devient visuelle, le mode destructif se reconnait a sa colonne
 * de croix avant meme d'avoir lu un mot.
 */
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import CloudSyncIcon from '@mui/icons-material/CloudSync';
import MergeIcon from '@mui/icons-material/CallMerge';
import RestartAltIcon from '@mui/icons-material/RestartAlt';
import ShieldIcon from '@mui/icons-material/GppGood';
import React, { useState } from 'react';

import {
  MaintenanceJob,
  ReloadMode,
  errorMessage,
  startReload,
} from '../../services/maintenanceSnapshotService';
import { Panel, SectionLabel } from './maintenanceUi';

interface Props {
  open: boolean;
  onClose: () => void;
  /** Appele quand le rechargement a ete lance (job a suivre). */
  onStarted: (job: MaintenanceJob) => void;
}

/** Les trois consequences qui distinguent reellement les deux modes. */
const IMPACTS = [
  { key: 'edits', label: 'Vos modifications', merge: true, reset: false },
  { key: 'manual', label: 'Vos ajouts manuels', merge: true, reset: true },
  { key: 'news', label: 'Nouveautés SAP', merge: true, reset: true },
] as const;

const MODES = [
  {
    value: 'merge' as ReloadMode,
    icon: MergeIcon,
    title: 'Fusionner',
    tagline: 'Rafraîchit SAP sans toucher à votre travail',
  },
  {
    value: 'reset' as ReloadMode,
    icon: RestartAltIcon,
    title: 'Réinitialiser',
    tagline: "Reconstruit l'arborescence telle qu'elle est dans SAP",
  },
];

const ReloadSapDialog: React.FC<Props> = ({ open, onClose, onStarted }) => {
  const theme = useTheme();
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
      <DialogTitle sx={{ pb: 1 }}>Recharger depuis SAP</DialogTitle>

      <DialogContent dividers>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        <SectionLabel sx={{ mb: 1 }}>Que deviennent vos données ?</SectionLabel>

        <Box
          role="radiogroup"
          aria-label="Mode de rechargement"
          sx={{ display: 'flex', gap: 1.5, flexDirection: { xs: 'column', sm: 'row' } }}
        >
          {MODES.map(({ value, icon: Icon, title, tagline }) => {
            const selected = mode === value;
            const destructive = value === 'reset';
            const tint = destructive ? theme.palette.warning.main : theme.palette.primary.main;

            return (
              <Box
                key={value}
                role="radio"
                aria-checked={selected}
                tabIndex={0}
                onClick={() => !submitting && setMode(value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    if (!submitting) setMode(value);
                  }
                }}
                sx={{
                  flex: 1,
                  p: 1.5,
                  borderRadius: 1,
                  cursor: submitting ? 'default' : 'pointer',
                  border: `1px solid ${selected ? tint : alpha(theme.palette.common.white, 0.12)}`,
                  backgroundColor: selected
                    ? alpha(tint, 0.09)
                    : alpha(theme.palette.common.black, 0.15),
                  boxShadow: selected ? `inset 0 0 0 1px ${alpha(tint, 0.5)}` : 'none',
                  transition: 'border-color .18s, background-color .18s, box-shadow .18s',
                  '&:hover': {
                    borderColor: selected ? tint : alpha(theme.palette.common.white, 0.25),
                  },
                  '&:focus-visible': { outline: `2px solid ${tint}`, outlineOffset: 2 },
                }}
              >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.25 }}>
                  <Icon sx={{ fontSize: 18, color: selected ? tint : 'text.secondary' }} />
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {title}
                  </Typography>
                </Box>
                <Typography
                  variant="caption"
                  color="text.secondary"
                  sx={{ display: 'block', minHeight: 32 }}
                >
                  {tagline}
                </Typography>

                {/* Grille d'impact : identique des deux cotes, donc comparable d'un regard */}
                <Box
                  sx={{
                    mt: 1,
                    pt: 1,
                    borderTop: `1px solid ${alpha(theme.palette.common.white, 0.08)}`,
                  }}
                >
                  {IMPACTS.map((impact) => {
                    const kept = destructive ? impact.reset : impact.merge;
                    return (
                      <Box
                        key={impact.key}
                        sx={{ display: 'flex', alignItems: 'center', gap: 0.75, py: 0.25 }}
                      >
                        {kept ? (
                          <CheckIcon
                            sx={{ fontSize: 14, color: theme.palette.secondary.main }}
                            titleAccess="conservé"
                          />
                        ) : (
                          <CloseIcon
                            sx={{ fontSize: 14, color: theme.palette.error.main }}
                            titleAccess="perdu"
                          />
                        )}
                        <Typography
                          variant="caption"
                          sx={{ color: kept ? 'text.secondary' : theme.palette.error.light }}
                        >
                          {impact.label}
                        </Typography>
                      </Box>
                    );
                  })}
                </Box>
              </Box>
            );
          })}
        </Box>

        {/* ── Option d'extraction et sa consequence ── */}
        <Panel sx={{ mt: 2 }} accent={withExtraction ? 'warning' : 'none'}>
          <FormControlLabel
            sx={{ m: 0 }}
            control={
              <Checkbox
                size="small"
                checked={withExtraction}
                onChange={(e) => setWithExtraction(e.target.checked)}
                disabled={submitting}
                sx={{ mr: 0.5 }}
              />
            }
            label={
              <Typography variant="body2" sx={{ fontWeight: 500 }}>
                Extraire au préalable les données depuis SAP
              </Typography>
            }
          />
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', ml: 4 }}>
            {withExtraction
              ? "Les tables SAP brutes sont ré-extraites avant la reconstruction (plusieurs minutes). Elles sont écrasées : les modifications faites depuis les écrans Équipements et Articles seront remplacées par les données de SAP."
              : 'La reconstruction utilise les données SAP déjà présentes en base. Rapide, et les tables brutes ne sont pas touchées.'}
          </Typography>
        </Panel>
      </DialogContent>

      {/* ── Filet de securite : derniere chose lue avant de cliquer ── */}
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          gap: 1,
          px: 3,
          py: 1,
          backgroundColor: alpha(theme.palette.secondary.main, 0.08),
        }}
      >
        <ShieldIcon sx={{ fontSize: 16, color: theme.palette.secondary.main }} />
        <Typography variant="caption" color="text.secondary">
          L'état actuel est sauvegardé automatiquement : l'opération reste annulable.
        </Typography>
      </Box>

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
          {submitting ? 'Lancement…' : mode === 'reset' ? 'Réinitialiser' : 'Fusionner'}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default ReloadSapDialog;
