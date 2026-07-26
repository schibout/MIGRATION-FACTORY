import {
    Add as AddIcon,
    ChatBubbleOutline as ChatIcon,
    DeleteOutline as DeleteIcon,
    ExpandMore as ExpandMoreIcon,
    Send as SendIcon,
    SmartToy as SmartToyIcon,
    ThumbDownAlt as ThumbDownIcon,
    ThumbUpAlt as ThumbUpIcon,
} from '@mui/icons-material';
import {
    Accordion,
    AccordionDetails,
    AccordionSummary,
    Alert,
    Box,
    Button,
    Chip,
    CircularProgress,
    Divider,
    IconButton,
    Paper,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useEffect, useRef, useState } from 'react';
import ResultsTable from '../components/ai/ResultsTable';
import aiService, {
    AiConversation,
    AiHealth,
    AiResult,
} from '../services/aiService';

interface ChatEntry {
  localId: number;
  question: string;
  // null tant que le job est en cours de traitement (arrière-plan).
  result: AiResult | null;
  pending?: boolean;
}

// Bloc de réponse à une question (résultat déjà disponible).
const ResponseBlock: React.FC<{ entry: ChatEntry }> = ({ entry }) => {
  const { result } = entry;
  const [vote, setVote] = React.useState<'up' | 'down' | null>(null);
  const idLog = result?.id_log ?? null;
  const envoyerVote = (v: 'up' | 'down') => {
    const suivant = vote === v ? null : v;
    setVote(suivant);
    if (idLog) aiService.feedback(idLog, suivant ?? 'none');
  };
  if (!result) return null;

  if (result.statut !== 'succes') {
    const severity =
      result.statut === 'rejete' ? 'warning' : result.statut === 'occupe' ? 'info' : 'error';
    const titre =
      result.statut === 'rejete'
        ? 'Requête rejetée par la sécurité'
        : result.statut === 'occupe'
        ? 'Analyse déjà en cours'
        : result.statut === 'indisponible'
        ? 'Assistant indisponible'
        : 'Erreur';
    return (
      <Box sx={{ mt: 1 }}>
        <Alert severity={severity as any}>
          <strong>{titre}.</strong> {result.raison}
        </Alert>
        {result.sql && (
          <Accordion disableGutters sx={{ mt: 1 }}>
            <AccordionSummary expandIcon={<ExpandMoreIcon />}>
              <Typography variant="caption" sx={{ fontFamily: 'monospace' }}>
                Voir le SQL généré
              </Typography>
            </AccordionSummary>
            <AccordionDetails>
              <Box
                component="pre"
                sx={{
                  m: 0,
                  p: 1.5,
                  bgcolor: '#1e2738',
                  color: '#e0e6f0',
                  borderRadius: 1,
                  overflowX: 'auto',
                  fontSize: 12,
                }}
              >
                {result.sql}
              </Box>
            </AccordionDetails>
          </Accordion>
        )}
      </Box>
    );
  }

  return (
    <Box sx={{ mt: 1 }}>
      {result.explication && (
        <Typography variant="body2" sx={{ mb: 1 }}>
          {result.explication}
        </Typography>
      )}

      <Accordion disableGutters>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography variant="caption" sx={{ fontFamily: 'monospace' }}>
            Voir le SQL généré
          </Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Box
            component="pre"
            sx={{
              m: 0,
              p: 1.5,
              bgcolor: '#1e2738',
              color: '#e0e6f0',
              borderRadius: 1,
              overflowX: 'auto',
              fontSize: 12,
            }}
          >
            {result.sql}
          </Box>
        </AccordionDetails>
      </Accordion>

      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1, flexWrap: 'wrap' }}>
        {typeof result.duree_ms === 'number' && (
          <Chip size="small" variant="outlined" label={`${result.duree_ms} ms`} />
        )}
        {result.tronque && (
          <Chip size="small" color="warning" label="Résultats tronqués à 500 lignes" />
        )}
        {result.source === 'cache' && (
          <Chip size="small" color="info" label="Réponse issue du cache" />
        )}
        {idLog && (
          <>
            <Box sx={{ flexGrow: 1 }} />
            <Tooltip title="Bonne réponse — la réutiliser comme exemple">
              <IconButton size="small" color={vote === 'up' ? 'success' : 'default'} onClick={() => envoyerVote('up')}>
                <ThumbUpIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            <Tooltip title="Réponse incorrecte">
              <IconButton size="small" color={vote === 'down' ? 'error' : 'default'} onClick={() => envoyerVote('down')}>
                <ThumbDownIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          </>
        )}
      </Box>

      <ResultsTable
        colonnes={result.colonnes ?? []}
        lignes={result.lignes ?? []}
        idLog={result.id_log ?? undefined}
        sql={result.sql}
      />
    </Box>
  );
};

