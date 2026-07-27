/**
 * Gestion des etats sauvegardes du module Maintenance :
 * creation d'un etat nomme, restauration, suppression.
 *
 * Restaurer est destructif pour l'etat courant — mais reversible : le backend
 * sauvegarde automatiquement l'etat courant (AUTO_PRE_RESTORE) avant d'ecraser.
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
  DialogContentText,
  DialogTitle,
  Divider,
  IconButton,
  List,
  ListItem,
  ListItemText,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import RestoreIcon from '@mui/icons-material/Restore';
import SaveIcon from '@mui/icons-material/Save';
import React, { useCallback, useEffect, useState } from 'react';

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

interface Props {
  open: boolean;
  onClose: () => void;
  /** Appele quand une restauration a ete lancee (job a suivre). */
  onRestoreStarted: (job: MaintenanceJob) => void;
  /** Desactive les actions quand une operation maintenance tourne deja. */
  jobActive?: boolean;
}

const formatDate = (iso: string | null): string =>
  iso ? new Date(iso).toLocaleString('fr-FR') : '—';

const SnapshotManagerDialog: React.FC<Props> = ({
  open,
  onClose,
  onRestoreStarted,
  jobActive = false,
}) => {
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
    if (open) load();
  }, [open, load]);

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
      onClose();
    } catch (e) {
      setError(errorMessage(e, 'Impossible de lancer la restauration.'));
    } finally {
      setBusyId(null);
    }
  };

  return (
    <>
      <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
        <DialogTitle>États sauvegardés</DialogTitle>
        <DialogContent dividers>
          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
              {error}
            </Alert>
          )}

          <Typography variant="subtitle2" sx={{ mb: 1 }}>
            Enregistrer l'état actuel
          </Typography>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mb: 1 }}>
            <TextField
              size="small"
              label="Nom de l'état"
              value={name}
              onChange={(e) => setName(e.target.value)}
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
              startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />}
              onClick={handleCreate}
              disabled={saving || jobActive || !name.trim()}
            >
              Enregistrer
            </Button>
          </Stack>
          <Typography variant="caption" color="text.secondary">
            Copie l'arborescence IH02, les équipements et les articles dans leur état actuel.
          </Typography>

          <Divider sx={{ my: 2 }} />

          <Typography variant="subtitle2" sx={{ mb: 1 }}>
            Historique
          </Typography>

          {loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress size={28} />
            </Box>
          ) : snapshots.length === 0 ? (
            <Typography variant="body2" color="text.secondary" sx={{ py: 2 }}>
              Aucun état sauvegardé pour l'instant.
            </Typography>
          ) : (
            <List dense>
              {snapshots.map((snapshot) => (
                <ListItem
                  key={snapshot.id}
                  divider
                  secondaryAction={
                    <Stack direction="row" spacing={1}>
                      <Tooltip title="Restaurer cet état">
                        <span>
                          <IconButton
                            edge="end"
                            color="primary"
                            onClick={() => setPendingRestore(snapshot)}
                            disabled={
                              jobActive || busyId === snapshot.id || snapshot.status !== 'READY'
                            }
                          >
                            {busyId === snapshot.id ? (
                              <CircularProgress size={20} />
                            ) : (
                              <RestoreIcon />
                            )}
                          </IconButton>
                        </span>
                      </Tooltip>
                      <Tooltip title="Supprimer">
                        <span>
                          <IconButton
                            edge="end"
                            onClick={() => handleDelete(snapshot)}
                            disabled={jobActive || busyId === snapshot.id}
                          >
                            <DeleteIcon />
                          </IconButton>
                        </span>
                      </Tooltip>
                    </Stack>
                  }
                >
                  <ListItemText
                    primary={
                      <Stack direction="row" spacing={1} alignItems="center">
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {snapshot.name}
                        </Typography>
                        {snapshot.kind !== 'MANUAL' && (
                          <Chip
                            size="small"
                            variant="outlined"
                            label={snapshotKindLabel(snapshot.kind)}
                          />
                        )}
                        {snapshot.status !== 'READY' && (
                          <Chip
                            size="small"
                            color={snapshot.status === 'FAILED' ? 'error' : 'default'}
                            label={snapshot.status === 'FAILED' ? 'Échec' : 'En cours'}
                          />
                        )}
                      </Stack>
                    }
                    secondary={
                      <>
                        {formatDate(snapshot.created_at)}
                        {snapshot.created_by ? ` — ${snapshot.created_by}` : ''}
                        {` — ${snapshot.total_rows.toLocaleString('fr-FR')} lignes`}
                        {` (${formatBytes(snapshot.size_bytes)})`}
                        {snapshot.description ? ` — ${snapshot.description}` : ''}
                      </>
                    }
                  />
                </ListItem>
              ))}
            </List>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={onClose}>Fermer</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={!!pendingRestore} onClose={() => setPendingRestore(null)} maxWidth="sm" fullWidth>
        <DialogTitle>Restaurer « {pendingRestore?.name} » ?</DialogTitle>
        <DialogContent>
          <DialogContentText component="div">
            <Typography variant="body2" sx={{ mb: 2 }}>
              Toutes les modifications faites depuis cette sauvegarde seront remplacées par
              l'état du {formatDate(pendingRestore?.created_at ?? null)}.
            </Typography>
            <Alert severity="info">
              L'état actuel sera automatiquement sauvegardé avant la restauration : vous
              pourrez revenir en arrière.
            </Alert>
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPendingRestore(null)}>Annuler</Button>
          <Button variant="contained" color="primary" onClick={confirmRestore}>
            Restaurer
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

export default SnapshotManagerDialog;
