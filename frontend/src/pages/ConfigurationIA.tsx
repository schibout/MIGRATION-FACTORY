import {
    Add as AddIcon,
    CloudOutlined as CloudIcon,
    DeleteOutline as DeleteIcon,
    Edit as EditIcon,
    ExpandMore as ExpandMoreIcon,
    PlayArrow as PlayArrowIcon,
    Refresh as RefreshIcon,
    Save as SaveIcon,
    Tune as TuneIcon,
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
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    IconButton,
    MenuItem,
    Paper,
    Snackbar,
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
import React, { useEffect, useState } from 'react';
import aiConfigService, {
    AiConfigDomain,
    AiConfigExample,
    AiConfigOverview,
    AiConfigPack,
    AiConfigUsage,
    AiInspectResult,
} from '../services/aiConfigService';
import aiService, { AiHealth } from '../services/aiService';
import settingsService, { SettingItem } from '../services/settingsService';

// Bloc monospace (prompt / SQL) — fond sombre, lisible.
const Mono: React.FC<{ children?: React.ReactNode }> = ({ children }) => (
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
      whiteSpace: 'pre-wrap',
      wordBreak: 'break-word',
    }}
  >
    {children}
  </Box>
);

const ListeChips: React.FC<{ items: string[]; color?: any }> = ({ items, color }) => (
  <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
    {items.map((v) => (
      <Chip key={v} size="small" label={v} variant="outlined" color={color} sx={{ height: 20, fontSize: 11 }} />
    ))}
  </Stack>
);

