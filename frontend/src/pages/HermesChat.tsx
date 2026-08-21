import {
    Add as AddIcon,
    Article as ResultsIcon,
    AttachFile as AttachFileIcon,
    Build as BuildIcon,
    ChatBubbleOutline as ChatIcon,
    DeleteOutline as DeleteIcon,
    Description as FileIcon,
    Edit as EditIcon,
    History as HistoryIcon,
    MonitorHeart as StatusIcon,
    Pause as PauseIcon,
    Person as PersonIcon,
    PlayArrow as PlayIcon,
    PlayCircleOutline as ResumeIcon,
    Psychology as HermesIcon,
    Refresh as RefreshIcon,
    Send as SendIcon,
    Stop as StopIcon,
    Visibility as ViewIcon,
    WarningAmber as WarnIcon,
    Work as JobsIcon,
} from '@mui/icons-material';
import {
    Alert,
    Avatar,
    Box,
    Button,
    Chip,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    IconButton,
    List,
    ListItem,
    ListItemButton,
    ListItemText,
    Paper,
    Stack,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Tabs,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
    AgentStatus,
    createJob,
    deleteConversation,
    deleteJob,
    deleteJobResult,
    executeJob,
    getAgentStatus,
    HermesConversationSummary,
    HermesJob,
    HermesJobResult,
    jobAction,
    jobId,
    listConversations,
    listJobResults,
    listJobs,
    updateJob,
} from '../services/hermesService';
import type { AppDispatch, RootState } from '../store';
import {
    ChatAttachment,
    ChatBubble,
    conversationCleared,
    errorDismissed,
    loadConversation,
    sendMessage,
} from '../store/slices/hermesChatSlice';

// Nom affiché de l'agent (marque). Le serveur reste « Hermes » techniquement.
const AGENT = 'Agent Trimet';

const ACCEPT_FILES =
  '.txt,.md,.markdown,.csv,.tsv,.json,.sql,.log,.py,.ts,.tsx,.js,.jsx,.java,.xml,.yaml,.yml,.html,.css,.scss,.sh,.ini,.conf,.env';
const MAX_FILE_BYTES = 256 * 1024;

const formatSize = (n: number): string =>
  n < 1024 ? `${n} o` : n < 1024 * 1024 ? `${Math.round(n / 1024)} Ko` : `${(n / 1024 / 1024).toFixed(1)} Mo`;

// Un champ de job Hermes peut arriver sous forme d'objet (ex. schedule =
// {display, expr, kind}). On ne rend JAMAIS un objet directement (React error #31).
const jobField = (v: unknown): string => {
  if (v == null) return '';
  if (typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return String(o.display ?? o.expr ?? o.name ?? '');
  }
  return String(v);
};
// Pour l'édition : on veut l'expression cron brute (pour re-sauvegarder).
const jobSchedExpr = (v: unknown): string => {
  if (v && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return String(o.expr ?? o.display ?? '');
  }
  return v == null ? '' : String(v);
};

// ----- Une ligne de conversation : avatar + bulle -----
const Ligne: React.FC<{ message: ChatBubble; streaming: boolean }> = ({ message, streaming }) => {
  const estUser = message.role === 'user';
  return (
    <Box sx={{ display: 'flex', gap: 1.5, flexDirection: estUser ? 'row-reverse' : 'row', alignItems: 'flex-start' }}>
      <Avatar sx={{ width: 32, height: 32, bgcolor: estUser ? 'secondary.main' : 'primary.main' }}>
        {estUser ? <PersonIcon fontSize="small" /> : <HermesIcon fontSize="small" />}
      </Avatar>
      <Box
        sx={{
          maxWidth: '80%',
          px: 1.75,
          py: 1.25,
          borderRadius: 2.5,
          borderTopRightRadius: estUser ? 4 : 20,
          borderTopLeftRadius: estUser ? 20 : 4,
          bgcolor: estUser ? 'primary.dark' : 'background.default',
          border: '1px solid',
          borderColor: estUser ? 'primary.main' : 'divider',
        }}
      >
        {message.attachment && (
          <Chip
            icon={<FileIcon />}
            size="small"
            label={`${message.attachment.name} · ${formatSize(message.attachment.size)}`}
            sx={{ mb: 0.75, maxWidth: '100%' }}
          />
        )}
        {message.content === '' && streaming ? (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <CircularProgress size={16} />
            <Typography variant="body2" color="text.secondary">{AGENT} réfléchit…</Typography>
          </Box>
        ) : (
          <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
            {message.content}
          </Typography>
        )}
      </Box>
    </Box>
  );
};

