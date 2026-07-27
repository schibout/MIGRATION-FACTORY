/**
 * Contenu de la gestion des etats sauvegardes : capture d'un etat nomme,
 * chronologie des points de restauration, restauration et suppression.
 *
 * Extrait du dialogue pour etre partage avec la page dediee
 * (/maintenance/backups) : meme comportement des deux cotes, un seul endroit
 * a maintenir.
 *
 * Design — un etat sauvegarde n'a de sens que dans le temps (« ou en etais-je
 * mardi ? »). L'historique se lit donc comme une CHRONOLOGIE et non comme une
 * liste : rail vertical, horodatage en chasse fixe en tete de ligne. Les etats
 * nommes par l'utilisateur (puce pleine) se distinguent des sauvegardes
 * automatiques prises par le systeme (puce creuse), sans les cacher : ce sont
 * elles qui rendent les operations annulables.
 */
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import DeleteIcon from '@mui/icons-material/Delete';
import HistoryIcon from '@mui/icons-material/History';
import RestoreIcon from '@mui/icons-material/Restore';
import SaveIcon from '@mui/icons-material/Save';
import ShieldIcon from '@mui/icons-material/GppGood';
import React, { useCallback, useEffect, useImperativeHandle, useState } from 'react';

import {
  MaintenanceJob,
  MaintenanceSnapshot,
  createSnapshot,
  deleteSnapshot,
  errorMessage,
  formatBytes,
  listSnapshots,
  restoreSnapshot,
  snapshotKindLabel,
} from '../../services/maintenanceSnapshotService';
import { Metric, Panel, RailMarker, SectionLabel, formatDateTime } from './maintenanceUi';

export interface SnapshotManagerHandle {
  /** Recharge la liste (ex. apres la fin d'une operation). */
  reload: () => void;
}

interface Props {
  /** Appele quand une restauration a ete lancee (job a suivre). */
  onRestoreStarted: (job: MaintenanceJob) => void;
  /** Desactive les actions quand une operation maintenance tourne deja. */
  jobActive?: boolean;
  /** Charge la liste des l'affichage (faux tant qu'un dialogue est ferme). */
  active?: boolean;
}

