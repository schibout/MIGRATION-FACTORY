import api from './api';

// Types
export interface EtlDefaultValue {
  id: number;
  module: string;
  table_cible: string;
  colonne: string;
  variante: string;
  type_valeur: 'CONSTANTE' | 'NULL';
  valeur: string | null;
  description?: string | null;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string;
  updated_by?: string;
}

export interface DefaultValueListResponse {
  default_values: EtlDefaultValue[];
  total: number;
  page: number;
  per_page: number;
  pages: number;
}

export interface DefaultValueMeta {
  modules: string[];
  tables: { module: string; table_cible: string }[];
}

export interface DefaultValueFilters {
  page?: number;
  per_page?: number;
  module?: string;
  table_cible?: string;
  colonne?: string;
  is_active?: string; // 'true' | 'false' | ''
}

const defaultValueService = {
  // Récupération de la liste des valeurs par défaut ETL
  list: async (filters: DefaultValueFilters): Promise<DefaultValueListResponse> => {
    try {
      const params = Object.fromEntries(
        Object.entries(filters).filter(([, v]) => v !== undefined && v !== '')
      );
      const response = await api.get('/config/default-values', { params });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des valeurs par défaut:', error);
      throw error;
    }
  },

  // Récupération des métadonnées (modules et tables cibles disponibles)
  meta: async (): Promise<DefaultValueMeta> => {
    try {
      const response = await api.get('/config/default-values/meta');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des métadonnées des valeurs par défaut:', error);
      throw error;
    }
  },

  // Mise à jour d'une valeur par défaut existante
  update: async (
    id: number,
    payload: Partial<Pick<EtlDefaultValue, 'valeur' | 'type_valeur' | 'description' | 'is_active'>>
  ): Promise<EtlDefaultValue> => {
    try {
      const response = await api.put(`/config/default-values/${id}`, payload);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour de la valeur par défaut ${id}:`, error);
      throw error;
    }
  },
};

export default defaultValueService;
