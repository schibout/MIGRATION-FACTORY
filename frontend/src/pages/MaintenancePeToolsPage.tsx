/**
 * Gammes de maintenance preventive — source raw_data.pe_tools.
 *
 * Une ligne = un poste technique + son plan d'entretien + sa gamme (groupe /
 * compteur), avec frequence et charge. L'ecran permet de filtrer, exporter en
 * CSV le perimetre filtre et ouvrir le detail d'une ligne (lecture seule,
 * page /maintenance/pe-tools/:rawId). Les gammes ne se modifient pas dans
 * l'application : on corrige les fichiers PE Tools puis on les reimporte.
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  FormControl,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  LinearProgress,
  List,
  ListItem,
  ListItemText,
  MenuItem,
  Paper,
  Select,
  Snackbar,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TableSortLabel,
  TextField,
  Tooltip,
  Typography,
  alpha,
  useTheme,
} from '@mui/material';
import {
  Clear as ClearIcon,
  Download as DownloadIcon,
  EventRepeat as FrequencyIcon,
  Handyman as PeToolsIcon,
  Refresh as RefreshIcon,
  Schedule as ScheduleIcon,
  Search as SearchIcon,
  Upload as UploadIcon,
  Visibility as DetailIcon,
  AccountTree as PosteIcon,
} from '@mui/icons-material';
import api from '../services/api';
import DateExecutionEditable, { fmtDateIso, ResultatSaisieDate } from '../components/maintenance/DateExecutionEditable';

interface PeTool {
  raw_id: number;
  [key: string]: any;
}

interface Stats {
  total: number;
  nb_postes_techniques: number;
  nb_plans_entretien: number;
  nb_gammes: number;
  charge_totale: string;
  by_frequence: { frequence: string; nb: number }[];
}

interface ImportResult {
  fichier: string;
  status: 'ok' | 'error';
  code_fichier: string | null;
  organisation_maintenance: string | null;
  lignes_supprimees: number;
  lignes_inserees: number;
  avertissements: string[];
  error?: string;
}

// Colonnes de la table, dans l'ordre d'affichage de la page detail.
// `inTable` = affichee dans la liste principale.
export const FIELDS: { key: string; label: string; inTable?: boolean; monospace?: boolean }[] = [
  { key: 'poste_technique', label: 'Poste technique', inTable: true, monospace: true },
  { key: 'niveau_sap', label: 'Niveau SAP' },
  { key: 'localisation_classement', label: 'Localisation / classement', inTable: true },
  { key: 'designation', label: 'Désignation', inTable: true },
  { key: 'frequence', label: 'Fréquence', inTable: true },
  { key: 'type', label: 'Type', inTable: true },
  // Fichier retire de la liste (redondant avec Organisation, deduite du nom de fichier) :
  // reste dans le detail et les filtres.
  { key: 'nom_fichier', label: 'Fichier', monospace: true },
  // A la place du fichier : cle de la date de derniere execution (plan, a defaut poste d'entretien).
  { key: 'plan_entretien', label: 'Plan d\'entretien', inTable: true, monospace: true },
  { key: 'organisation_maintenance', label: 'Organisation', inTable: true, monospace: true },
  { key: 'criticite', label: 'Criticité' },
  // Calculee (082/084) depuis raw_data.plan_entretien_derniere_exec ; saisie possible sur place (085).
  { key: 'date_derniere_execution', label: 'Dernière exécution', inTable: true },
  // Generee (migration 083) : derniere execution + frequence (S/M/A ; H -> vide).
  { key: 'ifs_date_execution', label: 'Date exécution IFS', inTable: true },
  { key: 'poste_entretien', label: 'Poste d\'entretien', monospace: true },
  { key: 'groupe_de_gamme', label: 'Groupe de gamme', monospace: true },
  { key: 'compteur_de_gamme', label: 'Compteur de gamme', monospace: true },
  { key: 'charge', label: 'Charge (h)', inTable: true },
  { key: 'nb_intervenants', label: 'Nb intervenants' },
  { key: 'parite_semaine', label: 'Parité semaine' },
  { key: 'jour', label: 'Jour' },
  { key: 'decalage', label: 'Décalage' },
  { key: 'date_validation', label: 'Date de validation' },
  { key: 'date_rev', label: 'Date de revue' },
  { key: 'nb_jours_depuis_derniere_rev', label: 'Jours depuis dernière revue' },
  { key: 'gamme_en_dms', label: 'Gamme en DMS' },
  { key: 'dms_sap', label: 'DMS SAP' },
  { key: 'lien_fichier_gamme_source', label: 'Lien fichier gamme source' },
  { key: 'lien_fichier_dms_sap_pdf', label: 'Lien fichier DMS SAP (PDF)' },
];

const TABLE_FIELDS = FIELDS.filter((f) => f.inTable);
// Colonnes DATE (ISO cote API) affichees en JJ/MM/AAAA.
const DATE_KEYS = ['date_derniere_execution', 'ifs_date_execution'];

// Filtres a liste deroulante : doivent correspondre a FILTER_COLUMNS cote API.
const SELECT_FILTERS: { key: string; label: string }[] = [
  { key: 'localisation_classement', label: 'Localisation' },
  { key: 'poste_technique', label: 'Poste technique' },
  { key: 'type', label: 'Type' },
  { key: 'frequence', label: 'Fréquence' },
  { key: 'criticite', label: 'Criticité' },
  { key: 'gamme_en_dms', label: 'Gamme en DMS' },
  { key: 'nom_fichier', label: 'Fichier' },
  { key: 'organisation_maintenance', label: 'Organisation' },
];

const MaintenancePeToolsPage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();

  const [rows, setRows] = useState<PeTool[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [orderBy, setOrderBy] = useState('poste_technique');
  const [order, setOrder] = useState<'asc' | 'desc'>('asc');

  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [filters, setFilters] = useState<Record<string, string>>({});
  const [filterOptions, setFilterOptions] = useState<Record<string, string[]>>({});

  const [stats, setStats] = useState<Stats | null>(null);

  const [exporting, setExporting] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  // Meme route d'import : seul le type de fichier propose change.
  const [importExcel, setImportExcel] = useState(false);
  const [importFiles, setImportFiles] = useState<File[]>([]);
  const [importing, setImporting] = useState(false);
  const [importResults, setImportResults] = useState<ImportResult[] | null>(null);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  const activeFilterCount = useMemo(
    () => Object.values(filters).filter(Boolean).length + (debouncedSearch ? 1 : 0),
    [filters, debouncedSearch]
  );

  /** Parametres de filtrage communs a la liste, aux stats et a l'export. */
  const filterParams = useCallback(() => {
    const params = new URLSearchParams();
    if (debouncedSearch) params.append('search', debouncedSearch);
    Object.entries(filters).forEach(([k, v]) => {
      if (v) params.append(k, v);
    });
    return params;
  }, [debouncedSearch, filters]);

  const loadRows = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = filterParams();
      params.append('page', String(page + 1));
      params.append('per_page', String(rowsPerPage));
      params.append('order_by', orderBy);
      params.append('order', order);

      const response = await api.get(`/maintenance/pe-tools?${params}`);
      if (response.data.success) {
        setRows(response.data.data || []);
        setTotal(response.data.total || 0);
        setFilterOptions(response.data.filter_options || {});
      }
    } catch (err: any) {
      console.error('Erreur chargement pe_tools:', err);
      setError(err?.response?.data?.error || 'Erreur lors du chargement des gammes');
    } finally {
      setLoading(false);
    }
  }, [filterParams, page, rowsPerPage, orderBy, order]);

  const loadStats = useCallback(async () => {
    try {
      const response = await api.get(`/maintenance/pe-tools/stats?${filterParams()}`);
      if (response.data.success) setStats(response.data.data);
    } catch (err) {
      console.error('Erreur stats pe_tools:', err);
    }
  }, [filterParams]);

  useEffect(() => { loadRows(); }, [loadRows]);
  useEffect(() => { loadStats(); }, [loadStats]);

  useEffect(() => {
    const t = setTimeout(() => {
      setDebouncedSearch(searchQuery);
      setPage(0);
    }, 400);
    return () => clearTimeout(t);
  }, [searchQuery]);

  // Une saisie vaut pour toutes les gammes du meme plan (ou poste) : on relit la page.
  const dateSaisie = (res: ResultatSaisieDate) => {
    const cible = `${res.id_type === 'POSTE' ? 'poste d\'entretien' : 'plan'} ${res.identifiant}`;
    setSnackbar({
      open: true,
      severity: 'success',
      message: res.saisie_manuelle
        ? `Date enregistrée pour le ${cible} (${res.nb_gammes} gamme(s)). Date IFS : ${fmtDateIso(res.ifs_date_execution) || '—'}`
        : `Saisie retirée pour le ${cible} : retour à la date du fichier.`,
    });
    loadRows();
  };

  const handleSort = (col: string) => {
    const isAsc = orderBy === col && order === 'asc';
    setOrder(isAsc ? 'desc' : 'asc');
    setOrderBy(col);
  };

  const clearFilters = () => {
    setSearchQuery('');
    setDebouncedSearch('');
    setFilters({});
    setPage(0);
  };

  /** Export CSV du perimetre filtre courant (pas seulement de la page affichee). */
  const exportCsv = async () => {
    try {
      setExporting(true);
      const params = filterParams();
      params.append('order_by', orderBy);
      params.append('order', order);
      const response = await api.get(`/maintenance/pe-tools/export?${params}`, { responseType: 'blob' });
      const url = window.URL.createObjectURL(new Blob([response.data], { type: 'text/csv;charset=utf-8;' }));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'pe_tools.csv');
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err: any) {
      setSnackbar({ open: true, message: 'Erreur lors de l\'export', severity: 'error' });
    } finally {
      setExporting(false);
    }
  };

  const openImport = (excel: boolean) => {
    setImportExcel(excel);
    setImportFiles([]);
    setImportResults(null);
    setImportOpen(true);
  };

  const closeImport = async () => {
    setImportOpen(false);
    if (importResults) {
      await loadRows();
      await loadStats();
    }
  };

  /** Import multi-fichiers : chaque fichier remplace les lignes de son code. */
  const runImport = async () => {
    if (importFiles.length === 0) return;
    const form = new FormData();
    importFiles.forEach((f) => form.append('files', f, f.name));
    try {
      setImporting(true);
      const response = await api.post('/maintenance/pe-tools/import', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setImportResults(response.data.results || []);
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err?.response?.data?.error || 'Erreur lors de l\'import',
        severity: 'error',
      });
    } finally {
      setImporting(false);
    }
  };

  const statCards = [
    { icon: PeToolsIcon, color: theme.palette.primary.main, value: stats?.total, label: 'Gammes' },
    { icon: PosteIcon, color: theme.palette.warning.main, value: stats?.nb_postes_techniques, label: 'Postes techniques' },
    { icon: ScheduleIcon, color: theme.palette.info.main, value: stats?.nb_plans_entretien, label: 'Plans d\'entretien' },
    {
      icon: FrequencyIcon,
      color: theme.palette.success.main,
      value: stats ? Math.round(Number(stats.charge_totale)) : undefined,
      label: 'Charge totale (h)',
    },
  ];

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <PeToolsIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.primary.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Gammes préventives (PE Tools)
        </Typography>
        <Chip label="raw_data.pe_tools" size="small" variant="outlined" sx={{ ml: 2, fontFamily: 'monospace' }} />
        <Box sx={{ flex: 1 }} />
        <Button variant="outlined" size="small" startIcon={<UploadIcon />} onClick={() => openImport(false)} sx={{ mr: 1 }}>
          Importer
        </Button>
        <Button variant="outlined" size="small" startIcon={<UploadIcon />} onClick={() => openImport(true)} sx={{ mr: 1 }}>
          Importer Excel
        </Button>
        <Button
          variant="outlined"
          size="small"
          startIcon={exporting ? <CircularProgress size={16} /> : <DownloadIcon />}
          onClick={exportCsv}
          disabled={exporting}
          sx={{ mr: 1 }}
        >
          Exporter CSV
        </Button>
        <Tooltip title="Rafraîchir">
          <span>
            <IconButton onClick={() => { loadRows(); loadStats(); }} disabled={loading}>
              <RefreshIcon />
            </IconButton>
          </span>
        </Tooltip>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Grid container spacing={2} sx={{ mb: 3 }}>
        {statCards.map((c) => {
          const Icon = c.icon;
          return (
            <Grid item xs={12} sm={6} md={3} key={c.label}>
              <Card sx={{ backgroundColor: alpha(c.color, 0.1) }}>
                <CardContent sx={{ py: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center' }}>
                    <Icon sx={{ fontSize: 40, color: c.color, mr: 2 }} />
                    <Box>
                      <Typography variant="h4" sx={{ fontWeight: 600 }}>
                        {c.value !== undefined && c.value !== null ? Number(c.value).toLocaleString() : '—'}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">{c.label}</Typography>
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      <Box sx={{ display: 'flex', flex: 1, minHeight: 0 }}>
        <Paper
          elevation={0}
          sx={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
            overflow: 'hidden',
          }}
        >
          <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
            <Grid container spacing={2} alignItems="center">
              <Grid item xs={12} md={4}>
                <TextField
                  fullWidth
                  size="small"
                  placeholder="Rechercher (désignation, poste, plan, gamme)..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start"><SearchIcon /></InputAdornment>
                    ),
                  }}
                />
              </Grid>
              {SELECT_FILTERS.map((f) => (
                <Grid item xs={6} md={2} key={f.key}>
                  <FormControl fullWidth size="small">
                    <InputLabel>{f.label}</InputLabel>
                    <Select
                      value={filters[f.key] || ''}
                      label={f.label}
                      onChange={(e) => {
                        setFilters((prev) => ({ ...prev, [f.key]: e.target.value as string }));
                        setPage(0);
                      }}
                    >
                      <MenuItem value="">Tous</MenuItem>
                      {(filterOptions[f.key] || []).map((v) => (
                        <MenuItem key={v} value={v}>{v}</MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                </Grid>
              ))}
              <Grid item xs={12} md={2}>
                <Button
                  fullWidth
                  variant="outlined"
                  startIcon={<ClearIcon />}
                  onClick={clearFilters}
                  disabled={activeFilterCount === 0}
                >
                  Effacer
                </Button>
              </Grid>
            </Grid>
          </Box>

          {loading && <LinearProgress />}

          <TableContainer sx={{ flex: 1 }}>
            <Table stickyHeader size="small">
              <TableHead>
                <TableRow>
                  <TableCell />
                  {TABLE_FIELDS.map((f) => (
                    <TableCell key={f.key}>
                      <TableSortLabel
                        active={orderBy === f.key}
                        direction={orderBy === f.key ? order : 'asc'}
                        onClick={() => handleSort(f.key)}
                      >
                        {f.label}
                      </TableSortLabel>
                    </TableCell>
                  ))}
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((r) => (
                  <TableRow key={r.raw_id} hover>
                    <TableCell padding="checkbox">
                      <Tooltip title="Voir détail">
                        <IconButton size="small" onClick={() => navigate(`/maintenance/pe-tools/${r.raw_id}`)}>
                          <DetailIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                    {TABLE_FIELDS.map((f) => (
                      <TableCell
                        key={f.key}
                        sx={{
                          fontFamily: f.monospace ? 'monospace' : 'inherit',
                          fontWeight: f.monospace ? 600 : 400,
                          maxWidth: f.key === 'designation' ? 320 : f.key === 'date_derniere_execution' ? 'none' : 200,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {f.key === 'date_derniere_execution' ? (
                          <DateExecutionEditable
                            rawId={r.raw_id}
                            valeur={r[f.key]}
                            onSaved={dateSaisie}
                            onError={(message) => setSnackbar({ open: true, message, severity: 'error' })}
                          />
                        ) : (DATE_KEYS.includes(f.key) ? fmtDateIso(r[f.key]) : r[f.key]) || '—'}
                      </TableCell>
                    ))}
                  </TableRow>
                ))}
                {!loading && rows.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={TABLE_FIELDS.length + 1} align="center" sx={{ py: 4 }}>
                      <Typography color="text.secondary">Aucune gamme trouvée</Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>

          <TablePagination
            component="div"
            count={total}
            page={page}
            onPageChange={(_, p) => setPage(p)}
            rowsPerPage={rowsPerPage}
            onRowsPerPageChange={(e) => {
              setRowsPerPage(parseInt(e.target.value, 10));
              setPage(0);
            }}
            rowsPerPageOptions={[10, 25, 50, 100, 200]}
            labelRowsPerPage="Lignes par page:"
            labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
          />
        </Paper>

      </Box>

      <Dialog open={importOpen} onClose={importing ? undefined : closeImport} maxWidth="md" fullWidth>
        <DialogTitle>Importer des fichiers PE Tools</DialogTitle>
        <DialogContent>
          {!importResults ? (
            <>
              <DialogContentText sx={{ mb: 2 }}>
                {importExcel ? (
                  <>Classeurs <code>PeTool - 7.&lt;CODE&gt;.xlsm</code> d'origine (onglet <code>7.&lt;CODE&gt;</code>,
                  seules les lignes portant un poste technique ou un plan sont reprises).</>
                ) : (
                  <>Fichiers <code>PeTool - 7.&lt;CODE&gt;.csv</code> (export Excel, séparateur « ; »).</>
                )}
                Les lignes déjà importées pour le même code de fichier sont remplacées ; les autres
                fichiers et les lignes historiques ne bougent pas. L'organisation de maintenance est
                déduite du nom du fichier.
              </DialogContentText>
              <Box
                component="input"
                type="file"
                multiple
                accept={importExcel ? '.xlsx,.xlsm' : '.csv'}
                aria-label={importExcel ? 'Classeurs Excel PE Tools' : 'Fichiers CSV PE Tools'}
                disabled={importing}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  setImportFiles(Array.from(e.target.files || []))
                }
                sx={{ display: 'block', mb: 2 }}
              />
              {importFiles.length > 0 && (
                <List dense>
                  {importFiles.map((f) => (
                    <ListItem key={f.name}>
                      <ListItemText
                        primary={f.name}
                        secondary={`${Math.max(1, Math.round(f.size / 1024))} Ko`}
                        primaryTypographyProps={{ fontFamily: 'monospace' }}
                      />
                    </ListItem>
                  ))}
                </List>
              )}
            </>
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Fichier</TableCell>
                    <TableCell>Organisation</TableCell>
                    <TableCell align="right">Supprimées</TableCell>
                    <TableCell align="right">Insérées</TableCell>
                    <TableCell>Statut</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {importResults.map((r) => (
                    <React.Fragment key={r.fichier}>
                      <TableRow>
                        <TableCell sx={{ fontFamily: 'monospace' }}>{r.fichier}</TableCell>
                        <TableCell>
                          {r.organisation_maintenance ? (
                            <Chip size="small" label={r.organisation_maintenance} sx={{ fontFamily: 'monospace' }} />
                          ) : (
                            <Chip size="small" color="warning" label="non résolue" />
                          )}
                        </TableCell>
                        <TableCell align="right">{r.lignes_supprimees}</TableCell>
                        <TableCell align="right">{r.lignes_inserees}</TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            color={r.status === 'ok' ? 'success' : 'error'}
                            label={r.status === 'ok' ? 'OK' : 'Erreur'}
                          />
                        </TableCell>
                      </TableRow>
                      {(r.error || r.avertissements.length > 0) && (
                        <TableRow>
                          <TableCell colSpan={5} sx={{ pt: 0 }}>
                            {r.error && <Alert severity="error" sx={{ mb: 0.5 }}>{r.error}</Alert>}
                            {r.avertissements.map((a) => (
                              <Alert key={a} severity="warning" sx={{ mb: 0.5 }}>{a}</Alert>
                            ))}
                          </TableCell>
                        </TableRow>
                      )}
                    </React.Fragment>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </DialogContent>
        <DialogActions>
          {!importResults ? (
            <>
              <Button onClick={closeImport} disabled={importing}>Annuler</Button>
              <Button
                variant="contained"
                onClick={runImport}
                disabled={importing || importFiles.length === 0}
                startIcon={importing ? <CircularProgress size={16} /> : <UploadIcon />}
              >
                Lancer l'import
              </Button>
            </>
          ) : (
            <Button variant="contained" onClick={closeImport}>Fermer</Button>
          )}
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={4000}
        onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
      >
        <Alert
          severity={snackbar.severity}
          onClose={() => setSnackbar((prev) => ({ ...prev, open: false }))}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default MaintenancePeToolsPage;
