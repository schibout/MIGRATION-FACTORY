import { FacetValue } from '../components/data/facettes';
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

export interface IfsView {
  view_id: number;
  owner: string;
  view_name: string;
  nature: string;
  taille: string | null;
  read_only: boolean | null;
  text_length: number | null;
  imported_at: string;
  etiquettes: string[];
  lu_name: string | null;
  prompt: string | null;
  module: string | null;
  nb_colonnes_fnd: number;
  base_table?: string | null;
  fnd_attributes?: Record<string, string> | null;
  view_text?: string | null;
  metadata?: Record<string, string>;
}

export interface IfsViewDetail {
  view: IfsView;
  columns: string[];
  columns_source: 'fnd' | 'sql';
  column_origins: Record<string, string | null>;
  tables: { name: string; table_id: number | null }[];
  natures: Record<string, string>;
  etiquettes: Record<string, string>;
}

export interface IfsViewFacets {
  facettes: Record<'nature' | 'owner' | 'lecture' | 'taille' | 'module', { titre: string; valeurs: FacetValue[] }>;
  total: number;
  catalogue: { views: number; imported_at: string | null; comments: number; columns: number };
  etiquettes: { cle: string; libelle: string; nb: number }[];
}

export const ifsViewService = {
  async list(params: Record<string, string | number>, signal?: AbortSignal) {
    return (await api.get<{ items: IfsView[]; total: number }>(`${base}/views`, { params, signal })).data;
  },
  async facets(params: Record<string, string>, signal?: AbortSignal) {
    return (await api.get<IfsViewFacets>(`${base}/views/facettes`, { params, signal })).data;
  },
  async detail(id: number, signal?: AbortSignal) {
    return (await api.get<IfsViewDetail>(`${base}/views/${id}`, { signal })).data;
  },
  async report(id: number, columns: string[], includeOwner: boolean) {
    return (await api.post<{ sql: string; filename: string }>(`${base}/views/${id}/report`, {
      columns, include_owner: includeOwner,
    })).data;
  },
  exportUrl: `${base}/views/export.xlsx`,
  async importFiles(views: File | null, comments: File | null, columns: File | null) {
    // Trois fichiers facultatifs : ALL_VIEWS, FND_TAB_COMMENTS, FND_TAB_VIEW_COLUMNS
    const data = new FormData();
    if (views) data.append('file', views);
    if (comments) data.append('comments_file', comments);
    if (columns) data.append('columns_file', columns);
    return (await api.post<{ views_imported?: number; comments_imported?: number; columns_imported?: number;
      views_with_columns?: number; message: string }>(
      `${base}/views/import`, data, { headers: { 'Content-Type': 'multipart/form-data' } })).data;
  },
};
