import {
  Add as AddIcon,
  Cancel as CancelIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  Save as SaveIcon,
  PlayArrow as TestIcon,
  Visibility as ViewIcon
} from '@mui/icons-material';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  Grid,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Snackbar,
  Switch,
  TextField,
  Tooltip,
  Typography
} from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import { DataTable } from '../../components/table';
import type { DataTableColumn, SortDirection } from '../../components/table';
import type { ExportQuery } from '../../services/exportService';
import * as exportService from '../../services/exportService';

interface FormData {
  table_name: string;
  table_schema: string;
  display_name: string;
  column_list: string;
  description: string;
  category: string;
  is_active: boolean;
}

const ExportQueriesManagement: React.FC = () => {
  const [queries, setQueries] = useState<ExportQuery[]>([]);
  const [loading, setLoading] = useState(true);
  // Tri et pagination cote client : la page charge tout le referentiel d'un bloc.
  const [sortBy, setSortBy] = useState('table_name');
  const [sortDir, setSortDir] = useState<SortDirection>('asc');
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(25);
  const [openDialog, setOpenDialog] = useState(false);
  const [openViewDialog, setOpenViewDialog] = useState(false);
  const [selectedQuery, setSelectedQuery] = useState<ExportQuery | null>(null);
  const [formData, setFormData] = useState<FormData>({
    table_name: '',
    table_schema: 'public',
    display_name: '',
    column_list: '',
    description: '',
    category: 'supplier',
    is_active: true
  });
  const [isEditing, setIsEditing] = useState(false);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' as 'success' | 'error' });
  const [testResult, setTestResult] = useState<any>(null);
  
  // États pour les filtres
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  const schemas = ['public', 'clean_data', 'raw_data'];

  // Catégories dynamiques : dérivées des requêtes existantes en base
  // (une nouvelle catégorie peut être saisie librement dans le formulaire)
  const categories = useMemo(
    () =>
      Array.from(new Set(queries.map((q) => q.category).filter(Boolean))).sort((a, b) =>
        a.localeCompare(b, 'fr')
      ),
    [queries]
  );

  useEffect(() => {
    loadQueries();
  }, []);

  const loadQueries = async () => {
    try {
      setLoading(true);
      const data = await exportService.getAllExportQueries();
      setQueries(data);
    } catch (error) {
      showSnackbar('Erreur lors du chargement des requêtes', 'error');
      console.error('Erreur:', error);
    } finally {
      setLoading(false);
    }
  };

  const showSnackbar = (message: string, severity: 'success' | 'error') => {
    setSnackbar({ open: true, message, severity });
  };

  const handleCloseSnackbar = () => {
    setSnackbar({ ...snackbar, open: false });
  };

  const handleOpenDialog = (query?: ExportQuery) => {
    if (query) {
      setIsEditing(true);
      setSelectedQuery(query);
      setFormData({
        table_name: query.table_name || '',
        table_schema: query.table_schema || 'public',
        display_name: query.display_name || '',
        column_list: query.column_list || '',
        description: query.description || '',
        category: query.category || 'supplier',
        is_active: query.is_active ?? true
      });
    } else {
      setIsEditing(false);
      setSelectedQuery(null);
      setFormData({
        table_name: '',
        table_schema: 'public',
        display_name: '',
        column_list: '',
        description: '',
        category: 'supplier',
        is_active: true
      });
    }
    setTestResult(null);
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setSelectedQuery(null);
    setTestResult(null);
  };

  const handleFormChange = (field: keyof FormData, value: any) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const handleSave = async () => {
    try {
      // Validation
      if (!formData.table_name || !formData.table_name.trim() ||
          !formData.display_name || !formData.display_name.trim() ||
          !formData.column_list || !formData.column_list.trim() ||
          !formData.category || !formData.category.trim()) {
        showSnackbar('Veuillez remplir tous les champs obligatoires', 'error');
        return;
      }

      if (isEditing && selectedQuery) {
        await exportService.updateExportQuery(selectedQuery.table_name, formData);
        showSnackbar('Requête mise à jour avec succès', 'success');
      } else {
        await exportService.createExportQuery(formData);
        showSnackbar('Requête créée avec succès', 'success');
      }

      handleCloseDialog();
      loadQueries();
    } catch (error: any) {
      const message = error.response?.data?.message || 'Erreur lors de la sauvegarde';
      showSnackbar(message, 'error');
      console.error('Erreur:', error);
    }
  };

  const handleDelete = async (query: ExportQuery) => {
    if (window.confirm(`Êtes-vous sûr de vouloir supprimer la requête "${query.display_name}" ?`)) {
      try {
        await exportService.deleteExportQuery(query.table_name);
        showSnackbar('Requête supprimée avec succès', 'success');
        loadQueries();
      } catch (error) {
        showSnackbar('Erreur lors de la suppression', 'error');
        console.error('Erreur:', error);
      }
    }
  };

  const handleTestQuery = async () => {
    try {
      setTestResult(null);
      const result = await exportService.testQuery(formData.column_list, formData.table_schema, formData.table_name);
      setTestResult(result);
      showSnackbar('Test de la requête réussi', 'success');
    } catch (error: any) {
      const message = error.message || error.response?.data?.error || 'Erreur lors du test de la requête';
      showSnackbar(message, 'error');
      setTestResult({ error: message });
    }
  };

  const handleViewQuery = (query: ExportQuery) => {
    setSelectedQuery(query);
    setOpenViewDialog(true);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Fonction de filtrage des requêtes
  const filteredQueries = queries.filter((query) => {
    // Filtre par catégorie
    const matchesCategory = selectedCategory === 'all' || query.category === selectedCategory;
    
    // Filtre par recherche (nom de table, nom d'affichage, description)
    const matchesSearch = searchTerm === '' || 
      query.table_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      query.display_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (query.description && query.description.toLowerCase().includes(searchTerm.toLowerCase()));
    
    return matchesCategory && matchesSearch;
  });

  // Toutes les requetes sont deja chargees : le tri et la pagination se font
  // donc ici, et la DataTable ne recoit que la tranche a afficher.
  const sortedQueries = useMemo(() => {
    const rows = [...filteredQueries];
    rows.sort((a, b) => {
      const av = (a as unknown as Record<string, unknown>)[sortBy];
      const bv = (b as unknown as Record<string, unknown>)[sortBy];
      if (av === bv) return 0;
      if (av === null || av === undefined) return 1;
      if (bv === null || bv === undefined) return -1;
      const cmp =
        typeof av === 'boolean' && typeof bv === 'boolean'
          ? Number(av) - Number(bv)
          : String(av).localeCompare(String(bv), 'fr', { numeric: true });
      return sortDir === 'asc' ? cmp : -cmp;
    });
    return rows;
  }, [filteredQueries, sortBy, sortDir]);

  const pagedQueries = useMemo(
    () => sortedQueries.slice(page * pageSize, page * pageSize + pageSize),
    [sortedQueries, page, pageSize],
  );

  const columns: DataTableColumn<ExportQuery>[] = useMemo(
    () => [
      {
        key: 'table_name',
        label: 'Nom de la table',
        sortable: true,
        mono: true,
        width: 200,
      },
      {
        key: 'table_schema',
        label: 'Schéma',
        sortable: true,
        width: 110,
        render: (q) => (
          <Chip
            label={q.table_schema}
            size="small"
            color={q.table_schema === 'public' ? 'primary' : 'default'}
          />
        ),
      },
      {
        key: 'display_name',
        label: "Nom d'affichage",
        sortable: true,
        ellipsisMaxWidth: 260,
      },
      {
        key: 'category',
        label: 'Catégorie',
        sortable: true,
        width: 140,
        render: (q) => <Chip label={q.category} size="small" variant="outlined" />,
      },
      {
        key: 'is_active',
        label: 'Statut',
        sortable: true,
        width: 100,
        render: (q) => (
          <Chip
            label={q.is_active ? 'Actif' : 'Inactif'}
            size="small"
            color={q.is_active ? 'success' : 'default'}
          />
        ),
        csvValue: (q) => (q.is_active ? 'Actif' : 'Inactif'),
      },
      {
        key: 'updated_at',
        label: 'Modifié le',
        sortable: true,
        width: 180,
        render: (q) => (
          <>
            <Typography variant="body2" color="text.secondary">
              {formatDate(q.updated_at)}
            </Typography>
            <Typography variant="caption" color="text.disabled">
              par {q.updated_by}
            </Typography>
          </>
        ),
      },
      {
        key: 'actions',
        label: 'Actions',
        align: 'center',
        width: 130,
        csvValue: () => '',
        render: (q) => (
          <Box sx={{ display: 'flex', justifyContent: 'center' }}>
            <Tooltip title="Voir">
              <IconButton size="small" onClick={() => handleViewQuery(q)}>
                <ViewIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            <Tooltip title="Modifier">
              <IconButton size="small" onClick={() => handleOpenDialog(q)}>
                <EditIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            <Tooltip title="Supprimer">
              <IconButton size="small" color="error" onClick={() => handleDelete(q)}>
                <DeleteIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          </Box>
        ),
      },
    ],
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );

  return (
    <Box p={3}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Gestion des Requêtes d'Export
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => handleOpenDialog()}
        >
          Nouvelle Requête
        </Button>
      </Box>

      {/* Barre de filtres */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                label="Rechercher"
                placeholder="Nom de table, nom d'affichage ou description..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                variant="outlined"
                size="small"
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <FormControl fullWidth size="small">
                <InputLabel>Catégorie</InputLabel>
                <Select
                  value={selectedCategory}
                  onChange={(e) => setSelectedCategory(e.target.value)}
                  label="Catégorie"
                >
                  <MenuItem value="all">Toutes les catégories</MenuItem>
                  {categories.map((category) => (
                    <MenuItem key={category} value={category}>
                      {category}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={2}>
              <Typography variant="body2" color="text.secondary">
                {filteredQueries.length} résultat{filteredQueries.length > 1 ? 's' : ''}
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <DataTable<ExportQuery>
            columns={columns}
            rows={pagedQueries}
            getRowKey={(q) => q.id}
            loading={loading}
            emptyLabel={
              queries.length === 0
                ? 'Aucune requête configurée'
                : 'Aucun résultat ne correspond aux filtres'
            }
            sortBy={sortBy}
            sortDir={sortDir}
            onSortChange={(key, dir) => {
              setSortBy(key);
              setSortDir(dir);
              setPage(0);
            }}
            pagination={{
              page,
              pageSize,
              total: sortedQueries.length,
              onPageChange: setPage,
              onPageSizeChange: setPageSize,
            }}
            toolbar={{ csvExport: { filePrefix: 'requetes_export' } }}
            maxHeight="calc(100vh - 420px)"
          />
        </CardContent>
      </Card>

      {/* Dialog de création/modification */}
      <Dialog 
        open={openDialog} 
        onClose={handleCloseDialog}
        maxWidth="lg"
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>
          {isEditing ? 'Modifier la Requête' : 'Nouvelle Requête'}
        </DialogTitle>
        <DialogContent>
          <Box mt={2}>
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  label="Nom de la Table"
                  value={formData.table_name}
                  onChange={(e) => handleFormChange('table_name', e.target.value)}
                  fullWidth
                  required
                  disabled={isEditing} // Ne pas permettre de changer le nom de table en édition
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <FormControl fullWidth required>
                  <InputLabel>Schéma</InputLabel>
                  <Select
                    value={formData.table_schema}
                    onChange={(e) => handleFormChange('table_schema', e.target.value)}
                    disabled={isEditing} // Ne pas permettre de changer le schéma en édition
                  >
                    {schemas.map((schema) => (
                      <MenuItem key={schema} value={schema}>
                        {schema}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Grid>
              <Grid item xs={12} md={8}>
                <TextField
                  label="Nom d'Affichage"
                  value={formData.display_name}
                  onChange={(e) => handleFormChange('display_name', e.target.value)}
                  fullWidth
                  required
                />
              </Grid>
              <Grid item xs={12} md={4}>
                <Autocomplete
                  freeSolo
                  options={categories}
                  value={formData.category}
                  onInputChange={(_, newValue) => handleFormChange('category', newValue)}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      label="Catégorie"
                      required
                      helperText="Sélectionnez une catégorie ou saisissez-en une nouvelle"
                    />
                  )}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  label="Description"
                  value={formData.description}
                  onChange={(e) => handleFormChange('description', e.target.value)}
                  fullWidth
                  multiline
                  rows={2}
                />
              </Grid>
              <Grid item xs={12}>
                <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
                  <Typography variant="h6">Liste des Colonnes</Typography>
                  <Button
                    variant="outlined"
                    startIcon={<TestIcon />}
                    onClick={handleTestQuery}
                    disabled={!formData.column_list || !formData.column_list.trim()}
                  >
                    Tester la Requête
                  </Button>
                </Box>
                <TextField
                  value={formData.column_list}
                  onChange={(e) => handleFormChange('column_list', e.target.value)}
                  fullWidth
                  multiline
                  rows={4}
                  required
                  placeholder="id, name, email, created_at, updated_at"
                  helperText="Séparez les noms de colonnes par des virgules"
                  sx={{
                    '& .MuiInputBase-input': {
                      fontFamily: 'monospace',
                      fontSize: '0.875rem'
                    }
                  }}
                />
              </Grid>
              <Grid item xs={12}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={formData.is_active}
                      onChange={(e) => handleFormChange('is_active', e.target.checked)}
                    />
                  }
                  label="Requête active"
                />
              </Grid>
              
              {/* Résultat du test */}
              {testResult && (
                <Grid item xs={12}>
                  <Divider sx={{ my: 2 }} />
                  <Typography variant="h6" gutterBottom>
                    Résultat du Test
                  </Typography>
                  {testResult.error ? (
                    <Alert severity="error">
                      {testResult.error}
                    </Alert>
                  ) : (
                    <Box>
                      <Alert severity="success" sx={{ mb: 2 }}>
                        Test réussi ! {testResult.total_rows || testResult.length} ligne(s) retournée(s) 
                        {testResult.execution_time && ` en ${testResult.execution_time}s`}
                      </Alert>
                      
                      {/* Affichage de la requête SQL générée */}
                      {testResult.generated_sql && (
                        <Box sx={{ mb: 2 }}>
                          <Typography variant="subtitle2" gutterBottom color="primary">
                            📝 Requête SQL Générée :
                          </Typography>
                          <Paper sx={{ p: 2, backgroundColor: '#f5f5f5', border: '1px solid #ddd' }}>
                            <pre style={{ 
                              margin: 0, 
                              fontSize: '0.875rem', 
                              overflow: 'auto',
                              whiteSpace: 'pre-wrap',
                              fontFamily: 'Monaco, Consolas, "Liberation Mono", "Courier New", monospace'
                            }}>
                              {testResult.generated_sql}
                            </pre>
                          </Paper>
                        </Box>
                      )}

                      {/* Aperçu des données */}
                      {(testResult.sample_data?.length > 0 || testResult.length > 0) && (
                        <Box>
                          <Typography variant="subtitle2" gutterBottom color="secondary">
                            📊 Aperçu des données (première ligne) :
                          </Typography>
                          <Paper sx={{ p: 2, backgroundColor: 'grey.50' }}>
                            <pre style={{ margin: 0, fontSize: '0.75rem', overflow: 'auto' }}>
                              {JSON.stringify(testResult.sample_data?.[0] || testResult[0], null, 2)}
                            </pre>
                          </Paper>
                          
                          {/* Affichage des colonnes */}
                          {testResult.columns && (
                            <Box sx={{ mt: 2 }}>
                              <Typography variant="subtitle2" gutterBottom>
                                🗂️ Colonnes détectées ({testResult.columns.length}) :
                              </Typography>
                              <Paper sx={{ p: 1, backgroundColor: '#fafafa' }}>
                                <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                                  {testResult.columns.join(', ')}
                                </Typography>
                              </Paper>
                            </Box>
                          )}
                        </Box>
                      )}
                    </Box>
                  )}
                </Grid>
              )}
            </Grid>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog} startIcon={<CancelIcon />}>
            Annuler
          </Button>
          <Button 
            onClick={handleSave} 
            variant="contained" 
            startIcon={<SaveIcon />}
          >
            {isEditing ? 'Mettre à jour' : 'Créer'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog de visualisation */}
      <Dialog 
        open={openViewDialog} 
        onClose={() => setOpenViewDialog(false)}
        maxWidth="lg"
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>
          Détails de la Requête: {selectedQuery?.display_name}
        </DialogTitle>
        <DialogContent>
          {selectedQuery && (
            <Box mt={2}>
              <Grid container spacing={2}>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Table
                  </Typography>
                  <Typography variant="body1">
                    {selectedQuery.table_schema}.{selectedQuery.table_name}
                  </Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Catégorie
                  </Typography>
                  <Typography variant="body1">
                    {selectedQuery.category}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Description
                  </Typography>
                  <Typography variant="body1">
                    {selectedQuery.description || 'Aucune description'}
                  </Typography>
                </Grid>
                <Grid item xs={12}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Liste des Colonnes
                  </Typography>
                  <Paper sx={{ p: 2, backgroundColor: 'grey.50', mt: 1 }}>
                    <pre style={{ margin: 0, fontSize: '0.875rem', overflow: 'auto' }}>
                      {selectedQuery.column_list}
                    </pre>
                  </Paper>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Créé le
                  </Typography>
                  <Typography variant="body2">
                    {formatDate(selectedQuery.created_at)} par {selectedQuery.created_by}
                  </Typography>
                </Grid>
                <Grid item xs={12} md={6}>
                  <Typography variant="subtitle2" color="text.secondary">
                    Modifié le
                  </Typography>
                  <Typography variant="body2">
                    {formatDate(selectedQuery.updated_at)} par {selectedQuery.updated_by}
                  </Typography>
                </Grid>
              </Grid>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenViewDialog(false)}>
            Fermer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Snackbar pour les notifications */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert 
          onClose={handleCloseSnackbar} 
          severity={snackbar.severity}
          sx={{ width: '100%' }}
        >
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default ExportQueriesManagement; 