import { Engineering as RessourceIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la catégorie d'export « maintenance » (api/ifs_data_ressources.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: 'Une ligne par ressource exportée vers IFS : type, site, calendrier, ressource parente et fiches rattachées.' },
  { value: 'ressources', label: 'Ressources',
    description: 'Détail des ressources (clean_data.resource_detail_file), avec les colonnes du fichier d’export.' },
  { value: 'connexions', label: 'Connexions',
    description: 'Connexions des ressources à une société, un site et une ressource parente (clean_data.resource_connection).' },
  { value: 'disponibilites', label: 'Disponibilités',
    description: 'Périodes de disponibilité et efficacité des ressources (clean_data.resource_availability).' },
  { value: 'hierarchie', label: 'Hiérarchie',
    description: 'Liens entre une ressource et sa ressource parente (clean_data.resource_parent).' },
  { value: 'personnes', label: 'Personnes de maintenance',
    description: 'Ressources de maintenance rattachées aux personnes (clean_data.maint_person_resource).' },
  { value: 'controles', label: 'Contrôles',
    description: 'Ressources incomplètes et lignes rattachées à une ressource inconnue. Choisir un contrôle pour voir les lignes concernées.' },
];

const IfsDataRessources: React.FC = () => (
  <IfsConsultationPage
    titre="Ressources de maintenance IFS"
    icone={<RessourceIcon sx={{ fontSize: 32, color: '#9c27b0' }} />}
    apiUrl="/ifs-data/maintenance-ressources"
    onglets={ONGLETS}
    placeholder="N° ressource, identifiant, nom…"
    entite="ressources"
    fichierExport="ressources_maintenance_ifs.xlsx"
  />
);

export default IfsDataRessources;
