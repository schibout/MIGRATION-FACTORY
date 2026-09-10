import api from './api';

export interface IfsDictionaryTable {
  table_id: number;
  owner: string;
  table_name: string;
  tablespace_name: string | null;
  status: string | null;
  num_rows: number | null;
  imported_at: string;
  column_count: number;
  metadata?: Record<string, string>;
}

export interface IfsDictionaryColumn {
  column_name: string;
  column_id: number;
  data_type: string;
  data_length: number | null;
  data_precision: number | null;
  data_scale: number | null;
  nullable: boolean;
  data_default: string | null;
  metadata: Record<string, string>;
}

export interface IfsDictionaryList {
  items: IfsDictionaryTable[];
  total: number;
  owners: string[];
  stats: { tables: number; columns: number; imported_at: string | null };
}

const base = '/data/ifs-dictionary';
export const ifsDictionaryService = {
  async list(params: { q: string; owner: string; page: number; page_size: number }, signal?: AbortSignal) {
    return (await api.get<IfsDictionaryList>(`${base}/tables`, { params, signal })).data;
  },
  async detail(id: number, signal?: AbortSignal) {
    return (await api.get<{ table: IfsDictionaryTable; columns: IfsDictionaryColumn[] }>(
      `${base}/tables/${id}`, { signal })).data;
  },
  async importFiles(tables: File | null, columns: File | null) {
    // Chaque fichier est facultatif : on n'envoie que ceux qui sont sélectionnés.
    const data = new FormData();
    if (tables) data.append('tables_file', tables);
    if (columns) data.append('columns_file', columns);
    return (await api.post<{ tables_imported: number; columns_imported: number; message: string }>(
      `${base}/import`, data, { headers: { 'Content-Type': 'multipart/form-data' } })).data;
  },
  async report(id: number, columns: string[], includeOwner: boolean) {
    return (await api.post<{ sql: string; filename: string }>(`${base}/tables/${id}/report`, {
      columns, include_owner: includeOwner,
    })).data;
  },
};
