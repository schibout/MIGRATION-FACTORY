/**
 * Primitives visuelles partagees par les ecrans « etats sauvegardes » et
 * « rechargement SAP ».
 *
 * Parti pris : ces ecrans pilotent des operations qui engagent des semaines de
 * travail. On traite donc l'interface comme une CONSOLE D'OPERATION —
 *   * le temps se lit comme un rail vertical (etapes d'un job, historique des
 *     etats) : une seule grammaire visuelle pour « ce qui s'est passe, quand » ;
 *   * les grandeurs (lignes, octets, horodatages) sont en chasse fixe a chiffres
 *     tabulaires, pour se comparer d'une ligne a l'autre sans effort ;
 *   * la couleur d'accent ne decore rien : elle marque un etat.
 *
 * Tout s'appuie sur les jetons du theme (`darkTheme.ts`) — aucune couleur en dur,
 * aucune police externe (la CSP du backend n'autorise que `self`).
 */
import { Box, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import type { Theme } from '@mui/material/styles';
import React from 'react';

/** Chiffres et horodatages : chasse fixe systeme (aucun chargement reseau). */
export const MONO =
  '"SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace';

export type StepState = 'done' | 'active' | 'pending' | 'error';

// --------------------------------------------------------------------------- //
// Formatage
// --------------------------------------------------------------------------- //

export const formatDateTime = (iso: string | null | undefined): string =>
  iso ? new Date(iso).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—';

/** Heure seule : utilisee dans les rails ou la date est portee par le contexte. */
export const formatClock = (iso: string | null | undefined): string =>
  iso ? new Date(iso).toLocaleTimeString('fr-FR', { hour12: false }) : '--:--:--';

/** Duree lisible a la seconde pres (1 h 04 min, 12 min 30 s, 8 s). */
export const formatDuration = (seconds: number): string => {
  if (!Number.isFinite(seconds) || seconds < 0) return '—';
  const s = Math.floor(seconds % 60);
  const m = Math.floor((seconds / 60) % 60);
  const h = Math.floor(seconds / 3600);
  if (h) return `${h} h ${String(m).padStart(2, '0')} min`;
  if (m) return `${m} min ${String(s).padStart(2, '0')} s`;
  return `${s} s`;
};

/**
 * Duree d'une operation : temps ecoule rafraichi chaque seconde tant qu'elle
 * tourne, puis duree TOTALE reelle une fois terminee (`endedAt`). Sans ce
 * second cas, rouvrir la page sur un job d'hier afficherait le temps ecoule
 * depuis son demarrage, pas sa duree.
 */
export const useElapsed = (
  startedAt: string | null | undefined,
  running: boolean,
  endedAt?: string | null,
): string => {
  const [now, setNow] = React.useState(() => Date.now());

  React.useEffect(() => {
    if (!running) return undefined;
    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [running]);

  if (!startedAt) return '—';
  const start = new Date(startedAt).getTime();
  const end = !running && endedAt ? new Date(endedAt).getTime() : now;
  return formatDuration((end - start) / 1000);
};

// --------------------------------------------------------------------------- //
// Composants
// --------------------------------------------------------------------------- //

/**
 * Micro-titre de section. Reprend la convention typographique du theme
 * (`h6` : majuscules + interlettrage) a une echelle plus discrete.
 */
export const SectionLabel: React.FC<{ children: React.ReactNode; sx?: object }> = ({
  children,
  sx,
}) => (
  <Typography
    component="div"
    sx={{
      fontSize: '0.6875rem',
      fontWeight: 600,
      letterSpacing: '0.12em',
      textTransform: 'uppercase',
      color: 'text.secondary',
      ...sx,
    }}
  >
    {children}
  </Typography>
);

/** Valeur chiffree : chasse fixe + chiffres tabulaires pour aligner les colonnes. */
export const Metric: React.FC<{ children: React.ReactNode; sx?: object }> = ({ children, sx }) => (
  <Box
    component="span"
    sx={{ fontFamily: MONO, fontVariantNumeric: 'tabular-nums', fontSize: '0.8125rem', ...sx }}
  >
    {children}
  </Box>
);

const markerColor = (theme: Theme, state: StepState): string => {
  switch (state) {
    case 'done':
      return theme.palette.secondary.main;
    case 'active':
      return theme.palette.primary.main;
    case 'error':
      return theme.palette.error.main;
    default:
      return theme.palette.text.disabled;
  }
};

/**
 * Puce d'un rail chronologique, avec le segment de liaison vers l'element suivant.
 * `hollow` distingue les entrees subies (snapshots automatiques) des entrees
 * voulues par l'utilisateur (snapshots nommes) — meme rail, deux poids de lecture.
 */
export const RailMarker: React.FC<{
  state: StepState;
  isLast?: boolean;
  hollow?: boolean;
}> = ({ state, isLast = false, hollow = false }) => {
  const theme = useTheme();
  const color = markerColor(theme, state);

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        alignSelf: 'stretch',
        width: 20,
        flexShrink: 0,
      }}
    >
      <Box
        sx={{
          mt: '5px',
          width: 10,
          height: 10,
          borderRadius: '50%',
          flexShrink: 0,
          border: `2px solid ${color}`,
          backgroundColor: hollow ? 'transparent' : color,
          // L'etape en cours respire : seul element anime de la liste, donc lisible
          // d'un coup d'oeil sans avoir a lire les libelles.
          ...(state === 'active' && {
            '@keyframes rail-pulse': {
              '0%, 100%': { boxShadow: `0 0 0 0 ${alpha(color, 0.5)}` },
              '50%': { boxShadow: `0 0 0 5px ${alpha(color, 0)}` },
            },
            animation: 'rail-pulse 1.8s ease-out infinite',
          }),
        }}
      />
      {!isLast && (
        <Box
          sx={{
            flex: 1,
            width: 2,
            minHeight: 14,
            mt: '3px',
            backgroundColor: alpha(theme.palette.common.white, 0.1),
          }}
        />
      )}
    </Box>
  );
};

/**
 * Bloc encadre servant de « zone d'instrument » (formulaire de capture, option
 * d'extraction...). Plus sobre qu'une Card, mais nettement detache du fond.
 */
export const Panel: React.FC<{
  children: React.ReactNode;
  accent?: 'none' | 'primary' | 'warning';
  sx?: object;
}> = ({ children, accent = 'none', sx }) => {
  const theme = useTheme();
  const accentColor =
    accent === 'primary'
      ? theme.palette.primary.main
      : accent === 'warning'
        ? theme.palette.warning.main
        : null;

  return (
    <Box
      sx={{
        p: 2,
        borderRadius: 1,
        border: `1px solid ${accentColor ? alpha(accentColor, 0.4) : alpha(theme.palette.common.white, 0.09)}`,
        backgroundColor: accentColor
          ? alpha(accentColor, 0.06)
          : alpha(theme.palette.common.black, 0.18),
        ...sx,
      }}
    >
      {children}
    </Box>
  );
};
