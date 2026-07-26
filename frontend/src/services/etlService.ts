import api from './api';

// Types basés sur la structure réelle de la table
export interface ETLTargetTable {
  id: number;
  table_name: string;
  display_name: string;
  description: string;
  source_schema: string;
  target_schema: string;
  python_module: string;
  execution_order: number;
  dependent_on: string | null;
  is_active: boolean;
  icon_name: string | null;
  last_modified: string;
  created_at: string;
  created_by: string | null;
}

export interface ETLExecutionResult {
  success: boolean;
  message: string;
  details?: any;
  rows_processed?: number;
}

export interface ETLProgressUpdate {
  progress: number;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  status: string;
  all_messages?: Array<{
    time: number;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
  }>;
}

const etlService = {
  // Récupérer toutes les tables cibles ETL
  getTargetTables: async (): Promise<ETLTargetTable[]> => {
    const response = await api.get('/config/etl/target-tables');
    return response.data;
  },
  
  // Exécuter un processus ETL
  executeETL: async (tableId: number): Promise<ETLExecutionResult> => {
    const response = await api.post('/config/etl/execute', { table_id: tableId });
    return response.data;
  },
  
  // Vérifier le statut d'une exécution ETL
  checkETLStatus: async (executionId: string): Promise<ETLProgressUpdate> => {
    const response = await api.get(`/config/etl/status/${executionId}`);
    return response.data;
  }
};

export default etlService; 