import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, CircularProgress, Paper, Typography } from '@mui/material';
import { ArrowBack as BackIcon } from '@mui/icons-material';
import { useNavigate, useParams } from 'react-router-dom';

import api from '../services/api';
import { FIELDS } from './MaintenancePeToolsPage';

// Detail d'une gamme PE Tools (GET /maintenance/pe-tools/<raw_id>). Lecture seule :
// les gammes se corrigent dans les fichiers PE Tools, puis se reimportent.
const BLOCS: { titre: string; champs: string[] }[] = [
  { titre: 'Identification', champs: ['poste_technique', 'niveau_sap', 'localisation_classement', 'designation', 'type', 'criticite'] },
  { titre: 'Planification', champs: ['plan_entretien', 'poste_entretien', 'groupe_de_gamme', 'compteur_de_gamme', 'frequence', 'parite_semaine', 'jour', 'decalage'] },
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

  useEffect(() => {
    api.get(`/maintenance/pe-tools/${rawId}`)
      .then((res) => setLigne(res.data?.data || null))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement de la gamme impossible'));
  }, [rawId]);

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
                {ligne[k] ?? ''}
              </Box>
            </Box>
          ))}
        </Paper>
      ))}
    </Box>
  );
};

export default MaintenancePeToolDetailPage;
