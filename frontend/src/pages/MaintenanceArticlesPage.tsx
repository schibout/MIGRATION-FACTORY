import React, { useState, useEffect, useCallback } from 'react';
import MaintenanceJobBanner from '../components/maintenance/MaintenanceJobBanner';
import {
  Box,
  Paper,
  Typography,
  TextField,
  InputAdornment,
  CircularProgress,
  Alert,
  Chip,
  IconButton,
  Divider,
  useTheme,
  alpha,
  Button,
  Grid,
  Tabs,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TablePagination,
  TableSortLabel,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Card,
  CardContent,
  LinearProgress,
  Snackbar,
} from '@mui/material';
import {
  Search as SearchIcon,
  Inventory2 as ArticleIcon,
  Refresh as RefreshIcon,
  Info as InfoIcon,
  Category as CategoryIcon,
  Warehouse as WarehouseIcon,
  FilterList as FilterIcon,
  Clear as ClearIcon,
  Layers as LayersIcon,
  Edit as EditIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
} from '@mui/icons-material';
import api from '../services/api';

const FIELD_MAX_LENGTHS: Record<string, number> = {
  description: 40,
  matkl: 9,
  meins: 3,
  bstme: 3,
  mbrsh: 1,
  bismt: 18,
  spart: 2,
  extwg: 18,
  brgew: 20,
  ntgew: 20,
  gewei: 3,
  volum: 20,
  voleh: 3,
  laeng: 20,
  breit: 20,
  hoehe: 20,
  meabm: 3,
  groes: 32,
  wrkst: 48,
  normt: 18,
  ean11: 18,
  mfrnr: 10,
  mfrpn: 40,
  zeinr: 22,
  lvorm: 1,
};

interface Article {
  matnr: string;
  matnr_short?: string;
  description?: string;
  mtart?: string;
  mtart_label?: string;
  matkl?: string;
  matkl_label?: string;
  meins?: string;
  mbrsh?: string;
  bismt?: string;
  brgew?: string;
  gewei?: string;
  ntgew?: string;
  lvorm?: string;
  ersda?: string;
  ernam?: string;
  [key: string]: any;
}

interface MatklOption {
  code: string;
  label: string;
}

// Couleur de la pastille par categorie d'article (MTART)
type ChipColor = 'default' | 'primary' | 'secondary' | 'info' | 'warning' | 'success' | 'error';
const mtartColor = (mtart?: string): ChipColor => {
  switch (mtart) {
    case 'ERSA': return 'warning';
    case 'IBAU': return 'info';
    case 'NLAG': return 'secondary';
    case 'HIBE': return 'primary';
    default: return 'default';
  }
};

interface ArticleDetails extends Article {
  description_fr?: string;
  bstme?: string;
  spart?: string;
  extwg?: string;
  volum?: string;
  voleh?: string;
  laeng?: string;
  breit?: string;
  hoehe?: string;
  meabm?: string;
  groes?: string;
  wrkst?: string;
  normt?: string;
  ean11?: string;
  laeda?: string;
  aenam?: string;
  mfrnr?: string;
  mfrpn?: string;
  zeinr?: string;
  descriptions?: { spras: string; maktx: string }[];
  plants?: any[];
  stocks?: any[];
}

