/**
 * Gammes de maintenance preventive — source raw_data.pe_tools.
 *
 * Une ligne = un poste technique + son plan d'entretien + sa gamme (groupe /
 * compteur), avec frequence et charge. L'ecran permet de filtrer, exporter en
 * CSV le perimetre filtre, et modifier / creer / supprimer une ligne.
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
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
  Divider,
  FormControl,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  LinearProgress,
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
  Add as AddIcon,
  Cancel as CancelIcon,
  Clear as ClearIcon,
  Delete as DeleteIcon,
  Download as DownloadIcon,
  Edit as EditIcon,
  EventRepeat as FrequencyIcon,
  Handyman as PeToolsIcon,
  Refresh as RefreshIcon,
  Save as SaveIcon,
  Schedule as ScheduleIcon,
  Search as SearchIcon,
  AccountTree as PosteIcon,
} from '@mui/icons-material';
import api from '../services/api';

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

// Colonnes de la table, dans l'ordre d'affichage du panneau de detail.
// `inTable` = affichee dans la liste principale.
const FIELDS: { key: string; label: string; inTable?: boolean; monospace?: boolean }[] = [
  { key: 'poste_technique', label: 'Poste technique', inTable: true, monospace: true },
  { key: 'niveau_sap', label: 'Niveau SAP' },
  { key: 'localisation_classement', label: 'Localisation / classement', inTable: true },
  { key: 'designation', label: 'Désignation', inTable: true },
  { key: 'frequence', label: 'Fréquence', inTable: true },
  { key: 'type', label: 'Type', inTable: true },
  { key: 'criticite', label: 'Criticité' },
  { key: 'plan_entretien', label: 'Plan d\'entretien', monospace: true },
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

// Filtres a liste deroulante : doivent correspondre a FILTER_COLUMNS cote API.
const SELECT_FILTERS: { key: string; label: string }[] = [
  { key: 'localisation_classement', label: 'Localisation' },
  { key: 'poste_technique', label: 'Poste technique' },
  { key: 'type', label: 'Type' },
  { key: 'frequence', label: 'Fréquence' },
  { key: 'criticite', label: 'Criticité' },
  { key: 'gamme_en_dms', label: 'Gamme en DMS' },
];

const MaintenancePeToolsPage: React.FC = () => {
  const theme = useTheme();

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

  const [selected, setSelected] = useState<PeTool | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [editedData, setEditedData] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<PeTool | null>(null);
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

  const selectRow = (row: PeTool) => {
    setSelected(row);
    setIsEditing(false);
    setIsCreating(false);
    setEditedData({});
  };

  const startCreating = () => {
    setSelected(null);
    setIsCreating(true);
    setIsEditing(true);
    setEditedData({});
  };

  const cancelEditing = () => {
    setIsEditing(false);
    setIsCreating(false);
    setEditedData({});
  };

  const handleFieldChange = (field: string, value: string) => {
    // En creation tout est conserve ; en edition on ne garde que les ecarts
    // avec la valeur d'origine (PUT partiel).
    if (isCreating) {
      setEditedData((prev) => ({ ...prev, [field]: value }));
      return;
    }
    const original = String(selected?.[field] ?? '');
    setEditedData((prev) => {
      const next = { ...prev };
      if (value === original) delete next[field];
      else next[field] = value;
      return next;
    });
  };

  const saveChanges = async () => {
    const payload = Object.fromEntries(
      Object.entries(editedData).filter(([, v]) => v !== undefined)
    );
    if (Object.keys(payload).length === 0) return;
    try {
      setSaving(true);
      if (isCreating) {
        const response = await api.post('/maintenance/pe-tools', payload);
        if (response.data.success) {
          setSnackbar({ open: true, message: 'Gamme créée', severity: 'success' });
          cancelEditing();
          await loadRows();
          await loadStats();
        }
      } else if (selected) {
        const response = await api.put(`/maintenance/pe-tools/${selected.raw_id}`, payload);
        if (response.data.success) {
          setSnackbar({ open: true, message: 'Modifications enregistrées', severity: 'success' });
          setIsEditing(false);
          setEditedData({});
          setSelected({ ...selected, ...payload });
          await loadRows();
          await loadStats();
        }
      }
    } catch (err: any) {
      setSnackbar({
        open: true,
        message: err?.response?.data?.error || 'Erreur lors de la sauvegarde',
        severity: 'error',
      });
    } finally {
      setSaving(false);
    }
  };

  const deleteRow = async () => {
    if (!confirmDelete) return;
    try {
      await api.delete(`/maintenance/pe-tools/${confirmDelete.raw_id}`);
      setSnackbar({ open: true, message: 'Ligne supprimée', severity: 'success' });
      if (selected?.raw_id === confirmDelete.raw_id) setSelected(null);
      setConfirmDelete(null);
      await loadRows();
      await loadStats();
    } catch (err: any) {
      setConfirmDelete(null);
      setSnackbar({
        open: true,
        message: err?.response?.data?.error || 'Erreur lors de la suppression',
        severity: 'error',
      });
    }
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

  const renderDetails = () => {
    if (!selected && !isCreating) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'text.secondary' }}>
          <PeToolsIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">Sélectionnez une gamme</Typography>
          <Typography variant="caption">ou créez-en une nouvelle</Typography>
        </Box>
      );
    }

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 2 }}>
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>
                {isCreating ? 'Nouvelle gamme' : (selected?.poste_technique || '—')}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                {isCreating ? 'Renseignez les champs puis enregistrez' : (selected?.designation || '—')}
              </Typography>
            </Box>
            <Box sx={{ flexShrink: 0, display: 'flex', gap: 1 }}>
              {isEditing ? (
                <>
                  <Button size="small" variant="outlined" startIcon={<CancelIcon />} onClick={cancelEditing}>
                    Annuler
                  </Button>
                  <Button
                    size="small"
                    variant="contained"
                    startIcon={saving ? <CircularProgress size={16} /> : <SaveIcon />}
                    onClick={saveChanges}
                    disabled={saving || Object.keys(editedData).length === 0}
                  >
                    Enregistrer
                  </Button>
                </>
              ) : (
                <>
                  <Button size="small" variant="outlined" startIcon={<EditIcon />} onClick={() => setIsEditing(true)}>
                    Modifier
                  </Button>
                  <Tooltip title="Supprimer cette ligne">
                    <IconButton size="small" color="error" onClick={() => setConfirmDelete(selected)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </>
              )}
            </Box>
          </Box>
          {!isCreating && selected?.updated_at && (
            <Typography variant="caption" color="text.secondary">
              Modifié le {String(selected.updated_at).slice(0, 16).replace('T', ' ')}
              {selected.updated_by ? ` par ${selected.updated_by}` : ''}
            </Typography>
          )}
        </Box>

        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          <Grid container spacing={2}>
            {FIELDS.map((f, idx) => {
              const raw = isCreating ? '' : (selected?.[f.key] ?? '');
              const current = f.key in editedData ? editedData[f.key] : (raw === null ? '' : String(raw));
              const isLink = f.key.startsWith('lien_fichier');
              return (
                <React.Fragment key={f.key}>
                  {idx === 7 && <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>}
                  {idx === 19 && <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>}
                  <Grid item xs={12} md={isLink || f.key === 'designation' || f.key === 'niveau_sap' ? 12 : 6}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                      {f.label}
                    </Typography>
                    {isEditing ? (
                      <TextField
                        size="small"
                        fullWidth
                        value={current}
                        onChange={(e) => handleFieldChange(f.key, e.target.value)}
                        sx={{ '& input': { fontFamily: f.monospace ? 'monospace' : 'inherit', fontSize: '0.875rem' } }}
                      />
                    ) : (
                      <Typography
                        variant="body2"
                        sx={{
                          fontFamily: f.monospace ? 'monospace' : 'inherit',
                          fontWeight: 500,
                          wordBreak: 'break-word',
                        }}
                      >
                        {current === '' ? '—' : current}
                      </Typography>
                    )}
                  </Grid>
                </React.Fragment>
              );
            })}
          </Grid>
        </Box>
      </Box>
    );
  };

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <PeToolsIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.primary.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Gammes préventives (PE Tools)
        </Typography>
        <Chip label="raw_data.pe_tools" size="small" variant="outlined" sx={{ ml: 2, fontFamily: 'monospace' }} />
        <Box sx={{ flex: 1 }} />
        <Button variant="contained" size="small" startIcon={<AddIcon />} onClick={startCreating} sx={{ mr: 1 }}>
          Nouvelle gamme
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

      <Box sx={{ display: 'flex', gap: 3, flex: 1, minHeight: 0 }}>
        <Paper
          elevation={0}
          sx={{
            flex: 2,
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
                  <TableCell align="right" />
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((r) => (
                  <TableRow
                    key={r.raw_id}
                    hover
                    selected={selected?.raw_id === r.raw_id}
                    onClick={() => selectRow(r)}
                    sx={{ cursor: 'pointer' }}
                  >
                    {TABLE_FIELDS.map((f) => (
                      <TableCell
                        key={f.key}
                        sx={{
                          fontFamily: f.monospace ? 'monospace' : 'inherit',
                          fontWeight: f.monospace ? 600 : 400,
                          maxWidth: f.key === 'designation' ? 320 : 200,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {r[f.key] || '—'}
                      </TableCell>
                    ))}
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Tooltip title="Supprimer">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={(e) => { e.stopPropagation(); setConfirmDelete(r); }}
                        >
                          <DeleteIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
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

        <Paper
          elevation={0}
          sx={{
            flex: 1,
            minWidth: 400,
            border: `1px solid ${theme.palette.divider}`,
            borderRadius: 2,
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {renderDetails()}
        </Paper>
      </Box>

      <Dialog open={!!confirmDelete} onClose={() => setConfirmDelete(null)}>
        <DialogTitle>Supprimer cette gamme ?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            La ligne « {confirmDelete?.designation || confirmDelete?.poste_technique} » sera
            définitivement supprimée de <code>raw_data.pe_tools</code>. Cette action est irréversible.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmDelete(null)}>Annuler</Button>
          <Button color="error" variant="contained" onClick={deleteRow}>Supprimer</Button>
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
