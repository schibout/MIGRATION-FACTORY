import api from './api';

// Catalogue de specs IFS (public.ifs_field_catalog) — cf. docs/catalogIfs/

export interface IfsCatalogLot {
  lot_id: string;
  nb_entities: number;
  nb_fields: number;
  source_file: string | null;
  loaded_at: string | null;
}

export interface IfsCatalogEntity {
  lot_id?: string;
  entity: string;
  theme?: string;
  nb_fields: number;
  nb_in_scope: number;
  nb_mandatory: number;
  nb_defaults: number;
  nb_enums: number;
  nb_references: number;
  nb_pk: number;
}

export interface IfsEnumPair {
  db: string;
  client: string;
}

export interface IfsCatalogField {
  catalog_id: number;
  lot_id: string;
  entity: string;
  field_name: string;
  field_label_fr: string | null;
  data_type: string | null;
  data_length: number | null;
  sql_type: string | null;
  mandatory: boolean;
  primary_key: boolean;
  insertable: boolean;
  updatable: boolean;
  lov: boolean;
  default_value: string | null;
  reference: string | null;
  enumeration_values: IfsEnumPair[] | null;
  rnd_flags: string | null;
  in_scope: boolean;
  transformation_rules: string | null;
  comments: string | null;
  sort_order: number | null;
  source_file: string | null;
  loaded_at: string | null;
}

export type IfsCatalogRuleType = 'NOT_NULL_ON_LOAD' | 'DEFAULT' | 'ENUM_DB_VALUES' | 'FK_LOGICAL';

export interface IfsCatalogRule {
  entity: string;
  field: string;
  rule: IfsCatalogRuleType;
  value?: string;
  target?: string;
  allowed?: string[];
}

export interface IfsCatalogStats {
  nb_entities: number;
  nb_fields: number;
  nb_in_scope: number;
  nb_mandatory: number;
  nb_defaults: number;
  nb_references: number;
  nb_enums: number;
  nb_transformations: number;
  nb_comments: number;
  per_entity: IfsCatalogEntity[];
}

class IfsCatalogService {
  async getLots(): Promise<IfsCatalogLot[]> {
    try {
      const response = await api.get('/data/ifs-catalog/lots');
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des lots du catalogue IFS:', error);
      throw error;
    }
  }

  async getEntities(lot: string): Promise<IfsCatalogEntity[]> {
    try {
      const response = await api.get('/data/ifs-catalog/entities', { params: { lot } });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des entités du catalogue IFS:', error);
      throw error;
    }
  }

  async getEntityFields(entity: string, lot: string): Promise<IfsCatalogField[]> {
    try {
      const response = await api.get(`/data/ifs-catalog/entities/${entity}/fields`, { params: { lot } });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la récupération des champs de ${entity}:`, error);
      throw error;
    }
  }

  // Recherche transverse d'un champ dans toutes les entités du lot
  async searchFields(lot: string, q: string): Promise<IfsCatalogField[]> {
    try {
      const response = await api.get('/data/ifs-catalog/fields/search', { params: { lot, q } });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la recherche de champs du catalogue IFS:', error);
      throw error;
    }
  }

  // Domaine métier (thème) choisi manuellement pour une entité
  async updateEntityTheme(entity: string, lot: string, theme: string): Promise<{ lot_id: string; entity: string; theme: string }> {
    try {
      const response = await api.put(`/data/ifs-catalog/entities/${entity}/theme`, { theme, lot }, { params: { lot } });
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour du domaine de ${entity}:`, error);
      throw error;
    }
  }

  // Métadonnées de curation modifiables (mapping, libellés, defaults, flags...)
  async updateField(catalogId: number, patch: Partial<IfsCatalogField>): Promise<IfsCatalogField> {
    try {
      const response = await api.patch(`/data/ifs-catalog/fields/${catalogId}`, patch);
      return response.data;
    } catch (error) {
      console.error(`Erreur lors de la mise à jour du champ ${catalogId}:`, error);
      throw error;
    }
  }

  async getRules(lot: string, entity?: string): Promise<IfsCatalogRule[]> {
    try {
      const params: Record<string, string> = { lot };
      if (entity) params.entity = entity;
      const response = await api.get('/data/ifs-catalog/rules', { params });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des règles du catalogue IFS:', error);
      throw error;
    }
  }

  async getStats(lot: string): Promise<IfsCatalogStats> {
    try {
      const response = await api.get('/data/ifs-catalog/stats', { params: { lot } });
      return response.data;
    } catch (error) {
      console.error('Erreur lors de la récupération des statistiques du catalogue IFS:', error);
      throw error;
    }
  }
}

export default new IfsCatalogService();
