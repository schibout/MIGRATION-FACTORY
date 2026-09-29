import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, CircularProgress, Paper, Typography } from '@mui/material';
import { ArrowBack as BackIcon } from '@mui/icons-material';
import { useNavigate, useParams } from 'react-router-dom';

import api from '../services/api';
import { FIELDS } from './MaintenancePeToolsPage';
import DateExecutionEditable, { fmtDateIso, ResultatSaisieDate } from '../components/maintenance/DateExecutionEditable';

// Detail d'une gamme PE Tools (GET /maintenance/pe-tools/<raw_id>). Lecture seule, sauf la
// date de derniere execution (saisie manuelle, 085) : les gammes se corrigent dans les
// fichiers PE Tools, puis se reimportent.
const BLOCS: { titre: string; champs: string[] }[] = [
  { titre: 'Identification', champs: ['poste_technique', 'niveau_sap', 'localisation_classement', 'designation', 'type', 'criticite'] },
  { titre: 'Planification', champs: ['plan_entretien', 'poste_entretien', 'groupe_de_gamme', 'compteur_de_gamme', 'frequence', 'parite_semaine', 'jour', 'decalage', 'date_derniere_execution', 'ifs_date_execution'] },
  { titre: 'Charge et revue', champs: ['charge', 'nb_intervenants', 'date_validation', 'date_rev', 'nb_jours_depuis_derniere_rev'] },
  { titre: 'Documents', champs: ['gamme_en_dms', 'dms_sap', 'lien_fichier_gamme_source', 'lien_fichier_dms_sap_pdf'] },
  { titre: 'Origine', champs: ['nom_fichier', 'organisation_maintenance', 'imported_at', 'updated_at', 'updated_by'] },
];

const LIBELLES: Record<string, string> = {
  ...Object.fromEntries(FIELDS.map((f) => [f.key, f.label])),
  imported_at: 'Importé le',
  updated_at: 'Modifié le',
  updated_by: 'Modifié par',
};

const MaintenancePeToolDetailPage: React.FC = () => {
  const { rawId } = useParams<{ rawId: string }>();
  const navigate = useNavigate();
  const [ligne, setLigne] = useState<Record<string, any> | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);

  const [message, setMessage] = useState<{ ok: boolean; texte: string } | null>(null);

  const charger = () => {
    api.get(`/maintenance/pe-tools/${rawId}`)
      .then((res) => setLigne(res.data?.data || null))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement de la gamme impossible'));
  };
  useEffect(charger, [rawId]);

  const dateSaisie = (res: ResultatSaisieDate) => {
    setMessage({ ok: true, texte: res.saisie_manuelle
      ? `Date enregistrée pour le ${res.id_type === 'POSTE' ? 'poste d\'entretien' : 'plan'} ${res.identifiant} `
        + `(${res.nb_gammes} gamme(s) concernée(s)).`
      : 'Saisie retirée : retour à la date du fichier.' });
    charger();
  };

  // Valeur affichee d'un champ ; la date de derniere execution est modifiable sur place (085).
  const valeur = (k: string) => {
    if (k === 'date_derniere_execution') {
      const m = ligne?.date_saisie_manuelle;
      const r = ligne?.date_rattachement;
      return (
        <Box>
          <DateExecutionEditable
            rawId={Number(rawId)} valeur={ligne?.[k]} onSaved={dateSaisie}
            onError={(texte) => setMessage({ ok: false, texte })}
          />
          <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'inherit' }}>
            {m ? `Saisie manuelle par ${m.saisi_par || '?'} le ${m.saisi_le}`
              : r?.id_type ? 'Date du fichier' : 'Ni plan ni poste d\'entretien : saisie impossible'}
            {r?.id_type && ` — rattachée au ${r.id_type === 'POSTE' ? 'poste d\'entretien' : 'plan'} ${r.identifiant}`}
          </Typography>
        </Box>
      );
    }
    if (k === 'ifs_date_execution') return fmtDateIso(ligne?.[k]);
    return ligne?.[k] ?? '';
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
        <Button startIcon={<BackIcon />} onClick={() => navigate('/maintenance/pe-tools')}>Gammes</Button>
        <Typography variant="h5" sx={{ fontWeight: 600, fontFamily: 'monospace' }}>
          {ligne?.poste_technique || ''}
        </Typography>
        <Typography variant="body1" color="text.secondary">{ligne?.designation || ''}</Typography>
      </Box>

      {erreur && <Alert severity="error">{erreur}</Alert>}
      {message && (
        <Alert severity={message.ok ? 'success' : 'error'} sx={{ mb: 2 }} onClose={() => setMessage(null)}>{message.texte}</Alert>
      )}
      {!ligne && !erreur && <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}><CircularProgress /></Box>}

      {ligne && BLOCS.map((b) => (
        <Paper key={b.titre} variant="outlined" sx={{ p: 2, mb: 2 }}>
          <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1, pb: 0.5, borderBottom: 2, borderColor: 'primary.main' }}>
            {b.titre}
          </Typography>
          {b.champs.filter((k) => k in ligne).map((k) => (
            <Box key={k} sx={{ display: 'grid', gridTemplateColumns: '240px 1fr', alignItems: 'center', gap: 1.5, py: 0.5 }}>
              <Typography variant="body2" color="text.secondary">{LIBELLES[k] || k}</Typography>
              <Box sx={{ px: 1, py: 0.25, bgcolor: 'action.hover', borderRadius: 0.5, minHeight: 24, fontFamily: 'monospace', fontSize: 14, wordBreak: 'break-all' }}>
                {valeur(k)}
              </Box>
            </Box>
          ))}
        </Paper>
      ))}
    </Box>
  );
};

export default MaintenancePeToolDetailPage;
