import api from './api';

// Interface pour les tables IFS
export interface IfsTable {
  id: string;
  name: string;
  label: string;
}

// Liste des tables IFS disponibles
export const IFS_TABLES: IfsTable[] = [
  {
    id: 'public.supplier_delivery_tax_code',
    name: 'public.supplier_delivery_tax_code',
    label: 'Codes de taxe de livraison des fournisseurs'
  },
  {
    id: 'public.supplier',
    name: 'public.supplier',
    label: 'Fournisseurs'
  },
  {
    id: 'public.supplier_document_tax_info',
    name: 'public.supplier_document_tax_info',
    label: 'Infos fiscales sur les documents fournisseurs'
  },
  {
    id: 'public.supplier_info_address',
    name: 'public.supplier_info_address',
    label: 'Adresses des fournisseurs'
  },
  {
    id: 'public.supplier_info_address_type',
    name: 'public.supplier_info_address_type',
    label: 'Types d\'adresse fournisseur'
  },
  {
    id: 'public.supplier_info_contact',
    name: 'public.supplier_info_contact',
    label: 'Contacts des fournisseurs'
  },
  {
    id: 'public.supplier_info_general',
    name: 'public.supplier_info_general',
    label: 'Infos générales sur les fournisseurs'
  },
  {
    id: 'public.supplier_info_our_id',
    name: 'public.supplier_info_our_id',
    label: 'Identifiants internes des fournisseurs'
  },
  {
    id: 'public.supplier_tax_info',
    name: 'public.supplier_tax_info',
    label: 'Infos fiscales des fournisseurs'
  }
];

// Interface pour les colonnes d'une table
export interface TableColumn {
  name: string;
  type: string;
  label: string;
}

