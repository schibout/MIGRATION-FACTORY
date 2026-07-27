/**
 * Banniere de suivi d'une operation maintenance (restauration / rechargement SAP).
 *
 * Montee sur toutes les pages maintenance : tant qu'une operation tourne, les
 * donnees affichees sont en cours de reecriture et les editions sont refusees
 * (409) par le backend. La banniere previent l'utilisateur et declenche un
 * rafraichissement de la page a la fin de l'operation.
 */
import { Alert, AlertTitle, Box, Button, Collapse, LinearProgress, Typography } from '@mui/material';
import React, { useCallback, useEffect, useRef, useState } from 'react';

import {
  MaintenanceJob,
  getActiveJob,
  getJob,
} from '../../services/maintenanceSnapshotService';

const POLL_INTERVAL_MS = 3000;

interface Props {
  /** Job a suivre en priorite (retourne par un lancement depuis cette page). */
  jobId?: number | null;
  /** Appele une fois quand l'operation se termine (succes ou echec). */
  onFinished?: (job: MaintenanceJob) => void;
  /** Notifie le parent de l'etat d'activite, pour passer l'UI en lecture seule. */
  onActiveChange?: (active: boolean) => void;
}

const JOB_LABEL: Record<string, string> = {
  RESTORE: "Restauration d'un état sauvegardé",
  RELOAD: 'Rechargement depuis SAP',
  SNAPSHOT: "Sauvegarde de l'état",
};

const MaintenanceJobBanner: React.FC<Props> = ({ jobId, onFinished, onActiveChange }) => {
  const [job, setJob] = useState<MaintenanceJob | null>(null);
  const [dismissed, setDismissed] = useState(false);
  // Refs : evite de relancer le polling a chaque rendu du parent.
  const finishedRef = useRef<number | null>(null);
  // Dernier job observe : permet de recuperer son issue une fois qu'il a quitte
  // la liste des jobs actifs.
  const watchedRef = useRef<number | null>(null);
  const onFinishedRef = useRef(onFinished);
  const onActiveChangeRef = useRef(onActiveChange);

  useEffect(() => {
    onFinishedRef.current = onFinished;
    onActiveChangeRef.current = onActiveChange;
  }, [onFinished, onActiveChange]);

  const poll = useCallback(async () => {
    try {
      let current: MaintenanceJob | null;

      if (jobId) {
        current = await getJob(jobId);
      } else {
        current = await getActiveJob();
        // /jobs/active ne renvoie que les jobs PENDING/RUNNING : une fois
        // l'operation terminee il renvoie null. On relit donc explicitement le
        // dernier job suivi pour connaitre son issue et rafraichir la page.
        if (!current && watchedRef.current) {
          current = await getJob(watchedRef.current);
        }
      }

      if (current) watchedRef.current = current.id;
      setJob(current);

      const active = !!current && (current.status === 'PENDING' || current.status === 'RUNNING');
      onActiveChangeRef.current?.(active);

      // Fin d'operation : on ne notifie qu'une seule fois par job.
      if (current && !active && finishedRef.current !== current.id) {
        finishedRef.current = current.id;
        setDismissed(false);
        onFinishedRef.current?.(current);
      }
    } catch {
      // Silencieux : une banniere de suivi ne doit pas polluer la page d'erreurs.
    }
  }, [jobId]);

  useEffect(() => {
    let cancelled = false;
    const tick = async () => {
      if (!cancelled) await poll();
    };
    tick();
    const timer = setInterval(tick, POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [poll]);

  if (!job || dismissed) return null;

  const running = job.status === 'PENDING' || job.status === 'RUNNING';
  const label = JOB_LABEL[job.job_type] ?? job.job_type;

  if (running) {
    return (
      <Alert severity="info" sx={{ mb: 2 }} icon={false}>
        <AlertTitle>{label} en cours</AlertTitle>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          {job.current_step ?? 'Démarrage…'} — les modifications sont temporairement
          suspendues sur les écrans maintenance.
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <LinearProgress
            variant="determinate"
            value={job.progress}
            sx={{ flex: 1, height: 6, borderRadius: 3 }}
          />
          <Typography variant="caption" color="text.secondary">
            {job.progress}%
          </Typography>
        </Box>
      </Alert>
    );
  }

  return (
    <Collapse in={!dismissed}>
      <Alert
        severity={job.status === 'DONE' ? 'success' : 'error'}
        sx={{ mb: 2 }}
        action={
          <Button color="inherit" size="small" onClick={() => setDismissed(true)}>
            Fermer
          </Button>
        }
      >
        <AlertTitle>
          {label} {job.status === 'DONE' ? 'terminé' : 'en échec'}
        </AlertTitle>
        {job.status === 'DONE' ? (
          <Typography variant="body2">
            {job.steps[job.steps.length - 1]?.detail ?? 'Les données ont été mises à jour.'}
          </Typography>
        ) : (
          <Typography variant="body2">
            {job.error_message ?? 'Cause inconnue.'}
            {job.snapshot_id
              ? ` — l'état précédent reste disponible (sauvegarde #${job.snapshot_id}).`
              : ''}
          </Typography>
        )}
      </Alert>
    </Collapse>
  );
};

export default MaintenanceJobBanner;
