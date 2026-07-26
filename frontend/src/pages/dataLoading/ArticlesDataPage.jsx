import {
    Box,
    Card,
    CardContent,
    CircularProgress,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    Typography
} from '@mui/material';
import { useEffect, useState } from 'react';
import SapDataTable from '../../components/sap/SapDataTable';
import sapViewsService from '../../services/sapViewsService';

const ArticlesDataPage = () => {
  const [views, setViews] = useState([]);
  const [selectedView, setSelectedView] = useState('');
  const [viewData, setViewData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [sortField, setSortField] = useState('');
  const [sortDirection, setSortDirection] = useState('asc');
  const [searchTerm, setSearchTerm] = useState('');
  const [filters, setFilters] = useState({});

  useEffect(() => {
    const loadViews = async () => {
      try {
        setLoading(true);
        const data = await sapViewsService.getViews();
        const articleViews = data.filter(view => 
          view.name === 'v_article' || 
          view.name === 'v_article_production' || 
          view.name === 'v_article_maintenance' || 
          view.name === 'v_article_achats'
        );
        setViews(articleViews);
        const defaultView = articleViews.find(view => view.name === 'v_article');
        if (defaultView) {
          setSelectedView(defaultView.name);
        } else if (articleViews.length > 0) {
          setSelectedView(articleViews[0].name);
        }
      } catch (error) {
        console.error('Erreur lors du chargement des vues SAP:', error);
      } finally {
        setLoading(false);
      }
    };

    loadViews();
  }, []);

  useEffect(() => {
    if (selectedView) {
      loadViewData();
    }
  }, [selectedView, page, rowsPerPage, sortField, sortDirection, searchTerm, filters]);

  const loadViewData = async () => {
    try {
      setLoading(true);
      
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
    } catch (error) {
      console.error(`Erreur lors du chargement des données pour la vue ${selectedView}:`, error);
    } finally {
      setLoading(false);
    }
  };

  const handleViewChange = (event) => {
    const newView = event.target.value;
    setSelectedView(newView);
    setPage(0);
    setSortField('');
    setSortDirection('asc');
    setSearchTerm('');
    setFilters({});
  };

  const handlePageChange = (newPage) => {
    setPage(newPage);
  };

  const handleRowsPerPageChange = (newRowsPerPage) => {
    setRowsPerPage(newRowsPerPage);
    setPage(0);
  };

  const handleSortChange = (field, direction) => {
    setSortField(field);
    setSortDirection(direction);
  };
  
  const handleSearchChange = (term) => {
    setSearchTerm(term);
    setPage(0);
  };
  
  const handleFilterChange = (newFilters) => {
    setFilters(newFilters);
    setPage(0);
  };

  return (
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 3 }}>
      <Box sx={{ mb: 2 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Données SAP - Articles
        </Typography>
      </Box>

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
                      {view.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {loading && !viewData && (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      )}

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

export default ArticlesDataPage; 