// ----- Onglet Conversation -----
const ConversationTab: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const { messages, isStreaming, toolActivity, error } = useSelector(
    (s: RootState) => s.hermesChat,
  );
  const [saisie, setSaisie] = useState('');
  const [attachment, setAttachment] = useState<ChatAttachment | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const bottomRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, toolActivity]);

  const choisirFichier = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    if (file.size > MAX_FILE_BYTES) {
      setFileError(`« ${file.name} » est trop volumineux (max ${formatSize(MAX_FILE_BYTES)}).`);
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      setAttachment({
        name: file.name,
        content: typeof reader.result === 'string' ? reader.result : '',
        size: file.size,
      });
      setFileError(null);
    };
    reader.onerror = () => setFileError('Lecture du fichier impossible (fichier texte attendu).');
    reader.readAsText(file);
  };

  const envoyer = () => {
    if (isStreaming) return;
    const texte = saisie.trim() || (attachment ? 'Analyse ce fichier.' : '');
    if (!texte) return;
    const att = attachment ?? undefined;
    setSaisie('');
    setAttachment(null);
    const controller = new AbortController();
    abortRef.current = controller;
    void dispatch(sendMessage(texte, att, controller.signal));
  };

  const arreter = () => abortRef.current?.abort();

  const peutEnvoyer = saisie.trim().length > 0 || attachment !== null;

  return (
    <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 1, mb: 1.5 }}>
        <Button
          size="small"
          startIcon={<AddIcon />}
          onClick={() => dispatch(conversationCleared())}
          disabled={isStreaming || messages.length === 0}
          sx={{ flexShrink: 0 }}
        >
          Nouvelle
        </Button>
      </Box>

      <Box sx={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2, py: 1, pr: 0.5 }}>
        {messages.length === 0 && (
          <Box sx={{ m: 'auto', textAlign: 'center', color: 'text.secondary', px: 2 }}>
            <HermesIcon sx={{ fontSize: 44, mb: 1, opacity: 0.7 }} />
            <Typography variant="h6" sx={{ fontWeight: 600 }}>Discutez avec l’{AGENT}</Typography>
            <Typography variant="body2" sx={{ mt: 0.5 }}>
              Posez une question, ou joignez un fichier (📎) pour le faire analyser.
            </Typography>
          </Box>
        )}
        {messages.map((m, i) => (
          <Ligne key={m.id} message={m} streaming={isStreaming && i === messages.length - 1} />
        ))}
        {toolActivity && (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, pl: 6 }}>
            <CircularProgress size={12} />
            <BuildIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
            <Typography variant="caption" color="text.secondary">
              L’{AGENT} utilise un outil… ({toolActivity})
            </Typography>
          </Box>
        )}
        <div ref={bottomRef} />
      </Box>

      {(error || fileError) && (
        <Alert severity="error" onClose={() => { dispatch(errorDismissed()); setFileError(null); }} sx={{ mt: 1.5 }}>
          {error || fileError}
        </Alert>
      )}

      <Paper variant="outlined" sx={{ mt: 1.5, borderRadius: 3, p: 1, bgcolor: 'background.paper' }}>
        {attachment && (
          <Box sx={{ px: 0.5, pt: 0.5, pb: 1 }}>
            <Chip
              icon={<FileIcon />}
              label={`${attachment.name} · ${formatSize(attachment.size)}`}
              onDelete={() => setAttachment(null)}
              variant="outlined"
              sx={{ maxWidth: '100%' }}
            />
          </Box>
        )}
        <TextField
          fullWidth
          multiline
          maxRows={8}
          variant="standard"
          placeholder={`Écrivez à l’${AGENT}…  (Entrée pour envoyer, Maj+Entrée = nouvelle ligne)`}
          value={saisie}
          onChange={(e) => setSaisie(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              envoyer();
            }
          }}
          disabled={isStreaming}
          InputProps={{ disableUnderline: true, sx: { px: 1, py: 0.5 } }}
        />
        <Box sx={{ display: 'flex', alignItems: 'center', mt: 0.5 }}>
          <input ref={fileInputRef} type="file" hidden accept={ACCEPT_FILES} onChange={choisirFichier} />
          <Tooltip title="Joindre un fichier texte pour analyse">
            <span>
              <IconButton onClick={() => fileInputRef.current?.click()} disabled={isStreaming}>
                <AttachFileIcon />
              </IconButton>
            </span>
          </Tooltip>
          <Box sx={{ flexGrow: 1 }} />
          {isStreaming ? (
            <Tooltip title="Arrêter la réponse">
              <IconButton color="error" onClick={arreter}>
                <StopIcon />
              </IconButton>
            </Tooltip>
          ) : (
            <Tooltip title="Envoyer">
              <span>
                <IconButton color="primary" onClick={envoyer} disabled={!peutEnvoyer}>
                  <SendIcon />
                </IconButton>
              </span>
            </Tooltip>
          )}
        </Box>
      </Paper>
    </Box>
  );
};

