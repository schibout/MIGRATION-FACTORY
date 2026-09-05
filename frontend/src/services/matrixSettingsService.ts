import api from './api';

// Referentiels de l'ecran Matrice Site x Famille (migration 067).
// Ces deux listes ne pilotent QUE ce que l'ecran propose : aucune procedure
// ETL ne les lit. Un referentiel vide fait retomber la matrice sur son
// comportement d'origine.

export interface PartFamily {
  id: number;
  code: string;
  libelle: string | null;
  description: string | null;
  ordre: number;
  is_active: boolean;
  updated_at?: string;
  updated_by?: string;
}

export interface MatrixTargetTable {
  id: number;
  table_cible: string;
  libelle: string | null;
  description: string | null;
  ordre: number;
  is_active: boolean;
  updated_at?: string;
  updated_by?: string;
}

export type PartFamilyPayload = Partial<Omit<PartFamily, 'id'>>;
export type TargetTablePayload = Partial<Omit<MatrixTargetTable, 'id'>>;

const matrixSettingsService = {
  // `detectees` = codes famille presents dans le fichier PHL charge, pour
  // signaler ceux qui ne sont pas encore declares.
  listFamilies: async (): Promise<{ part_families: PartFamily[]; detectees: string[] }> => {
    const response = await api.get('/config/matrix/part-families');
    return response.data;
  },

  createFamily: async (payload: PartFamilyPayload): Promise<PartFamily> => {
    const response = await api.post('/config/matrix/part-families', payload);
    return response.data;
  },

  updateFamily: async (id: number, payload: PartFamilyPayload): Promise<PartFamily> => {
    const response = await api.put(`/config/matrix/part-families/${id}`, payload);
    return response.data;
  },

  deleteFamily: async (id: number): Promise<void> => {
    await api.delete(`/config/matrix/part-families/${id}`);
  },

  listTargetTables: async (): Promise<MatrixTargetTable[]> => {
    const response = await api.get('/config/matrix/target-tables');
    return response.data.target_tables;
  },

  createTargetTable: async (payload: TargetTablePayload): Promise<MatrixTargetTable> => {
    const response = await api.post('/config/matrix/target-tables', payload);
    return response.data;
  },

  updateTargetTable: async (id: number, payload: TargetTablePayload): Promise<MatrixTargetTable> => {
    const response = await api.put(`/config/matrix/target-tables/${id}`, payload);
    return response.data;
  },

  deleteTargetTable: async (id: number): Promise<void> => {
    await api.delete(`/config/matrix/target-tables/${id}`);
  },
};

export default matrixSettingsService;