const DetailField: React.FC<{
  label: string;
  value: any;
  monospace?: boolean;
  fullWidth?: boolean;
  isEditing?: boolean;
  fieldName?: string;
  editedData?: Record<string, string>;
  onFieldChange?: (field: string, value: string) => void;
  editable?: boolean;
}> = ({
  label,
  value,
  monospace = false,
  fullWidth = false,
  isEditing = false,
  fieldName,
  editedData = {},
  onFieldChange,
  editable = true,
}) => {
  const editingThis = isEditing && editable && !!fieldName && !!onFieldChange;
  if (!editingThis && (value === null || value === undefined || value === '')) return null;

  const maxLen = fieldName ? FIELD_MAX_LENGTHS[fieldName] : undefined;
  const currentVal = fieldName && fieldName in editedData
    ? editedData[fieldName]
    : (value === null || value === undefined ? '' : String(value));
  const isOverLimit = maxLen !== undefined && currentVal.length > maxLen;

  return (
    <Grid item xs={fullWidth ? 12 : 6} md={fullWidth ? 12 : 4}>
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
        {label}
        {editingThis && maxLen !== undefined && (
          <Typography
            component="span"
            variant="caption"
            sx={{
              ml: 1,
              color: isOverLimit ? 'error.main' : 'text.disabled',
              fontWeight: isOverLimit ? 600 : 400,
            }}
          >
            ({currentVal.length}/{maxLen})
          </Typography>
        )}
      </Typography>
      {editingThis ? (
        <TextField
          size="small"
          fullWidth
          value={currentVal}
          onChange={(e) => onFieldChange!(fieldName!, e.target.value)}
          inputProps={{ maxLength: maxLen || undefined }}
          error={!!isOverLimit}
          helperText={isOverLimit ? `Max ${maxLen} caractères` : undefined}
          sx={{
            '& input': {
              fontFamily: monospace ? 'monospace' : 'inherit',
              fontSize: '0.875rem',
            },
          }}
        />
      ) : (
        <Typography
          variant="body2"
          sx={{ fontFamily: monospace ? 'monospace' : 'inherit', fontWeight: 500 }}
        >
          {String(value)}
        </Typography>
      )}
    </Grid>
  );
};

// Libelle du perimetre applique (toujours actif) : IBAU cadre par la structure IH02,
// ERSA/NLAG par la division 9200/2200, liste generale = l'union.
const scopeLabel = (fixedMtart?: string): string => {
  if (fixedMtart === 'IBAU') return 'Structure IH02';
  if (fixedMtart) return 'Division 9200 / 2200';
  return 'Périmètre St-Jean (9200/2200)';
};