const SnapshotManagerPanel = React.forwardRef<SnapshotManagerHandle, Props>(
  ({ onRestoreStarted, jobActive = false, active = true }, ref) => {
    const theme = useTheme();
    const [snapshots, setSnapshots] = useState<MaintenanceSnapshot[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [name, setName] = useState('');
    const [description, setDescription] = useState('');
    const [saving, setSaving] = useState(false);
    const [pendingRestore, setPendingRestore] = useState<MaintenanceSnapshot | null>(null);
    const [busyId, setBusyId] = useState<number | null>(null);

    const load = useCallback(async () => {
      setLoading(true);
      setError(null);
      try {
        setSnapshots(await listSnapshots());
      } catch (e) {
        setError(errorMessage(e, 'Impossible de charger les états sauvegardés.'));
      } finally {
        setLoading(false);
      }
    }, []);

    useEffect(() => {
      if (active) load();
    }, [active, load]);

    useImperativeHandle(ref, () => ({ reload: load }), [load]);

    const handleCreate = async () => {
      if (!name.trim()) return;
      setSaving(true);
      setError(null);
      try {
        await createSnapshot(name.trim(), description.trim() || undefined);
        setName('');
        setDescription('');
        await load();
      } catch (e) {
        setError(errorMessage(e, "Impossible de créer l'état sauvegardé."));
      } finally {
        setSaving(false);
      }
    };

    const handleDelete = async (snapshot: MaintenanceSnapshot) => {
      setBusyId(snapshot.id);
      setError(null);
      try {
        await deleteSnapshot(snapshot.id);
        await load();
      } catch (e) {
        setError(errorMessage(e, "Impossible de supprimer l'état."));
      } finally {
        setBusyId(null);
      }
    };

    const confirmRestore = async () => {
      if (!pendingRestore) return;
      setBusyId(pendingRestore.id);
      setError(null);
      try {
        const job = await restoreSnapshot(pendingRestore.id);
        setPendingRestore(null);
        onRestoreStarted(job);
      } catch (e) {
        setError(errorMessage(e, 'Impossible de lancer la restauration.'));
      } finally {
        setBusyId(null);
      }
    };

    return (
      <>
        {error && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {/* ── Zone de capture ── */}
        <SectionLabel sx={{ mb: 1 }}>Enregistrer l'état actuel</SectionLabel>
        <Panel accent="primary">
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
            <TextField
              size="small"
              label="Nom de l'état"
              value={name}
              onChange={(e) => setName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleCreate();
              }}
              disabled={saving || jobActive}
              sx={{ flex: 1 }}
            />
            <TextField
              size="small"
              label="Description (facultatif)"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              disabled={saving || jobActive}
              sx={{ flex: 2 }}
            />
            <Button
              variant="contained"
              startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveIcon />}
              onClick={handleCreate}
              disabled={saving || jobActive || !name.trim()}
            >
              Enregistrer
            </Button>
          </Stack>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
            Copie l'arborescence IH02, les équipements et les articles dans leur état actuel.
          </Typography>
        </Panel>

        {/* ── Chronologie des points de restauration ── */}
        <SectionLabel sx={{ mt: 2.5, mb: 1.5 }}>Historique</SectionLabel>

        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
            <CircularProgress size={28} />
          </Box>
        ) : snapshots.length === 0 ? (
          <Box sx={{ textAlign: 'center', py: 5, px: 2 }}>
            <HistoryIcon sx={{ fontSize: 34, color: 'text.disabled', mb: 1 }} />
            <Typography variant="body2" color="text.secondary">
              Aucun état sauvegardé pour l'instant.
            </Typography>
            <Typography variant="caption" color="text.disabled">
              Enregistrez-en un avant une session de modifications importante : vous pourrez y
              revenir à tout moment.
            </Typography>
          </Box>
        ) : (
          <Box>
            {snapshots.map((snapshot, index) => {
              const isLast = index === snapshots.length - 1;
              const auto = snapshot.kind !== 'MANUAL';
              const busy = busyId === snapshot.id;
              const failed = snapshot.status === 'FAILED';

              return (
                <Box
                  key={snapshot.id}
                  sx={{
                    display: 'flex',
                    gap: 1.25,
                    '@keyframes snap-in': {
                      from: { opacity: 0, transform: 'translateY(-2px)' },
                      to: { opacity: 1, transform: 'none' },
                    },
                    animation: 'snap-in .3s ease both',
                    animationDelay: `${Math.min(index, 8) * 40}ms`,
                  }}
                >
                  <RailMarker state={failed ? 'error' : 'done'} isLast={isLast} hollow={auto} />

                  <Box
                    sx={{
                      flex: 1,
                      minWidth: 0,
                      pb: isLast ? 0.5 : 2,
                      // La rangee d'actions n'apparait qu'au survol : l'historique
                      // reste calme tant qu'on ne cherche pas a agir.
                      '&:hover .snapshot-actions, &:focus-within .snapshot-actions': {
                        opacity: 1,
                      },
                    }}
                  >
                    <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1 }}>
                      <Box sx={{ flex: 1, minWidth: 0 }}>
                        <Metric sx={{ color: 'text.disabled', fontSize: '0.75rem' }}>
                          {formatDateTime(snapshot.created_at)}
                        </Metric>
                        <Box
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 0.75,
                            flexWrap: 'wrap',
                            mt: 0.25,
                          }}
                        >
                          <Typography
                            variant="body2"
                            sx={{
                              fontWeight: auto ? 400 : 600,
                              color: auto ? 'text.secondary' : 'text.primary',
                            }}
                          >
                            {snapshot.name}
                          </Typography>
                          {auto && (
                            <Tooltip title={snapshotKindLabel(snapshot.kind)}>
                              <ShieldIcon sx={{ fontSize: 14, color: 'text.disabled' }} />
                            </Tooltip>
                          )}
                          {failed && <Chip size="small" color="error" label="Échec" />}
                          {snapshot.status === 'CREATING' && <Chip size="small" label="En cours" />}
                        </Box>

                        {snapshot.description && (
                          <Typography
                            variant="caption"
                            color="text.secondary"
                            sx={{ display: 'block' }}
                          >
                            {snapshot.description}
                          </Typography>
                        )}

                        <Box sx={{ display: 'flex', gap: 1.5, mt: 0.5, flexWrap: 'wrap' }}>
                          <Metric sx={{ color: 'text.disabled', fontSize: '0.75rem' }}>
                            {snapshot.total_rows.toLocaleString('fr-FR')} lignes
                          </Metric>
                          <Metric sx={{ color: 'text.disabled', fontSize: '0.75rem' }}>
                            {formatBytes(snapshot.size_bytes)}
                          </Metric>
                          {snapshot.created_by && (
                            <Typography variant="caption" color="text.disabled">
                              {snapshot.created_by}
                            </Typography>
                          )}
                        </Box>
                      </Box>

                      <Stack
                        direction="row"
                        spacing={0.5}
                        className="snapshot-actions"
                        sx={{
                          opacity: { xs: 1, md: busy ? 1 : 0 },
                          transition: 'opacity .15s',
                          flexShrink: 0,
                        }}
                      >
                        <Tooltip title="Restaurer cet état">
                          <span>
                            <IconButton
                              size="small"
                              color="primary"
                              onClick={() => setPendingRestore(snapshot)}
                              disabled={jobActive || busy || snapshot.status !== 'READY'}
                              aria-label={`Restaurer ${snapshot.name}`}
                            >
                              {busy ? (
                                <CircularProgress size={18} />
                              ) : (
                                <RestoreIcon fontSize="small" />
                              )}
                            </IconButton>
                          </span>
                        </Tooltip>
                        <Tooltip title="Supprimer">
                          <span>
                            <IconButton
                              size="small"
                              onClick={() => handleDelete(snapshot)}
                              disabled={jobActive || busy}
                              aria-label={`Supprimer ${snapshot.name}`}
                            >
                              <DeleteIcon fontSize="small" />
                            </IconButton>
                          </span>
                        </Tooltip>
                      </Stack>
                    </Box>
                  </Box>
                </Box>
              );
            })}
          </Box>
        )}

        {/* ── Confirmation de restauration ── */}
        <Dialog
          open={!!pendingRestore}
          onClose={() => setPendingRestore(null)}
          maxWidth="sm"
          fullWidth
        >
          <DialogTitle sx={{ pb: 1 }}>Restaurer « {pendingRestore?.name} » ?</DialogTitle>
          <DialogContent>
            <Typography variant="body2" color="text.secondary">
              Les données maintenance reviendront à leur état du{' '}
              <Metric sx={{ color: 'text.primary' }}>
                {formatDateTime(pendingRestore?.created_at ?? null)}
              </Metric>
              . Toutes les modifications faites depuis seront remplacées.
            </Typography>

            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 1,
                mt: 2,
                p: 1.5,
                borderRadius: 1,
                backgroundColor: alpha(theme.palette.secondary.main, 0.09),
              }}
            >
              <ShieldIcon sx={{ fontSize: 18, color: theme.palette.secondary.main }} />
              <Typography variant="caption" color="text.secondary">
                L'état actuel sera sauvegardé avant la restauration : vous pourrez revenir en
                arrière.
              </Typography>
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setPendingRestore(null)}>Annuler</Button>
            <Button variant="contained" startIcon={<RestoreIcon />} onClick={confirmRestore}>
              Restaurer
            </Button>
          </DialogActions>
        </Dialog>
      </>
    );
  },
);

SnapshotManagerPanel.displayName = 'SnapshotManagerPanel';

export default SnapshotManagerPanel;
