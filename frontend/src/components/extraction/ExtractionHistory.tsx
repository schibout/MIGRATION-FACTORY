import { useState, useEffect, useCallback, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  Chip,
  IconButton,
  Button,
  Tooltip,
  LinearProgress,
  Card,
  CardContent,
  Grid,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Collapse,
  alpha,
  useTheme,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  Check as CheckIcon,
  Error as ErrorIcon,
  HourglassEmpty as PendingIcon,
  PlayArrow as RunningIcon,
  Stop as StopIcon,
  Cancel as CancelIcon,
  VisibilityOutlined as ViewDetailsIcon,
  ExpandMore as ExpandMoreIcon,
  ExpandLess as ExpandLessIcon,
  Storage as StorageIcon,
  AdminPanelSettings as AdminIcon,
  Email as EmailIcon,
} from '@mui/icons-material';
import Avatar from '@mui/material/Avatar';
import { format } from 'date-fns';

import {
  fetchExtractionHistory,
  refreshJobStatus,
  stopExtraction,
  ExtractionJob,
} from '../../store/slices/extractionSlice';
import { AppDispatch, RootState } from '../../store';
import extractionService, { ExtractionLog } from '../../services/extractionService';
import LogPanel from './LogPanel';

// Statuts terminaux : ces jobs ne bougent plus, inutile de réinterroger leur statut.
// ⚠️ Comparaison insensible à la casse : la base contient à la fois COMPLETED et completed.
const TERMINAL_STATUSES = new Set(['completed', 'failed', 'cancelled']);
const isTerminal = (status?: string) => TERMINAL_STATUSES.has((status || '').toLowerCase());
// Borne le nombre de /status déclenchés par cycle (anti-rafale / anti-429)
const MAX_STATUS_REFRESH_PER_CYCLE = 12;

const USER_COLORS = ['#1976d2','#388e3c','#f57c00','#7b1fa2','#c62828','#00796b','#5d4037'];
const stringHash = (s: string) => s.split('').reduce((a, c) => a + c.charCodeAt(0), 0);

const UserCell = ({ job }: { job: { user: string; userName?: string; userEmail?: string; userRole?: string } }) => {
  const name = job.userName || job.user || '?';
  const isDemoUser = job.user === 'demo_user' || (!job.userName && !job.userEmail);
  const initials = name.split(/[\s._-]/).map((p: string) => p[0]).join('').substring(0, 2).toUpperCase();
  const color = USER_COLORS[stringHash(name) % USER_COLORS.length];
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
      <Avatar sx={{ width: 28, height: 28, bgcolor: color, fontSize: '0.65rem', fontWeight: 700 }}>
        {initials || '?'}
      </Avatar>
      <Box>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
          <Typography variant="body2" sx={{ fontWeight: 600, lineHeight: 1.2 }}>
            {isDemoUser ? <em style={{ opacity: 0.5 }}>demo</em> : name}
          </Typography>
          {job.userRole === 'admin' && (
            <Tooltip title="Admin"><AdminIcon sx={{ fontSize: 13, color: 'warning.main' }} /></Tooltip>
          )}
        </Box>
        {job.userEmail && (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.3 }}>
            <EmailIcon sx={{ fontSize: 10, color: 'text.disabled' }} />
            <Typography variant="caption" color="text.secondary" sx={{ fontSize: '0.65rem' }}>
              {job.userEmail}
            </Typography>
          </Box>
        )}
      </Box>
    </Box>
  );
};

const StatusChip = ({ status }: { status: string }) => {
  // Casse ignorée : la base contient COMPLETED et completed
  switch ((status || '').toLowerCase()) {
    case 'completed':
      return <Chip icon={<CheckIcon />} label="Terminé" color="success" size="small" />;
    case 'completed_with_errors':
      return <Chip icon={<ErrorIcon />} label="Terminé (erreurs)" color="warning" size="small" />;
    case 'failed':
      return <Chip icon={<ErrorIcon />} label="Échec" color="error" size="small" />;
    case 'running':
      return <Chip icon={<RunningIcon />} label="En cours" color="primary" size="small" />;
    case 'pending':
      return <Chip icon={<PendingIcon />} label="En attente" color="warning" size="small" />;
    case 'cancelled':
      return <Chip icon={<CancelIcon />} label="Annulé" color="default" size="small" />;
    default:
      return <Chip label={status || '?'} size="small" />;
  }
};

const formatDate = (dateString?: string | null) => {
  if (!dateString) return '-';
  try {
    return format(new Date(dateString), 'dd/MM/yyyy HH:mm:ss');
  } catch {
    return dateString;
  }
};