const ConfigurationIA: React.FC = () => {
  const [tab, setTab] = useState(0);
  const [overview, setOverview] = useState<AiConfigOverview | null>(null);
  const [domains, setDomains] = useState<AiConfigDomain[]>([]);
  const [packs, setPacks] = useState<AiConfigPack[]>([]);
  const [examples, setExamples] = useState<{ total: number; items: AiConfigExample[] }>({ total: 0, items: [] });
  const [usage, setUsage] = useState<AiConfigUsage | null>(null);

  const [question, setQuestion] = useState('');
  const [inspect, setInspect] = useState<AiInspectResult | null>(null);
  const [loadingInspect, setLoadingInspect] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([
      aiConfigService.overview().then(setOverview).catch(() => null),
      aiConfigService.domains().then(setDomains).catch(() => []),
      aiConfigService.packs().then(setPacks).catch(() => []),
      aiConfigService.examples(150).then(setExamples).catch(() => null),
      aiConfigService.usage().then(setUsage).catch(() => null),
    ]);
  }, []);

  const lancerInspect = async () => {
    if (!question.trim()) return;
    setLoadingInspect(true);
    setErreur(null);
    setInspect(null);
    try {
      setInspect(await aiConfigService.inspect(question));
    } catch (e: any) {
      setErreur(e?.response?.data?.raison || e?.message || 'Échec de l’inspection.');
    } finally {
      setLoadingInspect(false);
    }
  };

  // ----- Édition -----
  const [snack, setSnack] = useState<{ msg: string; sev: 'success' | 'error' } | null>(null);
  const notifier = (msg: string, sev: 'success' | 'error' = 'success') => setSnack({ msg, sev });
  const rechargerDomaines = () => aiConfigService.domains().then(setDomains).catch(() => {});
  const rechargerPacks = () => {
    aiConfigService.packs().then(setPacks).catch(() => {});
    aiConfigService.overview().then(setOverview).catch(() => {});
  };

  const [domDialog, setDomDialog] = useState(false);
  const [domEdit, setDomEdit] = useState<{ id?: number | null; domain_id: string; kw: string; tbl: string } | null>(null);
  const ouvrirDomaine = (d?: AiConfigDomain) => {
    setDomEdit(d
      ? { id: d.id, domain_id: d.domain_id, kw: d.keywords.join(', '), tbl: d.tables.join(', ') }
      : { domain_id: '', kw: '', tbl: '' });
    setDomDialog(true);
  };
  const saveDomaine = async () => {
    if (!domEdit) return;
    const payload = {
      domain_id: domEdit.domain_id.trim(),
      keywords: domEdit.kw.split(',').map((s) => s.trim()).filter(Boolean),
      tables: domEdit.tbl.split(',').map((s) => s.trim()).filter(Boolean),
    };
    try {
      if (domEdit.id) await aiConfigService.updateDomain(domEdit.id, payload);
      else await aiConfigService.createDomain(payload);
      setDomDialog(false);
      await rechargerDomaines();
      notifier('Domaine enregistré.');
    } catch (e: any) {
      notifier(e?.response?.data?.raison || 'Échec de l’enregistrement.', 'error');
    }
  };
  const supprimerDomaine = async (d: AiConfigDomain) => {
    if (!d.id || !window.confirm(`Supprimer le domaine « ${d.domain_id} » ?`)) return;
    try {
      await aiConfigService.deleteDomain(d.id);
      await rechargerDomaines();
      notifier('Domaine supprimé.');
    } catch (e: any) {
      notifier(e?.response?.data?.raison || 'Échec.', 'error');
    }
  };

  const [packDialog, setPackDialog] = useState(false);
  const [packDomain, setPackDomain] = useState('');
  const [packJson, setPackJson] = useState('');
  const ouvrirPack = (p: AiConfigPack) => {
    const { nb_cards, ...content } = p as any;
    setPackDomain(p.domain);
    setPackJson(JSON.stringify(content, null, 2));
    setPackDialog(true);
  };
  const savePack = async () => {
    let content: any;
    try {
      content = JSON.parse(packJson);
    } catch {
      notifier('JSON invalide.', 'error');
      return;
    }
    try {
      await aiConfigService.savePack(packDomain, content);
      setPackDialog(false);
      await rechargerPacks();
      notifier('Pack enregistré. Lancez « Réindexer » pour le classement sémantique.');
    } catch (e: any) {
      notifier(e?.response?.data?.raison || 'Échec de l’enregistrement.', 'error');
    }
  };
  const reindexer = async () => {
    try {
      await aiConfigService.reindex();
      notifier('Réindexation lancée en arrière-plan.');
    } catch {
      notifier('Échec du lancement de la réindexation.', 'error');
    }
  };

  // Édition active seulement si la config est externalisée en base (seedée).
  const editable = domains.length > 0 && domains[0].id != null;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <TuneIcon color="primary" />
        <Typography variant="h5" sx={{ fontWeight: 700 }}>
          Configuration IA
        </Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Tout ce qui paramètre les prompts : associations mot-clé ↔ table, packs de connaissances
        (jointures, valeurs, règles, définitions, requêtes-types), few-shots et réglages. L’onglet
        « Inspecteur » montre, pour une question, exactement ce qui sera injecté dans le prompt.
      </Typography>

      <Tabs value={tab} onChange={(_, v) => setTab(v)} variant="scrollable" scrollButtons="auto" sx={{ mb: 2 }}>
        <Tab label="Vue d’ensemble" />
        <Tab label="Domaines & mots-clés" />
        <Tab label="Packs" />
        <Tab label="Few-shots" />
        <Tab label="Inspecteur" />
        <Tab label="Usage" />
        <Tab label="Modèle externe" />
      </Tabs>

      {/* ---- Vue d’ensemble ---- */}
      {tab === 0 && (
        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Paper variant="outlined" sx={{ p: 2, flex: '1 1 320px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Compteurs</Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              {overview && Object.entries(overview.compteurs).map(([k, v]) => (
                <Chip key={k} label={`${k} : ${v}`} color="primary" variant="outlined" />
              ))}
            </Stack>
          </Paper>
          <Paper variant="outlined" sx={{ p: 2, flex: '2 1 480px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Réglages</Typography>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              {overview && Object.entries(overview.reglages).map(([k, v]) => (
                <Chip
                  key={k}
                  size="small"
                  label={`${k} = ${v}`}
                  color={v === true ? 'success' : v === false ? 'default' : 'info'}
                  variant="outlined"
                />
              ))}
            </Stack>
          </Paper>
        </Box>
      )}

      {/* ---- Domaines & mots-clés ---- */}
      {tab === 1 && (
        <Paper variant="outlined" sx={{ p: 1 }}>
          {!editable && (
            <Alert severity="info" sx={{ mb: 1 }}>
              Configuration non encore externalisée en base — édition désactivée. Lancez{' '}
              <code>python seed_ai_config.py</code> sur le serveur (fait par <code>deploy_all.sh</code>).
            </Alert>
          )}
          <Box sx={{ display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
            <Button size="small" startIcon={<AddIcon />} onClick={() => ouvrirDomaine()} disabled={!editable}>
              Ajouter un domaine
            </Button>
          </Box>
          <TableContainer sx={{ maxHeight: 520 }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 700 }}>Domaine</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Mots-clés déclencheurs</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Tables</TableCell>
                  <TableCell sx={{ fontWeight: 700 }} align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {domains.map((d, idx) => (
                  <TableRow key={d.id ?? idx} hover>
                    <TableCell><Chip size="small" label={d.domain_id} color="primary" /></TableCell>
                    <TableCell><ListeChips items={d.keywords} /></TableCell>
                    <TableCell><ListeChips items={d.tables} color="secondary" /></TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Tooltip title="Éditer">
                        <span>
                          <IconButton size="small" onClick={() => ouvrirDomaine(d)} disabled={!d.id}>
                            <EditIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                      <Tooltip title="Supprimer">
                        <span>
                          <IconButton size="small" color="error" onClick={() => supprimerDomaine(d)} disabled={!d.id}>
                            <DeleteIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      )}

      {/* ---- Packs ---- */}
      {tab === 2 && (
        <Box>
          <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1, mb: 1 }}>
            <Button size="small" startIcon={<RefreshIcon />} onClick={reindexer} disabled={!editable}>
              Réindexer (sémantique)
            </Button>
          </Box>
          {packs.map((p) => (
            <Accordion key={p.domain} variant="outlined" disableGutters>
              <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                <Stack direction="row" spacing={1} alignItems="center" sx={{ flexGrow: 1 }}>
                  <Chip size="small" label={p.domain} color="primary" />
                  <Typography variant="caption" color="text.secondary">
                    {p.joins.length} jointures · {p.enums.length} valeurs · {p.rules.length} règles ·{' '}
                    {p.docs.length} définitions · {p.patterns.length} modèles · {p.nb_cards} cards
                  </Typography>
                </Stack>
                <Tooltip title="Éditer le pack (JSON)">
                  <span>
                    <IconButton
                      size="small"
                      component="div"
                      onClick={(e) => { e.stopPropagation(); ouvrirPack(p); }}
                      disabled={!editable}
                    >
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </span>
                </Tooltip>
              </AccordionSummary>
              <AccordionDetails>
                <PackSection titre="Mots-clés / synonymes" items={[...p.keywords, ...p.synonyms]} />
                <PackSection titre="Tables" items={p.tables} />
                <PackSection titre="Jointures" items={p.joins} />
                <PackSection titre="Valeurs / enums" items={p.enums} />
                <PackSection titre="Règles" items={p.rules} />
                <PackSection titre="Définitions" items={p.docs} />
                {p.patterns.length > 0 && (
                  <>
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                      Requêtes-types
                    </Typography>
                    {p.patterns.map((pat, i) => (
                      <Box key={i} sx={{ mb: 1 }}>
                        {pat.intent && <Typography variant="caption">{pat.intent}</Typography>}
                        <Mono>{pat.sql}</Mono>
                      </Box>
                    ))}
                  </>
                )}
              </AccordionDetails>
            </Accordion>
          ))}
        </Box>
      )}

      {/* ---- Few-shots ---- */}
      {tab === 3 && (
        <Paper variant="outlined" sx={{ p: 1 }}>
          <Typography variant="caption" color="text.secondary" sx={{ px: 1 }}>
            {examples.total} exemple(s) — {examples.items.length} affiché(s)
          </Typography>
          <Box sx={{ maxHeight: 540, overflowY: 'auto', mt: 1 }}>
            {examples.items.map((e, i) => (
              <Box key={i} sx={{ px: 1, py: 0.5 }}>
                <Typography variant="body2">• {e.question}</Typography>
                {i < examples.items.length - 1 && <Divider sx={{ mt: 0.5 }} />}
              </Box>
            ))}
          </Box>
        </Paper>
      )}

      {/* ---- Inspecteur ---- */}
      {tab === 4 && (
        <Box>
          <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
            <TextField
              fullWidth
              size="small"
              placeholder="Tapez une question pour voir le prompt qui serait construit…"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') lancerInspect(); }}
            />
            <Button
              variant="contained"
              startIcon={loadingInspect ? <CircularProgress size={16} color="inherit" /> : <PlayArrowIcon />}
              onClick={lancerInspect}
              disabled={loadingInspect || !question.trim()}
            >
              Inspecter
            </Button>
          </Box>

          {erreur && <Alert severity="error" sx={{ mb: 2 }}>{erreur}</Alert>}

          {inspect && (
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                <Chip size="small" color="info" label={`~${inspect.tokens_estimes} tokens`} />
                <Chip size="small" variant="outlined" label={`CoT : ${inspect.cot ? 'oui' : 'non'}`} />
                {inspect.domaines.map((d) => <Chip key={d} size="small" color="primary" label={d} />)}
              </Stack>

              <InspectBlock titre="Tables retrouvées">
                <ListeChips items={inspect.tables} color="secondary" />
              </InspectBlock>
              <InspectBlock titre="Schéma injecté"><Mono>{inspect.schema || '(vide)'}</Mono></InspectBlock>
              {inspect.subgraph && (
                <InspectBlock titre="Jointures (Knowledge Graph)"><Mono>{inspect.subgraph}</Mono></InspectBlock>
              )}
              {inspect.connaissances && (
                <InspectBlock titre="Connaissances métier (cards/packs)"><Mono>{inspect.connaissances}</Mono></InspectBlock>
              )}
              {inspect.exemples && (
                <InspectBlock titre="Few-shots sélectionnés"><Mono>{inspect.exemples}</Mono></InspectBlock>
              )}
              <Accordion variant="outlined" disableGutters>
                <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                  <Typography variant="body2" sx={{ fontWeight: 700 }}>Prompt système complet</Typography>
                </AccordionSummary>
                <AccordionDetails><Mono>{inspect.prompt}</Mono></AccordionDetails>
              </Accordion>
            </Box>
          )}
        </Box>
      )}

      {/* ---- Usage ---- */}
      {tab === 5 && usage && (
        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Paper variant="outlined" sx={{ p: 2, flex: '1 1 240px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Feedback</Typography>
            <Stack direction="row" spacing={1}>
              <Chip color="success" label={`👍 ${usage.feedback.up}`} />
              <Chip color="error" label={`👎 ${usage.feedback.down}`} />
            </Stack>
          </Paper>
          <Paper variant="outlined" sx={{ p: 2, flex: '1 1 300px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
              Résultats des 30 derniers jours
            </Typography>
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
              {(usage.erreurs_30j || []).map((e) => (
                <Chip
                  key={e.type}
                  size="small"
                  color={e.type === 'succes' ? 'success' : 'error'}
                  variant={e.type === 'succes' ? 'filled' : 'outlined'}
                  label={`${e.type} : ${e.nb}`}
                />
              ))}
            </Stack>
          </Paper>
          <Paper variant="outlined" sx={{ p: 2, flex: '2 1 420px' }}>
            <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
              Co-occurrences de tables (usage)
            </Typography>
            {usage.cooccurrences.length === 0 ? (
              <Typography variant="body2" color="text.secondary">
                Aucune co-occurrence (lancez build_cooccurrence.py).
              </Typography>
            ) : (
              <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
                {usage.cooccurrences.map((c, i) => (
                  <Chip key={i} size="small" variant="outlined" label={`${c.src} ~ ${c.dst} (×${c.poids})`} />
                ))}
              </Stack>
            )}
          </Paper>
        </Box>
      )}

      {/* ---- Modèle externe ---- */}
      {tab === 6 && <ModeleExterneTab notifier={notifier} />}

      {/* ---- Dialogue édition domaine ---- */}
      <Dialog open={domDialog} onClose={() => setDomDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{domEdit?.id ? 'Éditer le domaine' : 'Nouveau domaine'}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label="domain_id" size="small" fullWidth value={domEdit?.domain_id || ''}
              onChange={(e) => setDomEdit((s) => s && { ...s, domain_id: e.target.value })}
              helperText="Doit correspondre au nom d'un pack (ex. fournisseurs, factures…)."
            />
            <TextField
              label="Mots-clés (séparés par des virgules)" size="small" fullWidth multiline
              value={domEdit?.kw || ''}
              onChange={(e) => setDomEdit((s) => s && { ...s, kw: e.target.value })}
            />
            <TextField
              label="Tables (schéma-qualifiées, séparées par des virgules)" size="small" fullWidth multiline
              value={domEdit?.tbl || ''}
              onChange={(e) => setDomEdit((s) => s && { ...s, tbl: e.target.value })}
              helperText="ex. raw_data.lfa1, raw_data.lfb1"
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDomDialog(false)}>Annuler</Button>
          <Button variant="contained" onClick={saveDomaine}>Enregistrer</Button>
        </DialogActions>
      </Dialog>

      {/* ---- Dialogue édition pack (JSON) ---- */}
      <Dialog open={packDialog} onClose={() => setPackDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>Éditer le pack « {packDomain} »</DialogTitle>
        <DialogContent>
          <Typography variant="caption" color="text.secondary">
            Édition JSON. Les requêtes-types (`patterns[].sql`) sont validées par sql_guard à l'enregistrement.
          </Typography>
          <TextField
            multiline minRows={16} fullWidth value={packJson}
            onChange={(e) => setPackJson(e.target.value)}
            InputProps={{ sx: { fontFamily: 'monospace', fontSize: 12, bgcolor: '#fff', color: '#000', mt: 1 } }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPackDialog(false)}>Annuler</Button>
          <Button variant="contained" onClick={savePack}>Enregistrer</Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={!!snack}
        autoHideDuration={5000}
        onClose={() => setSnack(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        {snack ? <Alert severity={snack.sev} onClose={() => setSnack(null)}>{snack.msg}</Alert> : undefined}
      </Snackbar>
    </Box>
  );
};

// ---- Onglet « Modèle externe » : bascule local (Ollama) / distant (OpenAI-compatible) ----
const ModeleExterneTab: React.FC<{ notifier: (m: string, s?: 'success' | 'error') => void }> = ({ notifier }) => {
  const [items, setItems] = useState<SettingItem[]>([]);
  const [values, setValues] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [health, setHealth] = useState<AiHealth | null>(null);

  const charger = async () => {
    setLoading(true);
    try {
      const cats = await settingsService.getAll();
      const ai = cats.find((c) => c.key === 'ai');
      const its = ai?.items || [];
      setItems(its);
      setValues(Object.fromEntries(its.map((i) => [i.key, i.value ?? ''])));
    } catch {
      notifier('Impossible de charger la configuration du modèle.', 'error');
    } finally {
      setLoading(false);
    }
    aiService.getHealth().then(setHealth).catch(() => setHealth(null));
  };

  useEffect(() => { charger(); }, []);

  const provider = (values['AI_PROVIDER'] || 'ollama').toLowerCase();
  const setVal = (key: string, v: string) => setValues((s) => ({ ...s, [key]: v }));

  const enregistrer = async () => {
    setSaving(true);
    try {
      await settingsService.update(values);
      notifier('Configuration enregistrée.');
      await charger();
    } catch (e: any) {
      notifier(e?.response?.data?.error || 'Échec de l’enregistrement.', 'error');
    } finally {
      setSaving(false);
    }
  };

  const tester = async () => {
    setTesting(true);
    try {
      const r = await settingsService.test('ai');
      notifier(r.success ? `Connexion OK. ${r.details || ''}` : (r.error || 'Échec du test.'),
               r.success ? 'success' : 'error');
    } catch (e: any) {
      notifier(e?.response?.data?.error || 'Échec du test de connexion.', 'error');
    } finally {
      setTesting(false);
    }
  };

  if (loading) {
    return <Box sx={{ p: 3, textAlign: 'center' }}><CircularProgress size={24} /></Box>;
  }

  // Champs hors AI_PROVIDER (rendu en sélecteur dédié).
  const champs = items.filter((i) => i.key !== 'AI_PROVIDER');

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      {/* État du fournisseur courant */}
      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
        <Chip
          icon={<CloudIcon />}
          color={health?.provider === 'openai' ? 'warning' : 'primary'}
          label={`Fournisseur : ${health?.provider === 'openai' ? 'Externe (OpenAI-compatible)' : 'Ollama local'}`}
        />
        {health && (
          <Chip
            size="small"
            color={health.available ? 'success' : 'error'}
            variant="outlined"
            label={health.available ? `disponible · ${health.model}` : `indisponible${health.error ? ' · ' + health.error : ''}`}
          />
        )}
      </Stack>

      {provider === 'openai' && (
        <Alert severity="warning">
          <strong>Mode externe actif.</strong> Les questions et le prompt (schéma des tables,
          exemples) sont envoyés à un service tiers (cloud) — contrairement au mode Ollama local
          où aucune donnée ne sort du serveur. À n’utiliser que sur des données autorisées.
        </Alert>
      )}

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack spacing={2}>
          {/* Sélecteur fournisseur actif */}
          <TextField
            select size="small" label="Fournisseur actif"
            value={provider}
            onChange={(e) => setVal('AI_PROVIDER', e.target.value)}
            sx={{ maxWidth: 360 }}
            helperText="Ollama : modèle local (aucune donnée vers le cloud). Externe : API OpenAI-compatible."
          >
            <MenuItem value="ollama">Ollama (local)</MenuItem>
            <MenuItem value="openai">Externe (OpenAI-compatible)</MenuItem>
          </TextField>

          <Divider />

          {/* Champs de connexion au modèle externe */}
          {champs.map((it) => (
            <TextField
              key={it.key}
              size="small"
              label={it.label}
              type={it.type === 'password' ? 'password' : (it.type === 'number' ? 'number' : 'text')}
              value={values[it.key] ?? ''}
              onChange={(e) => setVal(it.key, e.target.value)}
              sx={{ maxWidth: 520 }}
              helperText={it.secret ? 'Laisser ••••••••  pour conserver la clé existante.' : undefined}
            />
          ))}
        </Stack>

        <Stack direction="row" spacing={1} sx={{ mt: 2 }}>
          <Button
            variant="contained" startIcon={saving ? <CircularProgress size={16} color="inherit" /> : <SaveIcon />}
            onClick={enregistrer} disabled={saving}
          >
            Enregistrer
          </Button>
          <Button
            variant="outlined" startIcon={testing ? <CircularProgress size={16} /> : <PlayArrowIcon />}
            onClick={tester} disabled={testing}
          >
            Tester la connexion
          </Button>
        </Stack>
      </Paper>
    </Box>
  );
};

const PackSection: React.FC<{ titre: string; items: string[] }> = ({ titre, items }) =>
  items.length === 0 ? null : (
    <Box sx={{ mb: 1 }}>
      <Typography variant="caption" color="text.secondary">{titre}</Typography>
      {items.map((it, i) => (
        <Typography key={i} variant="body2" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
          • {it}
        </Typography>
      ))}
    </Box>
  );

const InspectBlock: React.FC<{ titre: string; children?: React.ReactNode }> = ({ titre, children }) => (
  <Box>
    <Typography variant="caption" color="text.secondary">{titre}</Typography>
    <Box sx={{ mt: 0.5 }}>{children}</Box>
  </Box>
);

export default ConfigurationIA;
