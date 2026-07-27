/**
 * Barre d'actions commune a TOUS les ecrans maintenance (hierarchie, IH02,
 * equipements, articles, sauvegardes).
 *
 * Regroupe les trois gestes qui doivent etre disponibles partout :
 *   - rafraichir les donnees de l'ecran courant ;
 *   - recharger depuis SAP (fusion ou reinitialisation) ;
 *   - ouvrir les etats sauvegardes.
 *
 * Elle porte ses propres dialogues : une page n'a qu'a fournir son
 * rafraichissement et relayer le job demarre a la banniere de suivi.
 */
import { Button, IconButton, Stack, Tooltip } from '@mui/material';
import CloudSyncIcon from '@mui/icons-material/CloudSync';
import HistoryIcon from '@mui/icons-material/History';
import RefreshIcon from '@mui/icons-material/Refresh';
import React, { useState } from 'react';

import { MaintenanceJob } from '../../services/maintenanceSnapshotService';
import ReloadSapDialog from './ReloadSapDialog';
import SnapshotManagerDialog from './SnapshotManagerDialog';

interface Props {
  /** Rechargement des donnees de l'ecran (bouton Rafraichir). */
  onRefresh: () => void;
  /** Job demarre (restauration ou rechargement) : a passer a MaintenanceJobBanner. */
  onJobStarted: (job: MaintenanceJob) => void;
  /** Une operation maintenance tourne : les actions sont neutralisees. */
  jobActive?: boolean;
  /** Chargement en cours sur l'ecran (desactive le bouton Rafraichir). */
  loading?: boolean;
  /** Masque le bouton « Etats sauvegardes » (page dediee, ou il ferait doublon). */
  hideSnapshots?: boolean;
  size?: 'small' | 'medium';
}

const MaintenanceActions: React.FC<Props> = ({
  onRefresh,
  onJobStarted,
  jobActive = false,
  loading = false,
  hideSnapshots = false,
  size = 'small',
}) => {
  const [snapshotsOpen, setSnapshotsOpen] = useState(false);
  const [reloadOpen, setReloadOpen] = useState(false);

  return (
    <>
      <Stack direction="row" spacing={1} alignItems="center">
        {!hideSnapshots && (
          <Button
            variant="outlined"
            size={size}
            startIcon={<HistoryIcon />}
            onClick={() => setSnapshotsOpen(true)}
          >
            États sauvegardés
          </Button>
        )}
        <Button
          variant="outlined"
          size={size}
          color="secondary"
          startIcon={<CloudSyncIcon />}
          onClick={() => setReloadOpen(true)}
          disabled={jobActive}
        >
          Recharger depuis SAP
        </Button>
        <Tooltip title="Rafraîchir les données affichées">
          <span>
            <IconButton onClick={onRefresh} disabled={loading || jobActive}>
              <RefreshIcon />
            </IconButton>
          </span>
        </Tooltip>
      </Stack>

      {!hideSnapshots && (
        <SnapshotManagerDialog
          open={snapshotsOpen}
          onClose={() => setSnapshotsOpen(false)}
          onRestoreStarted={onJobStarted}
          jobActive={jobActive}
        />
      )}

      <ReloadSapDialog
        open={reloadOpen}
        onClose={() => setReloadOpen(false)}
        onStarted={onJobStarted}
      />
    </>
  );
};

export default MaintenanceActions;
