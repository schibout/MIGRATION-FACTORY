/**
 * Référentiel IBAU éditable — source clean_data.ibau_article.
 *
 * Liste avec SEULEMENT les IBAU, alimentée une fois depuis SAP (migration 030,
 * périmètre structure IH02) puis découplée : plus aucune mise à jour SAP, mais
 * modifiable par les équipes (ajout, suppression, modification).
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
  Layers as IbauIcon,
  Person as ManualIcon,
  Refresh as RefreshIcon,
  Save as SaveIcon,
  Category as GroupIcon,
  CloudOff as SapIcon,
  Search as SearchIcon,
} from '@mui/icons-material';
import api from '../services/api';

interface IbauRow {
  id: number;
  matnr: string | null;
  source: 'SAP' | 'MANUAL';
  [key: string]: any;
}

interface Stats {
  total: number;
  nb_sap: number;
  nb_manuel: number;
  nb_modifies: number;
  nb_groupes: number;
}

// Champs modifiables (doivent correspondre a EDITABLE_COLUMNS cote API).
// `inTable` = colonne de la liste principale.
const FIELDS: { key: string; label: string; inTable?: boolean; monospace?: boolean }[] = [
  { key: 'code', label: 'Code', inTable: true, monospace: true },
  { key: 'description', label: 'Désignation', inTable: true },
  { key: 'matkl', label: 'Groupe articles', inTable: true, monospace: true },
  { key: 'matkl_label', label: 'Libellé groupe' },
  { key: 'meins', label: 'Unité de base' },
  { key: 'bismt', label: 'Ancien n° article', monospace: true },
  { key: 'commentaire', label: 'Commentaire' },
];

const TABLE_FIELDS = FIELDS.filter((f) => f.inTable);

const MaintenanceIbauPage: React.FC = () => {
  const theme = useTheme();

  const [rows, setRows] = useState<IbauRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [orderBy, setOrderBy] = useState('code');
  const [order, setOrder] = useState<'asc' | 'desc'>('asc');

  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [matklFilter, setMatklFilter] = useState('');
  const [sourceFilter, setSourceFilter] = useState('');
  const [matklOptions, setMatklOptions] = useState<{ code: string; label: string }[]>([]);

  const [stats, setStats] = useState<Stats | null>(null);

  const [selected, setSelected] = useState<IbauRow | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [editedData, setEditedData] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<IbauRow | null>(null);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  const activeFilterCount = useMemo(
    () => (matklFilter ? 1 : 0) + (sourceFilter ? 1 : 0) + (debouncedSearch ? 1 : 0),
    [matklFilter, sourceFilter, debouncedSearch]
  );

  /** Paramètres de filtrage communs à la liste, aux stats et à l'export. */
  const filterParams = useCallback(() => {
    const params = new URLSearchParams();
    if (debouncedSearch) params.append('search', debouncedSearch);
    if (matklFilter) params.append('matkl', matklFilter);
    if (sourceFilter) params.append('source', sourceFilter);
    return params;
  }, [debouncedSearch, matklFilter, sourceFilter]);

  const loadRows = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = filterParams();
      params.append('page', String(page + 1));
      params.append('per_page', String(rowsPerPage));
      params.append('order_by', orderBy);
      params.append('order', order);

      const response = await api.get(`/maintenance/ibau?${params}`);
      if (response.data.success) {
        setRows(response.data.data || []);
        setTotal(response.data.total || 0);
        setMatklOptions(response.data.filter_options?.matkl || []);
      }
    } catch (err: any) {
      console.error('Erreur chargement ibau:', err);
      setError(err?.response?.data?.error || 'Erreur lors du chargement de la liste IBAU');
    } finally {
      setLoading(false);
    }
  }, [filterParams, page, rowsPerPage, orderBy, order]);

  const loadStats = useCallback(async () => {
    try {
      const response = await api.get(`/maintenance/ibau/stats?${filterParams()}`);
      if (response.data.success) setStats(response.data.data);
    } catch (err) {
      console.error('Erreur stats ibau:', err);
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
    setMatklFilter('');
    setSourceFilter('');
    setPage(0);
  };

  const selectRow = (row: IbauRow) => {
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
    // En création tout est conservé ; en édition on ne garde que les écarts
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
        const response = await api.post('/maintenance/ibau', payload);
        if (response.data.success) {
          setSnackbar({ open: true, message: 'IBAU créé', severity: 'success' });
          cancelEditing();
          await loadRows();
          await loadStats();
        }
      } else if (selected) {
        const response = await api.put(`/maintenance/ibau/${selected.id}`, payload);
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
      await api.delete(`/maintenance/ibau/${confirmDelete.id}`);
      setSnackbar({ open: true, message: 'IBAU supprimé de la liste', severity: 'success' });
      if (selected?.id === confirmDelete.id) setSelected(null);
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

  /** Export CSV du périmètre filtré courant (pas seulement de la page affichée). */
  const exportCsv = async () => {
    try {
      setExporting(true);
      const params = filterParams();
      params.append('order_by', orderBy);
      params.append('order', order);
      const response = await api.get(`/maintenance/ibau/export?${params}`, { responseType: 'blob' });
      const url = window.URL.createObjectURL(new Blob([response.data], { type: 'text/csv;charset=utf-8;' }));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'ibau.csv');
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
    { icon: IbauIcon, color: theme.palette.info.main, value: stats?.total, label: 'IBAU dans la liste' },
    { icon: SapIcon, color: theme.palette.primary.main, value: stats?.nb_sap, label: 'Issus de SAP (figés)' },
    { icon: ManualIcon, color: theme.palette.success.main, value: stats?.nb_manuel, label: 'Ajoutés par l\'équipe' },
    { icon: GroupIcon, color: theme.palette.warning.main, value: stats?.nb_groupes, label: 'Groupes d\'articles' },
  ];

  const renderDetails = () => {
    if (!selected && !isCreating) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'text.secondary' }}>
          <IbauIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">Sélectionnez un IBAU</Typography>
          <Typography variant="caption">ou créez-en un nouveau</Typography>
        </Box>
      );
    }

    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 2 }}>
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>
                {isCreating ? 'Nouvel IBAU' : (selected?.code || '—')}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                {isCreating ? 'Renseignez au moins le code puis enregistrez' : (selected?.description || '—')}
              </Typography>
              {!isCreating && selected && (
                <Box sx={{ display: 'flex', gap: 1, mt: 1, flexWrap: 'wrap' }}>
                  <Chip
                    size="small"
                    label={selected.source === 'SAP' ? 'Origine SAP' : 'Ajout équipe'}
                    color={selected.source === 'SAP' ? 'primary' : 'success'}
                    variant="outlined"
                  />
                  {selected.matnr && (
                    <Chip size="small" variant="outlined" sx={{ fontFamily: 'monospace' }}
                      label={`SAP ${String(selected.matnr).replace(/^0+/, '')}`} />
                  )}
                </Box>
              )}
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
                  <Tooltip title="Retirer de la liste">
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
            {FIELDS.map((f) => {
              const raw = isCreating ? '' : (selected?.[f.key] ?? '');
              const current = f.key in editedData ? editedData[f.key] : (raw === null ? '' : String(raw));
              const fullWidth = f.key === 'description' || f.key === 'commentaire' || f.key === 'matkl_label';
              return (
                <Grid item xs={12} md={fullWidth ? 12 : 6} key={f.key}>
                  <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
                    {f.label}
                  </Typography>
                  {isEditing ? (
                    <TextField
                      size="small"
                      fullWidth
                      multiline={f.key === 'commentaire'}
                      minRows={f.key === 'commentaire' ? 2 : undefined}
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
        <IbauIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.info.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Liste IBAU (référentiel équipe)
        </Typography>
        <Tooltip title="Alimentée une fois depuis SAP (structure IH02) puis figée : plus aucune mise à jour SAP, modifiable uniquement ici.">
          <Chip label="Découplée de SAP" size="small" color="info" variant="outlined" sx={{ ml: 2 }} />
        </Tooltip>
        <Box sx={{ flex: 1 }} />
        <Button variant="contained" size="small" startIcon={<AddIcon />} onClick={startCreating} sx={{ mr: 1 }}>
          Nouvel IBAU
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
              <Grid item xs={12} md={5}>
                <TextField
                  fullWidth
                  size="small"
                  placeholder="Rechercher (code, désignation, n° SAP, groupe)..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start"><SearchIcon /></InputAdornment>
                    ),
                  }}
                />
              </Grid>
              <Grid item xs={6} md={3}>
                <FormControl fullWidth size="small">
                  <InputLabel>Groupe articles</InputLabel>
                  <Select
                    value={matklFilter}
                    label="Groupe articles"
                    onChange={(e) => { setMatklFilter(e.target.value as string); setPage(0); }}
                  >
                    <MenuItem value="">Tous</MenuItem>
                    {matklOptions.map((o) => (
                      <MenuItem key={o.code} value={o.code}>
                        {o.code}{o.label ? ` — ${o.label}` : ''}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={6} md={2}>
                <FormControl fullWidth size="small">
                  <InputLabel>Origine</InputLabel>
                  <Select
                    value={sourceFilter}
                    label="Origine"
                    onChange={(e) => { setSourceFilter(e.target.value as string); setPage(0); }}
                  >
                    <MenuItem value="">Toutes</MenuItem>
                    <MenuItem value="SAP">SAP</MenuItem>
                    <MenuItem value="MANUAL">Équipe</MenuItem>
                  </Select>
                </FormControl>
              </Grid>
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
                  <TableCell>Origine</TableCell>
                  <TableCell align="right" />
                </TableRow>
              </TableHead>
              <TableBody>
                {rows.map((r) => (
                  <TableRow
                    key={r.id}
                    hover
                    selected={selected?.id === r.id}
                    onClick={() => selectRow(r)}
                    sx={{ cursor: 'pointer' }}
                  >
                    {TABLE_FIELDS.map((f) => (
                      <TableCell
                        key={f.key}
                        sx={{
                          fontFamily: f.monospace ? 'monospace' : 'inherit',
                          fontWeight: f.monospace ? 600 : 400,
                          maxWidth: f.key === 'description' ? 380 : 180,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {r[f.key] || '—'}
                      </TableCell>
                    ))}
                    <TableCell>
                      <Chip
                        size="small"
                        label={r.source === 'SAP' ? 'SAP' : 'Équipe'}
                        color={r.source === 'SAP' ? 'default' : 'success'}
                        variant="outlined"
                      />
                    </TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Tooltip title="Retirer de la liste">
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
                    <TableCell colSpan={TABLE_FIELDS.length + 2} align="center" sx={{ py: 4 }}>
                      <Typography color="text.secondary">
                        Aucun IBAU trouvé. Si la liste est entièrement vide, la migration 030
                        n'a probablement pas encore été jouée sur le serveur.
                      </Typography>
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
        <DialogTitle>Retirer cet IBAU de la liste ?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            « {confirmDelete?.description || confirmDelete?.code} » sera retiré de la liste IBAU
            (suppression logique : les données SAP d'origine ne sont pas touchées).
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

export default MaintenanceIbauPage;
