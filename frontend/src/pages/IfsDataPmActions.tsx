import { EventRepeat as PmIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la catégorie d'export « PM Action » (api/ifs_data_pm_actions.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: "Une ligne par plan de maintenance exporté vers IFS : objet, périodicité, heures prévues, nombre d'étapes, de ressources, de rôles, de travaux et de pièces." },
  { value: 'plans', label: 'Plans',
    description: 'Plans de maintenance préventive (clean_data.pm_action), avec les colonnes du fichier d’export.' },
  { value: 'etapes', label: 'Étapes de travail',
    description: 'Étapes opérationnelles de chaque plan (clean_data.pm_action_work_step).' },
  { value: 'ressources', label: 'Ressources', placeholder: 'N° plan, groupe, ressource…',
    description: 'Ressources planifiées de chaque plan (clean_data.pm_action_resource).' },
  { value: 'roles', label: 'Rôles',
    description: 'Rôles et équipes requis pour chaque plan (clean_data.pm_action_role).' },
  { value: 'travaux', label: 'Travaux', placeholder: 'N° plan, travail standard, description…',
    description: 'Travaux standards associés aux plans (clean_data.pm_action_job).' },
  { value: 'planification', label: 'Planification', placeholder: 'N° plan, catalogue…',
    description: 'Lignes de planification et de coûts des plans (clean_data.pm_action_planning).' },
  { value: 'pieces', label: 'Pièces de rechange', placeholder: 'N° plan, N° article…',
    description: 'Pièces de rechange planifiées pour chaque plan (clean_data.pm_action_spare_part).' },
  { value: 'controles', label: 'Contrôles',
    description: 'Objets absents de la structure, pièces hors catalogue, plans incomplets et lignes rattachées à un plan inconnu. Choisir un contrôle pour voir les lignes concernées.' },
];

const IfsDataPmActions: React.FC = () => (
  <IfsConsultationPage
    titre="PM Actions IFS"
    icone={<PmIcon sx={{ fontSize: 32, color: '#7b1fa2' }} />}
    apiUrl="/ifs-data/pm-actions"
    onglets={ONGLETS}
    placeholder="N° plan, description, objet…"
    entite="plans"
    fichierExport="pm_actions_ifs.xlsx"
    aideRecalculer="Relance le module ETL PM Actions depuis les données PE Tools importées"
    sansSynchronisation="Pas de synchronisation SAP : la source PE Tools provient d'un fichier, à importer dans Maintenance > PE Tools"
    libelleRecharge="plans de maintenance chargés"
    noteEchec="Relancez le calcul : le module recharge les tables PM Actions à chaque exécution."
  />
);

export default IfsDataPmActions;
