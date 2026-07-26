import api from './api';

export interface IfsArticleTable {
  id: string;
  name: string;
  label: string;
}

export interface IfsArticleColumn {
  name: string;
  type: string;
  label: string;
}

export interface IfsArticleTableData {
  columns: IfsArticleColumn[];
  rows: any[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface ExportOptions {
  format: 'csv' | 'excel';
  fields: string[];
  filters?: Record<string, any>;
  options?: {
    includeHeaders?: boolean;
    delimiter?: string;
    filename?: string;
  };
}

class IfsArticlesService {
  // Récupérer la liste des tables articles IFS
  async getTables(): Promise<IfsArticleTable[]> {
    try {
      const response = await api.get('/data/ifs-articles');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des tables articles IFS:', error);
      throw error;
    }
  }

  // Récupérer les colonnes d'une table article IFS
  async getTableColumns(tableName: string): Promise<IfsArticleColumn[]> {
    try {
      const response = await api.get(`/data/ifs-articles/${tableName}/columns`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des colonnes de la table ${tableName}:`, error);
      throw error;
    }
  }

  // Récupérer les données d'une table article IFS avec pagination, tri et filtres
  async getTableData(
    tableName: string,
    page: number = 0,
    pageSize: number = 10,
    sortField?: string,
    sortDirection?: 'asc' | 'desc',
    searchTerm?: string,
    filters?: Record<string, any>
  ): Promise<IfsArticleTableData> {
    try {
      const params: any = {
        page,
        pageSize
      };

      if (sortField) {
        params.sortField = sortField;
        params.sortDirection = sortDirection || 'asc';
      }

      if (searchTerm) {
        params.search = searchTerm;
      }

      if (filters && Object.keys(filters).length > 0) {
        params.filters = JSON.stringify(filters);
      }

      const response = await api.get(`/data/ifs-articles/${tableName}/data`, { params });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des données de la table ${tableName}:`, error);
      throw error;
    }
  }

  // Exporter les données d'une table article IFS
  async exportTable(tableName: string, exportOptions: ExportOptions): Promise<Blob> {
    try {
      const response = await api.post(
        `/data/ifs-articles/${tableName}/export`,
        exportOptions,
        {
          responseType: 'blob'
        }
      );
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de l'export de la table ${tableName}:`, error);
      throw error;
    }
  }

  // Mettre à jour un enregistrement dans une table article IFS
  async updateRecord(tableName: string, recordId: string, data: Record<string, any>): Promise<any> {
    try {
      const response = await api.put(`/data/ifs-articles/${tableName}/record/${recordId}`, data);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour de l'enregistrement ${recordId} dans la table ${tableName}:`, error);
      throw error;
    }
  }

  // Supprimer un enregistrement d'une table article IFS
  async deleteRecord(tableName: string, recordId: string): Promise<any> {
    try {
      const response = await api.delete(`/data/ifs-articles/${tableName}/record/${recordId}`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la suppression de l'enregistrement ${recordId} de la table ${tableName}:`, error);
      throw error;
    }
  }
}

export default new IfsArticlesService(); 