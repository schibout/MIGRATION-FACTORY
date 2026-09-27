import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert, Autocomplete, Box, Button, Card, CardContent, Checkbox, Chip, CircularProgress,
  Dialog, DialogActions, DialogContent, DialogTitle, FormControlLabel, Grid, IconButton,
  LinearProgress, Paper, Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  TextField, Tooltip, Typography,
} from '@mui/material';
import {
  Refresh as RefreshIcon, PlayArrow as StartIcon, Visibility as ViewIcon, Stop as StopIcon,
  CheckCircle as CheckIcon, ErrorOutline as ErrorIcon, Schedule as PendingIcon,
} from '@mui/icons-material';
import { format } from 'date-fns';
import extractionService, { ExtractionLog, TextesJob, TextesObjet } from '../services/extractionService';
import LogPanel from '../components/extraction/LogPanel';

/**
 * Extraction des textes longs SAP (STXH/STXL) vers raw_data.sap_long_text.
 *
 * Le contenu d'un texte long n'est pas lisible par l'extraction de tables
 * (STXL.CLUSTD est un cluster compresse) : il est lu par RFC_READ_TEXT dans
 * un job du conteneur sap-extraction, puis recompose par les ETL
 * (part_catalog.info_text, purchase_part_supplier.note_text...). Apres une
 * extraction, rejouer le module ETL concerne dans l'ecran ETL.
 */

const TERMINAL = new Set(['completed', 'failed', 'cancelled']);
const isTerminal = (s?: string) => TERMINAL.has((s || '').toLowerCase());

const StatusChip = ({ status }: { status?: string }) => {
  switch ((status || '').toLowerCase()) {
    case 'completed':
      return <Chip icon={<CheckIcon />} label="Terminé" color="success" size="small" />;
    case 'failed':
      return <Chip icon={<ErrorIcon />} label="Échec" color="error" size="small" />;
    case 'running':
      return <Chip icon={<CircularProgress size={12} />} label="En cours" color="primary" size="small" />;
    case 'pending':
      return <Chip icon={<PendingIcon />} label="En attente" color="warning" size="small" />;
    case 'cancelled':
      return <Chip label="Annulé" color="default" size="small" />;
    default:
      return <Chip label={status || '?'} size="small" />;
  }
};

const fmtDate = (d?: string | null) => {
  if (!d || isNaN(Date.parse(d))) return '-';
  return format(new Date(d), 'dd/MM/yyyy HH:mm:ss');
};
const fmtDuration = (s?: number | null) => (s == null ? '-' : s < 60 ? `${s.toFixed(1)}s` : `${Math.floor(s / 60)}m${Math.round(s % 60)}s`);
const fmtInt = (n?: number | null) => (n == null ? '-' : n.toLocaleString('fr-FR'));

// Objets dont un ETL exploite deja le contenu (info pour l'utilisateur)
const CIBLES_ETL: Record<string, string> = {
  MATERIAL: 'BEST → part_catalog.info_text (module inventory)',
  EINA: "AT → purchase_part_supplier.note_text (module inventory, avec EINE)",
  EINE: 'BT → purchase_part_supplier.note_text (module inventory, avec EINA)',
};

