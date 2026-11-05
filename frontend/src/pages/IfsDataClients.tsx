import { People as ClientIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data de la catégorie d'export « customer » (api/ifs_data_clients.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: "Une ligne par client exporté vers IFS : pays, devise, condition de paiement, nombre de fiches, d'adresses, de communications et de numéros fiscaux." },
  { value: 'general', label: 'Général',
    description: 'Informations générales du client (clean_data.customer_info), avec les colonnes du fichier d’export.' },
  { value: 'adresses', label: 'Adresses',
    description: 'Adresses du client et types de chaque adresse.' },
  { value: 'communication', label: 'Communication',
    description: 'Téléphones, e-mails et contacts du client.' },
  { value: 'commandes', label: 'Commandes',
    description: 'Paramètres de commande client et adresses de commande (clean_data.cust_ord_customer, cust_ord_customer_address).' },
  { value: 'fiscalite', label: 'Fiscalité',
    description: 'Informations fiscales, taxes et frais de livraison, codes hors taxes, exemptions, documents et numéros fiscaux.' },
  { value: 'paiement', label: 'Facturation et paiement',
    description: 'Facturation, crédit, paiement, modes de paiement et adresses de paiement.' },
  { value: 'controles', label: 'Contrôles',
    description: "Lignes en double dans une table exportée et clients absents d'une table attendue. Choisir un contrôle pour voir les lignes concernées." },
];

const IfsDataClients: React.FC = () => (
  <IfsConsultationPage
    titre="Clients IFS"
    icone={<ClientIcon sx={{ fontSize: 32, color: '#ff9800' }} />}
    apiUrl="/ifs-data/clients"
    onglets={ONGLETS}
    placeholder="N° IFS, N° SAP, nom…"
    entite="clients"
    fichierExport="clients_ifs.xlsx"
  />
);

export default IfsDataClients;