// Interface pour les données d'une table avec pagination
export interface TableData {
  columns: TableColumn[];
  rows: any[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Interface pour les options d'export
export interface ExportOptions {
  format: 'csv' | 'excel';
  filename?: string;
  includeHeaders?: boolean;
  useColumnNames?: boolean;  // Utiliser les noms de colonnes au lieu des descriptions
  delimiter?: string;
  encoding?: string;
  sheetName?: string;
  // Options pour exporter avec les filtres actuels
  searchTerm?: string;
  filters?: Record<string, {value: string, operator: string}>;
}

// Interface pour la mise à jour d'un enregistrement
export interface UpdateRecordResult {
  success: boolean;
  message: string;
  data?: any;
}

// Interface pour la suppression d'un enregistrement
export interface DeleteRecordResult {
  success: boolean;
  message: string;
}

const ifsTablesService = {
  // Récupérer les tables disponibles
  getTables: async (): Promise<IfsTable[]> => {
    try {
      // Tenter de récupérer les tables depuis l'API
      const response = await api.get('/data/ifs-tables');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des tables IFS:', error);
      // En cas d'erreur, retourner les tables prédéfinies
      return IFS_TABLES;
    }
  },

  // Récupérer les tables clients disponibles
  getClientTables: async (): Promise<IfsTable[]> => {
    try {
      // Tenter de récupérer les tables clients depuis l'API
      const response = await api.get('/data/ifs-tables-clients');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des tables clients IFS:', error);
      // En cas d'erreur, retourner un tableau vide
      return [];
    }
  },

  // Récupérer les colonnes d'une table
  getTableColumns: async (tableName: string): Promise<TableColumn[]> => {
    try {
      // Tenter de récupérer les colonnes depuis l'API
      const response = await api.get(`/data/ifs-tables/${tableName}/columns`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des colonnes pour la table ${tableName}:`, error);
      
      // En cas d'erreur, retourner des colonnes simulées
      const columnCount = Math.floor(Math.random() * 10) + 5; // Entre 5 et 15 colonnes
      return Array.from({ length: columnCount }, (_, i) => {
        const columnIndex = i + 1;
        return {
          name: `column_${columnIndex}`,
          type: i % 3 === 0 ? 'string' : i % 3 === 1 ? 'number' : 'date',
          label: `Colonne ${columnIndex}`
        };
      });
    }
  },

  // Récupérer les données d'une table avec pagination et tri
  getTableData: async (
    tableName: string, 
    page: number = 0, 
    pageSize: number = 10,
    sortField: string = '',
    sortDirection: 'asc' | 'desc' = 'asc',
    searchTerm: string = '',
    filters: Record<string, {value: string, operator: string}> = {}
  ): Promise<TableData> => {
    try {
      // Tenter de récupérer les données depuis l'API
      const response = await api.get(`/data/ifs-tables/${tableName}/data`, {
        params: {
          page,
          pageSize,
          sortField: sortField || undefined,
          sortDirection: sortDirection || undefined,
          search: searchTerm || undefined,
          filters: Object.keys(filters).length > 0 ? JSON.stringify(filters) : undefined
        }
      });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des données pour la table ${tableName}:`, error);
      
      // En cas d'erreur, générer des données aléatoires
      const columns = await ifsTablesService.getTableColumns(tableName);
      const rowCount = Math.min(pageSize, 50); // Maximum 50 lignes
      
      // Générer des données aléatoires en fonction des types de colonnes
      let rows = Array.from({ length: rowCount }, (_, rowIndex) => {
        const row: Record<string, any> = {};
        columns.forEach(column => {
          switch (column.type) {
            case 'string':
              row[column.name] = `Valeur ${rowIndex + 1}-${column.name}`;
              break;
            case 'number':
              row[column.name] = Math.floor(Math.random() * 10000) / 100;
              break;
            case 'date':
              const date = new Date();
              date.setDate(date.getDate() - Math.floor(Math.random() * 365));
              row[column.name] = date.toISOString().split('T')[0];
              break;
            default:
              row[column.name] = `Valeur ${rowIndex + 1}-${column.name}`;
          }
        });
        return row;
      });

      // Appliquer la recherche et les filtres
      if (searchTerm) {
        const searchLower = searchTerm.toLowerCase();
        rows = rows.filter(row => 
          Object.values(row).some(value => 
            value && String(value).toLowerCase().includes(searchLower)
          )
        );
      }

      // Appliquer les filtres spécifiques avec opérateurs
      if (Object.keys(filters).length > 0) {
        rows = rows.filter(row => 
          Object.entries(filters).every(([key, {value: filterValue, operator}]) => {
            const fieldValue = row[key];
            if (!fieldValue && operator !== 'is_null') return false;
            
            switch (operator) {
              case 'equals':
                return String(fieldValue) === filterValue;
              case 'contains':
                return String(fieldValue).toLowerCase().includes(filterValue.toLowerCase());
              case 'starts_with':
                return String(fieldValue).toLowerCase().startsWith(filterValue.toLowerCase());
              case 'ends_with':
                return String(fieldValue).toLowerCase().endsWith(filterValue.toLowerCase());
              case 'is_null':
                return !fieldValue || fieldValue === '';
              case 'is_not_null':
                return fieldValue && fieldValue !== '';
              default:
                return String(fieldValue).toLowerCase().includes(filterValue.toLowerCase());
            }
          })
        );
      }
      
      return {
        columns,
        rows,
        total: 100, // Simuler un total de 100 enregistrements
        page,
        pageSize,
        totalPages: Math.ceil(100 / pageSize)
      };
    }
  },

  // Mettre à jour un enregistrement
  updateRecord: async (
    tableName: string,
    recordId: string | number,
    data: Record<string, any>
  ): Promise<UpdateRecordResult> => {
    try {
      // Déterminer la clé primaire à partir du premier champ "id" trouvé
      const primaryKeyField = Object.keys(data).find(key => key.toLowerCase().includes('id')) || 'id';
      
      // Vérifier que l'identifiant est bien présent dans les données
      if (!recordId) {
        return {
          success: false,
          message: "Impossible de mettre à jour l'enregistrement: identifiant manquant"
        };
      }
      
      // Tenter de mettre à jour l'enregistrement via l'API
      const response = await api.put(`/data/ifs-tables/${tableName}/record/${recordId}`, data);
      
      return {
        success: true,
        message: "Enregistrement mis à jour avec succès",
        data: response.data
      };
    } catch (error) {
      console.error(`Erreur lors de la mise à jour de l'enregistrement dans la table ${tableName}:`, error);
      
      // En cas d'erreur, simuler une réponse positive en développement
      return {
        success: false,
        message: `Erreur lors de la mise à jour: ${(error as Error).message}`
      };
      
      return {
        success: false,
        message: `Erreur lors de la mise à jour: ${(error as Error).message}`
      };
    }
  },

  // Supprimer un enregistrement
  deleteRecord: async (
    tableName: string,
    recordId: string | number
  ): Promise<DeleteRecordResult> => {
    try {
      // Vérifier que l'identifiant est bien présent
      if (!recordId) {
        return {
          success: false,
          message: "Impossible de supprimer l'enregistrement: identifiant manquant"
        };
      }
      
      // Tenter de supprimer l'enregistrement via l'API
      await api.delete(`/data/ifs-tables/${tableName}/record/${recordId}`);
      
      return {
        success: true,
        message: "Enregistrement supprimé avec succès"
      };
    } catch (error) {
      console.error(`Erreur lors de la suppression de l'enregistrement dans la table ${tableName}:`, error);
      
      // En cas d'erreur, retourner l'erreur
      return {
        success: false,
        message: `Erreur lors de la suppression: ${(error as Error).message}`
      };
      
      return {
        success: false,
        message: `Erreur lors de la suppression: ${(error as Error).message}`
      };
    }
  },

  // Exporter les données au format CSV ou Excel
  exportTableData: async (
    tableName: string,
    fields: string[],
    options: ExportOptions
  ): Promise<Blob> => {
    try {
      // Récupération du type de contenu en fonction du format
      let contentType = '';
      if (options.format === 'csv') {
        contentType = 'text/csv';
      } else if (options.format === 'excel') {
        contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }

      // Mise à jour du nom de fichier
      if (!options.filename) {
        const now = new Date().toISOString().replace(/[:.]/g, '-');
        const extension = options.format === 'csv' ? 'csv' : 'xlsx';
        options.filename = `ifs_${tableName.replace(/\./g, '_')}_${now}.${extension}`;
      }

      // Préparer la requête d'export
      const exportData = {
        fields,
        filters: options.filters || {}, // Intégrer les filtres utilisés
        searchTerm: options.searchTerm || '', // Intégrer le terme de recherche
        format: options.format,
        options: {
          includeHeaders: options.includeHeaders !== undefined ? options.includeHeaders : true,
          useColumnNames: options.useColumnNames === true,
          delimiter: options.delimiter || ';',
          encoding: options.encoding || 'utf-8',
          sheetName: options.sheetName || tableName.split('.').pop(),
          filename: options.filename
        }
      };

      // Exécuter la requête d'export
      const response = await api.post(`/data/${tableName}/export`, exportData, {
        responseType: 'blob'
      });

      return response.data;
    } catch (error) {
      console.error(`Erreur lors de l'export des données pour la table ${tableName}:`, error);
      
      // En mode développement ou si l'API n'est pas disponible, créons un fichier CSV simple
      if (typeof window !== 'undefined') {
        try {
          // Récupérer les données actuelles (avec filtres appliqués)
          const data = await ifsTablesService.getTableData(
            tableName, 
            0, 
            1000, // récupérer un maximum de lignes
            '', 
            'asc',
            options.searchTerm,
            options.filters
          );
          
          // Générer un contenu CSV simple
          let content = '';
          
          // Ajouter les en-têtes
          if (options.includeHeaders !== false) {
            content += fields.map(field => {
              // Utiliser le nom de la colonne ou sa description selon l'option
              const headerText = options.useColumnNames === true ? 
                field : // Utiliser le nom de la colonne
                (data.columns.find(col => col.name === field)?.label || field); // Sinon utiliser la description
              return `"${headerText.replace(/"/g, '""')}"`;
            }).join(';') + '\n';
          }
          
          // Ajouter les lignes
          data.rows.forEach(row => {
            content += fields.map(field => {
              const value = row[field];
              // Convertir en chaîne et échapper les guillemets
              const strValue = value !== null && value !== undefined ? String(value) : '';
              return `"${strValue.replace(/"/g, '""')}"`;
            }).join(';') + '\n';
          });
          
          // Créer un blob pour le téléchargement
          const blob = new Blob([content], { type: 'text/csv;charset=utf-8' });
          return blob;
        } catch (fallbackError) {
          console.error('Erreur lors de la création du CSV de secours:', fallbackError);
          throw new Error(`Échec de l'export des données: ${(error as Error).message}`);
        }
      }
      
      throw new Error(`Échec de l'export des données: ${(error as Error).message}`);
    }
  },
  
  // Télécharger les données exportées
  downloadExport: (blob: Blob, filename: string): void => {
    // Créer un URL pour le blob
    const url = window.URL.createObjectURL(blob);
    
    // Créer un élément <a> pour le téléchargement
    const a = document.createElement('a');
    a.style.display = 'none';
    a.href = url;
    a.download = filename;
    
    // Ajouter un attribut pour indiquer que la ressource est sécurisée
    a.setAttribute('rel', 'noopener noreferrer');
    a.setAttribute('target', '_blank');
    
    // Ajouter l'élément au DOM, cliquer dessus, puis le supprimer
    document.body.appendChild(a);
    a.click();
    
    // Attendre un court instant avant de nettoyer
    setTimeout(() => {
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    }, 100);
  }
};

export default ifsTablesService; 