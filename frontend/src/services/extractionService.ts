import api from './api';

// Types pour les données d'extraction
export interface ExtractionOptions {
  batchSize?: number;
  limit?: number;
  mode?: 'standard' | 'debug' | 'complet';
  workers?: number;
  pageSize?: number;
  clean?: boolean;
}

export interface ExtractionRequest {
  tables: string[];
  options: ExtractionOptions;
}

export interface ExtractionStatus {
  id: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  tables: string[];
  startedAt: string;
  completedAt?: string;
  error?: string;
}

export interface ExtractionHistory {
  id: string;
  tables: string[];
  status: string;
  startedAt: string;
  completedAt?: string;
  rowsExtracted?: number;
  user: string;
  userId?: string;
  userName?: string;
  userEmail?: string;
  userRole?: string;
}

export interface ExtractionLog {
  timestamp: string;
  level: string;
  message: string;
}

export interface IfloNode {
  id: string;
  label: string;
  description: string;
  parent: string | null;
  children: IfloNode[];
}

// Catalogue SAP : tables transparentes non encore cataloguées
export interface AvailableSapTable {
  table_sap: string;
  description: string;
  domaine_applicatif: string;
  modifie_par: string;
  date_modification: string;
}

export interface AvailableTablesResult {
  total: number;
  limit: number;
  offset: number;
  results: AvailableSapTable[];
}

export interface AvailableTablesParams {
  search?: string;
  domaine?: string;
  limit?: number;
  offset?: number;
}

// Extraction des métadonnées SAP (structure + relations + création raw_data)
export interface MetadataExtractResult {
  metadata_job_id: string;
  status: string;
  tables: string[];
  add_to_config: boolean;
}

export type MetadataJobStatus =
  | 'pending'
  | 'running'
  | 'completed'
  | 'completed_with_errors'
  | 'failed'
  | 'cancelled';

export interface MetadataTableDetail {
  name: string;
  status: 'pending' | 'running' | 'completed' | 'error';
  fields_count?: number;
  added_to_config?: boolean;
  error?: string;
}

export interface MetadataJob {
  id: string;
  status: MetadataJobStatus;
  progress: number;
  tables: string[];
  addToConfig: boolean;
  tablesDone: number;
  errors: number;
  tablesDetails: MetadataTableDetail[];
  startedAt?: string;
  completedAt?: string;
  duration?: number;
  error?: string | null;
}

// Service d'extraction
const extractionService = {
  getAvailableTables: async (): Promise<{ name: string; description: string; tableClass?: string; clientDependent?: boolean; availableForMapping?: boolean }[]> => {
    try {
      const response = await api.get('/extraction/tables');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des tables disponibles:', error);
      throw error;
    }
  },

  // Démarrer une nouvelle extraction
  startExtraction: async (request: ExtractionRequest): Promise<{ extraction_id: string }> => {
    try {
      const response = await api.post('/extraction/start', request);
      return response.data;
    } catch (error) {
      console.error('Erreur lors du démarrage de l\'extraction:', error);
      throw error;
    }
  },

  // Obtenir le statut d'une extraction
  getExtractionStatus: async (extractionId: string): Promise<ExtractionStatus> => {
    try {
      const response = await api.get(`/extraction/status/${extractionId}`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération du statut de l'extraction ${extractionId}:`, error);
      throw error;
    }
  },

  // Arrêter une extraction en cours
  stopExtraction: async (extractionId: string, reason?: string): Promise<void> => {
    try {
      await api.post(`/extraction/stop/${extractionId}`, { reason });
    } catch (error) {
      console.error(`Erreur lors de l'arrêt de l'extraction ${extractionId}:`, error);
      throw error;
    }
  },

  // Obtenir les logs d'une extraction
  getExtractionLogs: async (extractionId: string, limit: number = 100): Promise<ExtractionLog[]> => {
    try {
      const response = await api.get(`/extraction/logs/${extractionId}`, {
        params: { limit }
      });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des logs de l'extraction ${extractionId}:`, error);
      throw error;
    }
  },

  // Rechercher des tables SAP disponibles (dictionnaire SAP, recherche serveur)
  searchAvailableTables: async (params: AvailableTablesParams = {}): Promise<AvailableTablesResult> => {
    try {
      const response = await api.get('/extraction/tables/available', { params });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la recherche des tables SAP disponibles:', error);
      throw error;
    }
  },

  // Lancer l'extraction des métadonnées SAP (structure + relations + création raw_data)
  extractMetadata: async (
    tables: string[],
    opts: { addToConfig?: boolean; batchSize?: number; force?: boolean; findRelations?: boolean } = {},
  ): Promise<MetadataExtractResult> => {
    try {
      const response = await api.post('/extraction/metadata/extract', {
        tables,
        add_to_config: opts.addToConfig ?? true,
        batch_size: opts.batchSize ?? 50,
        force: opts.force ?? false,
        find_relations: opts.findRelations ?? true,
      });
      return response.data;
    } catch (error) {
      console.error('Erreur lors du lancement de l\'extraction des métadonnées SAP:', error);
      throw error;
    }
  },

  // Obtenir le statut d'un job d'extraction de métadonnées
  getMetadataStatus: async (jobId: string): Promise<MetadataJob> => {
    try {
      const response = await api.get(`/extraction/metadata/status/${jobId}`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération du statut métadonnées ${jobId}:`, error);
      throw error;
    }
  },

  // Liste des jobs de métadonnées
  getMetadataJobs: async (limit = 30): Promise<MetadataJob[]> => {
    try {
      const response = await api.get('/extraction/metadata/jobs', { params: { limit } });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des jobs métadonnées:', error);
      throw error;
    }
  },

  // Logs d'un job de métadonnées
  getMetadataLogs: async (jobId: string, limit = 200): Promise<ExtractionLog[]> => {
    try {
      const response = await api.get(`/extraction/metadata/jobs/${jobId}/logs`, { params: { limit } });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des logs métadonnées ${jobId}:`, error);
      throw error;
    }
  },

  // Annuler un job de métadonnées
  cancelMetadataJob: async (jobId: string): Promise<{ message?: string }> => {
    try {
      const response = await api.post(`/extraction/metadata/jobs/${jobId}/cancel`);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de l'annulation du job métadonnées ${jobId}:`, error);
      throw error;
    }
  },

  // Obtenir la hiérarchie IFLO
  getIfloHierarchy: async (): Promise<IfloNode[]> => {
    try {
      const response = await api.get('/extraction/iflo-hierarchy');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération de la hiérarchie IFLO:', error);
      throw error;
    }
  },

  // Obtenir l'historique des extractions
  getExtractionHistory: async (limit: number = 20): Promise<ExtractionHistory[]> => {
    try {
      const response = await api.get('/extraction/history', {
        params: { limit }
      });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération de l\'historique des extractions:', error);
      throw error;
    }
  }
};

export default extractionService;