/**
 * Etats sauvegardes du module Maintenance : sauvegarde, restauration et
 * rechargement depuis SAP.
 *
 * Les operations longues (restauration, rechargement) sont asynchrones cote
 * serveur : elles renvoient un job dont on suit l'avancement par polling sur
 * `getJob`. Une seule operation maintenance peut tourner a la fois — le backend
 * renvoie 409 sinon (y compris sur les editions de l'arbre pendant l'operation).
 */
import api from './api';

export type SnapshotKind = 'MANUAL' | 'AUTO_PRE_RESTORE' | 'AUTO_PRE_RELOAD';
export type SnapshotStatus = 'CREATING' | 'READY' | 'FAILED';

export interface MaintenanceSnapshot {
  id: number;
  name: string;
  description: string | null;
  kind: SnapshotKind;
  status: SnapshotStatus;
  /** Nombre de lignes copiees par table, ex. { "clean_data.maintenance_object": 96551 } */
  tables: Record<string, number>;
  total_rows: number;
  size_bytes: number | null;
  created_by: string | null;
  created_at: string | null;
  error_message: string | null;
}

export type JobType = 'SNAPSHOT' | 'RESTORE' | 'RELOAD';
export type JobStatus = 'PENDING' | 'RUNNING' | 'DONE' | 'ERROR';
export type ReloadMode = 'merge' | 'reset';

export interface MaintenanceJobStep {
  step: string;
  ts: string;
  detail?: string | null;
}

export interface MaintenanceJob {
  id: number;
  job_type: JobType;
  params: { mode?: ReloadMode; with_extraction?: boolean; snapshot_id?: number };
  status: JobStatus;
  current_step: string | null;
  progress: number;
  steps: MaintenanceJobStep[];
  /** Etat sauvegarde automatiquement avant l'operation (permet de revenir en arriere). */
  snapshot_id: number | null;
  created_by: string | null;
  created_at: string | null;
  started_at: string | null;
  finished_at: string | null;
  error_message: string | null;
}

export interface ReloadOptions {
  /** merge : conserve les modifications de l'UI ; reset : reconstruit tout depuis SAP. */
  mode: ReloadMode;
  /** Relancer l'extraction SAP -> raw_data avant la reconstruction. */
  withExtraction: boolean;
}

const BASE = '/maintenance';

export const listSnapshots = async (): Promise<MaintenanceSnapshot[]> => {
  const { data } = await api.get(`${BASE}/snapshots`);
  return data.data ?? [];
};

export const createSnapshot = async (
  name: string,
  description?: string,
): Promise<MaintenanceSnapshot> => {
  const { data } = await api.post(`${BASE}/snapshots`, { name, description });
  return data.data;
};

export const deleteSnapshot = async (snapshotId: number): Promise<void> => {
  await api.delete(`${BASE}/snapshots/${snapshotId}`);
};

/** Lance la restauration (asynchrone) et renvoie le job a suivre. */
export const restoreSnapshot = async (snapshotId: number): Promise<MaintenanceJob> => {
  const { data } = await api.post(`${BASE}/snapshots/${snapshotId}/restore`);
  return data.data;
};

/** Lance le rechargement depuis SAP (asynchrone) et renvoie le job a suivre. */
export const startReload = async (options: ReloadOptions): Promise<MaintenanceJob> => {
  const { data } = await api.post(`${BASE}/reload`, {
    mode: options.mode,
    with_extraction: options.withExtraction,
  });
  return data.data;
};

export const getJob = async (jobId: number): Promise<MaintenanceJob> => {
  const { data } = await api.get(`${BASE}/jobs/${jobId}`);
  return data.data;
};

export const getActiveJob = async (): Promise<MaintenanceJob | null> => {
  const { data } = await api.get(`${BASE}/jobs/active`);
  return data.data ?? null;
};

export const listJobs = async (limit = 20): Promise<MaintenanceJob[]> => {
  const { data } = await api.get(`${BASE}/jobs`, { params: { limit } });
  return data.data ?? [];
};

/** Message d'erreur exploitable a partir d'une erreur axios de ce service. */
export const errorMessage = (error: unknown, fallback = 'Une erreur est survenue'): string => {
  const response = (error as { response?: { data?: { message?: string; error?: string } } })
    ?.response;
  return response?.data?.message || response?.data?.error || fallback;
};

/** Libelle lisible d'un type d'etat sauvegarde. */
export const snapshotKindLabel = (kind: SnapshotKind): string => {
  switch (kind) {
    case 'AUTO_PRE_RESTORE':
      return 'Automatique (avant restauration)';
    case 'AUTO_PRE_RELOAD':
      return 'Automatique (avant rechargement)';
    default:
      return 'Manuel';
  }
};

export const formatBytes = (bytes: number | null): string => {
  if (!bytes) return '—';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(value >= 10 || unit === 0 ? 0 : 1)} ${units[unit]}`;
};