// Dialog d'affichage d'un résultat de job (exécution à la demande / historique).
const ResultatDialog: React.FC<{ res: HermesJobResult | null; onClose: () => void }> = ({ res, onClose }) => (
  <Dialog open={res !== null} onClose={onClose} maxWidth="md" fullWidth>
    <DialogTitle sx={{ pb: 0.5 }}>
      Résultat — {res?.job_name}
      {res?.date_creation && (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
          {new Date(res.date_creation).toLocaleString('fr-FR')}
        </Typography>
      )}
    </DialogTitle>
    <DialogContent dividers>
      <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
        {res?.resultat || '(vide)'}
      </Typography>
    </DialogContent>
    <DialogActions>
      <Button onClick={onClose}>Fermer</Button>
    </DialogActions>
  </Dialog>
);

// ----- Onglet Jobs (tâches planifiées cron) -----
interface JobForm { id: string | null; name: string; schedule: string; prompt: string; deliver: string }
const FORM_VIDE: JobForm = { id: null, name: '', schedule: '', prompt: '', deliver: 'origin' };

// Modèles métier pré-remplis (contexte migration SAP → IFS). Cliquer ouvre le
// dialog pré-rempli : l'utilisateur relit/ajuste avant de créer le job.
const JOB_TEMPLATES: { label: string; job: JobForm }[] = [
  {
    label: 'Brief quotidien migration',
    job: {
      id: null, name: 'Brief quotidien migration', schedule: '0 8 * * 1-5', deliver: 'origin',
      prompt: 'Prépare un brief quotidien concis (5 points maximum) sur l’avancement du projet de '
        + 'migration SAP ECC → IFS Cloud : ce qui a avancé, les points de blocage, et les prochaines '
        + 'étapes prioritaires. Réponds en français, format court.',
    },
  },
  {
    label: 'Veille SAP → IFS (hebdo)',
    job: {
      id: null, name: 'Veille SAP → IFS', schedule: '0 9 * * 1', deliver: 'origin',
      prompt: 'Fais une veille web sur les bonnes pratiques et actualités de migration SAP ECC vers '
        + 'IFS Cloud (ETL, mapping de données, chargement, contraintes IFS). Résume les 5 points les '
        + 'plus utiles avec leurs liens. En français.',
    },
  },
  {
    label: 'Récap hebdo équipe',
    job: {
      id: null, name: 'Récap hebdomadaire', schedule: '0 17 * * 5', deliver: 'origin',
      prompt: 'Rédige un récapitulatif de fin de semaine pour l’équipe de migration : synthèse des '
        + 'avancées, risques ouverts, et to-do pour la semaine suivante. En français, format court.',
    },
  },
  {
    label: 'Checklist qualité données',
    job: {
      id: null, name: 'Checklist qualité données IFS', schedule: '0 7 * * 1', deliver: 'origin',
      prompt: 'Génère une checklist de contrôle qualité des données migrées vers IFS (fournisseurs, '
        + 'clients, articles/part_catalog, projets) : points à vérifier et requêtes SQL de '
        + 'vérification suggérées (schéma clean_data). En français.',
    },
  },
];

