import api from './api';

// Types
export interface Transcodification {
  id?: number;
  category: string;
  source_system: string;
  target_system: string;
  source_value: string;
  target_value: string;
  description?: string;
  created_at?: string;
  updated_at?: string;
  created_by?: string;
  updated_by?: string;
  is_active: boolean;
}

export interface TranscodificationListResponse {
  transcodifications: Transcodification[];
  total: number;
  page: number;
  per_page: number;
  pages: number;
}

export interface BulkActionRequest {
  action: 'activate' | 'deactivate' | 'delete' | 'duplicate';
  transcodification_ids: number[];
}

export interface ImportResponse {
  message: string;
  errors: string[];
}

const transcodificationService = {
  // Récupération de la liste des transcodifications
  getTranscodifications: async (
    page = 1,
    per_page = 25,
    category = '',
    source_system = '',
    target_system = '',
    status = 'all', // 'active', 'inactive', 'all'
    search = ''
  ): Promise<TranscodificationListResponse> => {
    try {
      const response = await api.get('/config/transcodifications', {
        params: {
          page,
          per_page,
          category,
          source_system,
          target_system,
          status,
          search
        }
      });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des transcodifications:', error);
      throw error;
    }
  },

  // Récupération d'une transcodification spécifique
  getTranscodification: async (id: number): Promise<Transcodification> => {
    try {
      const response = await api.get(`/config/transcodifications/${id}`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération de la transcodification ${id}:`, error);
      throw error;
    }
  },

  // Création d'une nouvelle transcodification
  createTranscodification: async (transcodification: Transcodification): Promise<Transcodification> => {
    try {
      const response = await api.post('/config/transcodifications', transcodification);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la création de la transcodification:', error);
      throw error;
    }
  },

  // Mise à jour d'une transcodification existante
  updateTranscodification: async (id: number, transcodification: Partial<Transcodification>): Promise<Transcodification> => {
    try {
      const response = await api.put(`/config/transcodifications/${id}`, transcodification);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour de la transcodification ${id}:`, error);
      throw error;
    }
  },

  // Suppression d'une transcodification
  deleteTranscodification: async (id: number): Promise<void> => {
    try {
      await api.delete(`/config/transcodifications/${id}`);
    } catch (error) {
      console.error(`Erreur lors de la suppression de la transcodification ${id}:`, error);
      throw error;
    }
  },

  // Actions en masse
  bulkAction: async (actionRequest: BulkActionRequest): Promise<{ message: string }> => {
    try {
      const response = await api.post('/config/transcodifications/bulk-action', actionRequest);
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'exécution de l\'action en masse:', error);
      throw error;
    }
  },

  // Import de transcodifications depuis un fichier CSV
  importTranscodifications: async (file: File): Promise<ImportResponse> => {
    try {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await api.post('/config/transcodifications/import', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      });
      
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'import des transcodifications:', error);
      throw error;
    }
  },
  // Export de transcodifications au format CSV
  exportTranscodifications: async (
    category = '',
    source_system = '',
    target_system = '',
    status = 'all',
    useColumnNames = false
  ): Promise<Blob> => {
    try {
      const response = await api.get('/config/transcodifications/export', {
        params: {
          category,
          source_system,
          target_system,
          status,
          useColumnNames
        },
        responseType: 'blob'
      });
      
      return response.data;
    } catch (error) {
      console.error('Erreur lors de l\'export des transcodifications:', error);
      throw error;
    }
  },

  // Récupération des catégories disponibles
  getCategories: async (): Promise<string[]> => {
    try {
      const response = await api.get('/config/transcodifications/categories');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des catégories:', error);
      throw error;
    }
  },

  // Téléchargement d'un fichier d'export
  downloadExport: (blob: Blob, filename: string): void => {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.style.display = 'none';
    a.href = url;
    a.download = filename || `transcodifications_export_${new Date().toISOString().replace(/[:.]/g, '-')}.csv`;
    
    document.body.appendChild(a);
    a.click();
    
    window.URL.revokeObjectURL(url);
    document.body.removeChild(a);
  }
};

export default transcodificationService; 