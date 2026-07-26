import api from './api';

// =====================================================
// Types
// =====================================================
export interface AiResult {
  statut: 'succes' | 'rejete' | 'erreur' | 'occupe' | 'indisponible';
  id_log?: number | null;
  sql?: string;
  explication?: string;
  colonnes?: string[];
  lignes?: Record<string, any>[];
  duree_ms?: number;
  tronque?: boolean;
  raison?: string;
  conversation_id?: number | null;
  source?: string;
  cache_similarity?: number;
}

export interface AiConversation {
  id: number;
  titre: string | null;
  date_creation: string;
  date_maj: string;
  nb_questions: number;
}

export interface AiMessage {
  id: number;
  role: 'user' | 'assistant';
  contenu: string | null;
  statut: string | null;
  sql_genere: string | null;
  nb_lignes: number | null;
  tronque: boolean | null;
  duree_ms: number | null;
  id_log: number | null;
  date_creation: string;
}

export interface AiConversationDetail {
  id: number;
  titre: string | null;
  date_creation: string;
  messages: AiMessage[];
}

export interface AiHealth {
  available: boolean;
  model: string;
  model_present: boolean;
  models: string[];
  error?: string | null;
  provider?: 'ollama' | 'openai';
}

export interface AiHistoryItem {
  id: number;
  utilisateur: string | null;
  question: string | null;
  sql_genere: string | null;
  statut: string;
  raison_rejet: string | null;
  template_id: string | null;
  duree_ms: number | null;
  nb_lignes: number | null;
  date_creation: string;
  feedback?: 'up' | 'down' | null;
}

export interface AiHistoryResponse {
  total: number;
  page: number;
  page_size: number;
  items: AiHistoryItem[];
}

// Accusé de réception d'une question : le traitement se fait en arrière-plan.
export interface AiJobSubmit {
  statut: string; // 'en_attente'
  job_id: number;
  conversation_id?: number | null;
}

// État d'un job IA (polling). `resultat` est rempli quand statut === 'termine'.
export interface AiJob {
  id: number;
  statut: 'en_attente' | 'en_cours' | 'termine' | 'erreur';
  resultat?: AiResult | null;
  conversation_id?: number | null;
  erreur?: string | null;
  date_creation?: string;
  date_debut?: string | null;
  date_fin?: string | null;
}

// Job actif (en attente / en cours) — sert à la reprise après rechargement.
export interface AiActiveJob {
  id: number;
  question: string;
  statut: string;
  conversation_id: number | null;
  date_creation: string;
}

// =====================================================
// Appels API
// =====================================================
const aiService = {
  /**
   * Soumet une question en langage naturel. Le traitement (génération SQL via le
   * modèle local) est effectué en ARRIÈRE-PLAN : la requête retourne aussitôt un
   * `job_id`. Suivre l'avancement avec `getJob(job_id)`. `conversationId`
   * rattache la question à une conversation existante (null = nouvelle).
   */
  async submitAsk(
    question: string,
    conversationId?: number | null,
  ): Promise<AiJobSubmit> {
    try {
      const res = await api.post('/ai/ask', {
        question,
        conversation_id: conversationId ?? null,
      });
      return res.data as AiJobSubmit;
    } catch (err: any) {
      if (err.response?.data) return err.response.data as AiJobSubmit;
      throw err;
    }
  },

  /** Récupère l'état d'un job (polling). */
  async getJob(jobId: number): Promise<AiJob> {
    const res = await api.get(`/ai/jobs/${jobId}`);
    return res.data as AiJob;
  },

  /** Liste les jobs actifs de l'utilisateur (reprise du suivi au chargement). */
  async listActiveJobs(): Promise<AiActiveJob[]> {
    const res = await api.get('/ai/jobs', { params: { actifs: true } });
    return (res.data?.jobs ?? []) as AiActiveJob[];
  },

  /** Liste les conversations de l'utilisateur (plus récentes d'abord). */
  async listConversations(): Promise<AiConversation[]> {
    const res = await api.get('/ai/conversations');
    return (res.data?.conversations ?? []) as AiConversation[];
  },

  /** Récupère une conversation et ses messages (pour la rouvrir). */
  async getConversation(id: number): Promise<AiConversationDetail> {
    const res = await api.get(`/ai/conversations/${id}`);
    return res.data as AiConversationDetail;
  },

  /** Supprime une conversation et ses messages. */
  async deleteConversation(id: number): Promise<void> {
    await api.delete(`/ai/conversations/${id}`);
  },

  /** Ré-exécute le SQL d'un message (via id_log) pour réafficher ses résultats. */
  async rerun(idLog: number): Promise<AiResult> {
    try {
      const res = await api.post('/ai/rerun', { id_log: idLog });
      return res.data as AiResult;
    } catch (err: any) {
      if (err.response?.data) return err.response.data as AiResult;
      throw err;
    }
  },

  /**
   * Enregistre le vote utilisateur sur une réponse ('up' | 'down' | 'none' pour retirer).
   * Best-effort : un échec ne doit pas perturber l'UI.
   */
  async feedback(idLog: number, vote: 'up' | 'down' | 'none'): Promise<void> {
    try {
      await api.post('/ai/feedback', { id_log: idLog, vote });
    } catch (err) {
      console.error('Feedback IA échoué', err);
    }
  },

  /**
   * Exécute un SQL édité manuellement (validé par sql_guard, exécuté en lecture
   * seule, journalisé dans l'historique). Renvoie le résultat ou le motif d'échec.
   */
  async runSql(sql: string, question?: string): Promise<AiResult> {
    try {
      const res = await api.post('/ai/run-sql', { sql, question });
      return res.data as AiResult;
    } catch (err: any) {
      if (err.response?.data) return err.response.data as AiResult;
      throw err;
    }
  },

  /** Historique paginé des questions. */
  async getHistory(page = 1, parUtilisateur = false): Promise<AiHistoryResponse> {
    const res = await api.get('/ai/history', {
      params: { page, par_utilisateur: parUtilisateur },
    });
    return res.data as AiHistoryResponse;
  },

  /** Statut du service Ollama. */
  async getHealth(): Promise<AiHealth> {
    try {
      const res = await api.get('/ai/health');
      return res.data as AiHealth;
    } catch (err: any) {
      if (err.response?.data) return err.response.data as AiHealth;
      return { available: false, model: '', model_present: false, models: [], error: 'injoignable' };
    }
  },

  /**
   * Télécharge le résultat d'une requête au format choisi ('xlsx' ou 'csv').
   * Le SQL d'origine est ré-exécuté côté serveur (LIMIT élargi).
   */
  async exportResult(idLog: number, format: 'xlsx' | 'csv' = 'xlsx'): Promise<void> {
    const res = await api.post(
      '/ai/export',
      { id_log: idLog, format },
      { responseType: 'blob' },
    );
    const url = window.URL.createObjectURL(new Blob([res.data]));
    const link = document.createElement('a');
    link.href = url;
    const ts = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '');
    link.setAttribute('download', `assistant_ia_export_${ts}.${format}`);
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.URL.revokeObjectURL(url);
  },
};

export default aiService;