const JobsTab: React.FC = () => {
  const [jobs, setJobs] = useState<HermesJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [form, setForm] = useState<JobForm | null>(null);
  const [saving, setSaving] = useState(false);
  const [running, setRunning] = useState<string | null>(null);
  const [resultat, setResultat] = useState<HermesJobResult | null>(null);

  const charger = useCallback(async () => {
    setLoading(true);
    setErreur(null);
    try {
      setJobs(await listJobs());
    } catch (e: any) {
      setErreur(e?.response?.status === 404
        ? 'Les jobs planifiés ne sont pas activés sur cette instance.'
        : (e?.response?.data?.error || 'Impossible de charger les jobs.'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void charger(); }, [charger]);

  const estEnPause = (j: HermesJob): boolean =>
    j.paused_at != null || j.enabled === false || jobField(j.state).toLowerCase().includes('paus');

  const action = async (j: HermesJob, a: 'pause' | 'resume') => {
    setErreur(null);
    try {
      await jobAction(jobId(j), a);
      setInfo(`${a === 'pause' ? 'Job mis en pause' : 'Job repris'} : « ${jobField(j.name) || jobId(j)} ».`);
      await charger();
    } catch (e: any) {
      setErreur(e?.response?.data?.error || 'Action impossible.');
    }
  };

  // Exécute le job MAINTENANT (rejoue son prompt via le chat) et affiche le résultat.
  const executer = async (j: HermesJob) => {
    setErreur(null);
    setInfo(null);
    setRunning(jobId(j));
    try {
      const res = await executeJob(jobId(j));
      setResultat(res);
      await charger(); // rafraîchit « dernière exéc. »
    } catch (e: any) {
      setErreur(e?.response?.data?.error || 'Exécution impossible.');
    } finally {
      setRunning(null);
    }
  };

  const supprimer = async (j: HermesJob) => {
    if (!window.confirm('Supprimer ce job ?')) return;
    try {
      await deleteJob(jobId(j));
      setJobs((prev) => prev.filter((x) => jobId(x) !== jobId(j)));
    } catch (e: any) {
      setErreur(e?.response?.data?.error || 'Suppression impossible.');
    }
  };

  const enregistrer = async () => {
    if (!form) return;
    if (!form.schedule.trim() || !form.prompt.trim()) {
      setErreur('« Planning » (cron) et « Prompt » sont obligatoires.');
      return;
    }
    setSaving(true);
    try {
      const payload = {
        name: form.name.trim() || undefined,
        schedule: form.schedule.trim(),
        prompt: form.prompt.trim(),
        deliver: form.deliver.trim() || undefined,
      };
      if (form.id) await updateJob(form.id, payload);
      else await createJob(payload);
      setForm(null);
      await charger();
    } catch (e: any) {
      setErreur(e?.response?.data?.error || 'Enregistrement impossible.');
    } finally {
      setSaving(false);
    }
  };

  const editer = (j: HermesJob) =>
    setForm({
      id: jobId(j),
      name: jobField(j.name),
      schedule: jobSchedExpr(j.schedule),
      prompt: jobField(j.prompt),
      deliver: jobField(j.deliver) || 'origin',
    });

  return (
    <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1, mb: 1 }}>
        <Button size="small" startIcon={<RefreshIcon />} onClick={charger} disabled={loading}>Rafraîchir</Button>
        <Button size="small" variant="contained" startIcon={<AddIcon />} onClick={() => setForm({ ...FORM_VIDE })}>
          Nouveau job
        </Button>
      </Box>
      {erreur && <Alert severity="error" sx={{ mb: 1.5 }} onClose={() => setErreur(null)}>{erreur}</Alert>}
      {info && <Alert severity="success" sx={{ mb: 1.5 }} onClose={() => setInfo(null)}>{info}</Alert>}

      {/* Modèles métier : création rapide pré-remplie */}
      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5, alignItems: 'center' }}>
        <Typography variant="caption" color="text.secondary">Modèles :</Typography>
        {JOB_TEMPLATES.map((t) => (
          <Chip
            key={t.label}
            label={t.label}
            icon={<AddIcon />}
            size="small"
            variant="outlined"
            clickable
            onClick={() => setForm({ ...t.job })}
          />
        ))}
      </Stack>

      <Paper variant="outlined" sx={{ flexGrow: 1, overflow: 'auto' }}>
        {loading ? (
          <Box sx={{ p: 3, textAlign: 'center' }}><CircularProgress size={24} /></Box>
        ) : jobs.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ p: 3, textAlign: 'center' }}>
            Aucun job planifié. Créez-en un (ex. planning « 0 9 * * * » pour tous les jours à 9 h).
          </Typography>
        ) : (
          <TableContainer>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 700 }}>Nom</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Planning</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Statut</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Dernière exéc.</TableCell>
                  <TableCell sx={{ fontWeight: 700 }} align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {jobs.map((j) => {
                  const paused = estEnPause(j);
                  return (
                    <TableRow key={jobId(j)} hover>
                      <TableCell>{jobField(j.name) || jobId(j) || '—'}</TableCell>
                      <TableCell><code>{jobField(j.schedule) || '—'}</code></TableCell>
                      <TableCell>
                        <Chip
                          size="small"
                          label={paused ? 'en pause' : (jobField(j.state) || 'actif')}
                          color={paused ? 'default' : 'success'}
                          variant="outlined"
                        />
                      </TableCell>
                      <TableCell>
                        {j.last_run_at ? (
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, flexWrap: 'wrap' }}>
                            <Typography variant="caption">
                              {new Date(String(j.last_run_at)).toLocaleString('fr-FR')}
                            </Typography>
                            {j.last_status && (
                              <Chip size="small" variant="outlined"
                                color={String(j.last_status).toLowerCase() === 'ok' ? 'success' : 'error'}
                                label={String(j.last_status)} />
                            )}
                            {j.last_delivery_error && (
                              <Tooltip title={`Résultat exécuté mais non livré à l’app : ${String(j.last_delivery_error)}`}>
                                <WarnIcon fontSize="small" color="warning" />
                              </Tooltip>
                            )}
                          </Box>
                        ) : (
                          <Typography variant="caption" color="text.secondary">jamais</Typography>
                        )}
                      </TableCell>
                      <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                        <Tooltip title="Exécuter maintenant et voir le résultat">
                          <span>
                            <IconButton size="small" color="primary"
                              onClick={() => executer(j)} disabled={running !== null}>
                              {running === jobId(j) ? <CircularProgress size={16} /> : <PlayIcon fontSize="small" />}
                            </IconButton>
                          </span>
                        </Tooltip>
                        {paused ? (
                          <Tooltip title="Reprendre">
                            <IconButton size="small" color="success" onClick={() => action(j, 'resume')}>
                              <ResumeIcon fontSize="small" />
                            </IconButton>
                          </Tooltip>
                        ) : (
                          <Tooltip title="Mettre en pause">
                            <IconButton size="small" onClick={() => action(j, 'pause')}><PauseIcon fontSize="small" /></IconButton>
                          </Tooltip>
                        )}
                        <Tooltip title="Éditer">
                          <IconButton size="small" onClick={() => editer(j)}><EditIcon fontSize="small" /></IconButton>
                        </Tooltip>
                        <Tooltip title="Supprimer">
                          <IconButton size="small" color="error" onClick={() => supprimer(j)}><DeleteIcon fontSize="small" /></IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Paper>

      {/* Dialogue création / édition */}
      <Dialog open={form !== null} onClose={() => setForm(null)} maxWidth="sm" fullWidth>
        <DialogTitle>{form?.id ? 'Éditer le job' : 'Nouveau job planifié'}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField label="Nom (optionnel)" size="small" fullWidth
              value={form?.name || ''} onChange={(e) => setForm((f) => f && { ...f, name: e.target.value })} />
            <TextField label="Planning (cron)" size="small" fullWidth required
              placeholder="0 9 * * *  (tous les jours à 9 h) — ou « every 2h »"
              value={form?.schedule || ''} onChange={(e) => setForm((f) => f && { ...f, schedule: e.target.value })} />
            <TextField label="Prompt" size="small" fullWidth required multiline minRows={3}
              placeholder="Ex. : Prépare un brief quotidien de l’avancement de la migration."
              value={form?.prompt || ''} onChange={(e) => setForm((f) => f && { ...f, prompt: e.target.value })} />
            <TextField label="Livraison (deliver)" size="small" fullWidth
              helperText="Cible de livraison du résultat (ex. « origin »)."
              value={form?.deliver || ''} onChange={(e) => setForm((f) => f && { ...f, deliver: e.target.value })} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setForm(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer} disabled={saving}>
            {saving ? <CircularProgress size={20} /> : 'Enregistrer'}
          </Button>
        </DialogActions>
      </Dialog>

      <ResultatDialog res={resultat} onClose={() => setResultat(null)} />
    </Box>
  );
};

