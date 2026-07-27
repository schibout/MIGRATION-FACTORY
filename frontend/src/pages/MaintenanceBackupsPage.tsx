/**
 * Sauvegardes & restauration du module Maintenance (/maintenance/backups).
 *
 * Meme contenu que le dialogue « Etats sauvegardes » disponible depuis les
 * autres ecrans, mais en page pleine : c'est ici qu'on vient pour gerer
 * l'historique, pas seulement pour prendre une sauvegarde au vol. On y ajoute
 * le perimetre couvert, qui conditionne ce qu'une restauration ramene
 * reellement.
 */
import { Box, Paper, Typography, useTheme } from '@mui/material';
import { alpha } from '@mui/material/styles';
import BackupIcon from '@mui/icons-material/SettingsBackupRestore';
import React, { useCallback, useRef, useState } from 'react';

import MaintenanceActions from '../components/maintenance/MaintenanceActions';
import MaintenanceJobBanner from '../components/maintenance/MaintenanceJobBanner';
import SnapshotManagerPanel, {
  SnapshotManagerHandle,
} from '../components/maintenance/SnapshotManagerPanel';
import { SectionLabel } from '../components/maintenance/maintenanceUi';
import { MaintenanceJob } from '../services/maintenanceSnapshotService';

/** Ce qu'une sauvegarde couvre — et ce qu'elle ne couvre pas. */
const SCOPE = [
  {
    title: 'Arborescence IH02',
    detail: 'Postes techniques, équipements, articles et nomenclatures édités dans l’écran IH02.',
  },
  {
    title: 'Écrans Équipements et Articles',
    detail: 'Les tables SAP brutes que ces écrans modifient directement sont également copiées.',
  },
];

const MaintenanceBackupsPage: React.FC = () => {
  const theme = useTheme();
  const panelRef = useRef<SnapshotManagerHandle>(null);
  const [trackedJobId, setTrackedJobId] = useState<number | null>(null);
  const [jobActive, setJobActive] = useState(false);

  const refresh = useCallback(() => panelRef.current?.reload(), []);

  const handleJobFinished = useCallback((_job: MaintenanceJob) => {
    setTrackedJobId(null);
    // Une operation vient de creer une sauvegarde automatique : la liste a change.
    panelRef.current?.reload();
  }, []);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3, gap: 2 }}>
        <BackupIcon sx={{ fontSize: 32, color: theme.palette.primary.main }} />
        <Box sx={{ flex: 1 }}>
          <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
            Sauvegardes & restauration
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Enregistrer un état de travail, y revenir, et recharger depuis SAP
          </Typography>
        </Box>
        <MaintenanceActions
          onRefresh={refresh}
          onJobStarted={(job) => setTrackedJobId(job.id)}
          jobActive={jobActive}
          hideSnapshots
        />
      </Box>

      <MaintenanceJobBanner
        jobId={trackedJobId}
        onFinished={handleJobFinished}
        onActiveChange={setJobActive}
      />

      <Box sx={{ display: 'flex', gap: 3, flexDirection: { xs: 'column', lg: 'row' } }}>
        <Paper
          elevation={0}
          sx={{
            flex: 2,
            p: 2.5,
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
          }}
        >
          <SnapshotManagerPanel
            ref={panelRef}
            jobActive={jobActive}
            onRestoreStarted={(job) => setTrackedJobId(job.id)}
          />
        </Paper>

        {/* Perimetre : ce qu'une restauration ramene reellement */}
        <Paper
          elevation={0}
          sx={{
            flex: 1,
            p: 2.5,
            alignSelf: 'flex-start',
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
          }}
        >
          <SectionLabel sx={{ mb: 1.5 }}>Périmètre d'une sauvegarde</SectionLabel>
          {SCOPE.map((item) => (
            <Box key={item.title} sx={{ mb: 2 }}>
              <Typography variant="body2" sx={{ fontWeight: 600 }}>
                {item.title}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {item.detail}
              </Typography>
            </Box>
          ))}

          <Box
            sx={{
              mt: 2,
              p: 1.5,
              borderRadius: 1,
              backgroundColor: alpha(theme.palette.warning.main, 0.09),
              border: `1px solid ${alpha(theme.palette.warning.main, 0.3)}`,
            }}
          >
            <Typography variant="caption" color="text.secondary">
              Une <strong>ré-extraction SAP</strong> écrase les tables brutes : le mode
              « Fusionner » ne protège que l'arborescence IH02. La sauvegarde automatique prise
              avant chaque opération reste le filet de sécurité.
            </Typography>
          </Box>

          <Typography variant="caption" color="text.disabled" sx={{ display: 'block', mt: 2 }}>
            Les sauvegardes automatiques sont purgées au fil de l'eau (les 3 dernières sont
            conservées). Les états que vous nommez ne sont jamais supprimés automatiquement.
          </Typography>
        </Paper>
      </Box>
    </Box>
  );
};

export default MaintenanceBackupsPage;
