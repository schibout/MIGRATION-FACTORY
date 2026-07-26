import React, { useState, useEffect } from 'react';
import {
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TableSortLabel,
  TablePagination,
  Paper,
  Typography,
  Box,
  useTheme,
  useMediaQuery,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  TextField,
  Button,
  IconButton,
  InputAdornment,
  Tooltip,
  Chip,
  Grid,
  Divider,
  Menu,
  Checkbox,
  ListItemText,
  LinearProgress,
} from '@mui/material';
import {
  Search as SearchIcon,
  FilterList as FilterListIcon,
  Close as CloseIcon,
  Add as AddIcon,
  Refresh as RefreshIcon,
  ExpandLess as ExpandLessIcon,
  ExpandMore as ExpandMoreIcon,
  FileDownload as FileDownloadIcon,
} from '@mui/icons-material';
import { ViewData } from '../../services/sapViewsService';

interface SapDataTableProps {
  data: ViewData;
  onPageChange: (page: number) => void;
  onRowsPerPageChange: (rowsPerPage: number) => void;
  onSortChange: (field: string, direction: 'asc' | 'desc') => void;
  onSearchChange?: (searchTerm: string) => void;
  onFilterChange?: (filters: Record<string, string>) => void;
  currentPage: number;
  currentRowsPerPage: number;
  currentSortField: string;
  currentSortDirection: 'asc' | 'desc';
  loading: boolean;
  /** Délai avant envoi de la recherche au parent (réduit les appels API). 0 = immédiat. */
  debounceSearchMs?: number;
  /** Change quand la vue change : remet recherche + filtres locaux à zéro. */
  toolbarResetKey?: string;
  enableExportCsv?: boolean;
  exportFilePrefix?: string;
}

