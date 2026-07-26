import api from './api';

// =====================================================
// Types
// =====================================================
export interface AiConfigDomain {
  id?: number | null;
  position: number;
  domain_id: string;
  keywords: string[];
  tables: string[];
  actif?: boolean;
}

export interface AiConfigPattern {
  intent?: string;
  sql: string;
}

export interface AiConfigPack {
  domain: string;
  keywords: string[];
  synonyms: string[];
  tables: string[];
  joins: string[];
  enums: string[];
  rules: string[];
  docs: string[];
  patterns: AiConfigPattern[];
  nb_cards: number;
}

export interface AiConfigOverview {
  reglages: Record<string, string | number | boolean>;
  compteurs: Record<string, number>;
}

export interface AiConfigExample {
  question: string;
  reponse: string;
}

export interface AiConfigUsage {
  feedback: { up: number; down: number };
  cooccurrences: { src: string; dst: string; poids: number }[];
  erreurs_30j?: { type: string; nb: number }[];
}

export interface AiInspectResult {
  question: string;
  cot: boolean;
  domaines: string[];
  tables: string[];
  schema: string;
  subgraph: string;
  connaissances: string;
  exemples: string;
  prompt: string;
  tokens_estimes: number;
}

// =====================================================
// Service
// =====================================================
const aiConfigService = {
  async overview(): Promise<AiConfigOverview> {
    return (await api.get('/ai-config/overview')).data as AiConfigOverview;
  },
  async domains(): Promise<AiConfigDomain[]> {
    return (await api.get('/ai-config/domains')).data.domains as AiConfigDomain[];
  },
  async packs(): Promise<AiConfigPack[]> {
    return (await api.get('/ai-config/packs')).data.packs as AiConfigPack[];
  },
  async examples(limit = 100): Promise<{ total: number; items: AiConfigExample[] }> {
    return (await api.get('/ai-config/examples', { params: { limit } })).data;
  },
  async usage(): Promise<AiConfigUsage> {
    return (await api.get('/ai-config/usage')).data as AiConfigUsage;
  },
  async inspect(question: string): Promise<AiInspectResult> {
    return (await api.post('/ai-config/inspect', { question })).data as AiInspectResult;
  },

  // ----- Édition -----
  async createDomain(d: { domain_id: string; keywords: string[]; tables: string[]; position?: number }): Promise<void> {
    await api.post('/ai-config/domains', d);
  },
  async updateDomain(id: number, d: { domain_id: string; keywords: string[]; tables: string[]; position?: number; actif?: boolean }): Promise<void> {
    await api.put(`/ai-config/domains/${id}`, d);
  },
  async deleteDomain(id: number): Promise<void> {
    await api.delete(`/ai-config/domains/${id}`);
  },
  async savePack(domain: string, content: Record<string, any>): Promise<void> {
    await api.put(`/ai-config/packs/${encodeURIComponent(domain)}`, content);
  },
  async deletePack(domain: string): Promise<void> {
    await api.delete(`/ai-config/packs/${encodeURIComponent(domain)}`);
  },
  async reindex(): Promise<void> {
    await api.post('/ai-config/reindex', {});
  },

  // ----- Promotion d'une requête corrigée vers la config -----
  async detect(question: string): Promise<string[]> {
    return (await api.get('/ai-config/detect', { params: { question } })).data.domaines as string[];
  },
  async promote(payload: {
    question: string; sql: string; domain: string; intent?: string; ajouter_mapping: boolean;
  }): Promise<{ statut: string; pattern_ajoute?: boolean; tables_ajoutees?: string[]; raison?: string }> {
    try {
      return (await api.post('/ai-config/promote', payload)).data;
    } catch (err: any) {
      if (err.response?.data) return err.response.data;
      throw err;
    }
  },
};

export default aiConfigService;
