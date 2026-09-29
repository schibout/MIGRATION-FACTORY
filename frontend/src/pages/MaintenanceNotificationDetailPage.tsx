import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, Chip, CircularProgress, Paper, Tab, Tabs, Typography } from '@mui/material';
import { ArrowBack as BackIcon } from '@mui/icons-material';
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom';

import api from '../services/api';
import SyncSapOperationsButton, { TABLES_AVIS } from '../components/maintenance/SyncSapOperationsButton';
import { Bloc, Champ, Liste, fmtDate, fmtNum } from './MaintenanceOrderDetailPage';

// Detail d'un avis SAP (ecran type IW23), GET /maintenance/notifications/<avis>. Lecture seule.
// Les codes de catalogue restent bruts (groupe / code) : la table des textes QPCT n'est pas extraite.
type Ligne = Record<string, any>;
interface Detail {
  entete: Ligne;
  postes: Ligne[];
  causes: Ligne[];
  mesures: Ligne[];
  actions: Ligne[];
}

// Heure SAP HHMMSS -> HH:MM.
const fmtHeure = (h?: string | null) => (h && h.length === 6 && h !== '000000' ? `${h.slice(0, 2)}:${h.slice(2, 4)}` : '');
const codes = (g?: string | null, c?: string | null) => [g, c].filter(Boolean).join(' / ');

const ONGLETS = ['Avis', 'Objet', 'Postes', 'Causes', 'Mesures', 'Actions', 'Pilotage'];

