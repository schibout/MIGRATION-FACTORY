/**
 * Suivi d'une operation maintenance (restauration / rechargement SAP).
 *
 * Montee sur toutes les pages maintenance : tant qu'une operation tourne, les
 * donnees affichees sont en cours de reecriture et les editions sont refusees
 * (409) par le backend. La banniere previent l'utilisateur et declenche un
 * rafraichissement de la page a la fin de l'operation.
 *
 * Design — l'operation dure plusieurs minutes et l'utilisateur ne peut rien
 * faire pendant ce temps : une barre de progression seule ne dit ni ou on en est
 * ni si ca avance encore. On affiche donc le RAIL DES ETAPES reellement
 * franchies, horodatees, plus le temps ecoule : l'attente devient lisible.
 */
import { Box, Button, Collapse, IconButton, LinearProgress, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import CloseIcon from '@mui/icons-material/Close';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';
import ShieldIcon from '@mui/icons-material/GppGood';
import React, { useCallback, useEffect, useRef, useState } from 'react';

import {
  MaintenanceJob,
  getActiveJob,
  getJob,
} from '../../services/maintenanceSnapshotService';
import { Metric, RailMarker, SectionLabel, formatClock, useElapsed } from './maintenanceUi';

const POLL_INTERVAL_MS = 3000;
/** Nombre d'etapes affichees : les dernieres sont les seules utiles a suivre. */
const VISIBLE_STEPS = 4;

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
  const theme = useTheme();
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

  const running = !!job && (job.status === 'PENDING' || job.status === 'RUNNING');
  const elapsed = useElapsed(job?.started_at ?? job?.created_at, running, job?.finished_at);

  if (!job || dismissed) return null;

  const label = JOB_LABEL[job.job_type] ?? job.job_type;
  const accent = running
    ? theme.palette.primary.main
    : job.status === 'DONE'
      ? theme.palette.secondary.main
      : theme.palette.error.main;

  const steps = job.steps.slice(-VISIBLE_STEPS);
  const hiddenSteps = job.steps.length - steps.length;

  return (
    <Collapse in appear>
      <Box
        sx={{
          mb: 2,
          borderRadius: 1,
          overflow: 'hidden',
          // Filet d'accent a gauche : marque l'etat sans consommer de place.
          borderLeft: `3px solid ${accent}`,
          border: `1px solid ${alpha(accent, 0.35)}`,
          borderLeftWidth: 3,
          backgroundColor: alpha(accent, 0.06),
        }}
      >
        {/* ── En-tete : nature de l'operation, chrono, avancement ── */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, px: 2, pt: 1.5, pb: 1 }}>
          {!running &&
            (job.status === 'DONE' ? (
              <CheckCircleIcon sx={{ color: accent, fontSize: 20 }} />
            ) : (
              <ErrorOutlineIcon sx={{ color: accent, fontSize: 20 }} />
            ))}
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <SectionLabel sx={{ color: accent }}>
              {label}
              {running ? ' — en cours' : job.status === 'DONE' ? ' — terminé' : ' — échec'}
            </SectionLabel>
            <Typography variant="body2" sx={{ mt: 0.25 }} noWrap>
              {running
                ? (job.current_step ?? 'Démarrage…')
                : job.status === 'DONE'
                  ? (job.steps[job.steps.length - 1]?.detail ?? 'Les données ont été mises à jour.')
                  : (job.error_message ?? 'Cause inconnue.')}
            </Typography>
          </Box>

          <Box sx={{ textAlign: 'right', flexShrink: 0 }}>
            <Metric sx={{ color: 'text.secondary' }}>{elapsed}</Metric>
            {running && (
              <Metric sx={{ display: 'block', fontSize: '1.125rem', color: accent, lineHeight: 1.2 }}>
                {job.progress}%
              </Metric>
            )}
          </Box>

          {!running && (
            <IconButton size="small" onClick={() => setDismissed(true)} aria-label="Fermer">
              <CloseIcon fontSize="small" />
            </IconButton>
          )}
        </Box>

        {running && (
          <LinearProgress
            variant="determinate"
            value={job.progress}
            sx={{
              height: 3,
              backgroundColor: alpha(theme.palette.common.white, 0.07),
              '& .MuiLinearProgress-bar': { transition: 'transform .6s ease' },
            }}
          />
        )}

        {/* ── Rail des etapes franchies ── */}
        {steps.length > 0 && (
          <Box sx={{ px: 2, py: 1.5 }}>
            {hiddenSteps > 0 && (
              <Typography
                variant="caption"
                color="text.disabled"
                sx={{ display: 'block', mb: 0.75 }}
              >
                + {hiddenSteps} étape{hiddenSteps > 1 ? 's' : ''} précédente
                {hiddenSteps > 1 ? 's' : ''}
              </Typography>
            )}
            {steps.map((step, index) => {
              const isLast = index === steps.length - 1;
              const state = !isLast ? 'done' : running ? 'active' : job.status === 'DONE' ? 'done' : 'error';
              return (
                <Box
                  key={`${step.ts}-${index}`}
                  sx={{
                    display: 'flex',
                    gap: 1.25,
                    // Revelation echelonnee : le rail se dessine de haut en bas.
                    '@keyframes step-in': {
                      from: { opacity: 0, transform: 'translateY(-3px)' },
                      to: { opacity: 1, transform: 'none' },
                    },
                    animation: 'step-in .35s ease both',
                    animationDelay: `${index * 60}ms`,
                  }}
                >
                  <RailMarker state={state} isLast={isLast} />
                  <Box sx={{ pb: isLast ? 0 : 1, minWidth: 0, flex: 1 }}>
                    <Box sx={{ display: 'flex', gap: 1, alignItems: 'baseline' }}>
                      <Metric sx={{ color: 'text.disabled', fontSize: '0.75rem' }}>
                        {formatClock(step.ts)}
                      </Metric>
                      <Typography
                        variant="body2"
                        sx={{ color: isLast ? 'text.primary' : 'text.secondary' }}
                      >
                        {step.step}
                      </Typography>
                    </Box>
                    {step.detail && (
                      <Typography variant="caption" color="text.disabled" sx={{ display: 'block' }}>
                        {step.detail}
                      </Typography>
                    )}
                  </Box>
                </Box>
              );
            })}
          </Box>
        )}

        {/* ── Filet de securite : rappele surtout en cas d'echec ── */}
        {job.snapshot_id && (
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: 1,
              px: 2,
              py: 1,
              borderTop: `1px solid ${alpha(theme.palette.common.white, 0.07)}`,
              backgroundColor: alpha(theme.palette.common.black, 0.15),
            }}
          >
            <ShieldIcon sx={{ fontSize: 16, color: 'text.disabled' }} />
            <Typography variant="caption" color="text.secondary">
              État précédent sauvegardé (#{job.snapshot_id}) — restaurable depuis « États
              sauvegardés ».
            </Typography>
          </Box>
        )}

        {running && (
          <Box sx={{ px: 2, pb: 1.5 }}>
            <Typography variant="caption" color="text.disabled">
              Les modifications sont suspendues sur les écrans maintenance jusqu'à la fin de
              l'opération.
            </Typography>
          </Box>
        )}

        {!running && job.status !== 'DONE' && (
          <Box sx={{ px: 2, pb: 1.5 }}>
            <Button size="small" onClick={() => setDismissed(true)}>
              Fermer
            </Button>
          </Box>
        )}
      </Box>
    </Collapse>
  );
};

export default MaintenanceJobBanner;
