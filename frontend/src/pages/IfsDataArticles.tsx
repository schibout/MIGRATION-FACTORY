import { Inventory2 as ArticleIcon } from '@mui/icons-material';
import React from 'react';
import IfsConsultationPage, { OngletConsultation } from '../components/ifs/IfsConsultationPage';

// Tables clean_data des modules ETL articles (api/ifs_articles.py), en lecture seule.

const ONGLETS: OngletConsultation[] = [
  { value: 'synthese', label: 'Synthèse',
    description: "Une ligne par article du catalogue : présence dans le périmètre SAP et le fichier validé, sites de stock, d'achat, de vente et de fabrication, nombre de fournisseurs." },
  { value: 'catalogue', label: 'Catalogue',
    description: 'Catalogue des articles IFS (clean_data.part_catalog), une ligne par article.' },
  { value: 'stock', label: 'Stock',
    description: 'Articles en stock et leur planification, une ligne par article et par site.' },
  { value: 'achats', label: 'Achats', placeholder: 'N° article, désignation, N° fournisseur…',
    description: "Articles d'achat et leurs fournisseurs, par site." },
  { value: 'vente', label: 'Vente', placeholder: 'N° article, désignation, article de vente…',
    description: 'Articles de vente, par site.' },
  { value: 'fabrication', label: 'Fabrication',
    description: 'Attributs des articles fabriqués, par site.' },
  { value: 'controles', label: 'Contrôles',
    description: "Écarts entre le fichier validé, le périmètre SAP et le catalogue chargé, lignes hors catalogue et données d'achat incomplètes. Choisir un contrôle pour voir les lignes concernées." },
  { value: 'mode_emploi', label: "Mode d'emploi",
    description: "Tables affichées, fonctionnement des boutons et limites de l'écran." },
];

const IfsDataArticles: React.FC = () => (
  <IfsConsultationPage
    titre="Articles IFS"
    icone={<ArticleIcon sx={{ fontSize: 32, color: '#3f51b5' }} />}
    apiUrl="/ifs-data/articles"
    guide="/guides/ifs-articles.html"
    onglets={ONGLETS}
    placeholder="N° article, désignation…"
    entite="articles"
    fichierExport="articles_ifs.xlsx"
    aideRecalculer="Relance les modules ETL articles (SAP, Article SAP, PHL, Composants) depuis les tables déjà extraites, sans appeler SAP"
    aideSynchroniser="Ré-extrait les tables articles de SAP, puis relance les modules ETL articles"
    libelleRecharge="articles SAP chargés"
    noteEchec="Les modules déjà terminés restent appliqués : le catalogue peut être incomplet, relancez le rechargement."
  />
);

export default IfsDataArticles;