const formatDuration = (seconds?: number | null) => {
  if (!seconds) return '-';
  const s = Math.round(seconds);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  const rs = s % 60;
  if (m < 60) return `${m}m ${rs}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
};

const ExtractionHistory = () => {
  const theme = useTheme();
  const dispatch = useDispatch<AppDispatch>();
  const { extractionJobs, status } = useSelector((state: RootState) => state.extraction);

  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [expandedRow, setExpandedRow] = useState<string | null>(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [detailsJobId, setDetailsJobId] = useState<string | null>(null);
  const [jobDetails, setJobDetails] = useState<any>(null);
  const [logs, setLogs] = useState<ExtractionLog[]>([]);
  const [stoppingId, setStoppingId] = useState<string | null>(null);

  const refreshingRef = useRef(false);

  const refresh = useCallback(async () => {
    // Anti-chevauchement : ne pas relancer un cycle si le précédent tourne encore
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    try {
      // 1) Rafraîchir la liste (historique paginé)
      const res = await dispatch(fetchExtractionHistory({ limit: rowsPerPage, offset: page * rowsPerPage }));
      // 2) Pour chaque job NON terminal (≠ completed / failed / cancelled, casse ignorée),
      //    interroger le statut par jobid (/extraction/status/{id}) pour maj sa ligne.
      //    Séquentiel + borné : évite la rafale de requêtes qui déclenchait le 429.
      if (fetchExtractionHistory.fulfilled.match(res)) {
        const nonTerminal = (res.payload as ExtractionJob[])
          .filter((j) => !isTerminal(j.status))
          .slice(0, MAX_STATUS_REFRESH_PER_CYCLE);
        for (const j of nonTerminal) {
          await dispatch(refreshJobStatus(j.id));
        }
      }
    } finally {
      refreshingRef.current = false;
    }
  }, [dispatch, page, rowsPerPage]);

  useEffect(() => { refresh(); }, [refresh]);

  // Auto-refresh toutes les 60 s s'il y a des jobs non terminaux (casse ignorée)
  useEffect(() => {
    const hasActive = extractionJobs.some((j) => !isTerminal(j.status));
    if (!hasActive) return;
    const iv = setInterval(refresh, 60000);
    return () => clearInterval(iv);
  }, [extractionJobs, refresh]);

  const handleViewDetails = async (jobId: string) => {
    try {
      setDetailsJobId(jobId);
      setLogs([]);
      // Appels directs (pas les thunks) : ne touchent pas au status global Redux
      const s = await extractionService.getExtractionStatus(jobId);
      setJobDetails(s);
      setDetailsOpen(true);
      extractionService.getExtractionLogs(jobId, 200).then(setLogs).catch(() => {});
    } catch (e) {
      console.error('Erreur détails:', e);
    }
  };

  const closeDetails = () => {
    setDetailsOpen(false);
    setDetailsJobId(null);
    setLogs([]);
  };

  // Suivi LIVE du dialogue de détails : tant qu'il est ouvert sur un job non
  // terminal, re-poll statut + logs toutes les 2 s (appels directs, sans toucher
  // au status global). S'arrête dès que le job est terminal ou le dialogue fermé.
  useEffect(() => {
    if (!detailsOpen || !detailsJobId || isTerminal(jobDetails?.status)) return;
    const iv = setInterval(() => {
      extractionService.getExtractionStatus(detailsJobId).then(setJobDetails).catch(() => {});
      extractionService.getExtractionLogs(detailsJobId, 200).then(setLogs).catch(() => {});
    }, 2000);
    return () => clearInterval(iv);
  }, [detailsOpen, detailsJobId, jobDetails?.status]);

  const handleStop = async (jobId: string) => {
    setStoppingId(jobId);
    try {
      await dispatch(stopExtraction({ extractionId: jobId, reason: 'Arrêt manuel' }));
      refresh();
    } finally {
      setStoppingId(null);
    }
  };

  const toggleExpand = (id: string) => {
    setExpandedRow((prev) => (prev === id ? null : id));
  };

  const statusBg = (s: string) => {
    const l = (s || '').toLowerCase();
    if (l === 'running') return alpha(theme.palette.primary.main, 0.06);
    if (l === 'failed') return alpha(theme.palette.error.main, 0.06);
    return undefined;
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2, alignItems: 'center' }}>
        <Typography variant="h6">Historique des extractions</Typography>
        <Button
          variant="outlined"
          size="small"
          startIcon={<RefreshIcon />}
          onClick={refresh}
          disabled={status === 'loading'}
        >
          Actualiser
        </Button>
      </Box>

      {status === 'loading' && <LinearProgress sx={{ mb: 1 }} />}

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell width={40} />
              <TableCell>ID</TableCell>
              <TableCell>Utilisateur</TableCell>
              <TableCell>Statut</TableCell>
              <TableCell>Tables</TableCell>
              <TableCell align="right">Lignes</TableCell>
              <TableCell>Progression</TableCell>
              <TableCell>Démarré</TableCell>
              <TableCell>Durée</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {extractionJobs.length === 0 && (
              <TableRow>
                <TableCell colSpan={10} align="center" sx={{ py: 4 }}>
                  <Typography color="text.secondary">Aucune extraction trouvée</Typography>
                </TableCell>
              </TableRow>
            )}
            {extractionJobs.map((job) => {
              const isActive = !isTerminal(job.status);
              const progress = job.progress ?? 0;
              const hasTD = Array.isArray(job.tablesDetails) && job.tablesDetails.length > 0;
              const isExpanded = expandedRow === job.id;

              return (
                <TableRow key={job.id} sx={{ bgcolor: statusBg(job.status), '& > td': { borderBottom: isExpanded ? 0 : undefined } }}>

                  {/* Expand */}
                  <TableCell sx={{ px: 0 }}>
                    {hasTD && (
                      <IconButton size="small" onClick={() => toggleExpand(job.id)}>
                        {isExpanded ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
                      </IconButton>
                    )}
                  </TableCell>

                  {/* ID */}
                  <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }} title={job.id}>
                    {job.id.length > 12 ? `${job.id.substring(0, 8)}…` : job.id}
                  </TableCell>

                  {/* User */}
                  <TableCell><UserCell job={job} /></TableCell>

                  {/* Status */}
                  <TableCell><StatusChip status={job.status} /></TableCell>

                  {/* Tables */}
                  <TableCell>
                    {Array.isArray(job.tables) ? (
                      <Tooltip title={job.tables.join(', ')}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                          <StorageIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                          <Typography variant="body2">{job.tables.length} tables</Typography>
                        </Box>
                      </Tooltip>
                    ) : '-'}
                  </TableCell>

                  {/* Rows */}
                  <TableCell align="right">
                    {job.rowsExtracted ? job.rowsExtracted.toLocaleString() : '-'}
                  </TableCell>

                  {/* Progress */}
                  <TableCell sx={{ minWidth: 120 }}>
                    {isActive ? (
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <LinearProgress
                          variant="determinate"
                          value={progress}
                          sx={{ flex: 1, height: 6, borderRadius: 3 }}
                        />
                        <Typography variant="caption" sx={{ minWidth: 30 }}>
                          {progress}%
                        </Typography>
                      </Box>
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        {job.status === 'completed' ? '100%' : '-'}
                      </Typography>
                    )}
                  </TableCell>

                  {/* Date */}
                  <TableCell sx={{ fontSize: '0.75rem' }}>
                    {formatDate(job.startedAt)}
                  </TableCell>

                  {/* Duration */}
                  <TableCell>{formatDuration(job.duration)}</TableCell>

                  {/* Actions */}
                  <TableCell align="center" sx={{ whiteSpace: 'nowrap' }}>
                    {isActive && (
                      <Tooltip title="Arrêter">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleStop(job.id)}
                          disabled={stoppingId === job.id}
                        >
                          <StopIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    <Tooltip title="Détails">
                      <IconButton size="small" color="primary" onClick={() => handleViewDetails(job.id)}>
                        <ViewDetailsIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              );
            })}

            {/* Expanded sub-rows (inline table details) */}
            {extractionJobs.map((job) => {
              const isExpanded = expandedRow === job.id;
              const hasTD = Array.isArray(job.tablesDetails) && job.tablesDetails.length > 0;
              if (!hasTD) return null;
              return (
                <TableRow key={`${job.id}-details`}>
                  <TableCell colSpan={10} sx={{ py: 0, px: 2 }}>
                    <Collapse in={isExpanded} timeout="auto" unmountOnExit>
                      <Box sx={{ py: 1.5, pl: 4 }}>
                        <Table size="small">
                          <TableHead>
                            <TableRow>
                              <TableCell>Table</TableCell>
                              <TableCell>Statut</TableCell>
                              <TableCell align="right">Lignes</TableCell>
                              <TableCell>Début</TableCell>
                              <TableCell>Fin</TableCell>
                            </TableRow>
                          </TableHead>
                          <TableBody>
                            {job.tablesDetails!.map((td) => (
                              <TableRow key={td.name}>
                                <TableCell sx={{ fontFamily: 'monospace', fontSize: '0.75rem' }}>{td.name}</TableCell>
                                <TableCell><StatusChip status={td.status} /></TableCell>
                                <TableCell align="right">{td.rows ? td.rows.toLocaleString() : '-'}</TableCell>
                                <TableCell sx={{ fontSize: '0.75rem' }}>
                                  {td.startTime ? format(new Date(td.startTime), 'HH:mm:ss') : '-'}
                                </TableCell>
                                <TableCell sx={{ fontSize: '0.75rem' }}>
                                  {td.endTime ? format(new Date(td.endTime), 'HH:mm:ss') : '-'}
                                </TableCell>
                              </TableRow>
                            ))}
                          </TableBody>
                        </Table>
                      </Box>
                    </Collapse>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </TableContainer>

      <TablePagination
        rowsPerPageOptions={[5, 10, 25]}
        component="div"
        count={-1}
        rowsPerPage={rowsPerPage}
        page={page}
        onPageChange={(_, p) => setPage(p)}
        onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
        labelDisplayedRows={({ from, to }) => `${from}–${to}`}
        labelRowsPerPage="Par page :"
      />

      {/* Dialog détails complets */}
      <Dialog open={detailsOpen} onClose={closeDetails} maxWidth="md" fullWidth>
        <DialogTitle>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            Détails de l'extraction
            <StatusChip status={jobDetails?.status || ''} />
          </Box>
        </DialogTitle>
        <DialogContent>
          {jobDetails && (
            <>
              <Grid container spacing={2} sx={{ mb: 3, mt: 0 }}>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">ID</Typography>
                  <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>{jobDetails.id}</Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">Utilisateur</Typography>
                  <Typography variant="body2">{jobDetails.user || '-'}</Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">Démarré</Typography>
                  <Typography variant="body2">{formatDate(jobDetails.startedAt)}</Typography>
                </Grid>
                <Grid item xs={6}>
                  <Typography variant="caption" color="text.secondary">Terminé</Typography>
                  <Typography variant="body2">{formatDate(jobDetails.completedAt)}</Typography>
                </Grid>
                <Grid item xs={4}>
                  <Typography variant="caption" color="text.secondary">Mode</Typography>
                  <Typography variant="body2" sx={{ textTransform: 'capitalize' }}>{jobDetails.mode || 'standard'}</Typography>
                </Grid>
                <Grid item xs={4}>
                  <Typography variant="caption" color="text.secondary">Batch size</Typography>
                  <Typography variant="body2">{jobDetails.batchSize || '-'}</Typography>
                </Grid>
                <Grid item xs={4}>
                  <Typography variant="caption" color="text.secondary">Lignes totales</Typography>
                  <Typography variant="body2">{jobDetails.rowsExtracted?.toLocaleString() || '-'}</Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="caption" color="text.secondary">Progression</Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <LinearProgress
                      variant="determinate"
                      value={jobDetails.progress ?? 0}
                      sx={{ flex: 1, height: 8, borderRadius: 4 }}
                    />
                    <Typography variant="body2">{Math.round(jobDetails.progress ?? 0)}%</Typography>
                  </Box>
                </Grid>
                {jobDetails.error && (
                  <Grid item xs={12}>
                    <Paper variant="outlined" sx={{ p: 1, bgcolor: alpha(theme.palette.error.main, 0.08) }}>
                      <Typography variant="body2" color="error">{jobDetails.error}</Typography>
                    </Paper>
                  </Grid>
                )}
              </Grid>

              <Typography variant="subtitle2" sx={{ mb: 1 }}>Détails par table</Typography>
              <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Table</TableCell>
                      <TableCell>Statut</TableCell>
                      <TableCell align="right">Lignes</TableCell>
                      <TableCell>Début</TableCell>
                      <TableCell>Fin</TableCell>
                      <TableCell>Durée</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {jobDetails.tablesDetails?.length > 0 ? (
                      jobDetails.tablesDetails.map((d: any) => (
                        <TableRow key={d.name}>
                          <TableCell sx={{ fontFamily: 'monospace' }}>{d.name}</TableCell>
                          <TableCell><StatusChip status={d.status} /></TableCell>
                          <TableCell align="right">{d.rows ? d.rows.toLocaleString() : '-'}</TableCell>
                          <TableCell>{d.startTime ? format(new Date(d.startTime), 'HH:mm:ss') : '-'}</TableCell>
                          <TableCell>{d.endTime ? format(new Date(d.endTime), 'HH:mm:ss') : '-'}</TableCell>
                          <TableCell>
                            {d.startTime && d.endTime
                              ? formatDuration((new Date(d.endTime).getTime() - new Date(d.startTime).getTime()) / 1000)
                              : '-'}
                          </TableCell>
                        </TableRow>
                      ))
                    ) : (
                      <TableRow>
                        <TableCell colSpan={6} align="center">Aucun détail disponible</TableCell>
                      </TableRow>
                    )}
                  </TableBody>
                </Table>
              </TableContainer>

              {/* Journal d'exécution (même rendu que /data-loading) */}
              <Box sx={{ mt: 3 }}>
                <LogPanel logs={logs} live={!isTerminal(jobDetails?.status)} height={220} />
              </Box>
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={closeDetails}>Fermer</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default ExtractionHistory;