const TextesExtraction = () => {
  const [inventaire, setInventaire] = useState<TextesObjet[]>([]);
  const [jobs, setJobs] = useState<TextesJob[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Lanceur
  const [objet, setObjet] = useState<string | null>('MATERIAL');
  const [tdids, setTdids] = useState<string[]>([]);
  const [langues, setLangues] = useState<string[]>([]);
  const [purge, setPurge] = useState(false);
  const [launching, setLaunching] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  // Détails
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [detailsJobId, setDetailsJobId] = useState<string | null>(null);
  const [detail, setDetail] = useState<TextesJob | null>(null);
  const [logs, setLogs] = useState<ExtractionLog[]>([]);
  const [cancelling, setCancelling] = useState<string | null>(null);

  const refreshingRef = useRef(false);

  const refresh = useCallback(async () => {
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    setLoading(true);
    try {
      const [inv, js] = await Promise.all([
        extractionService.getTextesObjets(),
        extractionService.getTextesJobs(30),
      ]);
      setInventaire(Array.isArray(inv) ? inv : []);
      setJobs(Array.isArray(js) ? js : []);
      setError(null);
    } catch (e: any) {
      setError(e?.response?.data?.error || e?.message || 'Erreur de chargement');
    } finally {
      setLoading(false);
      refreshingRef.current = false;
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  // Auto-refresh 5 s tant qu'un job est actif
  useEffect(() => {
    if (!jobs.some((j) => !isTerminal(j.status))) return;
    const iv = setInterval(refresh, 5000);
    return () => clearInterval(iv);
  }, [jobs, refresh]);

  // Objets, types et langues proposés, dérivés de l'inventaire STXH
  const objets = useMemo(() => {
    const totaux = new Map<string, number>();
    inventaire.forEach((r) => totaux.set(r.objet, (totaux.get(r.objet) || 0) + r.entetes));
    return Array.from(totaux.entries()).sort((a, b) => b[1] - a[1]).map(([o]) => o);
  }, [inventaire]);
  const lignesObjet = useMemo(() => inventaire.filter((r) => r.objet === objet), [inventaire, objet]);
  const tdidsDispo = useMemo(() => Array.from(new Set(lignesObjet.map((r) => r.tdid))).sort(), [lignesObjet]);
  const languesDispo = useMemo(() => Array.from(new Set(lignesObjet.map((r) => r.langue))).sort(), [lignesObjet]);
  const totalObjet = (o: string) => inventaire.filter((r) => r.objet === o).reduce((n, r) => n + r.entetes, 0);
  const selection = lignesObjet.filter(
    (r) => (tdids.length === 0 || tdids.includes(r.tdid)) && (langues.length === 0 || langues.includes(r.langue)),
  );
  const totalSelection = selection.reduce((n, r) => n + r.entetes, 0);

  const handleLaunch = async () => {
    if (!objet) return;
    setLaunching(true);
    setError(null);
    setMessage(null);
    try {
      const r = await extractionService.extractTextes(objet, { tdids, langues, purge });
      setMessage(`Extraction ${r.objet} lancée (job ${r.textes_job_id.substring(0, 8)}…). ` +
        'Une fois terminée, rejouer le module ETL concerné dans l\'écran ETL.');
      await refresh();
    } catch (e: any) {
      setError(e?.response?.data?.error || e?.message || 'Erreur lors du lancement');
    } finally {
      setLaunching(false);
    }
  };

  const openDetails = async (jobId: string) => {
    setDetailsJobId(jobId);
    setLogs([]);
    try {
      setDetail(await extractionService.getTextesStatus(jobId));
      setDetailsOpen(true);
      extractionService.getTextesLogs(jobId, 200).then(setLogs).catch(() => {});
    } catch (e) { console.error(e); }
  };
  const closeDetails = () => { setDetailsOpen(false); setDetailsJobId(null); setLogs([]); };

  useEffect(() => {
    if (!detailsOpen || !detailsJobId || isTerminal(detail?.status)) return;
    const iv = setInterval(() => {
      extractionService.getTextesStatus(detailsJobId).then(setDetail).catch(() => {});
      extractionService.getTextesLogs(detailsJobId, 200).then(setLogs).catch(() => {});
    }, 2000);
    return () => clearInterval(iv);
  }, [detailsOpen, detailsJobId, detail?.status]);

  const handleCancel = async (jobId: string) => {
    setCancelling(jobId);
    try {
      await extractionService.cancelTextesJob(jobId);
      await refresh();
    } finally {
      setCancelling(null);
    }
  };

  const jobActif = jobs.some((j) => !isTerminal(j.status));

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ mb: 3 }}>TEXTES LONGS SAP</Typography>

      {/* Lanceur */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Nouvelle extraction de textes</Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Lit le contenu des textes longs d'un objet SAP (en-têtes <b>STXH</b> déjà extraits, contenu
            lu par <b>RFC_READ_TEXT</b>) vers <code>raw_data.sap_long_text</code>. Le lot remplace les textes
            déjà chargés pour les mêmes objet / type / langue. Un seul job à la fois.
          </Typography>
          <Grid container spacing={1.5} alignItems="center">
            <Grid item xs={12} md={3}>
              <Autocomplete
                size="small"
                options={objets}
                value={objet}
                onChange={(_, v) => { setObjet(v); setTdids([]); setLangues([]); }}
                getOptionLabel={(o) => o}
                renderOption={(props, o) => (
                  <li {...props} key={o}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
                      <span>{o}</span>
                      <Typography variant="caption" color="text.secondary">{fmtInt(totalObjet(o))}</Typography>
                    </Box>
                  </li>
                )}
                renderInput={(params) => <TextField {...params} label="Objet SAP (STXH.TDOBJECT)" />}
              />
            </Grid>
            <Grid item xs={12} md={3}>
              <Autocomplete
                multiple size="small" options={tdidsDispo} value={tdids} onChange={(_, v) => setTdids(v)}
                renderInput={(params) => <TextField {...params} label="Types de texte (vide = tous)" />}
              />
            </Grid>
            <Grid item xs={12} md={2}>
              <Autocomplete
                multiple size="small" options={languesDispo} value={langues} onChange={(_, v) => setLangues(v)}
                renderInput={(params) => <TextField {...params} label="Langues (vide = toutes)" />}
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
                <FormControlLabel
                  control={<Checkbox checked={purge} onChange={(e) => setPurge(e.target.checked)} size="small" color="warning" />}
                  label="Purger toute la table avant"
                />
                <Box sx={{ flex: 1 }} />
                <Button
                  variant="contained"
                  startIcon={launching ? <CircularProgress size={18} /> : <StartIcon />}
                  disabled={launching || !objet || jobActif || totalSelection === 0}
                  onClick={handleLaunch}
                >
                  Lancer ({fmtInt(totalSelection)} textes)
                </Button>
              </Box>
            </Grid>
          </Grid>
          {objet && CIBLES_ETL[objet] && (
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
              Exploité par l'ETL : {CIBLES_ETL[objet]}
            </Typography>
          )}
          {message && <Alert severity="success" sx={{ mt: 2 }} onClose={() => setMessage(null)}>{message}</Alert>}
          {error && <Alert severity="error" sx={{ mt: 2 }} onClose={() => setError(null)}>{error}</Alert>}

          {/* Inventaire de l'objet choisi */}
          {lignesObjet.length > 0 && (
            <TableContainer component={Paper} variant="outlined" sx={{ mt: 2, maxHeight: 260 }}>
              <Table size="small" stickyHeader>
                <TableHead>
                  <TableRow>
                    <TableCell>Type</TableCell>
                    <TableCell>Langue</TableCell>
                    <TableCell align="right">En-têtes STXH</TableCell>
                    <TableCell align="right">Déjà chargés</TableCell>
                    <TableCell>Dernier chargement</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {lignesObjet.map((r) => {
                    const retenu = selection.includes(r);
                    return (
                      <TableRow key={`${r.tdid}-${r.langue}`} sx={{ opacity: retenu ? 1 : 0.45 }}>
                        <TableCell sx={{ fontFamily: 'monospace' }}>{r.tdid}</TableCell>
                        <TableCell>{r.langue}</TableCell>
                        <TableCell align="right">{fmtInt(r.entetes)}</TableCell>
                        <TableCell align="right">
                          <Typography variant="body2" color={r.charges >= r.entetes ? 'success.main' : r.charges ? 'warning.main' : 'text.disabled'}>
                            {fmtInt(r.charges)}
                          </Typography>
                        </TableCell>
                        <TableCell sx={{ fontSize: '0.75rem' }}>{fmtDate(r.loadedAt)}</TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>

      {/* Liste des jobs */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
        <Typography variant="h6">Jobs d'extraction de textes</Typography>
        <Button variant="outlined" size="small" startIcon={<RefreshIcon />} onClick={refresh} disabled={loading}>
          Actualiser
        </Button>
      </Box>
      {loading && <LinearProgress sx={{ mb: 1 }} />}

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Objet</TableCell>
              <TableCell>Types / langues</TableCell>
              <TableCell>Statut</TableCell>
              <TableCell align="right">Textes lus</TableCell>
              <TableCell align="right">Lignes chargées</TableCell>
              <TableCell>Démarré</TableCell>
              <TableCell>Durée</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {jobs.length === 0 && (
              <TableRow><TableCell colSpan={9} align="center" sx={{ py: 4, color: 'text.disabled' }}>Aucun job (les jobs sont oubliés au redémarrage du service SAP)</TableCell></TableRow>
            )}
            {jobs.map((job) => {
              const active = !isTerminal(job.status);
              return (
                <TableRow key={job.id}>
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }} title={job.id}>
                    {job.id?.length > 12 ? `${job.id.substring(0, 8)}…` : job.id}
                  </TableCell>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{job.objet}</TableCell>
                  <TableCell sx={{ fontSize: '0.75rem' }}>
                    {(job.tdids || ['tous']).join(', ')} / {(job.langues || ['toutes']).join(', ')}
                    {job.purge && <Chip label="purge" size="small" color="warning" sx={{ ml: 1 }} />}
                  </TableCell>
                  <TableCell>
                    <StatusChip status={job.status} />
                    {active && job.clesTotal ? (
                      <Typography variant="caption" sx={{ ml: 1 }}>{job.progress}%</Typography>
                    ) : null}
                  </TableCell>
                  <TableCell align="right">{fmtInt(job.textesLus)}{job.clesTotal ? ` / ${fmtInt(job.clesTotal)}` : ''}</TableCell>
                  <TableCell align="right">{fmtInt(job.lignesInserees)}</TableCell>
                  <TableCell sx={{ fontSize: '0.75rem' }}>{fmtDate(job.startedAt)}</TableCell>
                  <TableCell>{fmtDuration(job.duration)}</TableCell>
                  <TableCell align="center" sx={{ whiteSpace: 'nowrap' }}>
                    {active && (
                      <Tooltip title="Annuler (rien n'est chargé)">
                        <IconButton size="small" color="error" onClick={() => handleCancel(job.id)} disabled={cancelling === job.id}>
                          <StopIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    <Tooltip title="Détails">
                      <IconButton size="small" color="primary" onClick={() => openDetails(job.id)}>
                        <ViewIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Dialogue détails + logs live */}
      <Dialog open={detailsOpen} onClose={closeDetails} maxWidth="md" fullWidth>
        <DialogTitle>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            Extraction textes {detail?.objet}
            <StatusChip status={detail?.status} />
          </Box>
        </DialogTitle>
        <DialogContent>
          {detail && (
            <>
              <Grid container spacing={2} sx={{ mb: 2, mt: 0 }}>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">ID</Typography>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{detail.id}</Typography>
                </Grid>
                <Grid item xs={2}>
                  <Typography variant="caption" color="text.secondary">Textes lus</Typography>
                  <Typography variant="body2">{fmtInt(detail.textesLus)}{detail.clesTotal ? ` / ${fmtInt(detail.clesTotal)}` : ''}</Typography>
                </Grid>
                <Grid item xs={2}>
                  <Typography variant="caption" color="text.secondary">Absents</Typography>
                  <Typography variant="body2">{fmtInt(detail.absents)}</Typography>
                </Grid>
                <Grid item xs={2}>
                  <Typography variant="caption" color="text.secondary">Lignes chargées</Typography>
                  <Typography variant="body2">{fmtInt(detail.lignesInserees)}</Typography>
                </Grid>
                <Grid item xs={12}>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <LinearProgress variant="determinate" value={detail.progress ?? 0} sx={{ flex: 1, height: 8, borderRadius: 4 }} />
                    <Typography variant="body2">{Math.round(detail.progress ?? 0)}%</Typography>
                  </Box>
                </Grid>
                {detail.error && (
                  <Grid item xs={12}><Typography variant="body2" color="error">{detail.error}</Typography></Grid>
                )}
              </Grid>
              <LogPanel logs={logs} live={!isTerminal(detail.status)} height={260} />
            </>
          )}
        </DialogContent>
        <DialogActions>
          {detail && !isTerminal(detail.status) && (
            <Button color="error" startIcon={<StopIcon />} onClick={() => handleCancel(detail.id)} disabled={cancelling === detail.id}>
              Annuler le job
            </Button>
          )}
          <Button onClick={closeDetails}>Fermer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default TextesExtraction;
