import api from './api';

// Types
export interface FieldMapping {
  id?: number;
  source_table_name: string;
  source_field_name: string;
  target_table: string;
  target_field_name: string;
  created_at?: string;
  updated_at?: string;
  created_by?: string;
  updated_by?: string;
  is_active: boolean;
  transformation_rule?: string;
  data_type?: string;
  is_key: boolean;
  notes?: string;
}

export interface FieldMappingListResponse {
  mappings: FieldMapping[];
  total: number;
  page: number;
  per_page: number;
  pages: number;
}

export interface TableInfo {
  name: string;
  description: string;
}

export interface TablesInfoResponse {
  source_tables: TableInfo[];
  target_tables: TableInfo[];
}

export interface BulkActionRequest {
  action: 'activate' | 'deactivate' | 'delete';
  mapping_ids: number[];
}

export interface ImportResponse {
  message: string;
  errors: string[];
}

const fieldMappingService = {
  // Récupération de la liste des mappings
  getMappings: async (
    page = 1,
    per_page = 25,
    source_table = '',
    target_table = '',
    status = 'all', // 'active', 'inactive', 'all'
    search = ''
  ): Promise<FieldMappingListResponse> => {
    try {
      const response = await api.get('/config/field-mappings', {
        params: {
          page,
          per_page,
          source_table,
          target_table,
          status,
          search
        }
      });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des mappings:', error);
      throw error;
    }
  },

  // Récupération d'un mapping spécifique
  getMapping: async (id: number): Promise<FieldMapping> => {
    try {
      const response = await api.get(`/config/field-mappings/${id}`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération du mapping ${id}:`, error);
      throw error;
    }
  },

  // Création d'un nouveau mapping
  createMapping: async (mapping: FieldMapping): Promise<FieldMapping> => {
    try {
      const response = await api.post('/config/field-mappings', mapping);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la création du mapping:', error);
      throw error;
    }
  },

  // Mise à jour d'un mapping existant
  updateMapping: async (id: number, mapping: Partial<FieldMapping>): Promise<FieldMapping> => {
    try {
      const response = await api.put(`/config/field-mappings/${id}`, mapping);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour du mapping ${id}:`, error);
      throw error;
    }
  },

  // Suppression d'un mapping
  deleteMapping: async (id: number): Promise<void> => {
    try {
      await api.delete(`/config/field-mappings/${id}`);
    } catch (error) {
      console.error(`Erreur lors de la suppression du mapping ${id}:`, error);
      throw error;
    }
  },

  // Actions en masse
  bulkAction: async (actionRequest: BulkActionRequest): Promise<{ message: string }> => {
    try {
      const response = await api.post('/config/field-mappings/bulk-action', actionRequest);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'exécution de l\'action en masse:', error);
      throw error;
    }
  },

  // Import de mappings depuis un fichier CSV
  importMappings: async (file: File): Promise<ImportResponse> => {
    try {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await api.post('/config/field-mappings/import', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      });
      
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'import des mappings:', error);
      throw error;
    }
  },
  // Export de mappings au format CSV
  exportMappings: async (
    source_table = '',
    target_table = '',
    status = 'all',
    useColumnNames = false
  ): Promise<Blob> => {
    try {
      const response = await api.get('/config/field-mappings/export', {
        params: {
          source_table,
          target_table,
          status,
          useColumnNames
        },
        responseType: 'blob'
      });
      
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'export des mappings:', error);
      throw error;
    }
  },

  // Récupération des informations sur les tables source et cible
  getTablesInfo: async (): Promise<TablesInfoResponse> => {
    try {
      const response = await api.get('/config/field-mappings/tables-info');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des informations sur les tables:', error);
      throw error;
    }
  },

  // Téléchargement d'un fichier d'export
  downloadExport: (blob: Blob, filename: string): void => {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.style.display = 'none';
    a.href = url;
    a.download = filename || `field_mappings_export_${new Date().toISOString().replace(/[:.]/g, '-')}.csv`;
    
    document.body.appendChild(a);
    a.click();
    
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  }
};

export default fieldMappingService; 