// ----- Onglet Résultats (exécutions stockées) -----
const ResultatsTab: React.FC = () => {
  const [items, setItems] = useState<HermesJobResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);
  const [view, setView] = useState<HermesJobResult | null>(null);

  const charger = useCallback(async () => {
    setLoading(true);
    setErreur(null);
    try {
      setItems(await listJobResults());
    } catch {
      setErreur('Impossible de charger les résultats.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void charger(); }, [charger]);

  const supprimer = async (id: number | null) => {
    if (id == null || !window.confirm('Supprimer ce résultat ?')) return;
    try {
      await deleteJobResult(id);
      setItems((prev) => prev.filter((r) => r.id !== id));
    } catch {
      setErreur('Suppression impossible.');
    }
  };

  return (
    <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
        <Button size="small" startIcon={<RefreshIcon />} onClick={charger} disabled={loading}>Rafraîchir</Button>
      </Box>
      {erreur && <Alert severity="error" sx={{ mb: 1.5 }}>{erreur}</Alert>}
      <Paper variant="outlined" sx={{ flexGrow: 1, overflow: 'auto' }}>
        {loading ? (
          <Box sx={{ p: 3, textAlign: 'center' }}><CircularProgress size={24} /></Box>
        ) : items.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ p: 3, textAlign: 'center' }}>
            Aucun résultat. Exécutez un job depuis l’onglet « Jobs » pour en générer.
          </Typography>
        ) : (
          <List disablePadding>
            {items.map((r) => (
              <ListItem
                key={r.id}
                disablePadding
                secondaryAction={
                  <Tooltip title="Supprimer">
                    <IconButton edge="end" size="small" color="error" onClick={() => supprimer(r.id)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                }
                sx={{ borderBottom: '1px solid', borderColor: 'divider' }}
              >
                <ListItemButton onClick={() => setView(r)}>
                  <ViewIcon sx={{ mr: 1.5, color: 'text.secondary' }} fontSize="small" />
                  <ListItemText
                    primary={r.job_name || 'Job'}
                    primaryTypographyProps={{ noWrap: true, variant: 'body2' }}
                    secondary={r.date_creation ? new Date(r.date_creation).toLocaleString('fr-FR') : ''}
                    secondaryTypographyProps={{ variant: 'caption' }}
                  />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
        )}
      </Paper>
      <ResultatDialog res={view} onClose={() => setView(null)} />
    </Box>
  );
};

// ----- Onglet Historique -----
const HistoriqueTab: React.FC<{ onOuvrir: () => void }> = ({ onOuvrir }) => {
  const dispatch = useDispatch<AppDispatch>();
  const conversationId = useSelector((s: RootState) => s.hermesChat.conversationId);
  const [items, setItems] = useState<HermesConversationSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [erreur, setErreur] = useState<string | null>(null);

  const charger = useCallback(async () => {
    setLoading(true);
    setErreur(null);
    try {
      setItems(await listConversations());
    } catch {
      setErreur('Impossible de charger l’historique.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void charger(); }, [charger]);

  const ouvrir = async (id: number) => {
    try {
      await dispatch(loadConversation(id));
      onOuvrir();
    } catch {
      setErreur('Impossible d’ouvrir cette conversation.');
    }
  };

  const supprimer = async (id: number) => {
    if (!window.confirm('Supprimer cette conversation ?')) return;
    try {
      await deleteConversation(id);
      setItems((prev) => prev.filter((c) => c.id !== id));
    } catch {
      setErreur('Suppression impossible.');
    }
  };

  return (
    <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
        <Button size="small" startIcon={<RefreshIcon />} onClick={charger} disabled={loading}>Rafraîchir</Button>
      </Box>
      {erreur && <Alert severity="error" sx={{ mb: 1.5 }}>{erreur}</Alert>}
      <Paper variant="outlined" sx={{ flexGrow: 1, overflowY: 'auto' }}>
        {loading ? (
          <Box sx={{ p: 3, textAlign: 'center' }}><CircularProgress size={24} /></Box>
        ) : items.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ p: 3, textAlign: 'center' }}>
            Aucune conversation enregistrée pour le moment.
          </Typography>
        ) : (
          <List disablePadding>
            {items.map((c) => (
              <ListItem
                key={c.id}
                disablePadding
                secondaryAction={
                  <Tooltip title="Supprimer">
                    <IconButton edge="end" size="small" color="error" onClick={() => supprimer(c.id)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                }
                sx={{ borderBottom: '1px solid', borderColor: 'divider' }}
              >
                <ListItemButton selected={c.id === conversationId} onClick={() => ouvrir(c.id)}>
                  <ChatIcon sx={{ mr: 1.5, color: 'text.secondary' }} fontSize="small" />
                  <ListItemText
                    primary={c.titre || 'Conversation'}
                    primaryTypographyProps={{ noWrap: true, variant: 'body2' }}
                    secondary={`${new Date(c.date_maj).toLocaleString('fr-FR')} · ${c.nb_messages} message(s)`}
                    secondaryTypographyProps={{ variant: 'caption' }}
                  />
                </ListItemButton>
              </ListItem>
            ))}
          </List>
        )}
      </Paper>
    </Box>
  );
};

// ----- Onglet État de l'agent -----
const StatusTab: React.FC = () => {
  const [status, setStatus] = useState<AgentStatus | null>(null);
  const [loading, setLoading] = useState(true);

  const charger = useCallback(async () => {
    setLoading(true);
    try {
      setStatus(await getAgentStatus());
    } catch {
      setStatus({ reachable: false, capabilities: null, health: null });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void charger(); }, [charger]);

  const features = (status?.capabilities?.features ?? {}) as Record<string, boolean>;
  const health = (status?.health ?? {}) as Record<string, unknown>;
  const infosSante: [string, string][] = [
    ['Version', String(health.version ?? '—')],
    ['Gateway', String(health.gateway_state ?? '—')],
    ['Agents actifs', String(health.active_agents ?? '—')],
    ['Gateway occupé', health.gateway_busy === undefined ? '—' : (health.gateway_busy ? 'oui' : 'non')],
  ];

  return (
    <Box sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
        <Button size="small" startIcon={<RefreshIcon />} onClick={charger} disabled={loading}>Rafraîchir</Button>
      </Box>
      {loading ? (
        <Box sx={{ p: 3, textAlign: 'center' }}><CircularProgress size={24} /></Box>
      ) : (
        <Stack spacing={2}>
          <Chip
            label={status?.reachable ? `${AGENT} joignable` : `${AGENT} injoignable`}
            color={status?.reachable ? 'success' : 'error'}
            sx={{ alignSelf: 'flex-start' }}
          />
          <Paper variant="outlined" sx={{ p: 2 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Santé</Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              {infosSante.map(([k, v]) => (
                <Chip key={k} size="small" variant="outlined" label={`${k} : ${v}`} />
              ))}
            </Stack>
          </Paper>
          <Paper variant="outlined" sx={{ p: 2 }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Fonctionnalités (API)</Typography>
            {Object.keys(features).length === 0 ? (
              <Typography variant="body2" color="text.secondary">Non communiquées par l’instance.</Typography>
            ) : (
              <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap>
                {Object.entries(features).map(([k, v]) => (
                  <Chip key={k} size="small" label={k} color={v ? 'primary' : 'default'}
                    variant={v ? 'filled' : 'outlined'} />
                ))}
              </Stack>
            )}
          </Paper>
        </Stack>
      )}
    </Box>
  );
};

const HermesChat: React.FC = () => {
  const [tab, setTab] = useState(0);

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <HermesIcon color="primary" />
        <Typography variant="h5" sx={{ fontWeight: 700 }}>{AGENT}</Typography>
      </Box>

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Tab icon={<ChatIcon />} iconPosition="start" label="Conversation" />
        <Tab icon={<JobsIcon />} iconPosition="start" label="Jobs" />
        <Tab icon={<ResultsIcon />} iconPosition="start" label="Résultats" />
        <Tab icon={<HistoryIcon />} iconPosition="start" label="Historique" />
        <Tab icon={<StatusIcon />} iconPosition="start" label="État" />
      </Tabs>

      {/* Conversation monté en permanence (préserve la saisie / le stream en cours). */}
      <Box sx={{ display: tab === 0 ? 'flex' : 'none', flexDirection: 'column', flexGrow: 1, minHeight: 0 }}>
        <ConversationTab />
      </Box>
      {tab === 1 && <JobsTab />}
      {tab === 2 && <ResultatsTab />}
      {tab === 3 && <HistoriqueTab onOuvrir={() => setTab(0)} />}
      {tab === 4 && <StatusTab />}
    </Box>
  );
};

export default HermesChat;
