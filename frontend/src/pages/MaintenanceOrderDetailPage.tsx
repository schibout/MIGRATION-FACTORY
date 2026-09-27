import React, { useEffect, useState } from 'react';
import {
  Alert, Box, Button, Chip, CircularProgress, Paper, Tab, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Tabs, Typography,
} from '@mui/material';
import { ArrowBack as BackIcon } from '@mui/icons-material';
import { useNavigate, useParams } from 'react-router-dom';

import api from '../services/api';

// Detail d'un ordre SAP (ecran type IW33), un onglet par bloc renvoye par
// GET /maintenance/orders/<ordre>. Lecture seule.
type Ligne = Record<string, any>;
interface Detail {
  entete: Ligne;
  donnees_sup: Ligne | null;
  localisation: Ligne | null;
  operations: Ligne[];
  composants: Ligne[];
}

const fmtDate = (d?: string | null) => (d && d.length === 8 ? `${d.slice(6)}/${d.slice(4, 6)}/${d.slice(0, 4)}` : '');
const fmtNum = (n?: string | null) => (n == null || n === '' ? '' : String(Number(n)));

// Ligne « libelle | code | texte » a la maniere des ecrans SAP.
const Champ: React.FC<{ label: string; code?: any; texte?: any }> = ({ label, code, texte }) => (
  <Box sx={{ display: 'grid', gridTemplateColumns: '220px 160px 1fr', alignItems: 'center', gap: 1.5, py: 0.5 }}>
    <Typography variant="body2" color="text.secondary">{label}</Typography>
    <Box sx={{ px: 1, py: 0.25, bgcolor: 'action.hover', borderRadius: 0.5, minHeight: 24, fontFamily: 'monospace', fontSize: 14 }}>
      {code ?? ''}
    </Box>
    <Typography variant="body2">{texte ?? ''}</Typography>
  </Box>
);

const Bloc: React.FC<{ titre: string; children: React.ReactNode }> = ({ titre, children }) => (
  <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
    <Typography variant="subtitle2" sx={{ fontWeight: 600, mb: 1, pb: 0.5, borderBottom: 2, borderColor: 'primary.main' }}>
      {titre}
    </Typography>
    {children}
  </Paper>
);

