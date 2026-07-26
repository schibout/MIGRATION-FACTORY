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
// des actions au fil des deltas SSE. Les instructions vivent dans le store :
// persistantes sur toute la session SPA (navigation comprise).
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

/**
 * Contenu réellement envoyé à Hermes (et persisté) pour un message : le texte
 * de l'utilisateur, complété du fichier joint entre balises si présent.
 */
const toApiContent = (m: ChatBubble): string =>
  m.attachment
    ? `${m.content}\n\n[Fichier joint « ${m.attachment.name} »]\n\`\`\`\n${m.attachment.content}\n\`\`\``
    : m.content;

interface HermesChatState {
  messages: ChatBubble[];
  /** Consigne persistante, envoyée comme message system à chaque requête. */
  instructions: string;
  /** id du fil persisté en base (null = pas encore sauvegardé / nouveau). */
  conversationId: number | null;
  isStreaming: boolean;
  /** Libellé « Hermes utilise un outil… » (event hermes.tool.progress), null = caché. */
  toolActivity: string | null;
  error: string | null;
}

const initialState: HermesChatState = {
  messages: [],
  instructions: '',
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
    instructionsChanged(state, action: PayloadAction<string>) {
      state.instructions = action.payload;
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
      state.instructions = action.payload.instructions;
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
  instructionsChanged,
  errorDismissed,
  conversationSaved,
  conversationLoaded,
  conversationCleared,
} = hermesChatSlice.actions;

/**
 * Envoie un message : historique complet (API Hermes stateless) + instructions.
 * ⚠️ Ordre important : capturer l'historique APRÈS userMessageAdded mais AVANT
 * streamStarted (sinon la bulle assistant vide partirait dans l'historique).
 */
export const sendMessage = (content: string, attachment?: ChatAttachment, signal?: AbortSignal) =>
  async (dispatch: AppDispatch, getState: () => RootState): Promise<void> => {
    dispatch(userMessageAdded({ content, attachment }));
    const { messages, instructions } = getState().hermesChat;
    const history: HermesApiMessage[] = messages.map((m) => ({
      role: m.role,
      content: toApiContent(m),
    }));
    dispatch(streamStarted());
    await streamChat(history, instructions, {
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
          instructions: after.instructions,
          messages: after.messages.map((m) => ({ role: m.role, content: toApiContent(m) })),
        });
        dispatch(conversationSaved(id));
      } catch {
        /* sauvegarde best-effort */
      }
    }
  };

/** Rouvre une conversation persistée : charge messages + instructions dans le chat. */
export const loadConversation = (id: number) =>
  async (dispatch: AppDispatch): Promise<void> => {
    const detail = await getConversation(id);
    dispatch(conversationLoaded(detail));
  };

export default hermesChatSlice.reducer;
