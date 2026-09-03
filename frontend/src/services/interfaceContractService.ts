import api from './api';

// ---------------------------------------------------------------------------
// Types (miroir de public.v_interface_contract / v_interface_contract_summary)
// ---------------------------------------------------------------------------
export type ContractStatut = 'A_VALIDER' | 'VALIDE' | 'A_CORRIGER' | 'NON_APPLICABLE';
export type ContractRowType = 'COLUMN' | 'CONFIG_SUMMARY' | 'NOTE';

export interface ContractTableSummary {
  contract_table_id: number;
  module: string;
  schema_cible: string;
  table_cible: string;
  libelle: string;
  description: string | null;
  source_procedure: string | null;
  ordre: number;
  owner_metier: string | null;
  date_limite: string | null;
  signe_par: string | null;
  signe_le: string | null;
  nb_lignes: number;
  nb_valide: number;
  nb_a_corriger: number;
  nb_a_valider: number;
  nb_non_applicable: number;
  nb_obsolete: number;
  pct_valide: number | null;
}

export interface ContractColumn {
  contract_column_id: number;
  contract_table_id: number;
  section: string | null;
  target_column: string;
  field_label: string | null;
  systeme_source: string | null;
  source_schema: string | null;
  source_table: string | null;
  source_column: string | null;
  source_expression: string | null;
  transformation_rule: string | null;
  condition_application: string | null;
  exemple_valeur: string | null;
  row_type: ContractRowType;
  default_value_column: string | null;
  default_value_variante: string | null;
  sort_order: number;
  type_longueur: string | null;
  definition_updated_at: string | null;
  statut: ContractStatut;
  remarque_metier: string | null;
  validated_by: string | null;
  validated_at: string | null;
  validation_obsolete: boolean;
  nb_default_values: number | null;
  nb_commentaires: number;
}

export interface ContractEvent {
  id: number;
  contract_column_id: number;
  event_type: 'STATUT' | 'COMMENTAIRE' | 'DEFINITION' | 'IMPORT_EXCEL';
  ancien_statut: string | null;
  nouveau_statut: string | null;
  commentaire: string | null;
  auteur: string;
  created_at: string;
}

export interface ContractMeta {
  modules: string[];
  statuts: ContractStatut[];
  row_types: ContractRowType[];
  can_validate: boolean;
  can_manage: boolean;
}

export interface ContractCoverage {
  table_existe: boolean;
  non_documentees: { column_name: string; type: string; is_nullable: string }[];
  obsoletes: string[];
  nb_colonnes_reelles: number;
  nb_colonnes_documentees: number;
}

export interface ContractSampleSet {
  schema: string;
  table: string;
  column: string;
  values: string[];
  masked: boolean;
}

export interface ContractDefaultValue {
  colonne: string;
  variante: string;
  type_valeur: string;
  valeur: string | null;
  description: string | null;
  is_active: boolean;
}

export interface ContractSample {
  source: ContractSampleSet | null;
  targets: ContractSampleSet[];
  default_values: ContractDefaultValue[];
  limit: number;
  can_unmask: boolean;
}

export interface ContractColumnFilters {
  statut?: string;
  section?: string;
  row_type?: string;
  obsolete?: string;
  search?: string;
}

const BASE = '/interface-contracts';

const interfaceContractService = {
  meta: async (): Promise<ContractMeta> => (await api.get(`${BASE}/meta`)).data,

  listTables: async (module?: string): Promise<ContractTableSummary[]> => {
    const response = await api.get(`${BASE}/tables`, {
      params: module ? { module } : undefined,
    });
    return response.data.tables;
  },

  getColumns: async (
    tableId: number,
    filters: ContractColumnFilters = {},
  ): Promise<{ table: ContractTableSummary; columns: ContractColumn[] }> => {
    const params = Object.fromEntries(
      Object.entries(filters).filter(([, v]) => v !== undefined && v !== ''),
    );
    return (await api.get(`${BASE}/tables/${tableId}/columns`, { params })).data;
  },

  getCoverage: async (tableId: number): Promise<ContractCoverage> =>
    (await api.get(`${BASE}/tables/${tableId}/coverage`)).data,

  getSample: async (columnId: number, unmask = false): Promise<ContractSample> =>
    (await api.get(`${BASE}/columns/${columnId}/sample`, {
      params: unmask ? { unmask: 'true' } : undefined,
    })).data,

  getEvents: async (columnId: number): Promise<ContractEvent[]> =>
    (await api.get(`${BASE}/columns/${columnId}/events`)).data.events,

  setValidation: async (
    columnId: number,
    statut: ContractStatut,
    remarque?: string | null,
  ) =>
    (await api.put(`${BASE}/columns/${columnId}/validation`, {
      statut,
      remarque_metier: remarque ?? null,
    })).data,

  addComment: async (columnId: number, commentaire: string): Promise<ContractEvent> =>
    (await api.post(`${BASE}/columns/${columnId}/comments`, { commentaire })).data,

  sign: async (tableId: number, sign: boolean): Promise<ContractTableSummary> =>
    (await api.put(`${BASE}/tables/${tableId}/sign`, { sign })).data,

  setPilotage: async (
    tableId: number,
    payload: { owner_metier?: string | null; date_limite?: string | null },
  ) => (await api.put(`${BASE}/tables/${tableId}/pilotage`, payload)).data,

  updateColumn: async (columnId: number, payload: Partial<ContractColumn>) =>
    (await api.put(`${BASE}/columns/${columnId}`, payload)).data,

  // Le classeur est regenere depuis l'etat courant de la base : on recupere un
  // blob et on declenche le telechargement cote navigateur.
  exportWorkbook: async (module?: string, tableId?: number): Promise<void> => {
    const response = await api.get(`${BASE}/export`, {
      params: { ...(module ? { module } : {}), ...(tableId ? { table_id: tableId } : {}) },
      responseType: 'blob',
    });
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const lien = document.createElement('a');
    lien.href = url;
    lien.download = `contrat_interface_${module || 'tous_modules'}.xlsx`;
    document.body.appendChild(lien);
    lien.click();
    lien.remove();
    window.URL.revokeObjectURL(url);
  },

  importWorkbook: async (
    fichier: File,
    module: string,
    relecteur?: string,
  ): Promise<{ reprises: number; ignorees: number; tables_introuvables: string[] }> => {
    const donnees = new FormData();
    donnees.append('file', fichier);
    donnees.append('module', module);
    if (relecteur) donnees.append('relecteur', relecteur);
    const response = await api.post(`${BASE}/import`, donnees, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },
};

export default interfaceContractService;