const SapDataTable = ({
  data,
  onPageChange,
  onRowsPerPageChange,
  onSortChange,
  onSearchChange,
  onFilterChange,
  currentPage,
  currentRowsPerPage,
  currentSortField,
  currentSortDirection,
  loading,
  debounceSearchMs = 0,
  toolbarResetKey,
  enableExportCsv = false,
  exportFilePrefix = 'export_sap',
}: SapDataTableProps) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // Recherche (locale + synchro parent)
  const [localQuery, setLocalQuery] = useState('');
  const [activeFilters, setActiveFilters] = useState<{[key: string]: string}>({});
  const [showFilters, setShowFilters] = useState(false);
  const [filteredRows, setFilteredRows] = useState(data.rows);
  
  // État pour le filtre avancé (sélection de colonne et valeur)
  const [selectedColumn, setSelectedColumn] = useState('');
  const [filterValue, setFilterValue] = useState('');

  // Gestion du tri
  const handleSort = (column: string) => {
    const newDirection = currentSortField === column && currentSortDirection === 'asc' ? 'desc' : 'asc';
    onSortChange(column, newDirection);
  };

  // Gestion de la pagination
  const handleChangePage = (_event: unknown, newPage: number) => {
    onPageChange(newPage);
  };

  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    onRowsPerPageChange(parseInt(event.target.value, 10));
  };
  
  // Debounce recherche vers le parent
  useEffect(() => {
    if (!debounceSearchMs || debounceSearchMs <= 0 || !onSearchChange) return;
    const t = window.setTimeout(() => onSearchChange(localQuery), debounceSearchMs);
    return () => clearTimeout(t);
  }, [localQuery, debounceSearchMs, onSearchChange]);

  useEffect(() => {
    if (toolbarResetKey === undefined || toolbarResetKey === '') return;
    setLocalQuery('');
    setActiveFilters({});
    setSelectedColumn('');
    setFilterValue('');
    if (!debounceSearchMs || debounceSearchMs <= 0) {
      onSearchChange?.('');
    }
    onFilterChange?.({});
  }, [toolbarResetKey]);

  // Fonctions pour la recherche et les filtres
  const handleSearchChange = (event: any) => {
    const term = event.target.value;
    setLocalQuery(term);

    const useDebounce = debounceSearchMs > 0 && onSearchChange;
    if (useDebounce) {
      return;
    }

    if (onSearchChange) {
      onSearchChange(term);
    } else {
      applyFiltersAndSearch(term, activeFilters);
    }
  };

  const toggleFilters = () => {
    setShowFilters(!showFilters);
  };

  const resetFilters = () => {
    setActiveFilters({});
    setLocalQuery('');
    setSelectedColumn('');
    setFilterValue('');

    if (onSearchChange) {
      onSearchChange('');
    }
    if (onFilterChange) {
      onFilterChange({});
    } else {
      setFilteredRows(data.rows);
    }
  };

  // Nouvelle fonction pour gérer la sélection de colonne pour le filtre
  const handleColumnChange = (event: React.ChangeEvent<{ value: unknown }>) => {
    const column = event.target.value as string;
    setSelectedColumn(column);
  };

  // Nouvelle fonction pour gérer la saisie de valeur pour le filtre
  const handleValueChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setFilterValue(value);
  };

  // Nouvelle fonction pour ajouter un filtre
  const addFilter = () => {
    if (selectedColumn && filterValue) {
      const newFilters = { ...activeFilters };
      newFilters[selectedColumn] = filterValue;

      setActiveFilters(newFilters);

      if (onFilterChange) {
        onFilterChange(newFilters);
      } else {
        applyFiltersAndSearch(localQuery, newFilters);
      }

      setFilterValue('');
    }
  };

  // Fonction pour supprimer un filtre
  const removeFilter = (columnName: string) => {
    const newFilters = { ...activeFilters };
    delete newFilters[columnName];

    setActiveFilters(newFilters);

    if (onFilterChange) {
      onFilterChange(newFilters);
    } else {
      applyFiltersAndSearch(localQuery, newFilters);
    }
  };

  // Fonction pour appliquer les filtres et la recherche localement
  const applyFiltersAndSearch = (search: string, filters: { [key: string]: string }) => {
    let result = [...data.rows];

    if (search.trim() !== '') {
      const searchLower = search.toLowerCase();
      result = result.filter((row) =>
        Object.values(row).some(
          (value) =>
            value !== null &&
            value !== undefined &&
            String(value).toLowerCase().includes(searchLower)
        )
      );
    }

    Object.entries(filters).forEach(([column, fVal]) => {
      if (fVal.trim() !== '') {
        const filterLower = fVal.toLowerCase();
        result = result.filter((row) => {
          const cellValue = row[column];
          return (
            cellValue !== null &&
            cellValue !== undefined &&
            String(cellValue).toLowerCase().includes(filterLower)
          );
        });
      }
    });

    setFilteredRows(result);
  };

  // Recalculer les lignes filtrées quand les données changent
  useEffect(() => {
    if (onSearchChange && onFilterChange) {
      setFilteredRows(data.rows);
    } else {
      applyFiltersAndSearch(localQuery, activeFilters);
    }
  }, [data.rows]);

  // Déterminer les lignes à afficher
  const displayedRows = onSearchChange && onFilterChange ? data.rows : filteredRows;
  const displayedCount = onSearchChange && onFilterChange ? data.total : filteredRows.length;

  const columnSignature = data.columns.map((col) => col.name).join('\u0001');
  const [visibleColumns, setVisibleColumns] = useState<string[]>(() =>
    data.columns.map((col) => col.name)
  );
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const open = Boolean(anchorEl);

  useEffect(() => {
    setVisibleColumns(data.columns.map((col) => col.name));
  }, [columnSignature]);

  const handleOpenMenu = (event: React.MouseEvent<HTMLButtonElement>) => setAnchorEl(event.currentTarget);
  const handleCloseMenu = () => setAnchorEl(null);
  const handleToggleColumn = (colName: string) => {
    setVisibleColumns((cols) =>
      cols.includes(colName) ? cols.filter((c) => c !== colName) : [...cols, colName]
    );
  };

  const showAllColumns = () => {
    setVisibleColumns(data.columns.map((col) => col.name));
    handleCloseMenu();
  };

  const escapeCsv = (val: string) => `"${val.replace(/"/g, '""')}"`;

  const exportCurrentPageCsv = () => {
    const cols = data.columns.filter((c) => visibleColumns.includes(c.name));
    if (cols.length === 0) return;
    const header = cols.map((c) => escapeCsv(String(c.label || c.name))).join(',');
    const lines = displayedRows.map((row) =>
      cols.map((c) => escapeCsv(row[c.name] === null || row[c.name] === undefined ? '' : String(row[c.name]))).join(',')
    );
    const bom = '\uFEFF';
    const blob = new Blob([bom + header + '\n' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const safeName = (exportFilePrefix || 'export').replace(/[^a-z0-9_-]/gi, '_');
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${safeName}_page${currentPage + 1}.csv`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const visibleColsList = data.columns.filter((col) => visibleColumns.includes(col.name));
  const headerBgColor = '#1976d2';
  const headerTextColor = 'white';
  const rowEvenBgColor = '#ffffff';
  const rowOddBgColor = '#f8f9fa';
  const textColor = '#212529';
  const borderColor = '#dee2e6';
  const hoverColor = '#e3f2fd';

  return (
    <div style={{ width: '100%' }}>
      <div style={{ 
        display: 'flex', 
        flexDirection: isMobile ? 'column' : 'row',
        justifyContent: 'space-between',
        alignItems: isMobile ? 'stretch' : 'center',
        gap: '10px',
        marginBottom: '20px'
      }}>
        <TextField
          placeholder="Rechercher dans les données..."
          variant="outlined"
          value={localQuery}
          onChange={handleSearchChange}
          size="small"
          fullWidth
          helperText={debounceSearchMs > 0 ? `Recherche envoyée après ${debounceSearchMs} ms sans frappe` : undefined}
          FormHelperTextProps={{ sx: { mx: 0 } }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon sx={{ color: theme.palette.primary.main }} />
              </InputAdornment>
            ),
            endAdornment: localQuery && (
              <InputAdornment position="end">
                <IconButton
                  size="small"
                  onClick={() => handleSearchChange({ target: { value: '' } })}
                >
                  <CloseIcon fontSize="small" />
                </IconButton>
              </InputAdornment>
            ),
            sx: {
              bgcolor: 'white',
              borderRadius: 1,
              '& .MuiInputBase-input': {
                color: '#212529 !important',
                WebkitTextFillColor: '#212529 !important',
              },
              '& .MuiOutlinedInput-notchedOutline': {
                borderColor: borderColor,
              },
              '&:hover .MuiOutlinedInput-notchedOutline': {
                borderColor: theme.palette.primary.main,
              },
              '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                borderColor: theme.palette.primary.main,
              }
            }
          }}
          style={{ 
            flex: isMobile ? '1' : '1 1 60%',
            maxWidth: isMobile ? '100%' : '600px'
          }}
        />
        
        <div style={{ 
          display: 'flex',
          gap: '10px',
          alignItems: 'center',
          justifyContent: isMobile ? 'space-between' : 'flex-end',
          flex: isMobile ? '1' : '1 1 40%',
        }}>
          <Button
            variant={showFilters ? "contained" : "outlined"}
            color="primary"
            onClick={toggleFilters}
            startIcon={showFilters ? <ExpandLessIcon /> : <ExpandMoreIcon />}
            size="small"
            sx={{
              fontWeight: 600,
              textTransform: 'none',
              minWidth: '140px',
              boxShadow: showFilters ? 1 : 0
            }}
          >
            {showFilters ? "Masquer filtres" : "Filtres"}
          </Button>
          
          <Button
            variant="outlined"
            color="error"
            onClick={resetFilters}
            startIcon={<RefreshIcon />}
            size="small"
            disabled={!localQuery.trim() && Object.keys(activeFilters).length === 0}
            sx={{
              fontWeight: 600,
              textTransform: 'none',
              minWidth: '120px'
            }}
          >
            Réinitialiser
          </Button>
          <Button
            onClick={handleOpenMenu}
            variant="outlined"
            size="small"
            sx={{
              fontWeight: 600,
              textTransform: 'none',
              minWidth: '120px'
            }}
          >
            Colonnes
          </Button>
          {enableExportCsv && (
            <Tooltip title="Exporter la page affichée (CSV, séparateur virgule, UTF-8)">
              <Button
                variant="outlined"
                color="success"
                size="small"
                startIcon={<FileDownloadIcon />}
                onClick={exportCurrentPageCsv}
                disabled={displayedRows.length === 0}
                sx={{
                  fontWeight: 600,
                  textTransform: 'none',
                  minWidth: '120px'
                }}
              >
                Export CSV
              </Button>
            </Tooltip>
          )}
          <Menu anchorEl={anchorEl} open={open} onClose={handleCloseMenu}>
            <MenuItem onClick={showAllColumns} dense sx={{ fontWeight: 600 }}>
              Tout afficher
            </MenuItem>
            <Divider />
            {data.columns.map(col => (
              <MenuItem key={col.name} onClick={() => handleToggleColumn(col.name)}>
                <Checkbox checked={visibleColumns.includes(col.name)} />
                <ListItemText primary={col.label || col.name} />
              </MenuItem>
            ))}
          </Menu>
        </div>
      </div>
      
      {showFilters && (
        <Box sx={{ 
          mt: 2, 
          p: 2.5, 
          bgcolor: '#f8f9fa', 
          borderRadius: 2, 
          border: '1px solid',
          borderColor: borderColor,
          boxShadow: 1,
          mb: 2
        }}>
          <Typography variant="subtitle2" gutterBottom fontWeight={600} sx={{ 
            color: theme.palette.primary.main, 
            mb: 2
          }}>
            Filtres avancés
          </Typography>
          
          <Grid container spacing={2} alignItems="flex-end">
            <Grid item xs={12} md={5}>
              <FormControl fullWidth size="small">
                <InputLabel id="filter-column-label">Colonne</InputLabel>
                <Select
                  labelId="filter-column-label"
                  id="filter-column"
                  value={selectedColumn}
                  onChange={handleColumnChange}
                  label="Colonne"
                  sx={{ bgcolor: 'white' }}
                >
                  {data.columns.map(column => (
                    <MenuItem key={column.name} value={column.name}>
                      {column.label || column.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            
            <Grid item xs={12} md={5}>
              <TextField
                id="filter-value"
                label="Valeur"
                variant="outlined"
                size="small"
                value={filterValue}
                onChange={handleValueChange}
                onKeyPress={(e) => {
                  if (e.key === 'Enter' && selectedColumn && filterValue) {
                    addFilter();
                  }
                }}
                sx={{
                  width: '100%',
                  bgcolor: 'white',
                  '& .MuiInputBase-input': {
                    color: '#212529 !important',
                    WebkitTextFillColor: '#212529 !important',
                  },
                  '& .MuiInputLabel-root': { color: '#495057' },
                }}
              />
            </Grid>

            <Grid item xs={12} md={2}>
              <Button
                variant="contained"
                color="primary"
                startIcon={<AddIcon />}
                onClick={addFilter}
                disabled={!selectedColumn || !filterValue}
                size="small"
                fullWidth
                sx={{ 
                  fontWeight: 600,
                  textTransform: 'none'
                }}
              >
                Ajouter
              </Button>
            </Grid>
          </Grid>
          
          {/* Affichage des filtres actifs */}
          {Object.keys(activeFilters).length > 0 && (
            <Box sx={{ mt: 2 }}>
              <Typography variant="caption" sx={{ 
                fontWeight: 600, 
                color: theme.palette.text.secondary,
                mb: 1,
                display: 'block'
              }}>
                Filtres actifs
              </Typography>
              <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                {Object.entries(activeFilters).map(([column, value]) => (
                  <Chip
                    key={column}
                    label={`${data.columns.find(c => c.name === column)?.label || column}: ${value}`}
                    onDelete={() => removeFilter(column)}
                    color="primary"
                    variant="outlined"
                    size="small"
                  />
                ))}
              </Box>
            </Box>
          )}
        </Box>
      )}
        
      <Typography variant="body2" sx={{ mb: 1.5, color: theme.palette.text.secondary, fontWeight: 500 }}>
        {displayedCount.toLocaleString('fr-FR')} résultat{displayedCount !== 1 ? 's' : ''}{' '}
        {displayedCount !== data.total && data.total > 0
          ? `(sur ${data.total.toLocaleString('fr-FR')} au total)`
          : ''}
        {displayedRows.length > 0 &&
          ` · ${displayedRows.length.toLocaleString('fr-FR')} ligne${displayedRows.length !== 1 ? 's' : ''} sur cette page`}
      </Typography>

      {displayedRows.length === 0 ? (
        <Box sx={{ mb: 2 }}>
          {loading && <LinearProgress sx={{ borderRadius: 1, mb: 1 }} />}
          <Paper
          variant="outlined"
          sx={{
            p: 3,
            borderRadius: 2,
            bgcolor: 'action.hover',
            borderStyle: 'dashed',
          }}
        >
          <Typography variant="subtitle1" fontWeight={600} gutterBottom color="text.primary">
            Aucune ligne à afficher sur cette page
          </Typography>
          <Typography variant="body2" color="text.secondary" component="div" sx={{ lineHeight: 1.7 }}>
            <strong>Nombre de lignes (total requête) :</strong>{' '}
            {displayedCount.toLocaleString('fr-FR')}
            <br />
            <strong>Lignes par page :</strong> {currentRowsPerPage}
            <br />
            <strong>Page :</strong> {currentPage + 1}
            {data.total > 0 && displayedCount !== data.total && (
              <>
                <br />
                <strong>Total sans filtre recherche :</strong> {data.total.toLocaleString('fr-FR')}
              </>
            )}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
            Élargissez la recherche, retirez des filtres ou changez de vue.
          </Typography>
        </Paper>
        </Box>
      ) : (
      <Box sx={{ position: 'relative', mb: 2, width: '100%', flexShrink: 0 }}>
        {loading && (
          <LinearProgress
            sx={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              zIndex: 3,
              borderTopLeftRadius: 8,
              borderTopRightRadius: 8,
            }}
          />
        )}
        <TableContainer
          component={Paper}
          sx={{
            // Évite la grande zone blanche sous peu de lignes : pas de hauteur max si peu de lignes
            maxHeight: displayedRows.length < 15 ? undefined : 560,
            overflowX: 'auto',
            overflowY: displayedRows.length < 15 ? 'visible' : 'auto',
            border: `1px solid ${borderColor}`,
            borderRadius: 2,
            boxShadow: 1,
            width: '100%',
          }}
        >
          <Table stickyHeader aria-label="données SAP">
            <TableHead>
              <TableRow>
                {visibleColsList.map((column) => (
                  <TableCell
                    key={column.name}
                    align="left"
                    sx={{
                      fontWeight: 600,
                      fontSize: '0.875rem',
                      backgroundColor: headerBgColor,
                      color: headerTextColor,
                      borderBottom: 'none',
                      py: 1.5,
                      px: 2,
                      minWidth: '120px',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    <TableSortLabel
                      active={currentSortField === column.name}
                      direction={currentSortField === column.name ? currentSortDirection : 'asc'}
                      onClick={() => handleSort(column.name)}
                      sx={{
                        color: `${headerTextColor} !important`,
                        '& .MuiTableSortLabel-icon': {
                          color: `${headerTextColor} !important`,
                        },
                      }}
                    >
                      {column.label || column.name}
                    </TableSortLabel>
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {displayedRows.map((row, rowIndex) => (
                <TableRow
                  key={rowIndex}
                  sx={{
                    backgroundColor: rowIndex % 2 === 0 ? rowEvenBgColor : rowOddBgColor,
                    '&:hover': {
                      backgroundColor: hoverColor,
                    },
                  }}
                >
                  {visibleColsList.map((column) => (
                    <TableCell
                      key={`${rowIndex}-${column.name}`}
                      sx={{
                        color: textColor,
                        fontSize: '0.875rem',
                        py: 1,
                        px: 2,
                        borderColor: borderColor,
                      }}
                    >
                      {row[column.name] !== null && row[column.name] !== undefined
                        ? String(row[column.name])
                        : ''}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Box>
      )}
      
      {/* Pagination standard MUI */}
      <TablePagination
        component="div"
        count={displayedCount}
        page={currentPage}
        onPageChange={handleChangePage}
        rowsPerPage={currentRowsPerPage}
        onRowsPerPageChange={handleChangeRowsPerPage}
        rowsPerPageOptions={[10, 25, 50, 100, 200]}
        labelRowsPerPage="Lignes par page:"
        labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
        sx={{
          borderTop: `1px solid ${borderColor}`,
          bgcolor: 'background.paper',
          borderRadius: '0 0 8px 8px',
          flexShrink: 0,
          minHeight: 'auto',
          '& .MuiTablePagination-toolbar': {
            flexWrap: 'wrap',
            minHeight: 48,
            py: 0.5,
          },
          '& .MuiTablePagination-select': {
            fontSize: '0.875rem'
          },
          '& .MuiTablePagination-displayedRows': {
            fontSize: '0.875rem'
          },
          '& .MuiTablePagination-selectLabel': {
            fontSize: '0.875rem'
          }
        }}
      />
    </div>
  );
};

export default SapDataTable; 