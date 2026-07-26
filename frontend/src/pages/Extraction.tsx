import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Button,
  FormControl,
  FormControlLabel,
  Checkbox,
  TextField,
  Radio,
  RadioGroup,
  FormLabel,
  Chip,
  LinearProgress,
  Tabs,
  Tab,
  InputAdornment,
  IconButton,
  Tooltip,
  ToggleButton,
  ToggleButtonGroup,
  CardHeader,
  Divider,
  Collapse,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
} from '@mui/material';
import {
  Add as AddIcon,
  PlayArrow as StartIcon,
  Schedule as ScheduleIcon,
  History as HistoryIcon,
  Search as SearchIcon,
  Close as CloseIcon,
  SelectAll as SelectAllIcon,
  Deselect as DeselectIcon,
  Storage as StorageIcon,
  ExpandLess,
  ExpandMore,
  AccountTree as HierarchyIcon,
  TableChart as TableIcon,
  LibraryAdd as DiscoverIcon,
  CheckCircle as CheckIcon,
  ErrorOutline as ErrorIcon,
} from '@mui/icons-material';
import extractionService, { IfloNode, MetadataJob, AvailableSapTable, ExtractionLog } from '../services/extractionService';
import LogPanel from '../components/extraction/LogPanel';
import { RootState } from '../store';
import {
  fetchAvailableTables,
  setSelectedTables,
  setBatchSize,
  setLimit,
  setMode,
  setWorkers,
  setPageSize,
  setClean,
  startExtraction,
  clearExtractionSettings,
  fetchExtractionHistory,
} from '../store/slices/extractionSlice';

// Import du nouveau composant d'historique
import ExtractionHistory from '../components/extraction/ExtractionHistory';

// ── Composant récursif pour l'arbre IFLO ──────────────────────────────────────

interface IfloTreeNodeProps {
  node: IfloNode;
  depth: number;
  expanded: Set<string>;
  onToggle: (id: string) => void;
  selectedTables: string[];
  onSelectTable: (name: string) => void;
  searchQuery: string;
  matchesSearch: (node: IfloNode, q: string) => boolean;
}

function IfloTreeNode({
  node, depth, expanded, onToggle, selectedTables, onSelectTable, searchQuery, matchesSearch,
}: IfloTreeNodeProps) {
  const hasChildren = node.children.length > 0;
  const isOpen = expanded.has(node.id);
  const isSelected = selectedTables.includes('IFLO');

  const visibleChildren = searchQuery
    ? node.children.filter((c) => matchesSearch(c, searchQuery))
    : node.children;

  return (
    <>
      <ListItemButton
        onClick={() => {
          if (hasChildren) onToggle(node.id);
          else onSelectTable('IFLO');
        }}
        sx={{ pl: 1.5 + depth * 2, py: 0.4, borderBottom: '1px solid', borderColor: 'divider' }}
      >
        <ListItemIcon sx={{ minWidth: 28 }}>
          {hasChildren ? (
            isOpen ? <ExpandLess fontSize="small" /> : <ExpandMore fontSize="small" />
          ) : (
            <Checkbox
              size="small"
              checked={isSelected}
              sx={{ p: 0 }}
              onClick={(e) => { e.stopPropagation(); onSelectTable('IFLO'); }}
            />
          )}
        </ListItemIcon>
        <ListItemText
          primary={
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
              <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 700, fontSize: '0.78rem' }}>
                {node.id}
              </Typography>
              {node.description && (
                <Typography variant="caption" sx={{ opacity: 0.75, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  — {node.description}
                </Typography>
              )}
            </Box>
          }
        />
        {hasChildren && (
          <Typography variant="caption" color="text.secondary" sx={{ ml: 1, flexShrink: 0 }}>
            {node.children.length}
          </Typography>
        )}
      </ListItemButton>
      {hasChildren && (
        <Collapse in={isOpen} timeout="auto" unmountOnExit>
          <List dense disablePadding>
            {visibleChildren.map((child) => (
              <IfloTreeNode
                key={child.id}
                node={child}
                depth={depth + 1}
                expanded={expanded}
                onToggle={onToggle}
                selectedTables={selectedTables}
                onSelectTable={onSelectTable}
                searchQuery={searchQuery}
                matchesSearch={matchesSearch}
              />
            ))}
          </List>
        </Collapse>
      )}
    </>
  );
}