const Liste: React.FC<{ lignes: Ligne[]; colonnes: { label: string; valeur: (l: Ligne) => any }[]; vide: string }> = ({ lignes, colonnes, vide }) =>
  lignes.length === 0 ? <Typography color="text.secondary" sx={{ p: 2 }}>{vide}</Typography> : (
    <TableContainer component={Paper} variant="outlined">
      <Table size="small">
        <TableHead>
          <TableRow>{colonnes.map((c) => <TableCell key={c.label} sx={{ fontWeight: 600 }}>{c.label}</TableCell>)}</TableRow>
        </TableHead>
        <TableBody>
          {lignes.map((l, i) => (
            <TableRow hover key={i}>{colonnes.map((c) => <TableCell key={c.label}>{c.valeur(l)}</TableCell>)}</TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );

// Onglets de l'ecran SAP ; ceux sans contenu sont affiches desactives en attendant leur ecran.
const ONGLETS = ['Donn.en-t.', 'Opérations', 'Composants', 'Coûts', 'Objets', 'DonnéesSup', 'Localis.', 'Planific.', 'Pilotage'];
const A_VENIR = new Set(['Coûts', 'Objets', 'Planific.', 'Pilotage']);

const MaintenanceOrderDetailPage: React.FC = () => {
  const { ordre } = useParams<{ ordre: string }>();
  const navigate = useNavigate();
  const [detail, setDetail] = useState<Detail | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [onglet, setOnglet] = useState('Donn.en-t.');

  useEffect(() => {
    api.get(`/maintenance/orders/${encodeURIComponent(ordre || '')}`)
      .then((res) => setDetail(res.data?.data))
      .catch((e) => setErreur(e?.response?.data?.error || 'Chargement de l\'ordre impossible'));
  }, [ordre]);

  const e = detail?.entete;
  const ds = detail?.donnees_sup;
  const loc = detail?.localisation;

  return (
    <Box sx={{ p: 3 }}>
      <Button startIcon={<BackIcon />} onClick={() => navigate('/maintenance/operations')} sx={{ mb: 2 }}>
        Retour aux opérations
      </Button>

      {erreur && <Alert severity="error">{erreur}</Alert>}
      {!detail && !erreur && <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}><CircularProgress /></Box>}

      {e && (
        <>
          <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flexWrap: 'wrap' }}>
              <Typography variant="body2" color="text.secondary" sx={{ width: 90 }}>Ordre</Typography>
              <Chip label={e.type_ordre} size="small" />
              <Typography variant="h6" sx={{ fontWeight: 600, fontFamily: 'monospace' }}>{e.ordre}</Typography>
              <Typography variant="h6">{e.texte_ordre}</Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mt: 1 }}>
              <Typography variant="body2" color="text.secondary" sx={{ width: 90 }}>Sta. syst.</Typography>
              <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{(e.statuts_systeme || []).join(' ')}</Typography>
            </Box>
          </Paper>

          <Tabs value={onglet} onChange={(_, v) => setOnglet(v)} variant="scrollable" sx={{ mb: 2, borderBottom: 1, borderColor: 'divider' }}>
            {ONGLETS.map((o) => <Tab key={o} value={o} label={o} disabled={A_VENIR.has(o)} />)}
          </Tabs>

          {onglet === 'Donn.en-t.' && (
            <>
              <Bloc titre="Responsables">
                <Champ label="Groupe de planification" code={e.groupe_planif} texte={e.division_planif ? `Division ${e.division_planif}` : ''} />
                <Champ label="Poste de travail responsable" code={e.poste_responsable} texte={e.poste_responsable_texte} />
                <Champ label="Type d'activité" code={e.type_activite} />
                <Champ label="Priorité" code={e.priorite} />
              </Bloc>
              <Bloc titre="Dates">
                <Champ label="Début planifié" code={fmtDate(e.debut_planifie)} />
                <Champ label="Fin planifiée" code={fmtDate(e.fin_planifiee)} />
                <Champ label="Créé le / par" code={fmtDate(e.cree_le)} texte={e.cree_par} />
              </Bloc>
              <Bloc titre="Objet de référence">
                <Champ label="Poste technique" code={e.poste_technique} texte={e.poste_technique_texte} />
                <Champ label="Équipement" code={e.equipement} texte={e.equipement_texte} />
              </Bloc>
            </>
          )}

          {onglet === 'Opérations' && (
            <Liste
              lignes={detail!.operations}
              vide="Aucune opération."
              colonnes={[
                { label: 'Opé.', valeur: (l) => l.operation },
                { label: 'Pos. trav.', valeur: (l) => l.poste_travail },
                { label: 'Div.', valeur: (l) => l.division },
                { label: 'Clé cde', valeur: (l) => l.cle_commande },
                { label: 'Désignation opération', valeur: (l) => l.texte_operation },
                { label: 'Travail', valeur: (l) => `${fmtNum(l.travail)} ${l.unite_travail || ''}` },
                { label: 'Nombre', valeur: (l) => fmtNum(l.nombre) },
                { label: 'Durée', valeur: (l) => `${fmtNum(l.duree)} ${l.unite_duree || ''}` },
              ]}
            />
          )}

          {onglet === 'Composants' && (
            <Liste
              lignes={detail!.composants}
              vide="Aucun composant réservé pour cet ordre."
              colonnes={[
                { label: 'Poste', valeur: (l) => l.poste },
                { label: 'Article', valeur: (l) => l.article },
                { label: 'Désignation', valeur: (l) => l.designation },
                { label: 'Quantité', valeur: (l) => `${fmtNum(l.quantite)} ${l.unite || ''}` },
                { label: 'TyP', valeur: (l) => l.type_poste },
                { label: 'Opé.', valeur: (l) => l.operation },
                { label: 'Div.', valeur: (l) => l.division },
                { label: 'Magasin', valeur: (l) => l.magasin },
                { label: 'Date besoin', valeur: (l) => fmtDate(l.date_besoin) },
              ]}
            />
          )}

          {onglet === 'DonnéesSup' && (
            <Bloc titre="Organisation">
              <Champ label="Société" code={ds?.societe} texte={ds?.societe_texte} />
              <Champ label="Domaine d'activité" code={ds?.domaine_activite} texte={ds?.domaine_activite_texte} />
              <Champ label="Périmètre analytique" code={ds?.perimetre_analytique} />
              <Champ label="Centre responsable" code={ds?.centre_responsable} texte={ds?.centre_responsable_texte} />
              <Champ label="Centre de profit" code={ds?.centre_profit} texte={ds?.centre_profit_texte} />
              <Champ label="Domaine fonctionnel" code={ds?.domaine_fonctionnel} />
              <Champ label="Groupe de traitement" code={ds?.groupe_traitement} />
              <Champ label="Élément d'OTP" code={ds?.element_otp} />
            </Bloc>
          )}

          {onglet === 'Localis.' && (
            <Bloc titre="Données de localisation">
              <Champ label="Division de localisation" code={loc?.division_localisation} texte={loc?.division_localisation_texte} />
              <Champ label="Emplacement" code={loc?.emplacement} />
              <Champ label="Local" code={loc?.local} />
              <Champ label="Secteur d'exploitation" code={loc?.secteur_exploitation} />
              <Champ label="Code ABC" code={loc?.code_abc} />
              <Champ label="Zone de tri" code={loc?.zone_tri} />
              <Champ label="Société" code={loc?.societe} />
              <Champ label="Domaine d'activité" code={loc?.domaine_activite} />
              <Champ label="Centre de coûts" code={loc?.centre_couts} />
            </Bloc>
          )}
        </>
      )}
    </Box>
  );
};

export default MaintenanceOrderDetailPage;
