import { AccountTree as StructureIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la structure de maintenance (api/ifs_data_structure.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: "Une ligne par poste technique et par équipement : parent, équipements rattachés et pièces de rechange." },
  { value: 'postes', label: 'Postes techniques',
    description: 'Postes techniques exportés vers IFS (clean_data.equipment_functional).' },
  { value: 'equipements', label: 'Équipements',
    description: 'Équipements exportés vers IFS (clean_data.equipment_serial) : sous la structure et portant un article.' },
  { value: 'pieces', label: 'Pièces de rechange', placeholder: 'Code objet, désignation, N° article…',
    description: 'Articles rattachés à un poste technique ou à un équipement (clean_data.equipment_object_spare).' },
  { value: 'kits', label: 'Composition des kits', placeholder: 'N° article, N° composant, désignation…',
    description: 'Composants des articles kits (clean_data.equipment_spare_structure).' },
  { value: 'controles', label: 'Contrôles',
    description: 'Incohérences entre les tables de la structure et le catalogue. Choisir un contrôle pour voir les lignes concernées.' },
];

const IfsDataStructure: React.FC = () => (
  <IfsConsultationPage
    titre="Structure IFS"
    icone={<StructureIcon sx={{ fontSize: 32, color: '#2196f3' }} />}
    apiUrl="/ifs-data/structure"
    onglets={ONGLETS}
    placeholder="Code, désignation, parent…"
    entite="objets"
    fichierExport="structure_ifs.xlsx"
  />
);

export default IfsDataStructure;
