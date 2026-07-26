import axios from 'axios';
import { API_URL } from '../config';

// Interface pour les vues SAP
export interface SapView {
  id: string;
  name: string;
  label: string;
}

// Liste des vues SAP disponibles
export const SAP_VIEWS: SapView[] = [
  {
    id: 'v_coordonnees_bancaires_fournisseurs',
    name: 'v_coordonnees_bancaires_fournisseurs',
    label: 'Coordonnées bancaires fournisseurs'
  },
  {
    id: 'v_donnees_bancaires_fournisseurs',
    name: 'v_donnees_bancaires_fournisseurs',
    label: 'Données bancaires fournisseurs'
  },
  {
    id: 'v_donnees_banques',
    name: 'v_donnees_banques',
    label: 'Données des banques'
  },
  {
    id: 'v_donnees_fournisseurs_achats',
    name: 'v_donnees_fournisseurs_achats',
    label: 'Fournisseurs - Données achats'
  },
  {
    id: 'v_fournisseurs',
    name: 'v_fournisseurs',
    label: 'Fournisseurs - Vue générale'
  }
];

// Interface pour les colonnes d'une vue
export interface ViewColumn {
  name: string;
  type: string;
  label: string;
}

// Interface pour les données d'une vue avec pagination
export interface ViewData {
  columns: ViewColumn[];
  rows: Record<string, any>[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Interface pour les options de filtrage
export interface FilterOptions {
  search?: string;
  filters?: Record<string, string>;
}

// Récupérer la liste des vues SAP disponibles
// scope optionnel: fournisseur | article | client | achat | maintenance | comptabilite (aligné menu DONNÉES SAP)
export const getSapViews = async (scope?: string): Promise<SapView[]> => {
  try {
    const params = scope ? { scope } : {};
    const response = await axios.get(`${API_URL}/data/sap-views`, { params });
    return response.data;
  } catch (error) {
    console.error('Erreur lors de la récupération des vues SAP:', error);
    throw error;
  }
};

// Récupérer les colonnes d'une vue
export const getViewColumns = async (viewName: string): Promise<ViewColumn[]> => {
  try {
    const response = await axios.get(`${API_URL}/data/sap-views/${viewName}/columns`);
    return response.data;
  } catch (error) {
    console.error(`Erreur lors de la récupération des colonnes pour la vue ${viewName}:`, error);
    throw error;
  }
};

// Récupérer les données d'une vue avec pagination, tri et filtrage
export const getViewData = async (
  viewName: string, 
  page: number = 1, 
  pageSize: number = 25, 
  sortField: string = '', 
  sortDirection: 'asc' | 'desc' = 'asc',
  search: string = '',
  filters: Record<string, string> = {}
): Promise<ViewData> => {
  try {
    // Log pour déboguer les filtres
    console.log('Appel getViewData avec filtres:', filters);
    
    // Construire les paramètres
    const params: Record<string, any> = {
      page,
      pageSize,
      sortField: sortField || undefined,
      sortDirection: sortDirection || undefined,
      search: search || undefined
    };
    
    // S'assurer que les filtres sont correctement sérialisés
    if (Object.keys(filters).length > 0) {
      // Sérialiser les filtres en JSON
      params.filters = JSON.stringify(filters);
      console.log('Filtres sérialisés:', params.filters);
    }

    console.log('Paramètres de requête complets:', params);
    
    const response = await axios.get(`${API_URL}/data/sap-views/${viewName}/data`, { params });
    
    // Log de la réponse de l'API
    console.log(`Réponse du serveur pour ${viewName}:`, {
      total: response.data.total,
      rows: response.data.rows?.length || 0
    });
    
    return response.data;
  } catch (error) {
    console.error(`Erreur lors de la récupération des données pour la vue ${viewName}:`, error);
    throw error;
  }
};

// Objet service complet pour compatibilité avec le code existant
const sapViewsService = {
  getViews: getSapViews,
  getViewColumns,
  getViewData,
  
  // Fonction simplifiée pour compatibilité avec l'ancienne interface
  getTableData: async (
    viewName: string, 
    page: number = 1, 
    pageSize: number = 25, 
    sortField: string = '', 
    sortDirection: 'asc' | 'desc' = 'asc',
    searchTerm: string = '',
    filters: Record<string, string> = {}
  ): Promise<ViewData> => {
    console.log('Appel getTableData (compatibilité) avec filtres:', filters);
    return getViewData(viewName, page, pageSize, sortField, sortDirection, searchTerm, filters);
  }
};

export default sapViewsService; 