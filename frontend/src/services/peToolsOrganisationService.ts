import api from './api';

/**
 * Parametrage « code de fichier PE Tools -> organisation de maintenance IFS »
 * (table public.pe_tools_organisation, migration 077).
 *
 * L'organisation est posee sur une ligne AU MOMENT de l'import : modifier une
 * regle n'a d'effet que sur les imports suivants, sauf a lancer le recalcul.
 */
export interface PeToolsOrganisation {
  code_fichier: string;
  org_code: string;
  description: string | null;
  is_active: boolean;
  updated_at: string | null;
  updated_by: string | null;
  /** Lignes deja importees portant ce code (raw_data.pe_tools). */
  lignes_importees: number;
}

/** Code trouve dans les fichiers importes mais sans regle : organisation NULL. */
export interface CodeSansRegle {
  code_fichier: string;
  lignes_importees: number;
}

export interface PeToolsOrganisationListe {
  regles: PeToolsOrganisation[];
  codesSansRegle: CodeSansRegle[];
  lignesSansOrganisation: number;
}

export interface PeToolsOrganisationInput {
  code_fichier: string;
  org_code: string;
  description: string | null;
  is_active: boolean;
}

export interface RecalculResultat {
  success: boolean;
  lignes_modifiees: number;
  lignes_sans_organisation: number;
  message?: string;
  error?: string;
}

/** Limite IFS : clean_data.pm_action.org_code est un varchar(8). */
export const ORG_CODE_MAX = 8;

export const getOrganisations = async (): Promise<PeToolsOrganisationListe> => {
  const resp = await api.get('/maintenance/pe-tools-organisations');
  return {
    regles: (resp.data?.data ?? []) as PeToolsOrganisation[],
    codesSansRegle: (resp.data?.codes_sans_regle ?? []) as CodeSansRegle[],
    lignesSansOrganisation: resp.data?.lignes_sans_organisation ?? 0,
  };
};

export const createOrganisation = async (payload: PeToolsOrganisationInput) => {
  const resp = await api.post('/maintenance/pe-tools-organisations', payload);
  return resp.data;
};

/** `code` = code AVANT modification (le renommage est autorise). */
export const updateOrganisation = async (code: string, payload: PeToolsOrganisationInput) => {
  const resp = await api.put(`/maintenance/pe-tools-organisations/${encodeURIComponent(code)}`, payload);
  return resp.data;
};

export const deleteOrganisation = async (code: string) => {
  const resp = await api.delete(`/maintenance/pe-tools-organisations/${encodeURIComponent(code)}`);
  return resp.data;
};

/** Rejoue public.pe_tools_org_code() sur les lignes deja importees. */
export const recalculerOrganisations = async (): Promise<RecalculResultat> => {
  const resp = await api.post('/maintenance/pe-tools-organisations/recalculer');
  return resp.data as RecalculResultat;
};
