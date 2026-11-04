import { LocalShipping as FournisseurIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data du module ETL fournisseurs (api/ifs_fournisseurs.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: "Une ligne par fournisseur chargé, avec ses principales informations et le nombre d'adresses, de communications, de numéros fiscaux et d'articles." },
  { value: 'general', label: 'Général',
    description: 'Identité du fournisseur dans IFS et identifiants internes.' },
  { value: 'achats', label: 'Achats',
    description: "Paramètres d'achat du fournisseur (clean_data.supplier)." },
  { value: 'adresses', label: 'Adresses',
    description: 'Adresses du fournisseur, types de chaque adresse et adresses de livraison.' },
  { value: 'communication', label: 'Communication',
    description: 'Téléphones, fax et e-mails, et contacts du fournisseur.' },
  { value: 'fiscalite', label: 'Fiscalité',
    description: 'Informations fiscales, codes de taxe de livraison et numéros fiscaux (SIREN, SIRET, TVA).' },
  { value: 'paiement', label: 'Facturation et paiement',
    description: 'Facturation, paiement, modes de paiement et adresses de paiement (coordonnées bancaires).' },
  { value: 'articles', label: 'Articles', placeholder: 'N° IFS, N° SAP, nom, article…',
    description: "Liens article / fournisseur d'achat. Cette table dépend du module ETL Articles : Recalculer et Synchroniser SAP ne la rechargent pas." },
  { value: 'controles', label: 'Contrôles',
    description: "Écarts entre le périmètre (clean_data.ifs_fournisseurs) et les tables chargées, et fournisseurs absents d'une table attendue. Choisir un contrôle pour voir les fournisseurs concernés." },
  { value: 'mode_emploi', label: "Mode d'emploi",
    description: "Tables affichées, fonctionnement des boutons et limites de l'écran." },
];

const IfsDataFournisseurs: React.FC = () => (
  <IfsConsultationPage
    titre="Fournisseurs IFS"
    icone={<FournisseurIcon sx={{ fontSize: 32, color: '#3f51b5' }} />}
    apiUrl="/ifs-data/fournisseurs"
    guide="/guides/ifs-fournisseurs.html"
    onglets={ONGLETS}
    placeholder="N° IFS, N° SAP, nom…"
    entite="fournisseurs"
    fichierExport="fournisseurs_ifs.xlsx"
    aideRecalculer="Recharge les tables fournisseurs depuis le périmètre en place (Finance > Fournisseurs), sans appeler SAP"
    aideSynchroniser="Ré-extrait les tables fournisseurs de SAP, recalcule le périmètre à la même date d'arrêté, puis recharge les tables"
    libelleRecharge="fournisseurs chargés"
    noteEchec="Les tables n'ont pas été modifiées par le module ETL."
  />
);

export default IfsDataFournisseurs;