const MaintenanceNotificationDetailPage: React.FC = () => {
  const { avis } = useParams<{ avis: string }>();
  const navigate = useNavigate();
  const [detail, setDetail] = useState<Detail | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [onglet, setOnglet] = useState('Avis');

  const charger = () => {
    api.get(`/maintenance/notifications/${encodeURIComponent(avis || '')}`)
      .then((res) => setDetail(res.data?.data))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement de l\'avis impossible'));
  };
  useEffect(charger, [avis]);

  const e = detail?.entete;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <Button startIcon={<BackIcon />} onClick={() => navigate('/maintenance/avis')}>Retour aux avis</Button>
        <SyncSapOperationsButton onDone={charger} tables={TABLES_AVIS} ecran="Avis" />
      </Box>

      {erreur && <Alert severity="error">{erreur}</Alert>}
      {!detail && !erreur && <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}><CircularProgress /></Box>}

      {e && (
        <>
          <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
              <Typography variant="body2" color="text.secondary" sx={{ width: 90 }}>Avis</Typography>
              <Chip label={e.type_avis} size="small" />
              <Typography variant="h6" sx={{ fontWeight: 600, fontFamily: 'monospace' }}>{e.avis}</Typography>
              <Typography variant="h6">{e.texte}</Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mt: 1 }}>
              <Typography variant="body2" color="text.secondary" sx={{ width: 90 }}>Sta. syst.</Typography>
              <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{(e.statuts_systeme || []).join(' ')}</Typography>
            </Box>
          </Paper>

          <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} variant="scrollable" sx={{ mb: 2, borderBottom: 1, borderColor: 'divider' }}>
            {ONGLETS.map((o) => <Tab key={o} value={o} label={o} />)}
          </Tabs>

          {onglet === 'Avis' && (
            <>
              <Bloc titre="Responsabilités">
                <Champ label="GrpeGestio" code={`${e.groupe_planif || ''} / ${e.division_planif || ''}`} />
                <Champ label="PosteResp." code={`${e.poste_responsable || ''} / ${e.poste_responsable_division || ''}`} />
                <Champ label="Déclaré par" code={e.auteur} />
                <Champ label="Date avis" code={`${fmtDate(e.date_avis)} ${fmtHeure(e.heure_avis)}`} />
                <Champ
                  label="Ordre"
                  code={e.ordre && <RouterLink to={`/maintenance/operations/${e.ordre}`}>{e.ordre}</RouterLink>}
                />
                <Champ label="Codification" code={codes(e.groupe_codes, e.code)} texte={e.catalogue && `Catalogue ${e.catalogue}`} />
              </Bloc>
              <Bloc titre="Exécution">
                <Champ label="Priorité" code={e.priorite} texte={e.priorite_texte} />
                <Champ label="Début souhaité" code={fmtDate(e.debut_souhaite)} />
                <Champ label="Fin souhaitée" code={fmtDate(e.fin_souhaitee)} />
              </Bloc>
              <Bloc titre="Panne">
                <Champ label="Arrêt" code={e.arret} />
                <Champ label="Début panne" code={`${fmtDate(e.debut_panne)} ${fmtHeure(e.heure_debut_panne)}`} />
                <Champ label="Fin panne" code={`${fmtDate(e.fin_panne)} ${fmtHeure(e.heure_fin_panne)}`} />
                <Champ label="Durée panne" code={e.duree_panne ? `${fmtNum(e.duree_panne)} ${e.unite_duree_panne || ''}` : ''} />
              </Bloc>
            </>
          )}

          {onglet === 'Objet' && (
            <Bloc titre="Objet de référence">
              <Champ label="Pos.techn." code={e.poste_technique} texte={e.poste_technique_texte} />
              <Champ label="Equipem." code={e.equipement} texte={e.equipement_texte} />
              <Champ label="Ss-ensemb." code={e.sous_ensemble} />
            </Bloc>
          )}

          {onglet === 'Postes' && (
            <Liste
              lignes={detail!.postes}
              vide="Aucun poste (dommage) pour cet avis."
              colonnes={[
                { label: 'Poste', valeur: (l) => l.poste },
                { label: 'Partie objet', valeur: (l) => codes(l.groupe_partie_objet, l.partie_objet) },
                { label: 'Dommage', valeur: (l) => codes(l.groupe_dommage, l.dommage) },
                { label: 'Texte', valeur: (l) => l.texte },
                { label: 'Ss-ensemble', valeur: (l) => l.sous_ensemble },
              ]}
            />
          )}

          {onglet === 'Causes' && (
            <Liste
              lignes={detail!.causes}
              vide="Aucune cause pour cet avis."
              colonnes={[
                { label: 'Poste', valeur: (l) => l.poste },
                { label: 'Cause', valeur: (l) => l.cause },
                { label: 'Code', valeur: (l) => codes(l.groupe_codes, l.code) },
                { label: 'Texte', valeur: (l) => l.texte },
              ]}
            />
          )}

          {onglet === 'Mesures' && (
            <Liste
              lignes={detail!.mesures}
              vide="Aucune mesure pour cet avis."
              colonnes={[
                { label: 'Mesure', valeur: (l) => l.mesure },
                { label: 'Code', valeur: (l) => codes(l.groupe_codes, l.code) },
                { label: 'Texte', valeur: (l) => l.texte },
                { label: 'Responsable', valeur: (l) => l.responsable },
                { label: 'Début planifié', valeur: (l) => fmtDate(l.debut_planifie) },
                { label: 'Fin planifiée', valeur: (l) => fmtDate(l.fin_planifiee) },
                { label: 'Terminée le', valeur: (l) => fmtDate(l.terminee_le) },
                { label: 'Par', valeur: (l) => l.terminee_par },
              ]}
            />
          )}

          {onglet === 'Actions' && (
            <Liste
              lignes={detail!.actions}
              vide="Aucune action pour cet avis."
              colonnes={[
                { label: 'Action', valeur: (l) => l.action },
                { label: 'Code', valeur: (l) => codes(l.groupe_codes, l.code) },
                { label: 'Texte', valeur: (l) => l.texte },
                { label: 'Début', valeur: (l) => fmtDate(l.debut) },
                { label: 'Fin', valeur: (l) => fmtDate(l.fin) },
                { label: 'Créé par', valeur: (l) => l.cree_par },
              ]}
            />
          )}

          {onglet === 'Pilotage' && (
            <>
              <Bloc titre="Données de gestion">
                <Champ label="Saisi par" code={e.cree_par} />
                <Champ label="Date de saisie" code={fmtDate(e.cree_le)} />
                <Champ label="Modifié par" code={e.modifie_par} />
                <Champ label="Date modificat." code={fmtDate(e.modifie_le)} />
              </Bloc>
              <Bloc titre="Plan d'entretien">
                <Champ label="Plan d'entret." code={e.plan_entretien} />
                <Champ label="N° appel" code={e.numero_appel} />
                <Champ label="Poste d'entret." code={e.poste_entretien} />
              </Bloc>
            </>
          )}
        </>
      )}
    </Box>
  );
};

export default MaintenanceNotificationDetailPage;
