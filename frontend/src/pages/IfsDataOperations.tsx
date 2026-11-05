import { Build as OperationIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la catégorie d'export « Operation » (api/ifs_data_operations.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: 'Une ligne par opération de maintenance exportée vers IFS : bon de travail, objet, dates, nombre de ressources et de besoins matière.' },
  { value: 'operations', label: 'Opérations',
    description: 'Opérations des bons de travail (clean_data.jt_task), avec les colonnes du fichier d’export.' },
  { value: 'ressources', label: 'Ressources', placeholder: 'N° opération, N° bon de travail, ressource…',
    description: 'Demandes de ressources des opérations (clean_data.jt_task_resource).' },
  { value: 'besoins', label: 'Besoins matière', placeholder: 'N° opération, N° bon de travail, N° article…',
    description: 'Besoins matière des opérations (clean_data.maint_material_req_line).' },
  { value: 'controles', label: 'Contrôles',
    description: 'Objets absents de la structure, opérations sans ressource, lignes sans opération et articles hors catalogue. Choisir un contrôle pour voir les lignes concernées.' },
];

const IfsDataOperations: React.FC = () => (
  <IfsConsultationPage
    titre="Opérations de maintenance IFS"
    icone={<OperationIcon sx={{ fontSize: 32, color: '#5e35b1' }} />}
    apiUrl="/ifs-data/operations"
    onglets={ONGLETS}
    placeholder="N° opération, N° bon de travail, description, objet…"
    entite="opérations"
    fichierExport="operations_ifs.xlsx"
  />
);

export default IfsDataOperations;
