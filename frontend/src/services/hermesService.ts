import api from './api';

// =====================================================
// Service Assistant Hermes — chat streaming SSE.
//
// L'instance axios (api.ts) ne sait pas consommer un flux : on utilise fetch +
// ReadableStream. URL relative '/api/v1' (même origine que l'axios baseURL) et
// token JWT lu comme dans api.ts (localStorage['token']). La clé API Hermes
// reste côté backend (proxy /hermes/chat) : rien de sensible ne transite ici.
// =====================================================

const API_BASE = '/api/v1';

export interface HermesApiMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface HermesConversationSummary {
  id: number;
  titre: string | null;
  date_maj: string;
  nb_messages: number;
}

export interface HermesConversationDetail {
  id: number;
  titre: string | null;
  instructions: string;
  messages: HermesApiMessage[];
}

// ----- Historique (persistance DB via le backend, axios classique) -----
export async function listConversations(): Promise<HermesConversationSummary[]> {
  const res = await api.get('/hermes/conversations');
  return (res.data?.conversations ?? []) as HermesConversationSummary[];
}

export async function getConversation(id: number): Promise<HermesConversationDetail> {
  const res = await api.get(`/hermes/conversations/${id}`);
  return res.data as HermesConversationDetail;
}

export async function saveConversation(payload: {
  conversation_id: number | null;
  messages: HermesApiMessage[];
}): Promise<number> {
  const res = await api.post('/hermes/conversations', payload);
  return res.data.id as number;
}

export async function deleteConversation(id: number): Promise<void> {
  await api.delete(`/hermes/conversations/${id}`);
}

// ----- Jobs planifiés (cron) — proxy backend vers le serveur Hermes -----
export interface HermesJob {
  id?: string;
  job_id?: string;
  name?: string;
  // schedule/état peuvent être des objets selon l'instance -> lus via helpers UI.
  schedule?: unknown;
  prompt?: string;
  state?: string;
  enabled?: boolean;
  paused_at?: string | null;
  last_run_at?: string | null;
  last_status?: string | null;
  last_error?: string | null;
  last_delivery_error?: string | null;
  next_run_at?: string | null;
  deliver?: string;
  // Le shape exact varie selon l'instance Hermes -> champs libres tolérés.
  [k: string]: unknown;
}

export interface HermesJobInput {
  name?: string;
  schedule: string;
  prompt: string;
  deliver?: string;
}

/** Identifiant d'un job, quel que soit le champ renvoyé par Hermes. */
export const jobId = (j: HermesJob): string => String(j.job_id ?? j.id ?? '');

export async function listJobs(): Promise<HermesJob[]> {
  const d = (await api.get('/hermes/jobs')).data;
  return (Array.isArray(d) ? d : d?.jobs ?? []) as HermesJob[];
}

export async function createJob(input: HermesJobInput): Promise<HermesJob> {
  return (await api.post('/hermes/jobs', input)).data as HermesJob;
}

export async function updateJob(id: string, patch: Partial<HermesJobInput>): Promise<HermesJob> {
  return (await api.patch(`/hermes/jobs/${id}`, patch)).data as HermesJob;
}

export async function deleteJob(id: string): Promise<void> {
  await api.delete(`/hermes/jobs/${id}`);
}

export async function jobAction(id: string, action: 'pause' | 'resume' | 'run'): Promise<void> {
  await api.post(`/hermes/jobs/${id}/${action}`);
}

// ----- Exécution à la demande + résultats stockés -----
export interface HermesJobResult {
  id: number | null;
  job_id: string;
  job_name: string;
  resultat: string;
  statut: string;
  date_creation: string | null;
}

/** Exécute le prompt du job via le chat (peut prendre plusieurs dizaines de
 * secondes selon l'agent) et renvoie le résultat texte. */
export async function executeJob(id: string): Promise<HermesJobResult> {
  return (await api.post(`/hermes/jobs/${id}/execute`)).data as HermesJobResult;
}

export async function listJobResults(): Promise<HermesJobResult[]> {
  return ((await api.get('/hermes/job-results')).data?.results ?? []) as HermesJobResult[];
}

export async function deleteJobResult(id: number): Promise<void> {
  await api.delete(`/hermes/job-results/${id}`);
}

// ----- État de l'agent (capabilities + santé) -----
export interface AgentStatus {
  reachable: boolean;
  capabilities: Record<string, unknown> | null;
  health: Record<string, unknown> | null;
}

export async function getAgentStatus(): Promise<AgentStatus> {
  return (await api.get('/hermes/agent-status')).data as AgentStatus;
}