const AssistantIA: React.FC = () => {
  const [health, setHealth] = useState<AiHealth | null>(null);
  const [question, setQuestion] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [entries, setEntries] = useState<ChatEntry[]>([]);
  const [conversations, setConversations] = useState<AiConversation[]>([]);
  const [currentConvId, setCurrentConvId] = useState<number | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const entrySeqRef = useRef(0);
  // Pollers actifs, indexés par localId d'entrée.
  const pollers = useRef<Record<number, ReturnType<typeof setInterval>>>({});

  const updateEntry = (localId: number, patch: Partial<ChatEntry>) => {
    setEntries((prev) => prev.map((e) => (e.localId === localId ? { ...e, ...patch } : e)));
  };

  const stopPolling = (localId: number) => {
    const timer = pollers.current[localId];
    if (timer) {
      clearInterval(timer);
      delete pollers.current[localId];
    }
  };

  const stopAllPolling = () => {
    Object.keys(pollers.current).forEach((k) => stopPolling(Number(k)));
  };

  const loadConversations = async () => {
    try {
      setConversations(await aiService.listConversations());
    } catch {
      setConversations([]);
    }
  };

  // Suit un job d'arrière-plan jusqu'à sa fin et met à jour l'entrée associée.
  const startPolling = (jobId: number, localId: number) => {
    let attempts = 0;
    const tick = async () => {
      attempts += 1;
      try {
        const job = await aiService.getJob(jobId);
        if (job.statut === 'termine') {
          updateEntry(localId, {
            result: job.resultat ?? { statut: 'erreur', raison: 'Résultat indisponible.' },
            pending: false,
          });
          if (job.conversation_id) setCurrentConvId(job.conversation_id);
          loadConversations();
          stopPolling(localId);
          return;
        }
        if (job.statut === 'erreur') {
          updateEntry(localId, {
            result: { statut: 'erreur', raison: job.erreur || 'Échec du traitement.' },
            pending: false,
          });
          stopPolling(localId);
          return;
        }
      } catch {
        /* erreur réseau ponctuelle : on retentera au prochain tick */
      }
      if (attempts > 2400) {
        // ~60 min à 1,5 s : garde-fou ultime contre un job réellement bloqué.
        // (La génération n'a plus de délai imparti côté serveur ; on laisse donc
        //  largement le temps au modèle CPU avant d'abandonner l'affichage.)
        updateEntry(localId, {
          result: { statut: 'erreur', raison: 'Délai de traitement dépassé.' },
          pending: false,
        });
        stopPolling(localId);
      }
    };
    pollers.current[localId] = setInterval(tick, 1500);
    tick();
  };

  // Chargement initial : santé Ollama + conversations + reprise des jobs actifs.
  useEffect(() => {
    aiService.getHealth().then(setHealth).catch(() => setHealth(null));
    aiService.listConversations().then(setConversations).catch(() => setConversations([]));
    aiService
      .listActiveJobs()
      .then((jobs) => {
        jobs.forEach((j) => {
          const localId = (entrySeqRef.current += 1);
          setEntries((prev) => [...prev, { localId, question: j.question, result: null, pending: true }]);
          if (j.conversation_id) setCurrentConvId(j.conversation_id);
          startPolling(j.id, localId);
        });
      })
      .catch(() => {});
    return () => stopAllPolling();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [entries]);

  const newConversation = () => {
    stopAllPolling();
    setEntries([]);
    setCurrentConvId(null);
    setQuestion('');
  };

  const openConversation = async (id: number) => {
    stopAllPolling();
    try {
      const detail = await aiService.getConversation(id);
      // Reconstitue les échanges : chaque message assistant + la question précédente.
      const built: ChatEntry[] = [];
      detail.messages.forEach((m, i) => {
        if (m.role !== 'assistant') return;
        const prev = detail.messages[i - 1];
        const question = prev && prev.role === 'user' ? prev.contenu ?? '' : '';
        const succes = m.statut === 'succes';
        built.push({
          localId: (entrySeqRef.current += 1),
          question,
          result: {
            statut: (m.statut as AiResult['statut']) ?? 'succes',
            sql: m.sql_genere ?? undefined,
            explication: succes ? m.contenu ?? undefined : undefined,
            raison: succes ? undefined : m.contenu ?? undefined,
            id_log: m.id_log,
            duree_ms: m.duree_ms ?? undefined,
            tronque: m.tronque ?? undefined,
            colonnes: [],
            lignes: [],
          },
        });
      });
      setEntries(built);
      setCurrentConvId(id);
      // Ré-exécute le SQL des réponses réussies pour réafficher les résultats.
      built.forEach((entry) => {
        if (entry.result?.statut === 'succes' && entry.result.id_log) {
          aiService
            .rerun(entry.result.id_log)
            .then((r) => {
              if (r.statut !== 'succes') return;
              setEntries((prev) =>
                prev.map((e) =>
                  e.localId === entry.localId && e.result
                    ? { ...e, result: { ...e.result, colonnes: r.colonnes, lignes: r.lignes, tronque: r.tronque } }
                    : e,
                ),
              );
            })
            .catch(() => {});
        }
      });
    } catch {
      /* conversation introuvable : on ignore */
    }
  };

  const removeConversation = async (id: number, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await aiService.deleteConversation(id);
      if (id === currentConvId) newConversation();
      loadConversations();
    } catch {
      /* ignore */
    }
  };

  const handleAsk = async () => {
    const q = question.trim();
    if (!q || submitting) return;
    setQuestion('');
    setSubmitting(true);
    const localId = (entrySeqRef.current += 1);
    setEntries((prev) => [...prev, { localId, question: q, result: null, pending: true }]);
    try {
      const sub = await aiService.submitAsk(q, currentConvId);
      if (!sub.job_id) {
        updateEntry(localId, {
          result: { statut: 'erreur', raison: (sub as any).raison || 'Soumission impossible.' },
          pending: false,
        });
      } else {
        if (sub.conversation_id) setCurrentConvId(sub.conversation_id);
        startPolling(sub.job_id, localId);
      }
    } catch (err: any) {
      updateEntry(localId, {
        result: { statut: 'erreur', raison: err.message || 'Erreur réseau.' },
        pending: false,
      });
    } finally {
      setSubmitting(false);
    }
  };

  const ollamaIndispo = health && !health.available;
  const modeleAbsent = health && health.available && !health.model_present;
  const enCours = entries.some((e) => e.pending);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <SmartToyIcon color="primary" />
        <Typography variant="h5" sx={{ fontWeight: 700 }}>
          Assistant IA
        </Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Posez vos questions en français sur les données SAP. L'assistant génère une requête
        SQL en lecture seule, l'exécute et affiche les résultats. Le traitement se fait en
        arrière-plan : vous pouvez enchaîner les questions ou changer de page.
      </Typography>

      {ollamaIndispo && (
        <Alert severity="error" sx={{ mb: 2 }}>
          L'assistant local (Ollama) est indisponible{health?.error ? ` : ${health.error}` : ''}.
          Vérifiez que le service est démarré sur la VM.
        </Alert>
      )}
      {modeleAbsent && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Le modèle « {health?.model} » n'est pas chargé dans Ollama. Lancez
          {' '}<code>ollama pull {health?.model}</code>.
        </Alert>
      )}

      <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start' }}>
          {/* Sidebar : conversations */}
          <Box sx={{ width: 260, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Paper variant="outlined" sx={{ p: 2 }}>
              <Button
                fullWidth
                size="small"
                variant="contained"
                startIcon={<AddIcon />}
                onClick={newConversation}
                sx={{ mb: 1.5, textTransform: 'none' }}
              >
                Nouvelle conversation
              </Button>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                <ChatIcon fontSize="small" color="action" />
                <Typography variant="subtitle2">Conversations</Typography>
              </Box>
              <Divider sx={{ mb: 1 }} />
              <Box sx={{ maxHeight: 360, overflowY: 'auto' }}>
                {conversations.map((c) => (
                  <Box key={c.id} sx={{ display: 'flex', alignItems: 'center', mb: 0.5 }}>
                    <Button
                      size="small"
                      variant={c.id === currentConvId ? 'contained' : 'text'}
                      onClick={() => openConversation(c.id)}
                      sx={{ justifyContent: 'flex-start', textTransform: 'none', flexGrow: 1, minWidth: 0 }}
                    >
                      <Typography variant="caption" noWrap sx={{ flexGrow: 1, textAlign: 'left' }}>
                        {c.titre || `Conversation ${c.id}`}
                      </Typography>
                    </Button>
                    <Tooltip title="Supprimer">
                      <IconButton size="small" onClick={(e) => removeConversation(c.id, e)}>
                        <DeleteIcon fontSize="inherit" />
                      </IconButton>
                    </Tooltip>
                  </Box>
                ))}
                {!conversations.length && (
                  <Typography variant="caption" color="text.secondary">
                    Aucune conversation enregistrée.
                  </Typography>
                )}
              </Box>
            </Paper>
          </Box>

          {/* Zone de chat */}
          <Box sx={{ flexGrow: 1, minWidth: 0 }}>
            <Paper variant="outlined" sx={{ p: 2, minHeight: 320, maxHeight: 540, overflowY: 'auto' }}>
              {entries.length === 0 && (
                <Typography variant="body2" color="text.secondary">
                  Exemple : « Combien de fournisseurs actifs en France ? »
                </Typography>
              )}
              {entries.map((entry, i) => (
                <Box key={entry.localId} sx={{ mb: 3 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                    {entry.question}
                  </Typography>
                  {entry.pending || !entry.result ? (
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                      <CircularProgress size={18} />
                      <Typography variant="body2" color="text.secondary">
                        Traitement en arrière-plan (modèle local, ~20-60 s)…
                      </Typography>
                    </Box>
                  ) : (
                    <ResponseBlock entry={entry} />
                  )}
                  {i < entries.length - 1 && <Divider sx={{ mt: 2 }} />}
                </Box>
              ))}
              <div ref={bottomRef} />
            </Paper>

            <Box sx={{ display: 'flex', gap: 1, mt: 2 }}>
              <TextField
                fullWidth
                size="small"
                placeholder="Posez votre question…"
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    handleAsk();
                  }
                }}
              />
              <Button
                variant="contained"
                endIcon={submitting ? <CircularProgress size={16} color="inherit" /> : <SendIcon />}
                onClick={handleAsk}
                disabled={!question.trim() || submitting}
              >
                Envoyer
              </Button>
            </Box>
            {enCours && (
              <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                Une ou plusieurs questions sont en cours de traitement en arrière-plan.
              </Typography>
            )}
          </Box>
      </Box>
    </Box>
  );
};

export default AssistantIA;
