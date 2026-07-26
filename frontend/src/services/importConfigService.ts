import api from './api';

export interface ImportTypeConfig {
  id?: number;
  type_code: string;
  display_name: string;
  description: string;
  category: string;
  max_file_size_mb: number;
  allowed_extensions: string[];
  required_columns: string[];
  optional_columns: string[];
  column_mappings: { [key: string]: string };
  validation_rules: { [key: string]: string };
  target_table: string;
  processor_class: string;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: number;
  template_url?: string;
  help_text?: string;
  icon: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  count?: number;
}

class ImportConfigService {
  private baseUrl = '/import-types'; // Corrigé : sans /api car déjà dans le baseURL d'api

  /**
   * Récupère la liste des types d'import
   */
  async getImportTypes(category?: string, activeOnly: boolean = true): Promise<ImportTypeConfig[]> {
    try {
      const params = new URLSearchParams();
      if (category) params.append('category', category);
      if (!activeOnly) params.append('active_only', 'false');
      
      const url = params.toString() ? `${this.baseUrl}?${params.toString()}` : this.baseUrl;
      const response = await api.get<ApiResponse<ImportTypeConfig[]>>(url);
      
      if (response.data.success) {
        return response.data.data || [];
      } else {
        throw new Error(response.data.error || 'Erreur lors de la récupération des types');
      }
    } catch (error: any) {
      console.error('Erreur getImportTypes:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Récupère un type d'import par son ID
   */
  async getImportType(id: number): Promise<ImportTypeConfig> {
    try {
      const response = await api.get<ApiResponse<ImportTypeConfig>>(`${this.baseUrl}/${id}`);
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Type d\'import non trouvé');
      }
    } catch (error: any) {
      console.error('Erreur getImportType:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Récupère un type d'import par son code
   */
  async getImportTypeByCode(typeCode: string): Promise<ImportTypeConfig> {
    try {
      const response = await api.get<ApiResponse<ImportTypeConfig>>(`${this.baseUrl}/${typeCode}`);
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Type d\'import non trouvé');
      }
    } catch (error: any) {
      console.error('Erreur getImportTypeByCode:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Crée un nouveau type d'import
   */
  async createImportType(config: Omit<ImportTypeConfig, 'id' | 'created_at' | 'updated_at' | 'created_by'>): Promise<ImportTypeConfig> {
    try {
      const response = await api.post<ApiResponse<ImportTypeConfig>>(this.baseUrl, config);
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Erreur lors de la création');
      }
    } catch (error: any) {
      console.error('Erreur createImportType:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Met à jour un type d'import existant
   */
  async updateImportType(id: number, config: Partial<ImportTypeConfig>): Promise<ImportTypeConfig> {
    try {
      const response = await api.put<ApiResponse<ImportTypeConfig>>(`${this.baseUrl}/${id}`, config);
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Erreur lors de la mise à jour');
      }
    } catch (error: any) {
      console.error('Erreur updateImportType:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Supprime un type d'import
   */
  async deleteImportType(id: number): Promise<void> {
    try {
      const response = await api.delete<ApiResponse<void>>(`${this.baseUrl}/${id}`);
      
      if (!response.data.success) {
        throw new Error(response.data.error || 'Erreur lors de la suppression');
      }
    } catch (error: any) {
      console.error('Erreur deleteImportType:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Active/désactive un type d'import
   */
  async toggleImportType(id: number): Promise<ImportTypeConfig> {
    try {
      const response = await api.post<ApiResponse<ImportTypeConfig>>(`${this.baseUrl}/${id}/toggle`);
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Erreur lors du changement de statut');
      }
    } catch (error: any) {
      console.error('Erreur toggleImportType:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Valide la structure d'un fichier contre un type d'import
   */
  async validateFileStructure(typeCode: string, columns: string[]): Promise<ValidationResult> {
    try {
      const response = await api.post<ApiResponse<ValidationResult>>(`${this.baseUrl}/${typeCode}/validate`, {
        columns
      });
      
      if (response.data.success) {
        return response.data.data!;
      } else {
        throw new Error(response.data.error || 'Erreur lors de la validation');
      }
    } catch (error: any) {
      console.error('Erreur validateFileStructure:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Récupère la liste des catégories disponibles
   */
  async getCategories(): Promise<string[]> {
    try {
      const response = await api.get<ApiResponse<string[]>>(`${this.baseUrl}/categories`);
      
      if (response.data.success) {
        return response.data.data || [];
      } else {
        throw new Error(response.data.error || 'Erreur lors de la récupération des catégories');
      }
    } catch (error: any) {
      console.error('Erreur getCategories:', error);
      throw new Error(error.response?.data?.error || error.message || 'Erreur réseau');
    }
  }

  /**
   * Récupère les types d'import pour une catégorie spécifique
   */
  async getCustomerImportTypes(): Promise<ImportTypeConfig[]> {
    return this.getImportTypes('customer', true);
  }

  /**
   * Récupère les types d'import pour les produits
   */
  async getProductImportTypes(): Promise<ImportTypeConfig[]> {
    return this.getImportTypes('product', true);
  }

  /**
   * Récupère les types d'import pour les commandes
   */
  async getOrderImportTypes(): Promise<ImportTypeConfig[]> {
    return this.getImportTypes('order', true);
  }
}

export default new ImportConfigService(); 