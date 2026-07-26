import {
  Download as DownloadIcon,
  Inventory as InventoryIcon,
  Refresh as RefreshIcon
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  FormControl,
  Grid,
  InputLabel,
  MenuItem,
  Select,
  Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import SapDataTable from '../components/sap/SapDataTable';
import sapViewsService, { SapView, ViewData } from '../services/sapViewsService';

const SapArticles = () => {
  const [views, setViews] = useState<SapView[]>([]);
  const [selectedView, setSelectedView] = useState('');
  const [viewData, setViewData] = useState<ViewData | null>(null);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [sortField, setSortField] = useState('');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  const [searchTerm, setSearchTerm] = useState('');
  const [filters, setFilters] = useState({});
  const [error, setError] = useState<string | null>(null);

  // Statistiques des articles
  const [stats, setStats] = useState({
    totalArticles: 0,
    activeArticles: 0,
    categories: 0
  });

  useEffect(() => {
    loadViews();
  }, []);

  useEffect(() => {
    if (selectedView) {
      loadViewData();
    }
  }, [selectedView, page, rowsPerPage, sortField, sortDirection, searchTerm, filters]);

  const loadViews = async () => {
    try {
      setLoading(true);
      setError(null);
      const articleViews = await sapViewsService.getViews('article');
      setViews(articleViews);

      const defaultView = articleViews.find((view: SapView) => view.name === 'v_article');
      if (defaultView) {
        setSelectedView(defaultView.name);
      } else if (articleViews.length > 0) {
        setSelectedView(articleViews[0].name);
      }
    } catch (error) {
      console.error('Erreur lors du chargement des vues SAP:', error);
      setError('Impossible de charger les vues SAP. Vérifiez la connexion à l\'API.');
    } finally {
      setLoading(false);
    }
  };

  const loadViewData = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const data = await sapViewsService.getViewData(
        selectedView, 
        page + 1,
        rowsPerPage, 
        sortField, 
        sortDirection,
        searchTerm,
        filters
      );
      
      setViewData(data);
      
      // Calculer les statistiques
      if (data && data.rows) {
        setStats({
          totalArticles: data.total || data.rows.length,
          activeArticles: data.rows.filter((row: any) => {
            // Logique robuste pour détecter les articles actifs
            const status = (row.status || '').toString().toLowerCase();
            const actif = row.actif;
            const active = row.active;
            
            return (
              status === 'active' || 
              status === 'actif' || 
              status === '1' ||
              actif === true || 
              actif === 1 || 
              actif === '1' ||
              active === true || 
              active === 1 || 
              active === '1'
            );
          }).length,
          categories: new Set(data.rows.map((row: any) => row.category || row.categorie)).size
        });
      }
    } catch (error) {
      console.error(`Erreur lors du chargement des données pour la vue ${selectedView}:`, error);
      setError(`Impossible de charger les données de la vue ${selectedView}.`);
    } finally {
      setLoading(false);
    }
  };

  const handleViewChange = (event: any) => {
    const newView = event.target.value;
    setSelectedView(newView);
    setPage(0);
    setSortField('');
    setSortDirection('asc');
    setSearchTerm('');
    setFilters({});
  };

  const handlePageChange = (newPage: number) => {
    setPage(newPage);
  };

  const handleRowsPerPageChange = (newRowsPerPage: number) => {
    setRowsPerPage(newRowsPerPage);
    setPage(0);
  };

  const handleSortChange = (field: string, direction: 'asc' | 'desc') => {
    setSortField(field);
    setSortDirection(direction);
  };
  
  const handleSearchChange = (term: string) => {
    setSearchTerm(term);
    setPage(0);
  };
  
  const handleFilterChange = (newFilters: any) => {
    setFilters(newFilters);
    setPage(0);
  };

  const handleRefresh = () => {
    loadViewData();
  };

  const handleExport = () => {
    // TODO: Implémenter l'export des données
    alert('Fonctionnalité d\'export en cours de développement');
  };

  return (
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 3 }}>
      {/* En-tête */}
      <Box sx={{ mb: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 64,
              height: 64,
              borderRadius: '50%',
              backgroundColor: '#f8bbd0',
              mr: 2
            }}
          >
            <InventoryIcon sx={{ fontSize: 40, color: '#ad1457' }} />
          </Box>
          <Box sx={{ flexGrow: 1 }}>
            <Typography variant="h4" component="h1" sx={{ fontWeight: 600, mb: 1 }}>
              Articles SAP
            </Typography>
            <Typography variant="subtitle1" color="text.secondary">
              Catalogue des articles extraits de SAP
            </Typography>
          </Box>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button
              variant="outlined"
              startIcon={<RefreshIcon />}
              onClick={handleRefresh}
              disabled={loading}
            >
              Actualiser
            </Button>
            <Button
              variant="contained"
              startIcon={<DownloadIcon />}
              onClick={handleExport}
              disabled={!viewData || loading}
            >
              Exporter
            </Button>
          </Box>
        </Box>

        {/* Statistiques */}
        {viewData && (
          <Grid container spacing={2} sx={{ mb: 3 }}>
            <Grid item xs={12} sm={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="h3" color="primary" sx={{ fontWeight: 'bold' }}>
                    {stats.totalArticles.toLocaleString()}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Total articles
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="h3" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {stats.activeArticles.toLocaleString()}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Articles actifs
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="h3" color="info.main" sx={{ fontWeight: 'bold' }}>
                    {stats.categories}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Catégories
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        )}
      </Box>

      {/* Sélection de la vue */}
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={6}>
              <FormControl fullWidth>
                <InputLabel id="view-select-label">Sélectionner une vue</InputLabel>
                <Select
                  labelId="view-select-label"
                  id="view-select"
                  value={selectedView}
                  label="Sélectionner une vue"
                  onChange={handleViewChange}
                  disabled={loading}
                >
                  {views.map((view) => (
                    <MenuItem key={view.id} value={view.name}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        {view.label}
                        <Chip 
                          label={view.name} 
                          size="small" 
                          variant="outlined" 
                        />
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6}>
              <Typography variant="body2" color="text.secondary">
                {views.length} vue(s) disponible(s) pour les articles
              </Typography>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Gestion des erreurs */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
          <Button onClick={loadViews} sx={{ ml: 2 }}>
            Réessayer
          </Button>
        </Alert>
      )}

      {/* Chargement initial */}
      {loading && !viewData && (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {/* Table des données */}
      {viewData && (
        <SapDataTable
          data={viewData}
          onPageChange={handlePageChange}
          onRowsPerPageChange={handleRowsPerPageChange}
          onSortChange={handleSortChange}
          onSearchChange={handleSearchChange}
          onFilterChange={handleFilterChange}
          currentPage={page}
          currentRowsPerPage={rowsPerPage}
          currentSortField={sortField}
          currentSortDirection={sortDirection}
          loading={loading}
        />
      )}
    </Box>
  );
};

export default SapArticles; 