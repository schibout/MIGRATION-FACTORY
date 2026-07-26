import api from './api';

export interface SapTable {
  table_name: string;
  table_class: string | null;
  client_dependent: boolean;
  master_language: string | null;
  content_flag: string | null;
  auth_class: string | null;
  main_flag: string | null;
  buffer_allowed: boolean;
  description: string | null;
  availableformapping: boolean;
  created_at: string;
}

export interface SapTableField {
  id: number;
  table_name: string;
  field_name: string;
  position: number;
  key_flag: boolean;
  mandatory: boolean;
  data_type: string;
  check_table: string | null;
  length: number | null;
  decimals: number | null;
  abap_type: string | null;
  field_text: string | null;
  header_text: string | null;
  long_description: string | null;
  created_at: string;
}

class SapCatalogService {
  async getTables(scope?: string): Promise<SapTable[]> {
    try {
      const params = scope ? { scope } : {};
      // Instance `api` : chemin relatif /api/v1 proxifié par nginx (same-origin,
      // pas de CORS) + Authorization ajouté par l'intercepteur.
      const response = await api.get('/data/sap-catalog/tables', { params });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des tables SAP:', error);
      throw error;
    }
  }

  async getTableFields(tableName: string): Promise<SapTableField[]> {
    try {
      const response = await api.get(`/data/sap-catalog/tables/${tableName}/fields`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des champs de ${tableName}:`, error);
      throw error;
    }
  }
}

export default new SapCatalogService();

