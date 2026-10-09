import { Autocomplete, Box, Stack, TextField, Tooltip, Typography } from '@mui/material';
import React from 'react';
import api from '../../services/api';

// Éléments communs aux écrans de consultation filtrables (Articles SAP, Équipements) :
// facettes renvoyées par l'API { code, libelle, nb }, VIDE = valeur absente.

export const VIDE = '__vide__';

export interface FacetValue { code: string; libelle: string | null; nb: number }

export const nb = (v: number | null | undefined) => (v ?? 0).toLocaleString('fr-FR');

export const couleur = (palette: Record<string, string>, code: string) => palette[code] ?? '#bdbdbd';

export const libelleValeur = (v: FacetValue) =>
  v.code === VIDE ? '(non renseigné)' : v.libelle ? `${v.code} — ${v.libelle}` : v.code;

// Barre de répartition cliquable : un segment par valeur, clic = filtre.
export const RepartitionBar: React.FC<{
  titre: string; valeurs: FacetValue[]; actifs: string[]; palette: Record<string, string>;
  onToggle: (code: string) => void; legende?: (v: FacetValue) => string;
}> = ({ titre, valeurs, actifs, palette, onToggle, legende }) => {
  const total = valeurs.reduce((s, v) => s + v.nb, 0) || 1;
  const estActif = (code: string) => actifs.length === 0 || actifs.includes(code);
  return (
    <Box sx={{ flex: 1, minWidth: 280 }}>
      <Typography variant="overline" color="text.secondary">{titre}</Typography>
      <Box sx={{ display: 'flex', height: 30, borderRadius: 1, overflow: 'hidden', bgcolor: 'action.hover' }}>
        {valeurs.map((v) => (
          <Tooltip key={v.code} title={`${libelleValeur(v)} : ${nb(v.nb)}`}>
            <Box
              onClick={() => onToggle(v.code)}
              sx={{
                width: `${(v.nb / total) * 100}%`, minWidth: 4, bgcolor: couleur(palette, v.code),
                opacity: estActif(v.code) ? 1 : 0.25, cursor: 'pointer', transition: 'opacity .2s',
                borderRight: '2px solid', borderColor: 'background.paper',
                '&:hover': { opacity: 0.85 },
              }}
            />
          </Tooltip>
        ))}
      </Box>
      <Stack direction="row" spacing={1.5} sx={{ mt: 0.75, flexWrap: 'wrap', rowGap: 0.5 }}>
        {valeurs.map((v) => (
          <Box key={v.code} onClick={() => onToggle(v.code)}
            sx={{ display: 'flex', alignItems: 'center', gap: 0.5, cursor: 'pointer', opacity: estActif(v.code) ? 1 : 0.45 }}>
            <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: couleur(palette, v.code) }} />
            <Typography variant="caption">
              {legende ? legende(v) : v.code === VIDE ? '(vide)' : v.libelle ?? v.code} <b>{nb(v.nb)}</b>
            </Typography>
          </Box>
        ))}
      </Stack>
    </Box>
  );
};

// Liste de choix multiple d'une facette, avec le compteur de chaque valeur.
export const FacetteAuto: React.FC<{
  titre: string; valeurs: FacetValue[]; selection: string[]; onChange: (codes: string[]) => void; largeur?: number;
}> = ({ titre, valeurs, selection, onChange, largeur = 220 }) => (
  <Autocomplete
    multiple
    size="small"
    limitTags={1}
    options={valeurs}
    value={valeurs.filter((o) => selection.includes(o.code))}
    isOptionEqualToValue={(o, v) => o.code === v.code}
    getOptionLabel={libelleValeur}
    onChange={(_, vals) => onChange(vals.map((v) => v.code))}
    renderOption={(props, o) => (
      <li {...props} key={o.code}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%', gap: 1 }}>
          <span>{libelleValeur(o)}</span>
          <Typography variant="caption" color="text.secondary">{nb(o.nb)}</Typography>
        </Box>
      </li>
    )}
    renderInput={(p) => <TextField {...p} label={titre} />}
    sx={{ width: largeur }}
  />
);

// Téléchargement d'un fichier renvoyé par l'API (nom lu dans Content-Disposition).
export const telecharger = async (url: string, params: Record<string, string>, nomParDefaut: string) => {
  const res = await api.get(url, { params, responseType: 'blob' });
  const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
  const lien = window.URL.createObjectURL(res.data);
  const a = document.createElement('a');
  a.href = lien;
  a.download = match?.[1] ?? nomParDefaut;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.URL.revokeObjectURL(lien);
};