export interface HermesStreamHandlers {
  /** Fragment de texte assistant (delta d'un chunk chat.completion.chunk). */
  onDelta: (text: string) => void;
  /** Event custom hermes.tool.progress : Hermes commence à utiliser un outil. */
  onToolProgress: (label: string) => void;
  /** Fin de flux ([DONE] ou fermeture propre). Appelé exactement une fois. */
  onDone: () => void;
  /** Erreur HTTP du proxy, coupure mi-stream ou session expirée. */
  onError: (message: string) => void;
}

/**
 * Le fetch manuel contourne l'intercepteur axios (refresh silencieux sur 401).
 * On le déclenche indirectement : un GET léger sur /auth/me via l'instance api
 * force le refresh existant (qui met à jour localStorage['token']).
 * Renvoie true si un token valide est disponible après coup.
 */
async function tryRefreshViaAxios(): Promise<boolean> {
  try {
    await api.get('/auth/me');
    return !!localStorage.getItem('token');
  } catch {
    return false;
  }
}

/**
 * Envoie l'historique à POST /api/v1/hermes/chat et consomme le flux SSE.
 * Résout quand le flux est terminé (onDone/onError déjà déclenchés).
 */
export async function streamChat(
  messages: HermesApiMessage[],
  handlers: HermesStreamHandlers,
  signal?: AbortSignal,
): Promise<void> {
  const doFetch = (): Promise<Response> =>
    fetch(`${API_BASE}/hermes/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${localStorage.getItem('token') ?? ''}`,
      },
      body: JSON.stringify({
        messages,
        stream: true,
      }),
      signal,
    });

  let res: Response;
  try {
    res = await doFetch();
    if (res.status === 401 && (await tryRefreshViaAxios())) {
      res = await doFetch(); // un seul retry avec le token rafraîchi
    }
  } catch (e) {
    handlers.onError(e instanceof Error ? e.message : 'Erreur réseau.');
    return;
  }

  if (res.status === 401) {
    handlers.onError('Session expirée, veuillez vous reconnecter.');
    return;
  }
  if (!res.ok) {
    // Le proxy renvoie des erreurs JSON explicites (400/500/502/504).
    let message = `Erreur HTTP ${res.status}`;
    try {
      const body = (await res.json()) as { error?: string };
      if (body.error) message = body.error;
    } catch {
      /* corps non-JSON : message générique conservé */
    }
    handlers.onError(message);
    return;
  }
  if (!res.body) {
    handlers.onError('Streaming non supporté par ce navigateur.');
    return;
  }

  // ----- Parseur SSE : bufferise les lignes incomplètes entre chunks réseau -----
  const reader = res.body.getReader();
  const decoder = new TextDecoder('utf-8');
  let buffer = '';
  let eventName = '';
  let dataLines: string[] = [];
  let doneReceived = false;

  const dispatchEvent = (): void => {
    if (dataLines.length === 0) {
      eventName = '';
      return;
    }
    const data = dataLines.join('\n');
    const evt = eventName;
    dataLines = [];
    eventName = '';

    if (data === '[DONE]') {
      doneReceived = true;
      handlers.onDone();
      return;
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(data) as Record<string, unknown>;
    } catch {
      return; // fragment non-JSON (heartbeat exotique) : ignoré
    }

    // Event outil : forme "event: hermes.tool.progress" OU objet typé dans data.
    if (evt === 'hermes.tool.progress' || parsed.object === 'hermes.tool.progress') {
      const label =
        typeof parsed.message === 'string' ? parsed.message
        : typeof parsed.tool === 'string' ? parsed.tool
        : 'outil';
      handlers.onToolProgress(label);
      return;
    }
    // Erreur relayée mi-stream par le proxy (coupure Hermes).
    if (typeof parsed.error === 'string') {
      handlers.onError(parsed.error);
      return;
    }
    // Chunk standard chat.completion.chunk.
    const choices = parsed.choices as Array<{ delta?: { content?: string } }> | undefined;
    const delta = choices?.[0]?.delta?.content;
    if (typeof delta === 'string' && delta.length > 0) {
      handlers.onDelta(delta);
    }
  };

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let nl: number;
      while ((nl = buffer.indexOf('\n')) !== -1) {
        let line = buffer.slice(0, nl);
        buffer = buffer.slice(nl + 1);
        if (line.endsWith('\r')) line = line.slice(0, -1);
        if (line === '') {
          dispatchEvent(); // ligne vide = fin d'un event SSE
          continue;
        }
        if (line.startsWith(':')) continue; // commentaire/heartbeat SSE
        if (line.startsWith('event:')) {
          eventName = line.slice(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          dataLines.push(line.slice(5).replace(/^ /, ''));
        }
      }
    }
  } catch (e) {
    if (!(e instanceof DOMException && e.name === 'AbortError')) {
      handlers.onError(e instanceof Error ? e.message : 'Flux interrompu.');
      return;
    }
  }

  dispatchEvent(); // event final éventuel sans ligne vide terminale
  if (!doneReceived) handlers.onDone(); // flux clos sans [DONE] : terminer proprement
}
