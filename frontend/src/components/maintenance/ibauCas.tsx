import React, { useState } from 'react';
import { Box, Button, Chip, CircularProgress, Tooltip } from '@mui/material';
import { Rule as ClassifyIcon } from '@mui/icons-material';

import api from '../../services/api';

/**
 * Classification des IBAU (migration 079, document « Migration des donnees »
 * §3) : partagee par l'arbre IH02 et la liste fixe des IBAU.
 *
 * Le cas est CALCULE en base par clean_data.classifier_ibau_article()
 * (POST /maintenance/ibau/classify), jamais saisi ; il est stocke dans les
 * deux tables et relu tel quel ici. Les couleurs sont celles du document :
 * jaune = a conserver, bleu = a transformer en poste technique, rouge = a
 * transformer en article.
 */
export type CasIbau = 'CONSERVER' | 'POSTE_TECHNIQUE' | 'ARTICLE';

export const CAS_IBAU: Record<CasIbau, { label: string; court: string; color: string; description: string }> = {
  CONSERVER: {
    label: 'IBAU à conserver',
    court: 'À conserver',
    color: '#f9a825', // jaune
    description: 'Au moins un enfant et plusieurs occurrences dans la structure : vrai IBAU réutilisable',
  },
  POSTE_TECHNIQUE: {
    label: 'À transformer en poste technique',
    court: 'Poste technique',
    color: '#1e88e5', // bleu
    description: 'Au moins un enfant mais une seule occurrence : devient un objet fonctionnel IFS',
  },
  ARTICLE: {
    label: 'À transformer en article',
    court: 'Article',
    color: '#e53935', // rouge
    description: 'Aucun enfant : devient un article classique',
  },
};

export const CAS_IBAU_ORDRE: CasIbau[] = ['CONSERVER', 'POSTE_TECHNIQUE', 'ARTICLE'];

export interface ClassificationResult {
  compteurs: Record<CasIbau, number>;
  cas_calcule_at: string | null;
}

export async function classifierIbau(): Promise<ClassificationResult> {
  const response = await api.post('/maintenance/ibau/classify');
  if (!response.data?.success) throw new Error(response.data?.error || 'Classification impossible');
  return response.data.data as ClassificationResult;
}

export const formatCompteurs = (c: Record<CasIbau, number>): string =>
  CAS_IBAU_ORDRE.map((k) => `${c[k] ?? 0} ${CAS_IBAU[k].court.toLowerCase()}`).join(', ');

/** Pastille de cas, avec enfants / occurrences en info-bulle. Rien si pas de cas. */
export const CasIbauChip: React.FC<{
  cas: CasIbau | null | undefined;
  nbEnfants?: number | null;
  nbOccurrences?: number | null;
  /** 'dot' = pastille seule (arbre), 'chip' = libelle (liste). */
  variant?: 'dot' | 'chip';
  sx?: object;
}> = ({ cas, nbEnfants, nbOccurrences, variant = 'chip', sx }) => {
  if (!cas || !CAS_IBAU[cas]) return null;
  const def = CAS_IBAU[cas];
  const detail = nbEnfants != null && nbOccurrences != null
    ? ` — ${nbEnfants} enfant(s), ${nbOccurrences} occurrence(s)` : '';
  const title = `${def.label}${detail}. ${def.description}`;
  if (variant === 'dot') {
    return (
      <Tooltip title={title}>
        <Box
          component="span"
          aria-label={def.label}
          sx={{ display: 'inline-block', width: 12, height: 12, borderRadius: '50%', bgcolor: def.color,
                border: '1px solid rgba(0,0,0,0.25)', flexShrink: 0, ...sx }}
        />
      </Tooltip>
    );
  }
  return (
    <Tooltip title={title}>
      <Chip size="small" label={def.court}
        sx={{ bgcolor: def.color, color: '#fff', fontWeight: 600, height: 22, fontSize: '0.7rem', ...sx }} />
    </Tooltip>
  );
};

/** Bouton « Classifier les IBAU », identique sur les deux ecrans. */
export const ClassifierIbauButton: React.FC<{
  onDone: (result: ClassificationResult) => void;
  onError: (message: string) => void;
  disabled?: boolean;
  sx?: object;
}> = ({ onDone, onError, disabled, sx }) => {
  const [running, setRunning] = useState(false);
  const run = async () => {
    setRunning(true);
    try {
      onDone(await classifierIbau());
    } catch (err: any) {
      onError(err?.response?.data?.error || err?.message || 'Erreur lors de la classification');
    } finally {
      setRunning(false);
    }
  };
  return (
    <Tooltip title="Recalcule le cas de chaque IBAU de la structure (jaune : à conserver, bleu : poste technique, rouge : article)">
      <span>
        <Button variant="outlined" size="small" onClick={run} disabled={disabled || running} sx={sx}
          startIcon={running ? <CircularProgress size={16} /> : <ClassifyIcon />}>
          Classifier les IBAU
        </Button>
      </span>
    </Tooltip>
  );
};
