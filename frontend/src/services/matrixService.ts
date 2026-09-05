import api from './api';

// Matrice conditionnelle Site x Famille (migration 066).
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

// Famille proposee en colonne. `source` dit d'ou elle vient : REFERENCE (declaree
// mais pas encore livree), DONNEES (livree mais non declaree, donc a documenter),
// LES_DEUX (le cas nominal).
export interface MatrixFamille {
  code: string;
  libelle: string | null;
  description: string | null;
  source: 'REFERENCE' | 'DONNEES' | 'LES_DEUX';
}

export interface MatrixTableCible {
  table_cible: string;
  libelle: string | null;
  description: string | null;
}

// Libelle metier d'une colonne, lu dans public.ifs_field_catalog.
export interface MatrixColumn {
  colonne: string;
  libelle: string | null;
  type_ifs: string | null;
  obligatoire: boolean | null;
  commentaire: string | null;
}

export interface MatrixMeta {
  sites: string[];
  familles: MatrixFamille[];
  cibles: MatrixCible[];
  tables_cibles: MatrixTableCible[];
  part_type_tables: { target_table: string; libelle: string }[];
}

export interface MatrixResolution {
  valeur_effective: string | null;
  constante: string | null;
  origine: 'MATRICE' | 'CONSTANTE';
  regle: MatrixValue | null;
}

// Le backend peut etre plus ancien que le bundle servi (deploiement partiel :
// frontend rebati, service Flask pas encore redemarre). On normalise donc la
// reponse au lieu de faire confiance a sa forme : sans cela un champ absent
// casse l'ecran entier au premier .map().
const normaliserMeta = (brut: any): MatrixMeta => {
  const cibles: MatrixCible[] = Array.isArray(brut?.cibles) ? brut.cibles : [];

  // Avant la migration 067 l'API renvoyait les familles en simples chaines.
  const familles: MatrixFamille[] = (Array.isArray(brut?.familles) ? brut.familles : []).map(
    (f: any): MatrixFamille =>
      typeof f === 'string'
        ? { code: f, libelle: null, description: null, source: 'DONNEES' }
        : {
            code: f?.code,
            libelle: f?.libelle ?? null,
            description: f?.description ?? null,
            source: f?.source ?? 'DONNEES',
          }
  ).filter((f: MatrixFamille) => !!f.code);

  // Referentiel absent : on retombe sur les tables deduites des colonnes.
  let tables: MatrixTableCible[] = Array.isArray(brut?.tables_cibles) ? brut.tables_cibles : [];
  if (tables.length === 0) {
    tables = Array.from(new Set(cibles.map((c) => c.table_cible)))
      .sort()
      .map((t) => ({ table_cible: t, libelle: null, description: null }));
  }

  return {
    sites: Array.isArray(brut?.sites) ? brut.sites : [],
    familles,
    cibles,
    tables_cibles: tables,
    part_type_tables: Array.isArray(brut?.part_type_tables) ? brut.part_type_tables : [],
  };
};

const matrixService = {
  meta: async (): Promise<MatrixMeta> => {
    const response = await api.get('/config/matrix/meta');
    return normaliserMeta(response.data);
  },

  // Libelles IFS des colonnes d'une table cible.
  columns: async (table_cible: string): Promise<MatrixColumn[]> => {
    const response = await api.get('/config/matrix/columns', { params: { table_cible } });
    return response.data.columns;
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