const MaintenanceArticlesPage: React.FC<{ fixedMtart?: string }> = ({ fixedMtart }) => {
  const theme = useTheme();

  const [articles, setArticles] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [total, setTotal] = useState(0);
  const [orderBy, setOrderBy] = useState<string>('matnr');
  const [order, setOrder] = useState<'asc' | 'desc'>('asc');

  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [filterMtart, setFilterMtart] = useState(fixedMtart || '');
  const [filterMatkl, setFilterMatkl] = useState('');
  const [mtartOptions, setMtartOptions] = useState<MatklOption[]>([]);
  const [matklOptions, setMatklOptions] = useState<MatklOption[]>([]);

  const [selected, setSelected] = useState<ArticleDetails | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [activeTab, setActiveTab] = useState(0);

  const [isEditing, setIsEditing] = useState(false);
  const [editedData, setEditedData] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  const [stats, setStats] = useState<{ total: number; by_type: any[]; nb_groupes_articles: number } | null>(null);

  const loadArticles = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = new URLSearchParams({
        page: String(page + 1),
        per_page: String(rowsPerPage),
        order_by: orderBy,
        order,
      });
      if (debouncedSearch) params.append('search', debouncedSearch);
      if (filterMtart) params.append('mtart', filterMtart);
      if (filterMatkl) params.append('matkl', filterMatkl);
      params.append('st_jean', '1');

      const response = await api.get(`/maintenance/articles?${params}`);
      if (response.data.success) {
        setArticles(response.data.data || []);
        setTotal(response.data.total || 0);
        if (response.data.filter_options) {
          setMtartOptions(response.data.filter_options.mtart || []);
          setMatklOptions(response.data.filter_options.matkl || []);
        }
      }
    } catch (err: any) {
      console.error('Erreur chargement articles:', err);
      setError(err?.response?.data?.error || 'Erreur lors du chargement des articles');
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, orderBy, order, debouncedSearch, filterMtart, filterMatkl]);

  const loadStats = useCallback(async () => {
    try {
      const params = new URLSearchParams({ st_jean: '1' });
      if (fixedMtart) params.append('mtart', fixedMtart);
      const response = await api.get(`/maintenance/articles/stats?${params}`);
      if (response.data.success) setStats(response.data.data);
    } catch (err) {
      console.error('Erreur stats articles:', err);
    }
  }, [fixedMtart]);

  useEffect(() => {
    loadArticles();
  }, [loadArticles]);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  // Mode "type fixe" (page dédiée ERSA / IBAU / NLAG) : verrouille le filtre de type
  useEffect(() => {
    setFilterMtart(fixedMtart || '');
    setPage(0);
  }, [fixedMtart]);

  const loadDetails = async (matnr: string) => {
    try {
      setDetailsLoading(true);
      setIsEditing(false);
      setEditedData({});
      const response = await api.get(`/maintenance/articles/${encodeURIComponent(matnr)}/details`);
      if (response.data.success) {
        setSelected(response.data.data);
        setActiveTab(0);
      }
    } catch (err) {
      console.error('Erreur details article:', err);
    } finally {
      setDetailsLoading(false);
    }
  };

  const startEditing = () => {
    setIsEditing(true);
    setEditedData({});
  };

  const cancelEditing = () => {
    setIsEditing(false);
    setEditedData({});
  };

  const handleFieldChange = (field: string, value: string) => {
    if (!selected) return;
    const original = String(selected[field as keyof ArticleDetails] ?? '');
    if (value === original) {
      setEditedData((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    } else {
      setEditedData((prev) => ({ ...prev, [field]: value }));
    }
  };

  const saveChanges = async () => {
    if (!selected) return;
    for (const [field, val] of Object.entries(editedData)) {
      const maxLen = FIELD_MAX_LENGTHS[field];
      if (maxLen !== undefined && val.length > maxLen) {
        setSnackbar({ open: true, message: `Le champ "${field}" dépasse ${maxLen} caractères`, severity: 'error' });
        return;
      }
    }
    try {
      setSaving(true);
      const response = await api.put(
        `/maintenance/articles/${encodeURIComponent(selected.matnr)}`,
        editedData
      );
      if (response.data.success) {
        setSnackbar({ open: true, message: 'Modifications enregistrées', severity: 'success' });
        setIsEditing(false);
        await loadDetails(selected.matnr);
        loadArticles();
      }
    } catch (err: any) {
      const msg = err?.response?.data?.error || 'Erreur lors de la sauvegarde';
      setSnackbar({ open: true, message: msg, severity: 'error' });
    } finally {
      setSaving(false);
    }
  };

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
    setFilterMtart(fixedMtart || '');
    setFilterMatkl('');
    setPage(0);
  };

  const renderStats = () => (
    <Grid container spacing={2} sx={{ mb: 3 }}>
      {!fixedMtart && (
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.primary.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <ArticleIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {(stats?.total ?? total).toLocaleString()}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Articles maintenance
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      )}
      {(stats?.by_type || [])
        .filter((row: any) => !fixedMtart || row.mtart === fixedMtart)
        .map((row: any) => (
        <Grid item xs={12} sm={6} md={3} key={row.mtart}>
          <Card sx={{ backgroundColor: alpha(theme.palette.warning.main, 0.1) }}>
            <CardContent sx={{ py: 2 }}>
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                <LayersIcon sx={{ fontSize: 40, color: theme.palette.warning.main, mr: 2 }} />
                <Box>
                  <Typography variant="h4" sx={{ fontWeight: 600 }}>
                    {Number(row.nb).toLocaleString()}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {row.mtart}
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      ))}
      <Grid item xs={12} sm={6} md={3}>
        <Card sx={{ backgroundColor: alpha(theme.palette.info.main, 0.1) }}>
          <CardContent sx={{ py: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center' }}>
              <CategoryIcon sx={{ fontSize: 40, color: theme.palette.info.main, mr: 2 }} />
              <Box>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                  {stats?.nb_groupes_articles ?? '-'}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  Groupes articles
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );

  const renderDetails = () => {
    if (!selected) {
      return (
        <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'text.secondary' }}>
          <ArticleIcon sx={{ fontSize: 64, mb: 2, opacity: 0.3 }} />
          <Typography variant="body1">Sélectionnez un article</Typography>
        </Box>
      );
    }
    if (detailsLoading) {
      return (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
          <CircularProgress />
        </Box>
      );
    }

    const a = selected;
    const ef = (label: string, fieldName: keyof ArticleDetails | string, opts: { monospace?: boolean; fullWidth?: boolean; editable?: boolean } = {}) => (
      <DetailField
        label={label}
        value={a[fieldName as keyof ArticleDetails]}
        fieldName={String(fieldName)}
        isEditing={isEditing}
        editedData={editedData}
        onFieldChange={handleFieldChange}
        monospace={opts.monospace}
        fullWidth={opts.fullWidth}
        editable={opts.editable !== false}
      />
    );
    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', minWidth: 0 }}>
              <ArticleIcon sx={{ fontSize: 32, color: theme.palette.primary.main, mr: 2 }} />
              <Box sx={{ minWidth: 0 }}>
                <Typography variant="h6" sx={{ fontFamily: 'monospace' }}>
                  {a.matnr_short || a.matnr.replace(/^0+/, '')}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                  {a.description || '-'}
                </Typography>
              </Box>
            </Box>
            <Box sx={{ flexShrink: 0 }}>
              {isEditing ? (
                <>
                  <Button size="small" variant="outlined" startIcon={<CancelIcon />} onClick={cancelEditing} sx={{ mr: 1 }}>
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
                <Button size="small" variant="outlined" startIcon={<EditIcon />} onClick={startEditing}>
                  Modifier
                </Button>
              )}
            </Box>
          </Box>
        </Box>

        <Tabs
          value={activeTab}
          onChange={(_, v) => setActiveTab(v)}
          sx={{ borderBottom: `1px solid ${theme.palette.divider}`, px: 2 }}
        >
          <Tab icon={<InfoIcon />} iconPosition="start" label="Général" />
          <Tab icon={<WarehouseIcon />} iconPosition="start" label={`Divisions (${a.plants?.length || 0})`} />
          <Tab icon={<LayersIcon />} iconPosition="start" label={`Stocks (${a.stocks?.length || 0})`} />
        </Tabs>

        <Box sx={{ flex: 1, overflow: 'auto', p: 2 }}>
          {activeTab === 0 && (
            <Grid container spacing={2}>
              {ef('Description (FR)', 'description', { fullWidth: true })}
              <DetailField label="N° Article" value={a.matnr} monospace />
              <DetailField label="Type article" value={a.mtart} />
              <DetailField label="Catégorie" value={a.mtart_label} />
              {ef('Groupe articles', 'matkl')}
              {!isEditing && a.matkl_label && (
                <DetailField label="Libellé groupe" value={a.matkl_label} />
              )}
              {ef('Unité de mesure', 'meins')}
              {ef('UM commande', 'bstme')}
              {ef('Branche', 'mbrsh')}
              {ef('Ancien n°', 'bismt', { monospace: true })}
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              {ef('Poids brut', 'brgew')}
              {ef('Poids net', 'ntgew')}
              {ef('Unité poids', 'gewei')}
              {ef('Volume', 'volum')}
              {ef('Unité volume', 'voleh')}
              {ef('Taille / Format', 'groes')}
              {ef('Longueur', 'laeng')}
              {ef('Largeur', 'breit')}
              {ef('Hauteur', 'hoehe')}
              {ef('Unité dimensions', 'meabm')}
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              {ef('EAN/UPC', 'ean11', { monospace: true })}
              {ef('Fabricant', 'mfrnr')}
              {ef('N° pièce fabricant', 'mfrpn', { monospace: true })}
              {ef('N° plan', 'zeinr', { monospace: true })}
              {ef('Matière', 'wrkst')}
              {ef('Norme', 'normt')}
              <Grid item xs={12}><Divider sx={{ my: 1 }} /></Grid>
              <DetailField label="Date création" value={a.ersda} />
              <DetailField label="Créé par" value={a.ernam} />
              <DetailField label="Date modif." value={a.laeda} />
              <DetailField label="Modifié par" value={a.aenam} />
              {isEditing
                ? ef('Indicateur suppression (X = oui)', 'lvorm')
                : <DetailField label="Suppression" value={a.lvorm === 'X' ? 'Oui' : 'Non'} />}
            </Grid>
          )}

          {activeTab === 1 && (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Division</TableCell>
                    <TableCell>Gr. achats</TableCell>
                    <TableCell>MRP</TableCell>
                    <TableCell align="right">Stock min</TableCell>
                    <TableCell align="right">Stock sécurité</TableCell>
                    <TableCell>Statut</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(a.plants || []).map((p: any, i: number) => (
                    <TableRow key={`${p.werks}-${i}`}>
                      <TableCell sx={{ fontFamily: 'monospace' }}>{p.werks}</TableCell>
                      <TableCell>{p.ekgrp}</TableCell>
                      <TableCell>{p.dispo}</TableCell>
                      <TableCell align="right">{p.minbe}</TableCell>
                      <TableCell align="right">{p.eisbe}</TableCell>
                      <TableCell>{p.mmsta || '-'}</TableCell>
                    </TableRow>
                  ))}
                  {(!a.plants || a.plants.length === 0) && (
                    <TableRow>
                      <TableCell colSpan={6} align="center" sx={{ py: 3, color: 'text.secondary' }}>
                        Aucune donnée par division
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          )}

          {activeTab === 2 && (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Division</TableCell>
                    <TableCell>Magasin</TableCell>
                    <TableCell align="right">Stock libre</TableCell>
                    <TableCell align="right">Transit</TableCell>
                    <TableCell align="right">Qualité</TableCell>
                    <TableCell align="right">Bloqué</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(a.stocks || []).map((s: any, i: number) => (
                    <TableRow key={`${s.werks}-${s.lgort}-${i}`}>
                      <TableCell sx={{ fontFamily: 'monospace' }}>{s.werks}</TableCell>
                      <TableCell sx={{ fontFamily: 'monospace' }}>{s.lgort}</TableCell>
                      <TableCell align="right">{s.labst}</TableCell>
                      <TableCell align="right">{s.umlme}</TableCell>
                      <TableCell align="right">{s.insme}</TableCell>
                      <TableCell align="right">{s.speme}</TableCell>
                    </TableRow>
                  ))}
                  {(!a.stocks || a.stocks.length === 0) && (
                    <TableRow>
                      <TableCell colSpan={6} align="center" sx={{ py: 3, color: 'text.secondary' }}>
                        Aucun stock
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Box>
      </Box>
    );
  };

  return (
    <Box sx={{ p: 3, height: 'calc(100vh - 64px)', display: 'flex', flexDirection: 'column' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <ArticleIcon sx={{ fontSize: 32, mr: 2, color: theme.palette.primary.main }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          {fixedMtart ? `Articles maintenance — ${fixedMtart}` : 'Articles maintenance'}
        </Typography>
        <Box sx={{ display: 'flex', gap: 0.5, ml: 2 }}>
          {(fixedMtart ? [fixedMtart] : ['ERSA', 'IBAU', 'NLAG']).map((m) => (
            <Chip key={m} label={m} size="small" color={mtartColor(m)} variant="outlined" />
          ))}
          <Chip
            icon={<LayersIcon />}
            label={scopeLabel(fixedMtart)}
            size="small"
            color="success"
            variant="outlined"
          />
        </Box>
        <IconButton onClick={loadArticles} sx={{ ml: 2 }} disabled={loading}>
          <RefreshIcon />
        </IconButton>
      </Box>

      {/* Restauration / rechargement SAP : ces donnees sont reecrites pendant l'operation */}
      <MaintenanceJobBanner onFinished={() => loadArticles()} />

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      {renderStats()}

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
                  placeholder="Rechercher (n° article, description, groupe)..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <SearchIcon />
                      </InputAdornment>
                    ),
                  }}
                />
              </Grid>
              {!fixedMtart && (
              <Grid item xs={6} md={3}>
                <FormControl fullWidth size="small">
                  <InputLabel>Catégorie</InputLabel>
                  <Select
                    value={filterMtart}
                    onChange={(e) => {
                      setFilterMtart(e.target.value);
                      setPage(0);
                    }}
                    label="Catégorie"
                  >
                    <MenuItem value="">Toutes</MenuItem>
                    {mtartOptions.map((m) => (
                      <MenuItem key={m.code} value={m.code}>
                        {m.label ? `${m.code} — ${m.label}` : m.code}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              )}
              <Grid item xs={6} md={3}>
                <FormControl fullWidth size="small">
                  <InputLabel>Groupe articles</InputLabel>
                  <Select
                    value={filterMatkl}
                    onChange={(e) => {
                      setFilterMatkl(e.target.value);
                      setPage(0);
                    }}
                    label="Groupe articles"
                  >
                    <MenuItem value="">Tous</MenuItem>
                    {matklOptions.map((m) => (
                      <MenuItem key={m.code} value={m.code}>
                        {m.label ? `${m.code} — ${m.label}` : m.code}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={2}>
                <Button
                  fullWidth
                  variant="outlined"
                  startIcon={<ClearIcon />}
                  onClick={clearFilters}
                  disabled={!searchQuery && !filterMtart && !filterMatkl}
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
                  <TableCell>
                    <TableSortLabel
                      active={orderBy === 'matnr'}
                      direction={orderBy === 'matnr' ? order : 'asc'}
                      onClick={() => handleSort('matnr')}
                    >
                      N° Article
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>
                    <TableSortLabel
                      active={orderBy === 'description'}
                      direction={orderBy === 'description' ? order : 'asc'}
                      onClick={() => handleSort('description')}
                    >
                      Description
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>
                    <TableSortLabel
                      active={orderBy === 'mtart'}
                      direction={orderBy === 'mtart' ? order : 'asc'}
                      onClick={() => handleSort('mtart')}
                    >
                      Catégorie
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>
                    <TableSortLabel
                      active={orderBy === 'matkl'}
                      direction={orderBy === 'matkl' ? order : 'asc'}
                      onClick={() => handleSort('matkl')}
                    >
                      Groupe
                    </TableSortLabel>
                  </TableCell>
                  <TableCell>UM</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {articles.map((a) => (
                  <TableRow
                    key={a.matnr}
                    hover
                    selected={selected?.matnr === a.matnr}
                    onClick={() => loadDetails(a.matnr)}
                    sx={{ cursor: 'pointer' }}
                  >
                    <TableCell sx={{ fontFamily: 'monospace', fontWeight: 600, color: theme.palette.primary.dark }}>
                      {a.matnr_short || a.matnr.replace(/^0+/, '')}
                    </TableCell>
                    <TableCell sx={{ maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {a.description || '-'}
                    </TableCell>
                    <TableCell sx={{ maxWidth: 220 }}>
                      {a.mtart && (
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.75, minWidth: 0 }}>
                          <Chip
                            size="small"
                            label={a.mtart}
                            color={mtartColor(a.mtart)}
                            sx={{ height: 20, fontSize: '0.7rem', flexShrink: 0 }}
                          />
                          {a.mtart_label && (
                            <Typography
                              variant="body2"
                              sx={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                            >
                              {a.mtart_label}
                            </Typography>
                          )}
                        </Box>
                      )}
                    </TableCell>
                    <TableCell sx={{ maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {a.matkl
                        ? (a.matkl_label ? `${a.matkl} — ${a.matkl_label}` : a.matkl)
                        : '-'}
                    </TableCell>
                    <TableCell>{a.meins || '-'}</TableCell>
                  </TableRow>
                ))}
                {!loading && articles.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} align="center" sx={{ py: 4 }}>
                      <Typography color="text.secondary">Aucun article trouvé</Typography>
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
            rowsPerPageOptions={[10, 25, 50, 100]}
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

export default MaintenanceArticlesPage;