// Tabs panel
interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel({ children, value, index, ...other }: TabPanelProps) {
  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`extraction-tabpanel-${index}`}
      aria-labelledby={`extraction-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ pt: 3 }}>{children}</Box>}
    </div>
  );
}

const Extraction = ({ mode = 'overview' }: { mode?: string }) => {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const [tabValue, setTabValue] = useState(
    mode === 'new' ? 0 : mode === 'history' ? 1 : mode === 'status' ? 2 : 0
  );
  // Repli des options techniques (batch / page RFC / workers) — épure le flux principal
  const [advancedOpen, setAdvancedOpen] = useState(false);
  // Journal d'exécution live du job d'extraction lancé depuis cet écran
  const [runningJobId, setRunningJobId] = useState<string | null>(null);
  const [runJob, setRunJob] = useState<any>(null);
  const [runLogs, setRunLogs] = useState<ExtractionLog[]>([]);

  // Redux state
  const availableTables = useSelector(
    (state: RootState) => state.extraction.availableTables
  );
  const extractionJobs = useSelector(
    (state: RootState) => state.extraction.extractionJobs
  );
  const selectedTables = useSelector(
    (state: RootState) => state.extraction.selectedTables
  );
  const batchSize = useSelector((state: RootState) => state.extraction.batchSize);
  const limit = useSelector((state: RootState) => state.extraction.limit);
  const extractionMode = useSelector((state: RootState) => state.extraction.mode);
  const workers = useSelector((state: RootState) => state.extraction.workers);
  const pageSize = useSelector((state: RootState) => state.extraction.pageSize);
  const clean = useSelector((state: RootState) => state.extraction.clean);
  const status = useSelector((state: RootState) => state.extraction.status);

  // Local state
  const [showRunningOnly, setShowRunningOnly] = useState(false);
  const [tableSearch, setTableSearch] = useState('');
  const [classFilter, setClassFilter] = useState<string>('ALL');
  const [selectionMode, setSelectionMode] = useState<'tables' | 'iflo'>('tables');
  const [ifloTree, setIfloTree] = useState<IfloNode[]>([]);
  const [ifloLoading, setIfloLoading] = useState(false);
  const [ifloExpanded, setIfloExpanded] = useState<Set<string>>(new Set());
  const [ifloSearch, setIfloSearch] = useState('');

  // ── Recherche / création de tables SAP (catalogue dictionnaire SAP) ──
  const [discoverOpen, setDiscoverOpen] = useState(false);
  const [availLoading, setAvailLoading] = useState(false);
  const [availError, setAvailError] = useState<string | null>(null);
  const [availResults, setAvailResults] = useState<AvailableSapTable[]>([]);
  const [availTotal, setAvailTotal] = useState(0);
  const [availSearch, setAvailSearch] = useState('');
  const [availDomaine, setAvailDomaine] = useState('');
  const [availPage, setAvailPage] = useState(0); // 0-based (TablePagination)
  const [availRowsPerPage, setAvailRowsPerPage] = useState(100);
  const [tablesToCreate, setTablesToCreate] = useState<string[]>([]);
  const [creating, setCreating] = useState(false);
  const [metadataJob, setMetadataJob] = useState<MetadataJob | null>(null);
  // Job métadonnées en cours de suivi (null = aucun / suivi annulé)
  const metadataPollRef = useRef<string | null>(null);

  // Charge une page du catalogue SAP (GET /tables/available)
  const loadAvailable = useCallback(async () => {
    setAvailLoading(true);
    setAvailError(null);
    try {
      const res = await extractionService.searchAvailableTables({
        search: availSearch || undefined,
        domaine: availDomaine || undefined,
        limit: availRowsPerPage,
        offset: availPage * availRowsPerPage,
      });
      setAvailResults(res.results);
      setAvailTotal(res.total);
    } catch (e: any) {
      const code = e?.response?.status;
      setAvailError(
        code === 502
          ? 'Service SAP / PostgreSQL indisponible (502). Réessayez plus tard.'
          : e?.response?.data?.error || e?.message || 'Erreur lors de la recherche'
      );
      setAvailResults([]);
      setAvailTotal(0);
    } finally {
      setAvailLoading(false);
    }
  }, [availSearch, availDomaine, availPage, availRowsPerPage]);

  // Debounce ~300 ms : déclenche la recherche quand un paramètre change
  useEffect(() => {
    if (!discoverOpen) return;
    const t = setTimeout(() => { loadAvailable(); }, 300);
    return () => clearTimeout(t);
  }, [discoverOpen, loadAvailable]);

  const openDiscover = () => {
    setMetadataJob(null);
    setTablesToCreate([]);
    setAvailLoading(true); // évite le flash "Aucune table" pendant le debounce initial
    setDiscoverOpen(true);
    // le chargement initial est déclenché par le useEffect ci-dessus
  };

  const closeDiscover = () => {
    metadataPollRef.current = null; // stoppe tout suivi de job en cours
    setDiscoverOpen(false);
  };

  const handleAvailSearchChange = (v: string) => { setAvailSearch(v); setAvailPage(0); };
  const handleAvailDomaineChange = (v: string) => { setAvailDomaine(v); setAvailPage(0); };

  const toggleTableToCreate = (name: string) => {
    setTablesToCreate((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name]
    );
  };

  const METADATA_TERMINAL = ['completed', 'completed_with_errors', 'failed', 'cancelled'];

  // Suit un job de métadonnées jusqu'à un statut terminal (poll ~2 s)
  const pollMetadataJob = async (jobId: string) => {
    while (metadataPollRef.current === jobId) {
      let job: MetadataJob;
      try {
        job = await extractionService.getMetadataStatus(jobId);
      } catch (e: any) {
        if (metadataPollRef.current === jobId) {
          setAvailError(e?.response?.data?.error || e?.message || 'Erreur de suivi du job');
        }
        break;
      }
      if (metadataPollRef.current !== jobId) return; // suivi annulé entre-temps
      setMetadataJob(job);
      if (METADATA_TERMINAL.includes(job.status)) break;
      await new Promise((r) => setTimeout(r, 2000));
    }
    if (metadataPollRef.current === jobId) {
      metadataPollRef.current = null;
      setCreating(false);
      setTablesToCreate([]);
      // Rafraîchir le catalogue d'extraction + la page courante
      dispatch(fetchAvailableTables() as any);
      loadAvailable();
    }
  };

  const handleCreateTables = async () => {
    if (tablesToCreate.length === 0) return;
    setCreating(true);
    setAvailError(null);
    setMetadataJob(null);
    try {
      const res = await extractionService.extractMetadata(tablesToCreate);
      metadataPollRef.current = res.metadata_job_id;
      pollMetadataJob(res.metadata_job_id);
    } catch (e: any) {
      setAvailError(e?.response?.data?.error || e?.message || 'Erreur lors du lancement');
      setCreating(false);
    }
  };

  // Formate une date SAP "YYYYMMDD" en "JJ/MM/AAAA"
  const formatSapDate = (d?: string) => {
    if (!d || d.length !== 8) return d || '';
    return `${d.slice(6, 8)}/${d.slice(4, 6)}/${d.slice(0, 4)}`;
  };

  const filteredTables = useMemo(() => {
    const q = tableSearch.toLowerCase();
    return availableTables.filter((t) => {
      const matchSearch =
        !q ||
        t.name.toLowerCase().includes(q) ||
        (t.description || '').toLowerCase().includes(q);
      const matchClass =
        classFilter === 'ALL' || (t.tableClass || '') === classFilter;
      return matchSearch && matchClass;
    });
  }, [availableTables, tableSearch, classFilter]);

  const tableClasses = useMemo(() => {
    const classes = [...new Set(availableTables.map((t) => t.tableClass || '').filter(Boolean))].sort();
    return classes;
  }, [availableTables]);

  // Fetch data
  useEffect(() => {
    dispatch(fetchAvailableTables() as any);
    dispatch(fetchExtractionHistory({}) as any);
  }, [dispatch]);

  // Fetch IFLO hierarchy on demand
  useEffect(() => {
    if (selectionMode !== 'iflo' || ifloTree.length > 0) return;
    setIfloLoading(true);
    extractionService.getIfloHierarchy()
      .then((tree) => {
        setIfloTree(tree);
        // Auto-expand root nodes
        setIfloExpanded(new Set(tree.map((n) => n.id)));
      })
      .catch(console.error)
      .finally(() => setIfloLoading(false));
  }, [selectionMode, ifloTree.length]);

  const toggleIfloExpand = useCallback((id: string) => {
    setIfloExpanded((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }, []);

  const matchesIfloSearch = useCallback((node: IfloNode, q: string): boolean => {
    if (!q) return true;
    if (node.id.toLowerCase().includes(q) || node.description.toLowerCase().includes(q)) return true;
    return node.children.some((c) => matchesIfloSearch(c, q));
  }, []);

  // Handle tab change
  const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  // Handle table selection
  const handleTableSelection = (tableName: string) => {
    const newSelection = selectedTables.includes(tableName)
      ? selectedTables.filter((name) => name !== tableName)
      : [...selectedTables, tableName];
    dispatch(setSelectedTables(newSelection));
  };

  // Handle batch size change
  const handleBatchSizeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = parseInt(event.target.value, 10);
    if (!isNaN(value) && value > 0) {
      dispatch(setBatchSize(value));
    }
  };

  // Handle limit change
  const handleLimitChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value === '' ? null : parseInt(event.target.value, 10);
    if (value === null || (!isNaN(value) && value > 0)) {
      dispatch(setLimit(value));
    }
  };

  // Handle mode change
  const handleModeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    dispatch(setMode(event.target.value as 'standard' | 'debug' | 'complet'));
  };

  // Start extraction — reste sur l'écran et affiche le journal d'exécution live
  const handleStartExtraction = async () => {
    if (selectedTables.length === 0) return;
    setRunLogs([]);
    setRunJob(null);
    setRunningJobId(null);
    const res: any = await dispatch(
      startExtraction({
        tables: selectedTables,
        options: { batchSize, limit, mode: extractionMode, workers, pageSize, clean },
      }) as any
    );
    const jobId = res?.payload?.extraction_id;
    dispatch(clearExtractionSettings());
    if (jobId) {
      setRunningJobId(jobId);
    }
  };

  // Annuler : abandonner la saisie et revenir au tableau de bord
  const handleCancelExtraction = () => {
    dispatch(clearExtractionSettings());
    navigate('/');
  };

  // Journal live : poll statut + logs du job lancé depuis cet écran, jusqu'au statut terminal
  useEffect(() => {
    if (!runningJobId) return;
    let active = true;
    const TERMINAL = ['completed', 'completed_with_errors', 'failed', 'cancelled'];
    const poll = async () => {
      try {
        const s: any = await extractionService.getExtractionStatus(runningJobId);
        if (!active) return;
        setRunJob(s);
        const l = await extractionService.getExtractionLogs(runningJobId, 300);
        if (!active) return;
        setRunLogs(l);
        if (TERMINAL.includes((s?.status || '').toLowerCase())) active = false;
      } catch { /* erreurs transitoires ignorées */ }
    };
    poll();
    const iv = setInterval(() => {
      if (active) poll();
      else clearInterval(iv);
    }, 2000);
    return () => { active = false; clearInterval(iv); };
  }, [runningJobId]);

  const runActive =
    !!runJob &&
    !['completed', 'completed_with_errors', 'failed', 'cancelled'].includes(
      (runJob?.status || '').toLowerCase()
    );

  // Filter jobs
  const filteredJobs = showRunningOnly
    ? extractionJobs.filter((job) => job.status === 'running')
    : extractionJobs;

  return (
    <Box>
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          mb: 3,
        }}
      >
        <Typography variant="h4">EXTRACTION DE DONNÉES</Typography>
        <Box sx={{ display: 'flex', gap: 1.5 }}>
          <Button
            variant="outlined"
            startIcon={<DiscoverIcon />}
            onClick={openDiscover}
          >
            Ajouter des tables SAP
          </Button>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => setTabValue(0)}
          >
            Nouvelle Extraction
          </Button>
        </Box>
      </Box>

      <Card>
        <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tabs
            value={tabValue}
            onChange={handleTabChange}
            aria-label="extraction tabs"
          >
            <Tab
              icon={<StartIcon />}
              label="NOUVELLE EXTRACTION"
              id="extraction-tab-0"
              aria-controls="extraction-tabpanel-0"
            />
            <Tab
              icon={<HistoryIcon />}
              label="HISTORIQUE"
              id="extraction-tab-1"
              aria-controls="extraction-tabpanel-1"
            />
            <Tab
              icon={<ScheduleIcon />}
              label="STATUT EN COURS"
              id="extraction-tab-2"
              aria-controls="extraction-tabpanel-2"
            />
          </Tabs>
        </Box>

        {/* New Extraction Tab */}
        <TabPanel value={tabValue} index={0}>
          <CardContent>
            <Grid container spacing={4}>
              <Grid item xs={12} md={7}>
                {/* Toggle vue */}
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
                  <Typography variant="h6">
                    {selectionMode === 'iflo' ? 'Hiérarchie des postes techniques' : 'Sélectionnez les tables à extraire'}
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    {selectionMode === 'tables' && (
                      <>
                        <Tooltip title="Tout sélectionner (résultats filtrés)">
                          <IconButton size="small" onClick={() => {
                            const names = filteredTables.map((t) => t.name);
                            dispatch(setSelectedTables([...new Set([...selectedTables, ...names])]));
                          }}>
                            <SelectAllIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Tout désélectionner">
                          <IconButton size="small" onClick={() => dispatch(setSelectedTables([]))}>
                            <DeselectIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </>
                    )}
                    <ToggleButtonGroup
                      size="small"
                      exclusive
                      value={selectionMode}
                      onChange={(_, v) => v && setSelectionMode(v)}
                      sx={{ ml: 1 }}
                    >
                      <ToggleButton value="tables" sx={{ fontSize: '0.65rem', py: 0.3, px: 1 }}>
                        <TableIcon sx={{ fontSize: 14, mr: 0.5 }} /> Tables
                      </ToggleButton>
                      <ToggleButton value="iflo" sx={{ fontSize: '0.65rem', py: 0.3, px: 1 }}>
                        <HierarchyIcon sx={{ fontSize: 14, mr: 0.5 }} /> Hiérarchie SAP
                      </ToggleButton>
                    </ToggleButtonGroup>
                  </Box>
                </Box>

                {selectionMode === 'tables' ? (
                  <>
                {/* Recherche */}
                <TextField
                  size="small"
                  fullWidth
                  placeholder="Rechercher une table (nom ou description)…"
                  value={tableSearch}
                  onChange={(e) => setTableSearch(e.target.value)}
                  sx={{ mb: 1 }}
                  InputProps={{
                    startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                    endAdornment: tableSearch && (
                      <InputAdornment position="end">
                        <IconButton size="small" onClick={() => setTableSearch('')}><CloseIcon fontSize="small" /></IconButton>
                      </InputAdornment>
                    ),
                  }}
                />

                {/* Filtre par classe SAP */}
                {tableClasses.length > 0 && (
                  <ToggleButtonGroup
                    size="small"
                    value={classFilter}
                    exclusive
                    onChange={(_, v) => v && setClassFilter(v)}
                    sx={{ mb: 1, flexWrap: 'wrap', gap: 0.5 }}
                  >
                    <ToggleButton value="ALL" sx={{ fontSize: '0.7rem', py: 0.3 }}>Toutes</ToggleButton>
                    {tableClasses.map((cls) => (
                      <ToggleButton key={cls} value={cls} sx={{ fontSize: '0.7rem', py: 0.3 }}>{cls}</ToggleButton>
                    ))}
                  </ToggleButtonGroup>
                )}

                {/* Liste des tables */}
                {status === 'loading' ? (
                  <LinearProgress />
                ) : (
                  <Box
                    sx={{
                      maxHeight: 380,
                      overflowY: 'auto',
                      border: '1px solid',
                      borderColor: 'divider',
                      borderRadius: 1,
                    }}
                  >
                    {filteredTables.length === 0 ? (
                      <Box sx={{ p: 3, textAlign: 'center' }}>
                        <Typography color="text.secondary" variant="body2">Aucune table trouvée</Typography>
                      </Box>
                    ) : (
                      filteredTables.map((table) => {
                        const isSelected = selectedTables.includes(table.name);
                        return (
                          <Box
                            key={table.name}
                            onClick={() => handleTableSelection(table.name)}
                            sx={{
                              display: 'flex',
                              alignItems: 'flex-start',
                              gap: 1,
                              px: 1.5,
                              py: 0.8,
                              cursor: 'pointer',
                              borderBottom: '1px solid',
                              borderColor: 'divider',
                              bgcolor: isSelected ? 'primary.main' : 'transparent',
                              color: isSelected ? 'primary.contrastText' : 'inherit',
                              '&:hover': {
                                bgcolor: isSelected ? 'primary.dark' : 'action.hover',
                              },
                              '&:last-child': { borderBottom: 0 },
                            }}
                          >
                            <Checkbox
                              checked={isSelected}
                              size="small"
                              sx={{ p: 0, mt: 0.2, color: isSelected ? 'inherit' : undefined }}
                            />
                            <Box sx={{ flex: 1, minWidth: 0 }}>
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, flexWrap: 'wrap' }}>
                                <Typography variant="body2" sx={{ fontFamily: 'monospace', fontWeight: 700, fontSize: '0.8rem' }}>
                                  {table.name}
                                </Typography>
                                {table.tableClass && (
                                  <Chip
                                    label={table.tableClass}
                                    size="small"
                                    sx={{ height: 16, fontSize: '0.6rem', opacity: 0.8 }}
                                  />
                                )}
                                {table.clientDependent && (
                                  <Chip label="mandant" size="small" color="warning" sx={{ height: 16, fontSize: '0.6rem' }} />
                                )}
                              </Box>
                              {table.description && (
                                <Typography
                                  variant="caption"
                                  sx={{
                                    display: 'block',
                                    opacity: 0.8,
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    whiteSpace: 'nowrap',
                                    maxWidth: '100%',
                                  }}
                                >
                                  {table.description}
                                </Typography>
                              )}
                            </Box>
                          </Box>
                        );
                      })
                    )}
                  </Box>
                )}

                <Box sx={{ mt: 1.5, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <Typography variant="body2" color="text.secondary">
                    {filteredTables.length} / {availableTables.length} tables affichées
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    <StorageIcon sx={{ fontSize: 14, color: 'primary.main' }} />
                    <Typography variant="body2" color="primary" fontWeight={600}>
                      {selectedTables.length} sélectionnée{selectedTables.length > 1 ? 's' : ''}
                    </Typography>
                  </Box>
                </Box>
                  </>
                ) : (
                  /* ── Vue Hiérarchie IFLO ── */
                  <>
                    <TextField
                      size="small"
                      fullWidth
                      placeholder="Rechercher un poste technique (code ou libellé)…"
                      value={ifloSearch}
                      onChange={(e) => setIfloSearch(e.target.value)}
                      sx={{ mb: 1 }}
                      InputProps={{
                        startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                        endAdornment: ifloSearch && (
                          <InputAdornment position="end">
                            <IconButton size="small" onClick={() => setIfloSearch('')}><CloseIcon fontSize="small" /></IconButton>
                          </InputAdornment>
                        ),
                      }}
                    />
                    <Box sx={{ maxHeight: 420, overflowY: 'auto', border: '1px solid', borderColor: 'divider', borderRadius: 1 }}>
                      {ifloLoading ? (
                        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                          <CircularProgress size={28} />
                        </Box>
                      ) : ifloTree.length === 0 ? (
                        <Box sx={{ p: 3, textAlign: 'center' }}>
                          <Typography color="text.secondary" variant="body2">Aucune donnée IFLO disponible</Typography>
                        </Box>
                      ) : (
                        <List dense disablePadding>
                          {ifloTree
                            .filter((n) => matchesIfloSearch(n, ifloSearch.toLowerCase()))
                            .map((node) => (
                              <IfloTreeNode
                                key={node.id}
                                node={node}
                                depth={0}
                                expanded={ifloExpanded}
                                onToggle={toggleIfloExpand}
                                selectedTables={selectedTables}
                                onSelectTable={handleTableSelection}
                                searchQuery={ifloSearch.toLowerCase()}
                                matchesSearch={matchesIfloSearch}
                              />
                            ))}
                        </List>
                      )}
                    </Box>
                    <Box sx={{ mt: 1, display: 'flex', justifyContent: 'space-between' }}>
                      <Typography variant="caption" color="text.secondary">
                        Cliquer sur un nœud pour l'ajouter à la sélection (ajoute IFLO aux tables)
                      </Typography>
                    </Box>
                  </>
                )}

                {/* Chips des tables sélectionnées */}
                {selectedTables.length > 0 && (
                  <Box sx={{ mt: 1, display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                    {selectedTables.map((name) => (
                      <Chip
                        key={name}
                        label={name}
                        size="small"
                        onDelete={() => handleTableSelection(name)}
                        color="primary"
                        variant="outlined"
                        sx={{ fontFamily: 'monospace', fontSize: '0.7rem' }}
                      />
                    ))}
                  </Box>
                )}
              </Grid>

              <Grid item xs={12} md={5}>
                <Typography variant="h6" gutterBottom>
                  Options d'extraction
                </Typography>

                <FormControl component="fieldset" sx={{ mb: 2 }}>
                  <FormLabel component="legend">Mode d'extraction</FormLabel>
                  <RadioGroup
                    value={extractionMode}
                    onChange={handleModeChange}
                  >
                    <FormControlLabel
                      value="standard"
                      control={<Radio />}
                      label="Standard (données de base uniquement)"
                    />
                    <FormControlLabel
                      value="debug"
                      control={<Radio />}
                      label="Debug (inclut les logs détaillés)"
                    />
                    <FormControlLabel
                      value="complet"
                      control={<Radio />}
                      label="Complet (vide la table puis recharge — TRUNCATE)"
                    />
                  </RadioGroup>
                </FormControl>

                {/* clean : action destructive → visible avec avertissement */}
                <FormControlLabel
                  control={
                    <Checkbox
                      checked={clean}
                      onChange={(e) => dispatch(setClean(e.target.checked))}
                      color="warning"
                    />
                  }
                  label="TRUNCATE les tables avant extraction (clean)"
                  sx={{ display: 'block', mb: 1 }}
                />

                {/* Options avancées repliables (techniques, rarement modifiées) */}
                <Box
                  onClick={() => setAdvancedOpen((o) => !o)}
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 0.5,
                    cursor: 'pointer',
                    userSelect: 'none',
                    color: 'text.secondary',
                    '&:hover': { color: 'text.primary' },
                  }}
                >
                  {advancedOpen ? <ExpandLess fontSize="small" /> : <ExpandMore fontSize="small" />}
                  <Typography variant="body2" fontWeight={600}>Options avancées</Typography>
                  <Typography variant="caption" sx={{ opacity: 0.8 }}>
                    (lot, page RFC, parallélisme)
                  </Typography>
                </Box>
                <Collapse in={advancedOpen}>
                  <Box sx={{ pl: 1, pt: 1 }}>
                    <TextField
                      label="Taille de lot (batch_size)"
                      type="number"
                      fullWidth
                      value={batchSize}
                      onChange={handleBatchSizeChange}
                      helperText="Nombre d'enregistrements par lot SAP"
                      margin="dense"
                    />
                    <TextField
                      label="Taille de page RFC (page_size)"
                      type="number"
                      fullWidth
                      value={pageSize}
                      onChange={(e) => {
                        const v = parseInt(e.target.value, 10);
                        if (!isNaN(v) && v > 0) dispatch(setPageSize(v));
                      }}
                      helperText="Lignes par page RFC (défaut : 5000)"
                      margin="dense"
                    />
                    <TextField
                      label="Connexions parallèles (workers)"
                      type="number"
                      fullWidth
                      value={workers}
                      onChange={(e) => {
                        const v = parseInt(e.target.value, 10);
                        if (!isNaN(v) && v >= 1 && v <= 16) dispatch(setWorkers(v));
                      }}
                      helperText="Nb de connexions SAP parallèles (1-16)"
                      margin="dense"
                      inputProps={{ min: 1, max: 16 }}
                    />
                  </Box>
                </Collapse>

                <Divider sx={{ mt: 3 }} />
                <Box
                  sx={{
                    mt: 2,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: 2,
                    flexWrap: 'wrap',
                  }}
                >
                  <Typography variant="body2" color="text.secondary">
                    {selectedTables.length > 0
                      ? `${selectedTables.length} table${selectedTables.length > 1 ? 's' : ''} sélectionnée${selectedTables.length > 1 ? 's' : ''}`
                      : 'Aucune table sélectionnée'}
                  </Typography>
                  <Box sx={{ display: 'flex', gap: 1.5 }}>
                    <Button
                      variant="outlined"
                      color="inherit"
                      startIcon={<CloseIcon />}
                      onClick={handleCancelExtraction}
                    >
                      Annuler
                    </Button>
                    <Tooltip
                      title={selectedTables.length === 0 ? 'Sélectionnez au moins une table à extraire' : ''}
                    >
                      <span>
                        <Button
                          variant="contained"
                          startIcon={<StartIcon />}
                          onClick={handleStartExtraction}
                          disabled={selectedTables.length === 0 || status === 'loading'}
                        >
                          Démarrer l'extraction
                        </Button>
                      </span>
                    </Tooltip>
                  </Box>
                </Box>
              </Grid>
            </Grid>

            {/* Journal d'exécution live (même rendu que /data-loading) */}
            {runningJobId && (
              <Box sx={{ mt: 3 }}>
                {runActive && (
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                    <LinearProgress
                      variant="determinate"
                      value={runJob?.progress ?? 0}
                      sx={{ flex: 1, height: 8, borderRadius: 4 }}
                    />
                    <Typography variant="body2" sx={{ minWidth: 40 }}>
                      {Math.round(runJob?.progress ?? 0)}%
                    </Typography>
                  </Box>
                )}
                <LogPanel logs={runLogs} live={runActive} height={300} />
              </Box>
            )}
          </CardContent>
        </TabPanel>

        {/* History Tab - Remplacé par le nouveau composant ExtractionHistory */}
        <TabPanel value={tabValue} index={1}>
          <ExtractionHistory />
        </TabPanel>

        {/* Modale Catalogue SAP — recherche de tables disponibles */}
        <Dialog open={discoverOpen} onClose={closeDiscover} maxWidth="lg" fullWidth>
          <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <DiscoverIcon color="primary" />
            Catalogue des tables SAP
          </DialogTitle>
          <DialogContent dividers>
            {/* Barre de recherche + filtre domaine */}
            <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
              <TextField
                size="small"
                sx={{ flex: 1, minWidth: 240 }}
                placeholder="Rechercher (nom de table ou description)…"
                value={availSearch}
                onChange={(e) => handleAvailSearchChange(e.target.value)}
                InputProps={{
                  startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                  endAdornment: availSearch && (
                    <InputAdornment position="end">
                      <IconButton size="small" onClick={() => handleAvailSearchChange('')}><CloseIcon fontSize="small" /></IconButton>
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                size="small"
                sx={{ width: 160 }}
                label="Domaine (MM, SD…)"
                value={availDomaine}
                onChange={(e) => handleAvailDomaineChange(e.target.value.toUpperCase())}
                InputProps={{
                  endAdornment: availDomaine && (
                    <InputAdornment position="end">
                      <IconButton size="small" onClick={() => handleAvailDomaineChange('')}><CloseIcon fontSize="small" /></IconButton>
                    </InputAdornment>
                  ),
                }}
              />
            </Box>

            {availError && <Alert severity="error" sx={{ mb: 2 }}>{availError}</Alert>}

            {/* Progression du job d'extraction de métadonnées */}
            {metadataJob && (
              <Alert
                severity={
                  metadataJob.status === 'failed'
                    ? 'error'
                    : metadataJob.status === 'completed_with_errors'
                    ? 'warning'
                    : metadataJob.status === 'completed'
                    ? 'success'
                    : 'info'
                }
                sx={{ mb: 2 }}
                icon={
                  METADATA_TERMINAL.includes(metadataJob.status)
                    ? undefined
                    : <CircularProgress size={18} />
                }
              >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5 }}>
                  <Typography variant="body2" sx={{ fontWeight: 700 }}>
                    Métadonnées : {metadataJob.tablesDone}/{metadataJob.tables.length} table(s)
                    {metadataJob.errors > 0 ? ` — ${metadataJob.errors} erreur(s)` : ''}
                  </Typography>
                </Box>
                {metadataJob.error && (
                  <Typography variant="body2" color="error">{metadataJob.error}</Typography>
                )}
                {metadataJob.tablesDetails?.map((d) => (
                  <Box key={d.name} sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                    {d.status === 'error' ? (
                      <ErrorIcon fontSize="small" color="error" />
                    ) : d.status === 'completed' ? (
                      <CheckIcon fontSize="small" color="success" />
                    ) : d.status === 'running' ? (
                      <CircularProgress size={14} />
                    ) : (
                      <ScheduleIcon fontSize="small" color="disabled" />
                    )}
                    <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                      {d.name} — {d.status}
                      {d.status === 'completed' && d.fields_count ? ` (${d.fields_count} champs${d.added_to_config ? ', table créée' : ''})` : ''}
                      {d.error ? ` : ${d.error}` : ''}
                    </Typography>
                  </Box>
                ))}
              </Alert>
            )}

            <TableContainer sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1, position: 'relative' }}>
              {availLoading && <LinearProgress sx={{ position: 'absolute', top: 0, left: 0, right: 0 }} />}
              <Table size="small" stickyHeader>
                <TableHead>
                  <TableRow>
                    <TableCell padding="checkbox" />
                    <TableCell sx={{ fontWeight: 700 }}>Table SAP</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Description</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Domaine</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Modifié par</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Date</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {availResults.length === 0 && !availLoading ? (
                    <TableRow>
                      <TableCell colSpan={6} align="center" sx={{ py: 4, color: 'text.disabled' }}>
                        Aucune table trouvée
                      </TableCell>
                    </TableRow>
                  ) : (
                    availResults.map((t) => {
                      const checked = tablesToCreate.includes(t.table_sap);
                      return (
                        <TableRow
                          key={t.table_sap}
                          hover
                          selected={checked}
                          onClick={() => toggleTableToCreate(t.table_sap)}
                          sx={{ cursor: 'pointer' }}
                        >
                          <TableCell padding="checkbox">
                            <Checkbox checked={checked} size="small" />
                          </TableCell>
                          <TableCell sx={{ fontFamily: 'monospace', fontWeight: 700 }}>{t.table_sap}</TableCell>
                          <TableCell>{t.description}</TableCell>
                          <TableCell>
                            {t.domaine_applicatif && (
                              <Chip label={t.domaine_applicatif} size="small" sx={{ height: 18, fontSize: '0.65rem' }} />
                            )}
                          </TableCell>
                          <TableCell>{t.modifie_par}</TableCell>
                          <TableCell>{formatSapDate(t.date_modification)}</TableCell>
                        </TableRow>
                      );
                    })
                  )}
                </TableBody>
              </Table>
              <TablePagination
                component="div"
                count={availTotal}
                page={availPage}
                onPageChange={(_, p) => setAvailPage(p)}
                rowsPerPage={availRowsPerPage}
                onRowsPerPageChange={(e) => { setAvailRowsPerPage(parseInt(e.target.value, 10)); setAvailPage(0); }}
                rowsPerPageOptions={[50, 100, 250, 500]}
                labelRowsPerPage="Lignes/page"
                labelDisplayedRows={({ from, to, count }) => `${from}–${to} sur ${count}`}
              />
            </TableContainer>
          </DialogContent>
          <DialogActions>
            <Typography variant="body2" color="text.secondary" sx={{ mr: 'auto', ml: 1 }}>
              {tablesToCreate.length} sélectionnée{tablesToCreate.length > 1 ? 's' : ''}
            </Typography>
            <Button onClick={closeDiscover}>Fermer</Button>
            <Button
              variant="contained"
              startIcon={creating ? <CircularProgress size={18} /> : <AddIcon />}
              disabled={tablesToCreate.length === 0 || creating}
              onClick={handleCreateTables}
            >
              {creating ? 'Extraction…' : `Ajouter ${tablesToCreate.length || ''} table(s)`}
            </Button>
          </DialogActions>
        </Dialog>

        {/* Status Tab */}
        <TabPanel value={tabValue} index={2}>
          <CardContent>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
              <Typography variant="h6">Extractions en cours</Typography>
              <FormControlLabel
                control={
                  <Checkbox
                    checked={showRunningOnly}
                    onChange={(e) => setShowRunningOnly(e.target.checked)}
                  />
                }
                label="Voir uniquement les tâches en cours"
              />
            </Box>
            <Divider sx={{ mb: 3 }} />

            {extractionJobs
              .filter((job) => job.status === 'running' || job.status === 'pending')
              .map((job) => (
                <Card key={job.id} sx={{ mb: 3, bgcolor: 'background.paper' }}>
                  <CardHeader
                    title={`Extraction #${job.id.substring(0, 8)}...`}
                    subheader={`${job.tables.length} tables - Démarré le ${new Date(
                      job.startedAt
                    ).toLocaleString()}`}
                    action={
                      <Chip
                        label={job.status === 'running' ? 'En cours' : 'En attente'}
                        color="primary"
                      />
                    }
                  />
                  <CardContent>
                    <Box sx={{ mb: 2 }}>
                      <Typography variant="body2" gutterBottom>
                        Progression: {job.progress || 0}%
                      </Typography>
                      <LinearProgress
                        variant="determinate"
                        value={job.progress || 0}
                        sx={{ height: 8, borderRadius: 1 }}
                      />
                    </Box>
                    <Typography variant="body2">
                      Tables: {job.tables.join(', ')}
                    </Typography>
                    <Typography variant="body2">
                      Lignes extraites: {job.rowsExtracted ? job.rowsExtracted.toLocaleString() : 0}
                    </Typography>
                  </CardContent>
                </Card>
              ))}

            {extractionJobs.filter(
              (job) => job.status === 'running' || job.status === 'pending'
            ).length === 0 && (
              <Box sx={{ textAlign: 'center', py: 4 }}>
                <Typography variant="body1" color="text.secondary">
                  Aucune extraction en cours
                </Typography>
                <Button
                  variant="contained"
                  startIcon={<AddIcon />}
                  sx={{ mt: 2 }}
                  onClick={() => setTabValue(0)}
                >
                  Démarrer une nouvelle extraction
                </Button>
              </Box>
            )}
          </CardContent>
        </TabPanel>
      </Card>
    </Box>
  );
};

export default Extraction;