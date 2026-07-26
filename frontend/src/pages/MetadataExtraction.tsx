import { Fragment, useCallback, useEffect, useRef, useState } from 'react';
import {
  Box, Button, Card, CardContent, Checkbox, Chip, CircularProgress, Collapse,
  Dialog, DialogActions, DialogContent, DialogTitle, FormControlLabel, Grid,
  IconButton, LinearProgress, Paper, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, TextField, Tooltip, Typography,
} from '@mui/material';
import {
  Refresh as RefreshIcon, PlayArrow as StartIcon, Visibility as ViewIcon,
  Stop as StopIcon, ExpandMore as ExpandMoreIcon, ExpandLess as ExpandLessIcon,
  CheckCircle as CheckIcon, ErrorOutline as ErrorIcon, Schedule as PendingIcon,
} from '@mui/icons-material';
import { format } from 'date-fns';
import extractionService, { MetadataJob, ExtractionLog } from '../services/extractionService';
import LogPanel from '../components/extraction/LogPanel';

const TERMINAL = new Set(['completed', 'completed_with_errors', 'failed', 'cancelled']);
const isTerminal = (s?: string) => TERMINAL.has((s || '').toLowerCase());

const StatusChip = ({ status }: { status?: string }) => {
  switch ((status || '').toLowerCase()) {
    case 'completed':
      return <Chip icon={<CheckIcon />} label="Terminé" color="success" size="small" />;
    case 'completed_with_errors':
      return <Chip icon={<ErrorIcon />} label="Terminé (erreurs)" color="warning" size="small" />;
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
// Lecture défensive camelCase / snake_case
const tablesDone = (j: any) => j.tablesDone ?? j.tables_done ?? 0;

const MetadataExtraction = () => {
  const [jobs, setJobs] = useState<MetadataJob[]>([]);
  const [loading, setLoading] = useState(false);

  // Lanceur
  const [tablesInput, setTablesInput] = useState('');
  const [addToConfig, setAddToConfig] = useState(true);
  const [findRelations, setFindRelations] = useState(true);
  const [force, setForce] = useState(false);
  const [launching, setLaunching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Détails
  const [expanded, setExpanded] = useState<string | null>(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [detailsJobId, setDetailsJobId] = useState<string | null>(null);
  const [detail, setDetail] = useState<MetadataJob | null>(null);
  const [logs, setLogs] = useState<ExtractionLog[]>([]);
  const [cancelling, setCancelling] = useState<string | null>(null);

  const refreshingRef = useRef(false);

  const refresh = useCallback(async () => {
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    setLoading(true);
    try {
      const data = await extractionService.getMetadataJobs(30);
      setJobs(Array.isArray(data) ? data : []);
    } catch (e: any) {
      setError(e?.response?.data?.error || e?.message || 'Erreur de chargement des jobs');
    } finally {
      setLoading(false);
      refreshingRef.current = false;
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  // Auto-refresh 10 s tant qu'un job est actif
  useEffect(() => {
    if (!jobs.some((j) => !isTerminal(j.status))) return;
    const iv = setInterval(refresh, 10000);
    return () => clearInterval(iv);
  }, [jobs, refresh]);

  const handleLaunch = async () => {
    const tables = tablesInput.split(/[\s,;]+/).map((t) => t.trim().toUpperCase()).filter(Boolean);
    if (tables.length === 0) return;
    setLaunching(true);
    setError(null);
    try {
      await extractionService.extractMetadata(tables, { addToConfig, findRelations, force });
      setTablesInput('');
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
      setDetail(await extractionService.getMetadataStatus(jobId));
      setDetailsOpen(true);
      extractionService.getMetadataLogs(jobId, 200).then(setLogs).catch(() => {});
    } catch (e) { console.error(e); }
  };

  const closeDetails = () => { setDetailsOpen(false); setDetailsJobId(null); setLogs([]); };

  // Polling live du dialogue tant que le job est actif
  useEffect(() => {
    if (!detailsOpen || !detailsJobId || isTerminal(detail?.status)) return;
    const iv = setInterval(() => {
      extractionService.getMetadataStatus(detailsJobId).then(setDetail).catch(() => {});
      extractionService.getMetadataLogs(detailsJobId, 200).then(setLogs).catch(() => {});
    }, 2000);
    return () => clearInterval(iv);
  }, [detailsOpen, detailsJobId, detail?.status]);

  const handleCancel = async (jobId: string) => {
    setCancelling(jobId);
    try {
      await extractionService.cancelMetadataJob(jobId);
      await refresh();
    } finally {
      setCancelling(null);
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ mb: 3 }}>EXTRACTION DE MÉTADONNÉES</Typography>

      {/* Lanceur */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>Nouvelle extraction de métadonnées</Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Extrait la structure (types, PK, relations) d'une ou plusieurs tables SAP. À lancer
            avant d'extraire les <b>données</b> d'une table jamais vue.
          </Typography>
          <TextField
            fullWidth
            size="small"
            label="Tables SAP (séparées par espace, virgule ou point-virgule)"
            placeholder="ex : MARA EKKO KOTE006"
            value={tablesInput}
            onChange={(e) => setTablesInput(e.target.value)}
            sx={{ mb: 1.5 }}
          />
          <Box sx={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 1 }}>
            <FormControlLabel
              control={<Checkbox checked={addToConfig} onChange={(e) => setAddToConfig(e.target.checked)} size="small" />}
              label="Ajouter à la config + créer la table raw_data"
            />
            <FormControlLabel
              control={<Checkbox checked={findRelations} onChange={(e) => setFindRelations(e.target.checked)} size="small" />}
              label="Rechercher les relations"
            />
            <FormControlLabel
              control={<Checkbox checked={force} onChange={(e) => setForce(e.target.checked)} size="small" color="warning" />}
              label="Forcer (remplace la config existante)"
            />
            <Box sx={{ flex: 1 }} />
            <Button
              variant="contained"
              startIcon={launching ? <CircularProgress size={18} /> : <StartIcon />}
              disabled={launching || tablesInput.trim() === ''}
              onClick={handleLaunch}
            >
              Lancer
            </Button>
          </Box>
        </CardContent>
      </Card>

      {/* Liste des jobs */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
        <Typography variant="h6">Jobs de métadonnées</Typography>
        <Button variant="outlined" size="small" startIcon={<RefreshIcon />} onClick={refresh} disabled={loading}>
          Actualiser
        </Button>
      </Box>
      {loading && <LinearProgress sx={{ mb: 1 }} />}
      {error && <Typography color="error" variant="body2" sx={{ mb: 1 }}>{error}</Typography>}

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell width={40} />
              <TableCell>ID</TableCell>
              <TableCell>Tables</TableCell>
              <TableCell>Statut</TableCell>
              <TableCell align="right">Avancement</TableCell>
              <TableCell align="right">Erreurs</TableCell>
              <TableCell>Démarré</TableCell>
              <TableCell>Durée</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {jobs.length === 0 && (
              <TableRow><TableCell colSpan={9} align="center" sx={{ py: 4, color: 'text.disabled' }}>Aucun job de métadonnées</TableCell></TableRow>
            )}
            {jobs.map((job) => {
              const active = !isTerminal(job.status);
              const hasTD = Array.isArray(job.tablesDetails) && job.tablesDetails.length > 0;
              const isExp = expanded === job.id;
              return (
                <Fragment key={job.id}>
                  <TableRow>
                    <TableCell sx={{ px: 0 }}>
                      {hasTD && (
                        <IconButton size="small" onClick={() => setExpanded(isExp ? null : job.id)}>
                          {isExp ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
                        </IconButton>
                      )}
                    </TableCell>
                    <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }} title={job.id}>
                      {job.id?.length > 12 ? `${job.id.substring(0, 8)}…` : job.id}
                    </TableCell>
                    <TableCell>
                      <Tooltip title={(job.tables || []).join(', ')}>
                        <span>{(job.tables || []).length} table(s)</span>
                      </Tooltip>
                    </TableCell>
                    <TableCell><StatusChip status={job.status} /></TableCell>
                    <TableCell align="right">{tablesDone(job)}/{(job.tables || []).length}</TableCell>
                    <TableCell align="right">
                      {job.errors ? <Typography variant="body2" color="error">{job.errors}</Typography> : '-'}
                    </TableCell>
                    <TableCell sx={{ fontSize: '0.75rem' }}>{fmtDate(job.startedAt)}</TableCell>
                    <TableCell>{fmtDuration(job.duration)}</TableCell>
                    <TableCell align="center" sx={{ whiteSpace: 'nowrap' }}>
                      {active && (
                        <Tooltip title="Annuler">
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
                  {hasTD && (
                    <TableRow>
                      <TableCell colSpan={9} sx={{ py: 0, px: 2 }}>
                        <Collapse in={isExp} timeout="auto" unmountOnExit>
                          <Box sx={{ py: 1.5, pl: 4 }}>
                            <Table size="small">
                              <TableHead>
                                <TableRow>
                                  <TableCell>Table</TableCell>
                                  <TableCell>Statut</TableCell>
                                  <TableCell align="right">Champs</TableCell>
                                  <TableCell>Table créée</TableCell>
                                </TableRow>
                              </TableHead>
                              <TableBody>
                                {job.tablesDetails!.map((td) => (
                                  <TableRow key={td.name}>
                                    <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>{td.name}</TableCell>
                                    <TableCell><StatusChip status={td.status} /></TableCell>
                                    <TableCell align="right">{td.fields_count ?? '-'}</TableCell>
                                    <TableCell>{td.added_to_config ? 'oui' : '-'}</TableCell>
                                  </TableRow>
                                ))}
                              </TableBody>
                            </Table>
                          </Box>
                        </Collapse>
                      </TableCell>
                    </TableRow>
                  )}
                </Fragment>
              );
            })}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Dialogue détails + logs live */}
      <Dialog open={detailsOpen} onClose={closeDetails} maxWidth="md" fullWidth>
        <DialogTitle>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            Détails métadonnées
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
                <Grid item xs={3}>
                  <Typography variant="caption" color="text.secondary">Avancement</Typography>
                  <Typography variant="body2">{tablesDone(detail)}/{(detail.tables || []).length}</Typography>
                </Grid>
                <Grid item xs={3}>
                  <Typography variant="caption" color="text.secondary">Erreurs</Typography>
                  <Typography variant="body2" color={detail.errors ? 'error' : 'text.primary'}>{detail.errors ?? 0}</Typography>
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

              <Typography variant="subtitle2" sx={{ mb: 1 }}>Détails par table</Typography>
              <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Table</TableCell>
                      <TableCell>Statut</TableCell>
                      <TableCell align="right">Champs</TableCell>
                      <TableCell>Table créée</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {(detail.tablesDetails || []).map((td) => (
                      <TableRow key={td.name}>
                        <TableCell sx={{ fontFamily: 'monospace' }}>{td.name}</TableCell>
                        <TableCell><StatusChip status={td.status} /></TableCell>
                        <TableCell align="right">{td.fields_count ?? '-'}</TableCell>
                        <TableCell>{td.added_to_config ? 'oui' : '-'}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>

              <Box sx={{ mt: 3 }}>
                <LogPanel logs={logs} live={!isTerminal(detail.status)} height={220} />
              </Box>
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

export default MetadataExtraction;
