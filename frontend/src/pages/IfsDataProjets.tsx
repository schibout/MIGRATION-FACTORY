import { Assignment as ProjetIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la catégorie d'export « project » (api/ifs_data_projets.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: 'Une ligne par projet exporté vers IFS : site, responsable, dates, sous-projets, activités et rôles.' },
  { value: 'projets', label: 'Projets', placeholder: 'N° projet, nom, responsable, site…',
    description: 'Projets et sites exportés vers IFS (clean_data.project_base, project_site_ext), avec les colonnes du fichier d’export.' },
  { value: 'sous_projets', label: 'Sous-projets', placeholder: 'N° projet, sous-projet, description, responsable…',
    description: 'Sous-projets exportés vers IFS (clean_data.sub_project).' },
  { value: 'activites', label: 'Activités', placeholder: 'N° projet, sous-projet, N° activité, description…',
    description: 'Activités et classes d’activité exportées vers IFS (clean_data.project_activity, project_activity_class).' },
  { value: 'roles', label: 'Rôles', placeholder: 'N° projet, rôle, personne…',
    description: 'Rôles et affectations exportés vers IFS (clean_data.project_role, project_role_assignment).' },
  { value: 'controles', label: 'Contrôles',
    description: 'Incohérences entre les tables projet. Choisir un contrôle pour voir les lignes concernées.' },
];

const IfsDataProjets: React.FC = () => (
  <IfsConsultationPage
    titre="Projets IFS"
    icone={<ProjetIcon sx={{ fontSize: 32, color: '#f44336' }} />}
    apiUrl="/ifs-data/projets"
    onglets={ONGLETS}
    placeholder="N° projet, nom, responsable, site…"
    entite="projets"
    fichierExport="projets_ifs.xlsx"
    aideRecalculer="Relance le module ETL projets depuis les données ASAP déjà importées, sans appeler ASAP"
    aideSynchroniser="Réimporte depuis ASAP les projets, utilisateurs, projets à reprendre et états d'avancement (plus de 1 000 sites, peut être long), puis relance le module ETL projets"
    libelleSynchroniser="Synchroniser ASAP"
    libelleRecharge="projets chargés"
    noteEchec="Le module ETL n'est pas lancé si un import ASAP échoue ; les listes déjà importées restent en place."
  />
);

export default IfsDataProjets;
