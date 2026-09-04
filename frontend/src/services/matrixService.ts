import api from './api';

// Matrice conditionnelle Site x Famille (migration 052).
// contract / part_family a null = joker : la regle s'applique a toutes les
// valeurs de cet axe. La regle la plus specifique gagne
// (site + famille > site > famille > joker).

export interface MatrixValue {
  id: number;
  module: string;
  table_cible: string;
  colonne: string;
  contract: string | null;
  part_family: string | null;
  variante: string;
  type_valeur: 'CONSTANTE' | 'NULL';
  valeur: string | null;
  description?: string | null;
  is_active: boolean;
  specificite: number;
  updated_at?: string;
  updated_by?: string;
}

export interface PartTypeRule {
  id: number;
  target_table: string;
  contract: string | null;
  part_family: string | null;
  should_create: boolean;
  description?: string | null;
  is_active: boolean;
  specificite: number;
  updated_at?: string;
  updated_by?: string;
}

export interface MatrixCible {
  module: string;
  table_cible: string;
  colonne: string;
  variante: string;
}

export interface MatrixMeta {
  sites: string[];
  familles: string[];
  cibles: MatrixCible[];
  part_type_tables: { target_table: string; libelle: string }[];
}

export interface MatrixResolution {
  valeur_effective: string | null;
  constante: string | null;
  origine: 'MATRICE' | 'CONSTANTE';
  regle: MatrixValue | null;
}

const matrixService = {
  meta: async (): Promise<MatrixMeta> => {
    const response = await api.get('/config/matrix/meta');
    return response.data;
  },

  listValues: async (params: {
    table_cible?: string;
    colonne?: string;
    variante?: string;
  }): Promise<MatrixValue[]> => {
    const response = await api.get('/config/matrix/values', { params });
    return response.data.values;
  },

  // Cree la regle, ou met a jour celle qui occupe deja la cellule.
  saveValue: async (payload: {
    table_cible: string;
    colonne: string;
    variante?: string;
    contract: string | null;
    part_family: string | null;
    type_valeur: 'CONSTANTE' | 'NULL';
    valeur: string | null;
    description?: string | null;
    module?: string;
  }): Promise<MatrixValue> => {
    const response = await api.post('/config/matrix/values', payload);
    return response.data;
  },

  updateValue: async (
    id: number,
    payload: Partial<Pick<MatrixValue, 'valeur' | 'type_valeur' | 'description' | 'is_active'>>
  ): Promise<MatrixValue> => {
    const response = await api.put(`/config/matrix/values/${id}`, payload);
    return response.data;
  },

  deleteValue: async (id: number): Promise<void> => {
    await api.delete(`/config/matrix/values/${id}`);
  },

  // Valeur reellement appliquee par l'ETL pour un couple (site, famille).
  resolve: async (params: {
    table_cible: string;
    colonne: string;
    contract?: string | null;
    part_family?: string | null;
    variante?: string;
  }): Promise<MatrixResolution> => {
    const response = await api.get('/config/matrix/resolve', { params });
    return response.data;
  },

  listPartTypes: async (target_table?: string): Promise<PartTypeRule[]> => {
    const response = await api.get('/config/matrix/part-types', {
      params: target_table ? { target_table } : undefined,
    });
    return response.data.part_types;
  },

  savePartType: async (payload: {
    target_table: string;
    contract: string | null;
    part_family: string | null;
    should_create: boolean;
    description?: string | null;
  }): Promise<PartTypeRule> => {
    const response = await api.post('/config/matrix/part-types', payload);
    return response.data;
  },

  deletePartType: async (id: number): Promise<void> => {
    await api.delete(`/config/matrix/part-types/${id}`);
  },
};

export default matrixService;
