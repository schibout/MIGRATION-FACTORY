import api from './api';

// Une valeur de liste. `contract` NULL = valeur commune a tous les sites.
export interface LovValue {
  id: number;
  code: string;
  libelle: string;
  contract: string | null;
  ordre: number | null;
  actif: boolean;
}

/** Champs modifiables depuis l'ecran d'administration. */
export interface LovValueInput {
  code: string;
  libelle: string;
  contract: string | null;
  ordre: number | null;
  actif: boolean;
}

export interface LovType {
  code: string;
  libelle: string;
  ordre: number | null;
  nb_valeurs: number;
}

/**
 * Valeurs actives d'une liste pour un site.
 * GET /api/v1/lov/types/<listCode>/values?contract=<contract>
 */
export const getLovValues = async (
  listCode: string,
  contract?: string,
  includeInactive = false,
): Promise<LovValue[]> => {
  const params: Record<string, string> = {};
  if (contract) params.contract = contract;
  if (includeInactive) params.all = '1';
  const resp = await api.get(`/lov/types/${encodeURIComponent(listCode)}/values`, {
    params: Object.keys(params).length ? params : undefined,
  });
  return resp.data?.success ? (resp.data.data as LovValue[]) : [];
};

/** Ajoute une valeur a une liste. */
export const createLovValue = async (listCode: string, payload: LovValueInput) => {
  const resp = await api.post(`/lov/types/${encodeURIComponent(listCode)}/values`, payload);
  return resp.data;
};

/** Modifie une valeur existante (modification partielle acceptee). */
export const updateLovValue = async (valueId: number, payload: Partial<LovValueInput>) => {
  const resp = await api.put(`/lov/values/${valueId}`, payload);
  return resp.data;
};

/** Supprime une valeur ; 409 si des postes techniques la portent encore. */
export const deleteLovValue = async (valueId: number) => {
  const resp = await api.delete(`/lov/values/${valueId}`);
  return resp.data;
};

/** Listes de valeurs declarees (ecran d'administration / diagnostic). */
export const getLovTypes = async (): Promise<LovType[]> => {
  const resp = await api.get('/lov/types');
  return resp.data?.success ? (resp.data.data as LovType[]) : [];
};
