/**
 * Gestion des etats sauvegardes, en dialogue (depuis les ecrans maintenance).
 *
 * Simple habillage de SnapshotManagerPanel, qui porte tout le comportement et
 * sert aussi la page dediee /maintenance/backups.
 */
import { Button, Dialog, DialogActions, DialogContent, DialogTitle } from '@mui/material';
import React from 'react';

import { MaintenanceJob } from '../../services/maintenanceSnapshotService';
import SnapshotManagerPanel from './SnapshotManagerPanel';

interface Props {
  open: boolean;
  onClose: () => void;
  /** Appele quand une restauration a ete lancee (job a suivre). */
  onRestoreStarted: (job: MaintenanceJob) => void;
  /** Desactive les actions quand une operation maintenance tourne deja. */
  jobActive?: boolean;
}

const SnapshotManagerDialog: React.FC<Props> = ({
  open,
  onClose,
  onRestoreStarted,
  jobActive = false,
}) => (
  <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
    <DialogTitle sx={{ pb: 1 }}>États sauvegardés</DialogTitle>
    <DialogContent dividers>
      <SnapshotManagerPanel
        active={open}
        jobActive={jobActive}
        onRestoreStarted={(job) => {
          onRestoreStarted(job);
          onClose();
        }}
      />
    </DialogContent>
    <DialogActions>
      <Button onClick={onClose}>Fermer</Button>
    </DialogActions>
  </Dialog>
);

export default SnapshotManagerDialog;
