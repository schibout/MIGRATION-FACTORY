import {
  Autocomplete,
  Box,
  Breadcrumbs,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Container,
  Link,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import StoreIcon from '@mui/icons-material/Store';
import TableChartIcon from '@mui/icons-material/TableChart';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import DatasetIcon from '@mui/icons-material/Dataset';
import { useEffect, useMemo, useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import SapDataTable from '../components/sap/SapDataTable';
import sapViewsService, { SapView, ViewData } from '../services/sapViewsService';

const SapDataFournisseurs = () => {
  const [views, setViews] = useState<SapView[]>([]);
  const [selectedView, setSelectedView] = useState<string>('');
  const [selectedViewMeta, setSelectedViewMeta] = useState<SapView | null>(null);
  const [viewData, setViewData] = useState<ViewData | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [viewsLoading, setViewsLoading] = useState<boolean>(true);
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(25);
  const [sortField, setSortField] = useState<string>('');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filters, setFilters] = useState<Record<string, string>>({});

  const totalPages = useMemo(
    () => (viewData ? Math.max(1, Math.ceil(viewData.total / rowsPerPage)) : 0),
    [viewData, rowsPerPage]
  );

  useEffect(() => {
    const loadViews = async () => {
      try {
        setViewsLoading(true);
        const data = await sapViewsService.getViews('fournisseur');
        setViews(data);
        const defaultView = data.find((view) => view.name === 'v_fournisseurs');
        const initial = defaultView ?? data[0];
        if (initial) {
          setSelectedView(initial.name);
          setSelectedViewMeta(initial);
        }
      } catch (error) {
        console.error('Erreur lors du chargement des vues SAP:', error);
      } finally {
        setViewsLoading(false);
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

  const handleViewChange = (_: unknown, value: SapView | null) => {
    if (!value) return;
    setSelectedView(value.name);
    setSelectedViewMeta(value);
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

  const handleFilterChange = (newFilters: Record<string, string>) => {
    setFilters(newFilters);
    setPage(0);
  };

  const currentViewOption = views.find((v) => v.name === selectedView) ?? null;

  return (
    <Box
      sx={{
        minHeight: '100%',
        background: (theme) =>
          `linear-gradient(180deg, ${theme.palette.primary.dark}12 0%, ${theme.palette.background.default} 320px)`,
      }}
    >
      <Container maxWidth={false} sx={{ py: 3, px: { xs: 2, sm: 3 } }}>
        <Breadcrumbs sx={{ mb: 2 }} aria-label="fil d'Ariane">
          <Link component={RouterLink} to="/sap-data" color="inherit" underline="hover">
            Données SAP
          </Link>
          <Typography color="text.primary">Fournisseurs</Typography>
        </Breadcrumbs>

        <Paper
          elevation={0}
          sx={{
            p: { xs: 2.5, md: 3 },
            mb: 3,
            borderRadius: 3,
            background: (theme) =>
              `linear-gradient(135deg, ${theme.palette.primary.main} 0%, ${theme.palette.primary.dark} 100%)`,
            color: 'primary.contrastText',
            position: 'relative',
            overflow: 'hidden',
          }}
        >
          <Box
            sx={{
              position: 'absolute',
              right: -24,
              top: -24,
              opacity: 0.12,
              transform: 'rotate(-8deg)',
            }}
          >
            <StoreIcon sx={{ fontSize: 180 }} />
          </Box>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'flex-start' }} sx={{ position: 'relative' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, flex: 1 }}>
              <Box
                sx={{
                  width: 56,
                  height: 56,
                  borderRadius: 2,
                  bgcolor: 'rgba(255,255,255,0.2)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <StoreIcon sx={{ fontSize: 32 }} />
              </Box>
              <Box>
                <Typography variant="h4" component="h1" sx={{ fontWeight: 700, letterSpacing: '-0.02em' }}>
                  Fournisseurs SAP
                </Typography>
                <Typography variant="body2" sx={{ mt: 0.5, opacity: 0.92, maxWidth: 640 }}>
                  Consultation des vues <strong>clean_data</strong> (extractions SAP). Recherche globale,
                  filtres par colonne, tri et export de la page courante.
                </Typography>
              </Box>
            </Box>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ pt: { xs: 1, md: 0 } }}>
              <Button
                component={RouterLink}
                to="/sap-data/catalog?scope=fournisseur"
                variant="contained"
                size="small"
                startIcon={<TableChartIcon />}
                endIcon={<OpenInNewIcon sx={{ fontSize: 16 }} />}
                sx={{
                  bgcolor: 'rgba(255,255,255,0.18)',
                  color: 'inherit',
                  textTransform: 'none',
                  fontWeight: 600,
                  '&:hover': { bgcolor: 'rgba(255,255,255,0.28)' },
                }}
              >
                Catalogue tables
              </Button>
              <Button
                component={RouterLink}
                to="/sap-data/explorer"
                variant="contained"
                size="small"
                startIcon={<DatasetIcon />}
                endIcon={<OpenInNewIcon sx={{ fontSize: 16 }} />}
                sx={{
                  bgcolor: 'rgba(255,255,255,0.18)',
                  color: 'inherit',
                  textTransform: 'none',
                  fontWeight: 600,
                  '&:hover': { bgcolor: 'rgba(255,255,255,0.28)' },
                }}
              >
                Explorateur raw_data
              </Button>
            </Stack>
          </Stack>
        </Paper>

        <Card sx={{ mb: 2, borderRadius: 2, boxShadow: 2 }}>
          <CardContent sx={{ py: 2.5 }}>
            <Stack spacing={2}>
              <Typography variant="subtitle2" color="text.secondary" fontWeight={600}>
                Vue active
              </Typography>
              {viewsLoading ? (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  <CircularProgress size={24} />
                  <Typography variant="body2" color="text.secondary">
                    Chargement des vues…
                  </Typography>
                </Box>
              ) : (
                <Autocomplete
                  options={views}
                  value={currentViewOption}
                  onChange={handleViewChange}
                  getOptionLabel={(o) => o.label || o.name}
                  isOptionEqualToValue={(a, b) => a.name === b.name}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      label="Choisir une vue métier"
                      placeholder="Rechercher une vue…"
                      helperText="Les vues listées correspondent au périmètre fournisseur (API scope)."
                    />
                  )}
                  renderOption={(props, option) => (
                    <li {...props} key={option.name}>
                      <Stack>
                        <Typography variant="body2" fontWeight={600}>
                          {option.label}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
                          {option.name}
                        </Typography>
                      </Stack>
                    </li>
                  )}
                />
              )}
            </Stack>
          </CardContent>
        </Card>

        {viewData && selectedViewMeta && (
          <Paper variant="outlined" sx={{ p: 2, mb: 2, borderRadius: 2, bgcolor: 'background.paper' }}>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
              <Chip
                size="small"
                color="primary"
                variant="outlined"
                label={`${viewData.total.toLocaleString('fr-FR')} ligne(s) totales`}
              />
              <Chip
                size="small"
                variant="outlined"
                label={`${viewData.columns.length} colonnes`}
              />
              <Chip
                size="small"
                variant="outlined"
                label={`Page ${page + 1} / ${totalPages}`}
              />
              {sortField && (
                <Chip size="small" color="secondary" variant="outlined" label={`Tri : ${sortField} (${sortDirection})`} />
              )}
            </Stack>
          </Paper>
        )}

        {viewsLoading && !viewData && (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
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
            debounceSearchMs={400}
            toolbarResetKey={selectedView}
            enableExportCsv
            exportFilePrefix={selectedViewMeta?.name ?? 'fournisseurs_sap'}
          />
        )}
      </Container>
    </Box>
  );
};

export default SapDataFournisseurs;
