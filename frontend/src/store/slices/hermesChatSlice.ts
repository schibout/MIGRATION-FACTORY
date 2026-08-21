import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { AppDispatch, RootState } from '../index';
import {
    getConversation,
    HermesApiMessage,
    HermesConversationDetail,
    saveConversation,
    streamChat,
} from '../../services/hermesService';

// =====================================================
// Slice du chat Assistant Hermes.
//
// Streaming => pas de createAsyncThunk : le thunk manuel sendMessage dispatch
// des actions au fil des deltas SSE. La consigne système est fixée côté backend
// (HERMES_DEFAULT_INSTRUCTIONS) : le chat n'envoie plus d'instructions client.
// =====================================================

/** Fichier joint (texte lu côté client) pour analyse par Hermes. */
export interface ChatAttachment {
  name: string;
  content: string;
  size: number;
}

export interface ChatBubble {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  /** Fichier joint au message user (affiché en carte, injecté dans l'envoi). */
  attachment?: ChatAttachment;
}

// Fenêtre d'historique envoyée à Hermes (API stateless : tout repart à chaque
// tour). On limite les tokens : seuls les N derniers messages partent, et le
// contenu des fichiers joints n'est inclus en entier que dans les derniers
// tours. La persistance en base (saveConversation) reste, elle, intégrale.
const MAX_HISTORY_MESSAGES = 16;
const ATTACHMENT_FRESH_WINDOW = 4;

/**
 * Contenu réellement envoyé à Hermes (et persisté) pour un message : le texte
 * de l'utilisateur, complété du fichier joint entre balises si présent.
 * `omitAttachment` remplace le contenu du fichier par une mention (messages
 * anciens de l'historique : on économise les tokens sans perdre la trace).
 */
const toApiContent = (m: ChatBubble, omitAttachment = false): string => {
  if (!m.attachment) return m.content;
  if (omitAttachment) {
    return `${m.content}\n\n[Fichier joint « ${m.attachment.name} » omis de l'historique — le joindre à nouveau si son contenu est requis]`;
  }
  return `${m.content}\n\n[Fichier joint « ${m.attachment.name} »]\n\`\`\`\n${m.attachment.content}\n\`\`\``;
};

interface HermesChatState {
  messages: ChatBubble[];
  /** id du fil persisté en base (null = pas encore sauvegardé / nouveau). */
  conversationId: number | null;
  isStreaming: boolean;
  /** Libellé « Hermes utilise un outil… » (event hermes.tool.progress), null = caché. */
  toolActivity: string | null;
  error: string | null;
}

const initialState: HermesChatState = {
  messages: [],
  conversationId: null,
  isStreaming: false,
  toolActivity: null,
  error: null,
};

let bubbleCounter = 0;
const nextId = (): string => `${Date.now()}-${bubbleCounter++}`;

const hermesChatSlice = createSlice({
  name: 'hermesChat',
  initialState,
  reducers: {
    userMessageAdded(state, action: PayloadAction<{ content: string; attachment?: ChatAttachment }>) {
      state.messages.push({
        id: nextId(),
        role: 'user',
        content: action.payload.content,
        attachment: action.payload.attachment,
      });
      state.error = null;
    },
    streamStarted(state) {
      // Bulle assistant vide, remplie au fil des deltas.
      state.messages.push({ id: nextId(), role: 'assistant', content: '' });
      state.isStreaming = true;
      state.toolActivity = null;
    },
    deltaReceived(state, action: PayloadAction<string>) {
      const last = state.messages[state.messages.length - 1];
      if (last && last.role === 'assistant') {
        last.content += action.payload;
      }
      state.toolActivity = null; // du texte arrive : l'outil a fini
    },
    toolProgressReceived(state, action: PayloadAction<string>) {
      state.toolActivity = action.payload;
    },
    streamFinished(state) {
      state.isStreaming = false;
      state.toolActivity = null;
      // Réponse restée vide (erreur avant le 1er delta) : retirer la bulle.
      const last = state.messages[state.messages.length - 1];
      if (last && last.role === 'assistant' && last.content === '') {
        state.messages.pop();
      }
    },
    streamFailed(state, action: PayloadAction<string>) {
      state.isStreaming = false;
      state.toolActivity = null;
      state.error = action.payload;
      const last = state.messages[state.messages.length - 1];
      if (last && last.role === 'assistant' && last.content === '') {
        state.messages.pop();
      }
    },
    errorDismissed(state) {
      state.error = null;
    },
    conversationSaved(state, action: PayloadAction<number>) {
      state.conversationId = action.payload;
    },
    conversationLoaded(state, action: PayloadAction<HermesConversationDetail>) {
      state.messages = action.payload.messages
        .filter((m) => m.role === 'user' || m.role === 'assistant')
        .map((m) => ({ id: nextId(), role: m.role as 'user' | 'assistant', content: m.content }));
      state.conversationId = action.payload.id;
      state.error = null;
      state.toolActivity = null;
      state.isStreaming = false;
    },
    // « Nouvelle conversation » / « Effacer » : repart d'un fil vierge (non persisté).
    conversationCleared(state) {
      state.messages = [];
      state.conversationId = null;
      state.error = null;
      state.toolActivity = null;
    },
  },
});

export const {
  userMessageAdded,
  streamStarted,
  deltaReceived,
  toolProgressReceived,
  streamFinished,
  streamFailed,
  errorDismissed,
  conversationSaved,
  conversationLoaded,
  conversationCleared,
} = hermesChatSlice.actions;

/**
 * Envoie un message : fenêtre d'historique (API Hermes stateless).
 * ⚠️ Ordre important : capturer l'historique APRÈS userMessageAdded mais AVANT
 * streamStarted (sinon la bulle assistant vide partirait dans l'historique).
 */
export const sendMessage = (content: string, attachment?: ChatAttachment, signal?: AbortSignal) =>
  async (dispatch: AppDispatch, getState: () => RootState): Promise<void> => {
    dispatch(userMessageAdded({ content, attachment }));
    const { messages } = getState().hermesChat;
    const recent = messages.slice(-MAX_HISTORY_MESSAGES);
    const freshFrom = recent.length - ATTACHMENT_FRESH_WINDOW;
    const history: HermesApiMessage[] = recent.map((m, i) => ({
      role: m.role,
      content: toApiContent(m, i < freshFrom),
    }));
    dispatch(streamStarted());
    await streamChat(history, {
      onDelta: (text) => dispatch(deltaReceived(text)),
      onToolProgress: (label) => dispatch(toolProgressReceived(label)),
      onDone: () => dispatch(streamFinished()),
      onError: (message) => dispatch(streamFailed(message)),
    }, signal);

    // Persistance auto de l'historique après un échange abouti (best-effort :
    // une sauvegarde qui échoue ne doit pas casser le chat).
    const after = getState().hermesChat;
    const aReponse = after.messages.some((m) => m.role === 'assistant' && m.content.length > 0);
    if (!after.error && aReponse) {
      try {
        const id = await saveConversation({
          conversation_id: after.conversationId,
          messages: after.messages.map((m) => ({ role: m.role, content: toApiContent(m) })),
        });
        dispatch(conversationSaved(id));
      } catch {
        /* sauvegarde best-effort */
      }
    }
  };

/** Rouvre une conversation persistée : recharge ses messages dans le chat. */
export const loadConversation = (id: number) =>
  async (dispatch: AppDispatch): Promise<void> => {
    const detail = await getConversation(id);
    dispatch(conversationLoaded(detail));
  };

export default hermesChatSlice.reducer;
