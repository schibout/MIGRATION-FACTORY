import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  LinearProgress,
  useTheme,
  useMediaQuery
} from '@mui/material';
import sapViewsService, { SapView, ViewData } from '../services/sapViewsService';
import SapDataTable from '../components/sap/SapDataTable';

const SapRawData = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // États
  const [views, setViews] = useState<SapView[]>([]);
  const [selectedView, setSelectedView] = useState<string>('');
  const [viewData, setViewData] = useState<ViewData | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(25);
  const [sortField, setSortField] = useState<string>('');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  // Nouveaux états pour la recherche et le filtrage
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filters, setFilters] = useState<Record<string, string>>({});

  // Récupérer la liste des vues SAP disponibles
  useEffect(() => {
    const fetchViews = async () => {
      try {
        setLoading(true);
        const fetchedViews = await sapViewsService.getViews();
        setViews(fetchedViews);
        
        // Sélectionner la première vue par défaut si aucune n'est déjà sélectionnée
        if (fetchedViews.length > 0 && !selectedView) {
          setSelectedView(fetchedViews[0].id);
        }
      } catch (error) {
        console.error('Erreur lors de la récupération des vues SAP:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchViews();
  }, []);

  // Récupérer les données de la vue sélectionnée
  useEffect(() => {
    const fetchViewData = async () => {
      if (!selectedView) return;
      
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
        console.error(`Erreur lors de la récupération des données pour la vue ${selectedView}:`, error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchViewData();
  }, [selectedView, page, rowsPerPage, sortField, sortDirection, searchTerm, filters]);

  // Gestion du changement de vue
  const handleViewChange = (event: any) => {
    const newView = event.target.value;
    setSelectedView(newView);
    setPage(0); // Réinitialiser la pagination lors du changement de vue
    setSortField(''); // Réinitialiser le tri
    setSortDirection('asc');
    setSearchTerm(''); // Réinitialiser la recherche
    setFilters({}); // Réinitialiser les filtres
  };

  // Gestion de la pagination
  const handlePageChange = (newPage: number) => {
    setPage(newPage);
  };

  const handleRowsPerPageChange = (newRowsPerPage: number) => {
    setRowsPerPage(newRowsPerPage);
    setPage(0);
  };

  // Gestion du tri
  const handleSortChange = (field: string, direction: 'asc' | 'desc') => {
    setSortField(field);
    setSortDirection(direction);
  };

  // Gestion de la recherche
  const handleSearchChange = (term: string) => {
    setSearchTerm(term);
    setPage(0); // Réinitialiser à la première page lors d'une recherche
  };
  
  // Gestion des filtres
  const handleFilterChange = (newFilters: Record<string, string>) => {
    setFilters(newFilters);
    setPage(0); // Réinitialiser à la première page lors d'un filtrage
  };

  // Trouver le label de la vue sélectionnée
  const selectedViewLabel = views.find(view => view.id === selectedView)?.label || '';

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        DONNÉES BRUTES DE SAP
      </Typography>
      
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={12}>
              <FormControl fullWidth sx={{ minWidth: 400, maxWidth: 600, width: '100%' }}>
                <InputLabel>Sélectionner une vue</InputLabel>
                <Select
                  value={selectedView}
                  label="Sélectionner une vue"
                  onChange={handleViewChange}
                  disabled={loading}
                >
                  {views.map((view) => (
                    <MenuItem key={view.id} value={view.id}>
                      {view.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
      
      {loading && <LinearProgress sx={{ mb: 2 }} />}
      
      {selectedView && viewData && (
        <>
          <Typography variant="h5" sx={{ mt: 4, mb: 2 }}>
            {selectedViewLabel}
          </Typography>
          
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
        </>
      )}
    </Box>
  );
};

export default SapRawData;