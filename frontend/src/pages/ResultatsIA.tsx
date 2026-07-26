import {
    Code as CodeIcon,
    ExpandMore as ExpandMoreIcon,
    NavigateNext as NextIcon,
    NavigateBefore as PrevIcon,
    PlayArrow as PlayArrowIcon,
    Refresh as RefreshIcon,
    RestartAlt as RestartAltIcon,
    Schedule as ScheduleIcon,
    School as SchoolIcon,
    TableChart as TableChartIcon,
    TableRows as TableRowsIcon,
    ThumbDownAlt as ThumbDownIcon,
    ThumbUpAlt as ThumbUpIcon,
} from '@mui/icons-material';
import SearchIcon from '@mui/icons-material/Search';
import {
    Accordion,
    AccordionDetails,
    AccordionSummary,
    Alert,
    Box,
    Button,
    Checkbox,
    Chip,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    FormControlLabel,
    IconButton,
    InputAdornment,
    MenuItem,
    Paper,
    Snackbar,
    Stack,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import ResultsTable from '../components/ai/ResultsTable';
import aiService, { AiHistoryItem, AiResult } from '../services/aiService';
import aiConfigService, { AiConfigPack } from '../services/aiConfigService';

/**
 * Page « Résultats IA » : liste les requêtes passées de l'assistant et permet
 * de rouvrir n'importe quel résultat réussi (tableau triable/filtrable + export
 * CSV/Excel + copie). Facilite la consultation hors du fil de conversation.
 *
 * Organisation : maître-détail responsive (liste à gauche / détail à droite,
 * empilés sur petit écran). Le détail affiche d'abord les métadonnées et le SQL
 * — instantanés — puis (re)joue le SQL pour reconstruire le tableau, car seul le
 * SQL est journalisé, pas les lignes de résultat.
 */

type StatutFiltre = 'tous' | 'succes' | 'rejete' | 'erreur';

const STATUT_OPTIONS: { value: StatutFiltre; label: string }[] = [
  { value: 'tous', label: 'Tous les statuts' },
  { value: 'succes', label: 'Succès' },
  { value: 'rejete', label: 'Rejetés' },
  { value: 'erreur', label: 'Erreurs' },
];

const statutColor = (statut: string): 'success' | 'warning' | 'error' =>
  statut === 'succes' ? 'success' : statut === 'rejete' ? 'warning' : 'error';

const formatDuree = (ms: number | null): string => {
  if (ms == null) return '—';
  return ms < 1000 ? `${ms} ms` : `${(ms / 1000).toFixed(1)} s`;
};

const ResultatsIA: React.FC = () => {
  const [items, setItems] = useState<AiHistoryItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [loadingList, setLoadingList] = useState(false);
  const [filtre, setFiltre] = useState('');
  const [statutFiltre, setStatutFiltre] = useState<StatutFiltre>('tous');

  const [selected, setSelected] = useState<AiHistoryItem | null>(null);
  const [result, setResult] = useState<AiResult | null>(null);
  const [loadingResult, setLoadingResult] = useState(false);
  const [sqlEdite, setSqlEdite] = useState('');
  const [vote, setVote] = useState<'up' | 'down' | null>(null);

  // Le vote cible la requête actuellement AFFICHÉE : après « Enregistrer et
  // relancer », c'est la nouvelle ligne (result.id_log), pas l'originale
  // sélectionnée — sinon on noterait la mauvaise requête.
  const envoyerVote = (v: 'up' | 'down') => {
    const cible = result?.id_log ?? selected?.id;
    if (!cible) return;
    const suivant = vote === v ? null : v;
    setVote(suivant);
    aiService.feedback(cible, suivant ?? 'none');
  };

  const loadHistory = async (p = page) => {
    setLoadingList(true);
    try {
      const res = await aiService.getHistory(p, false);
      setItems(res.items);
      setTotal(res.total);
      setPage(res.page);
      setPageSize(res.page_size);
    } catch {
      setItems([]);
      setTotal(0);
    } finally {
      setLoadingList(false);
    }
  };

  useEffect(() => {
    loadHistory(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Filtrage client (sur la page chargée) : texte sur la question + statut.
  const itemsAffiches = useMemo(() => {
    const q = filtre.trim().toLowerCase();
    return items.filter((it) => {
      if (statutFiltre !== 'tous' && it.statut !== statutFiltre) return false;
      if (q && !(it.question || '').toLowerCase().includes(q)) return false;
      return true;
    });
  }, [items, filtre, statutFiltre]);

  // Charge (ou recharge) le résultat en rejouant le SQL journalisé. Autorisé
  // aussi pour les requêtes échouées : un SQL en erreur (ex. timeout, bug déjà
  // corrigé) peut désormais réussir ; un SQL rejeté repassera par sql_guard.
  const chargerResultat = async (it: AiHistoryItem) => {
    if (!it.id) return;
    setResult(null);
    setLoadingResult(true);
    try {
      const r = await aiService.rerun(it.id);
      setResult(r);
    } catch (e: any) {
      setResult({ statut: 'erreur', raison: e?.message || 'Échec du rechargement.' });
    } finally {
      setLoadingResult(false);
    }
  };

  // Sélection d'une ligne : on affiche aussitôt les métadonnées + le SQL (éditable),
  // et on lance le rejeu du résultat uniquement pour les requêtes réussies.
  const selectionner = (it: AiHistoryItem) => {
    setSelected(it);
    setResult(null);
    setSqlEdite(it.sql_genere ?? '');
    setVote((it.feedback as 'up' | 'down' | null) ?? null);
    if (it.statut === 'succes' && it.id) {
      chargerResultat(it);
    }
  };

  // Exécute le SQL édité à l'écran : validé par sql_guard, exécuté en lecture
  // seule et journalisé (= « enregistré »). Rafraîchit la liste pour faire
  // apparaître la nouvelle entrée.
  const lancerSqlEdite = async () => {
    if (!selected || !sqlEdite.trim()) return;
    setResult(null);
    setLoadingResult(true);
    try {
      const r = await aiService.runSql(sqlEdite, selected.question ?? undefined);
      setResult(r);
      // Une requête éditée+relancée à succès est auto-marquée 'up' côté serveur
      // (elle devient few-shot vivant / hit de cache) : on reflète ce vote dans l'UI.
      if (r.statut === 'succes') setVote('up');
      loadHistory(page);
    } catch (e: any) {
      setResult({ statut: 'erreur', raison: e?.message || "Échec de l'exécution." });
    } finally {
      setLoadingResult(false);
    }
  };

  // ----- Promotion vers la Configuration IA -----
  const [promoteOpen, setPromoteOpen] = useState(false);
  const [promotePacks, setPromotePacks] = useState<AiConfigPack[]>([]);
  const [promoteDomain, setPromoteDomain] = useState('');
  const [promoteIntent, setPromoteIntent] = useState('');
  const [promoteSql, setPromoteSql] = useState('');
  const [promoteMapping, setPromoteMapping] = useState(true);
  const [promoteBusy, setPromoteBusy] = useState(false);
  const [snack, setSnack] = useState<{ msg: string; sev: 'success' | 'error' } | null>(null);

  const ouvrirPromote = async () => {
    if (!selected) return;
    setPromoteSql((result?.sql ?? sqlEdite ?? '').trim());
    setPromoteIntent((selected.question ?? '').slice(0, 120));
    setPromoteMapping(true);
    setPromotePacks([]);
    setPromoteDomain('');
    setPromoteOpen(true);
    try {
      const [packsList, dets] = await Promise.all([
        aiConfigService.packs(),
        aiConfigService.detect(selected.question ?? ''),
      ]);
      setPromotePacks(packsList);
      setPromoteDomain(dets[0] ?? packsList[0]?.domain ?? '');
    } catch {
      setPromotePacks([]);
    }
  };

  const confirmerPromote = async () => {
    if (!selected || !promoteDomain || !promoteSql.trim()) return;
    setPromoteBusy(true);
    try {
      const r = await aiConfigService.promote({
        question: selected.question ?? '',
        sql: promoteSql,
        domain: promoteDomain,
        intent: promoteIntent,
        ajouter_mapping: promoteMapping,
      });
      if (r.statut === 'succes') {
        setPromoteOpen(false);
        const tAdd = r.tables_ajoutees?.length ? ` (+${r.tables_ajoutees.length} table(s))` : '';
        setSnack({ msg: `Ajouté aux connaissances du domaine « ${promoteDomain} »${tAdd}.`, sev: 'success' });
      } else {
        setSnack({ msg: r.raison || 'Échec de l’ajout.', sev: 'error' });
      }
    } catch (e: any) {
      setSnack({ msg: e?.message || 'Échec de l’ajout.', sev: 'error' });
    } finally {
      setPromoteBusy(false);
    }
  };

  const nbPages = Math.max(1, Math.ceil(total / pageSize));
  const enErreur = selected && selected.statut !== 'succes';

  return (
    <Box sx={{ p: 3 }}>
      {/* En-tête */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <TableChartIcon color="primary" />
        <Typography variant="h5" sx={{ fontWeight: 700 }}>
          Résultats IA
        </Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Retrouvez et rouvrez les résultats des questions posées à l'assistant. Sélectionnez
        une requête pour voir son SQL ; les requêtes réussies réaffichent leur tableau
        (triable, filtrable, exportable).
      </Typography>

      {/* Barre d'outils */}
      <Paper variant="outlined" sx={{ p: 1.5, mb: 2 }}>
        <Box sx={{ display: 'flex', gap: 1.5, alignItems: 'center', flexWrap: 'wrap' }}>
          <TextField
            size="small"
            placeholder="Rechercher une question…"
            value={filtre}
            onChange={(e) => setFiltre(e.target.value)}
            sx={{ flexGrow: 1, minWidth: 220 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" />
                </InputAdornment>
              ),
            }}
          />
          <TextField
            size="small"
            select
            label="Statut"
            value={statutFiltre}
            onChange={(e) => setStatutFiltre(e.target.value as StatutFiltre)}
            sx={{ width: 170 }}
          >
            {STATUT_OPTIONS.map((o) => (
              <MenuItem key={o.value} value={o.value}>
                {o.label}
              </MenuItem>
            ))}
          </TextField>
          <Tooltip title="Rafraîchir la liste">
            <IconButton size="small" onClick={() => loadHistory(page)} disabled={loadingList}>
              {loadingList ? <CircularProgress size={18} /> : <RefreshIcon fontSize="small" />}
            </IconButton>
          </Tooltip>
        </Box>
        {(filtre || statutFiltre !== 'tous') && (
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
            {itemsAffiches.length} requête(s) affichée(s) sur cette page (filtre appliqué côté
            client à la page courante).
          </Typography>
        )}
      </Paper>

      {/* Maître-détail responsive */}
      <Box
        sx={{
          display: 'flex',
          gap: 2,
          alignItems: 'flex-start',
          flexDirection: { xs: 'column', md: 'row' },
        }}
      >
        {/* Liste des requêtes passées */}
        <Paper
          variant="outlined"
          sx={{ p: 1.5, width: { xs: '100%', md: 440 }, flexShrink: 0 }}
        >
          <TableContainer sx={{ maxHeight: 540 }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 700 }}>Date</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Question</TableCell>
                  <TableCell sx={{ fontWeight: 700 }} align="right">Lignes</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {itemsAffiches.map((it) => {
                  const openable = it.statut === 'succes' && !!it.id;
                  return (
                    <TableRow
                      key={it.id}
                      hover
                      selected={selected?.id === it.id}
                      onClick={() => selectionner(it)}
                      sx={{ cursor: 'pointer' }}
                    >
                      <TableCell sx={{ whiteSpace: 'nowrap', verticalAlign: 'top' }}>
                        {new Date(it.date_creation).toLocaleString('fr-FR')}
                      </TableCell>
                      <TableCell>
                        <Typography variant="caption" sx={{ display: 'block', mb: 0.5 }}>
                          {it.question}
                        </Typography>
                        <Stack direction="row" spacing={0.5} alignItems="center">
                          <Chip
                            size="small"
                            label={it.statut}
                            color={statutColor(it.statut)}
                            variant={openable ? 'filled' : 'outlined'}
                            sx={{ height: 18, fontSize: 11 }}
                          />
                          {it.duree_ms != null && (
                            <Typography variant="caption" color="text.secondary">
                              {formatDuree(it.duree_ms)}
                            </Typography>
                          )}
                        </Stack>
                      </TableCell>
                      <TableCell align="right" sx={{ verticalAlign: 'top' }}>
                        {it.nb_lignes ?? ''}
                      </TableCell>
                    </TableRow>
                  );
                })}
                {!itemsAffiches.length && !loadingList && (
                  <TableRow>
                    <TableCell colSpan={3}>
                      <Typography variant="body2" color="text.secondary" sx={{ p: 1 }}>
                        Aucune requête à afficher.
                      </Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>

          {/* Pagination */}
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mt: 1 }}>
            <Typography variant="caption" color="text.secondary">
              {total} requête(s) — page {page}/{nbPages}
            </Typography>
            <Box>
              <IconButton
                size="small"
                disabled={page <= 1 || loadingList}
                onClick={() => loadHistory(page - 1)}
              >
                <PrevIcon fontSize="small" />
              </IconButton>
              <IconButton
                size="small"
                disabled={page >= nbPages || loadingList}
                onClick={() => loadHistory(page + 1)}
              >
                <NextIcon fontSize="small" />
              </IconButton>
            </Box>
          </Box>
        </Paper>

        {/* Détail du résultat sélectionné */}
        <Box sx={{ flexGrow: 1, minWidth: 0, width: '100%' }}>
          {!selected && (
            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center' }}>
              <TableRowsIcon sx={{ fontSize: 40, color: 'text.disabled', mb: 1 }} />
              <Typography variant="body2" color="text.secondary">
                Sélectionnez une requête à gauche pour afficher son détail.
              </Typography>
            </Paper>
          )}

          {selected && (
            <Paper variant="outlined" sx={{ p: 2 }}>
              {/* En-tête du détail : question + métadonnées */}
              <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 1 }}>
                {selected.question}
              </Typography>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
                <Chip size="small" label={selected.statut} color={statutColor(selected.statut)} />
                <Chip
                  size="small"
                  variant="outlined"
                  label={new Date(selected.date_creation).toLocaleString('fr-FR')}
                />
                {selected.utilisateur && (
                  <Chip size="small" variant="outlined" label={selected.utilisateur} />
                )}
                <Chip
                  size="small"
                  variant="outlined"
                  icon={<ScheduleIcon />}
                  label={formatDuree(selected.duree_ms)}
                />
                {selected.nb_lignes != null && (
                  <Chip
                    size="small"
                    variant="outlined"
                    icon={<TableRowsIcon />}
                    label={`${selected.nb_lignes} ligne(s)`}
                  />
                )}
                {selected.id && (
                  <>
                    <Box sx={{ flexGrow: 1 }} />
                    <Tooltip title="Bonne réponse — la réutiliser comme exemple">
                      <IconButton
                        size="small"
                        color={vote === 'up' ? 'success' : 'default'}
                        onClick={() => envoyerVote('up')}
                      >
                        <ThumbUpIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Réponse incorrecte">
                      <IconButton
                        size="small"
                        color={vote === 'down' ? 'error' : 'default'}
                        onClick={() => envoyerVote('down')}
                      >
                        <ThumbDownIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </>
                )}
              </Stack>

              {/* SQL généré — éditable (texte noir sur fond blanc) */}
              <Accordion variant="outlined" disableGutters defaultExpanded sx={{ mb: 1.5 }}>
                <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <CodeIcon fontSize="small" color="action" />
                    <Typography variant="body2">SQL généré (éditable)</Typography>
                  </Stack>
                </AccordionSummary>
                <AccordionDetails>
                  <TextField
                    multiline
                    minRows={4}
                    fullWidth
                    value={sqlEdite}
                    onChange={(e) => setSqlEdite(e.target.value)}
                    placeholder="SELECT ..."
                    InputProps={{
                      sx: {
                        bgcolor: '#ffffff',
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: '#000000',
                        alignItems: 'flex-start',
                      },
                    }}
                    sx={{
                      '& textarea': { color: '#000000' },
                      '& .MuiInputBase-input::placeholder': { color: '#888' },
                    }}
                  />
                  <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                    <Button
                      size="small"
                      variant="contained"
                      startIcon={
                        loadingResult ? <CircularProgress size={14} color="inherit" /> : <PlayArrowIcon />
                      }
                      onClick={lancerSqlEdite}
                      disabled={loadingResult || !sqlEdite.trim()}
                    >
                      Enregistrer et relancer
                    </Button>
                    <Button
                      size="small"
                      startIcon={<RestartAltIcon />}
                      onClick={() => setSqlEdite(selected.sql_genere ?? '')}
                      disabled={loadingResult || sqlEdite === (selected.sql_genere ?? '')}
                    >
                      Réinitialiser
                    </Button>
                    {result?.statut === 'succes' && (
                      <Button
                        size="small"
                        color="secondary"
                        startIcon={<SchoolIcon />}
                        onClick={ouvrirPromote}
                      >
                        Ajouter aux connaissances IA
                      </Button>
                    )}
                  </Stack>
                </AccordionDetails>
              </Accordion>

              {/* Échec d'origine (tel que journalisé) pour les requêtes ratées */}
              {enErreur && (
                <Alert severity={selected.statut === 'rejete' ? 'warning' : 'error'} sx={{ mb: 1 }}>
                  <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 0.5 }}>
                    {selected.statut === 'rejete' ? 'Rejet initial' : 'Erreur initiale'}
                  </Typography>
                  <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                    {selected.raison_rejet || 'Aucun détail enregistré.'}
                  </Typography>
                </Alert>
              )}

              <Divider sx={{ mb: 1 }}>
                <Typography variant="caption" color="text.secondary">
                  Résultat
                </Typography>
              </Divider>

              {loadingResult && (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, py: 2 }}>
                  <CircularProgress size={18} />
                  <Typography variant="body2" color="text.secondary">
                    Exécution du SQL en cours…
                  </Typography>
                </Box>
              )}

              {!loadingResult && !result && !enErreur && (
                <Typography variant="body2" color="text.secondary" sx={{ py: 1 }}>
                  Aucun résultat chargé.
                </Typography>
              )}

              {!loadingResult && result && result.statut !== 'succes' && (
                <Alert severity={result.statut === 'rejete' ? 'warning' : 'error'}>
                  <strong>{result.statut === 'rejete' ? 'Toujours rejeté' : 'Échec du rejeu'}.</strong>{' '}
                  {result.raison || 'Impossible de recharger ce résultat.'}
                </Alert>
              )}

              {!loadingResult && result && result.statut === 'succes' && (
                <>
                  {enErreur && (
                    <Alert severity="success" sx={{ mb: 1 }}>
                      Le rejeu a réussi cette fois-ci.
                    </Alert>
                  )}
                  <ResultsTable
                    colonnes={result.colonnes ?? []}
                    lignes={result.lignes ?? []}
                    idLog={result.id_log ?? selected.id}
                    sql={result.sql ?? sqlEdite ?? undefined}
                    maxHeight={520}
                  />
                </>
              )}
            </Paper>
          )}
        </Box>
      </Box>

      {/* Dialogue : promouvoir la requête vers la Configuration IA */}
      <Dialog open={promoteOpen} onClose={() => setPromoteOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>Ajouter aux connaissances IA</DialogTitle>
        <DialogContent>
          {promotePacks.length === 0 ? (
            <Alert severity="info" sx={{ mt: 1 }}>
              Configuration non externalisée en base (ou aucun pack) — lancez{' '}
              <code>seed_ai_config.py</code> sur le serveur avant de promouvoir.
            </Alert>
          ) : (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                select size="small" fullWidth label="Domaine cible"
                value={promoteDomain} onChange={(e) => setPromoteDomain(e.target.value)}
                helperText="La requête-type sera ajoutée au pack de ce domaine."
              >
                {promotePacks.map((p) => (
                  <MenuItem key={p.domain} value={p.domain}>{p.domain}</MenuItem>
                ))}
              </TextField>
              <TextField
                size="small" fullWidth label="Intitulé (intent)"
                value={promoteIntent} onChange={(e) => setPromoteIntent(e.target.value)}
              />
              <TextField
                multiline minRows={5} fullWidth label="SQL (requête-type)"
                value={promoteSql} onChange={(e) => setPromoteSql(e.target.value)}
                InputProps={{ sx: { fontFamily: 'monospace', fontSize: 12, bgcolor: '#fff', color: '#000' } }}
              />
              <FormControlLabel
                control={<Checkbox checked={promoteMapping} onChange={(e) => setPromoteMapping(e.target.checked)} />}
                label="Compléter aussi les mots-clés↔tables du domaine (tables utilisées par la requête)"
              />
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPromoteOpen(false)}>Annuler</Button>
          <Button
            variant="contained"
            onClick={confirmerPromote}
            disabled={promoteBusy || promotePacks.length === 0 || !promoteDomain || !promoteSql.trim()}
            startIcon={promoteBusy ? <CircularProgress size={14} color="inherit" /> : <SchoolIcon />}
          >
            Ajouter
          </Button>
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

export default ResultatsIA;
