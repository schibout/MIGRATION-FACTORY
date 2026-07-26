import {
  FileDownload as DownloadIcon,
  ExpandLess as ExpandLessIcon,
  ExpandMore as ExpandMoreIcon,
  Description as FileIcon,
  Search as SearchIcon,
  TableChart as TableIcon
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  Grid,
  InputAdornment,
  InputLabel,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Select,
  SelectChangeEvent,
  TextField,
  Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import IfsDataTable from '../components/ifs/IfsDataTable';
import ifsArticlesService, { IfsArticleTable } from '../services/ifsArticlesService';
import { TableData } from '../services/ifsTablesService';

const IfsDataArticles: React.FC = () => {
  // Données principales
  const [tables, setTables] = useState<IfsArticleTable[]>([]);
  const [selectedTable, setSelectedTable] = useState<string>('');
  const [tableData, setTableData] = useState<TableData | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  
  // État de pagination et tri
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(10);
  const [sortField, setSortField] = useState<string>('');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  
  // États pour la recherche avancée
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [advancedFilterOpen, setAdvancedFilterOpen] = useState<boolean>(false);
  const [filters, setFilters] = useState<Record<string, {value: string, operator: string}>>({});
  const [availableColumns, setAvailableColumns] = useState<string[]>([]);
  const [selectedFilterColumn, setSelectedFilterColumn] = useState<string>('');
  const [filterValue, setFilterValue] = useState<string>('');
  const [selectedOperator, setSelectedOperator] = useState<string>('contains');
  
  // État pour l'export
  const [exportMenuAnchor, setExportMenuAnchor] = useState<null | HTMLElement>(null);
  const [exporting, setExporting] = useState<boolean>(false);
  
  // État pour les dialogues
  const [viewDialogOpen, setViewDialogOpen] = useState<boolean>(false);
  const [editDialogOpen, setEditDialogOpen] = useState<boolean>(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState<boolean>(false);
  const [currentRow, setCurrentRow] = useState<any>(null);
  const [editedValues, setEditedValues] = useState<Record<string, any>>({});

  // Opérateurs disponibles
  const filterOperators = [
    { value: 'contains', label: 'Contient' },
    { value: 'equals', label: '=' },
    { value: 'not_equals', label: '≠' },
    { value: 'greater_than', label: '>' },
    { value: 'greater_equal', label: '>=' },
    { value: 'less_than', label: '<' },
    { value: 'less_equal', label: '<=' },
    { value: 'starts_with', label: 'Commence par' },
    { value: 'ends_with', label: 'Finit par' },
    { value: 'is_null', label: 'Est vide' },
    { value: 'is_not_null', label: 'N\'est pas vide' }
  ];

  // Chargement initial des tables
  useEffect(() => {
    const loadTables = async () => {
      try {
        const tablesData = await ifsArticlesService.getTables();
        setTables(tablesData);
        if (tablesData.length > 0) {
          setSelectedTable(tablesData[0].id);
        }
      } catch (error) {
        console.error('Erreur lors du chargement des tables articles:', error);
      }
    };
    
    loadTables();
  }, []);
  
  // Mise à jour des colonnes disponibles pour les filtres
  useEffect(() => {
    if (tableData && tableData.columns) {
      const columns = tableData.columns.map(col => col.name);
      setAvailableColumns(columns);
      
      // Sélectionner la première colonne par défaut si aucune n'est sélectionnée
      if (columns.length > 0 && !selectedFilterColumn) {
        setSelectedFilterColumn(columns[0]);
      }
    }
  }, [tableData, selectedFilterColumn]);
  
  // Chargement des données de la table
  useEffect(() => {
    if (!selectedTable) return;
    
    const loadTableData = async () => {
      setLoading(true);
      try {
        const data = await ifsArticlesService.getTableData(
          selectedTable,
          page,
          rowsPerPage,
          sortField,
          sortDirection,
          searchTerm,
          filters
        );
        setTableData(data as TableData);
      } catch (error) {
        console.error('Erreur lors du chargement des données articles:', error);
      } finally {
        setLoading(false);
      }
    };
    
    loadTableData();
  }, [selectedTable, page, rowsPerPage, sortField, sortDirection, searchTerm, filters]);
  
  // Gestion du changement de table
  const handleTableChange = (event: SelectChangeEvent) => {
    const tableId = event.target.value;
    setSelectedTable(tableId);
    setPage(0);
    setSortField('');
    setSortDirection('asc');
    setSearchTerm('');
    setFilters({});
    setAdvancedFilterOpen(false);
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
  const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSearchTerm(event.target.value);
    setPage(0); // Réinitialiser la pagination lors de la recherche
  };
  
  const handleSearchSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    // La recherche est déjà déclenchée par l'effet useEffect
  };
  
  // Gestion des filtres avancés
  const toggleAdvancedFilter = () => {
    setAdvancedFilterOpen(!advancedFilterOpen);
  };
  
  const handleFilterColumnChange = (event: SelectChangeEvent) => {
    setSelectedFilterColumn(event.target.value);
  };
  
  const handleFilterValueChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setFilterValue(event.target.value);
  };
  
  const handleOperatorChange = (event: SelectChangeEvent) => {
    setSelectedOperator(event.target.value);
  };
  
  const addFilter = () => {
    if (selectedFilterColumn && (filterValue || ['is_null', 'is_not_null'].includes(selectedOperator))) {
      setFilters(prev => ({
        ...prev,
        [selectedFilterColumn]: { value: filterValue, operator: selectedOperator }
      }));
      setFilterValue('');
      setPage(0); // Réinitialiser la pagination lors de l'ajout d'un filtre
    }
  };
  
  const removeFilter = (columnName: string) => {
    const newFilters = { ...filters };
    delete newFilters[columnName];
    setFilters(newFilters);
    setPage(0);
  };
  
  const clearAllFilters = () => {
    setFilters({});
    setSearchTerm('');
    setPage(0);
  };
  
  // Gestion de l'export
  const handleExportClick = (event: React.MouseEvent<HTMLButtonElement>) => {
    setExportMenuAnchor(event.currentTarget);
  };
  
  const handleExportClose = () => {
    setExportMenuAnchor(null);
  };
  
  const handleExport = async (format: 'csv' | 'excel') => {
    if (!selectedTable || !tableData) return;
    
    setExporting(true);
    handleExportClose();
    
    try {
      const fields = tableData.columns.map(col => col.name);
      
      const exportOptions = {
        format,
        fields,
        filters,
        options: {
          includeHeaders: true,
          delimiter: ';',
          filename: `articles_${selectedTable}_${new Date().toISOString().split('T')[0]}`
        }
      };
      
      await ifsArticlesService.exportTable(selectedTable, exportOptions);
    } catch (error) {
      console.error('Erreur lors de l\'export:', error);
      alert('Erreur lors de l\'export des données');
    } finally {
      setExporting(false);
    }
  };
  
  // Gestion des actions sur les lignes
  const handleViewRow = (row: any) => {
    setCurrentRow(row);
    setViewDialogOpen(true);
  };
  
  const handleEditRow = (row: any) => {
    setCurrentRow(row);
    setEditedValues(row);
    setEditDialogOpen(true);
  };
  
  const handleDeleteRow = (row: any) => {
    setCurrentRow(row);
    setDeleteDialogOpen(true);
  };
  
  const handleViewDialogClose = () => {
    setViewDialogOpen(false);
    setCurrentRow(null);
  };
  
  const handleEditDialogClose = () => {
    setEditDialogOpen(false);
    setCurrentRow(null);
    setEditedValues({});
  };
  
  const handleDeleteDialogClose = () => {
    setDeleteDialogOpen(false);
    setCurrentRow(null);
  };
  
  const handleInputChange = (fieldName: string, value: any) => {
    setEditedValues(prev => ({
      ...prev,
      [fieldName]: value
    }));
  };
  
  const handleSaveEdit = async () => {
    if (!currentRow || !selectedTable) return;
    
    try {
      const recordId = currentRow['Code article'] || Object.values(currentRow)[0];
      await ifsArticlesService.updateRecord(selectedTable, recordId, editedValues);
      
      // Rafraîchir les données
      const data = await ifsArticlesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data as TableData);
      
      handleEditDialogClose();
      alert('Enregistrement mis à jour avec succès');
    } catch (error) {
      console.error('Erreur lors de la mise à jour:', error);
      alert('Erreur lors de la mise à jour de l\'enregistrement');
    }
  };
  
  const handleConfirmDelete = async () => {
    if (!currentRow || !selectedTable) return;
    
    try {
      const recordId = currentRow['Code article'] || Object.values(currentRow)[0];
      await ifsArticlesService.deleteRecord(selectedTable, recordId);
      
      // Rafraîchir les données
      const data = await ifsArticlesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data as TableData);
      
      handleDeleteDialogClose();
      alert('Enregistrement supprimé avec succès');
    } catch (error) {
      console.error('Erreur lors de la suppression:', error);
      alert('Erreur lors de la suppression de l\'enregistrement');
    }
  };
  
  const handleDeleteMultiple = async (rowsToDelete: any[]) => {
    if (!selectedTable || rowsToDelete.length === 0) return;
    
    setLoading(true);
    
    try {
      let successCount = 0;
      let errorCount = 0;
      const errorMessages: string[] = [];
      
      // Fonction pour déterminer l'ID d'un enregistrement
      const getRecordId = (row: any) => {
        // Priorité aux champs articles
        if (row['Code article']) {
          return row['Code article'];
        }
        
        // Fallback générique pour autres champs ID
        const keys = Object.keys(row);
        const idFields = keys.filter(key => 
          key.toLowerCase().endsWith('_id') || 
          key.toLowerCase() === 'id' ||
          key.toLowerCase().endsWith('_no') ||
          key.toLowerCase().includes('code')
        );
        
        if (idFields.length > 0) {
          const sortedFields = idFields.sort((a, b) => {
            if (a.toLowerCase() === 'id') return -1;
            if (b.toLowerCase() === 'id') return 1;
            if (a.toLowerCase().includes('code')) return -1;
            if (b.toLowerCase().includes('code')) return 1;
            return 0;
          });
          
          return row[sortedFields[0]];
        } else {
          return Object.values(row)[0];
        }
      };
      
      // Traiter les suppressions en série
      for (const row of rowsToDelete) {
        try {
          const recordId = getRecordId(row);
          
          if (!recordId) {
            errorCount++;
            errorMessages.push(`Impossible de déterminer l'identifiant d'un enregistrement`);
            continue;
          }
          
          const result = await ifsArticlesService.deleteRecord(selectedTable, recordId);
          
          if (result.success) {
            successCount++;
          } else {
            errorCount++;
            errorMessages.push(result.message || 'Erreur inconnue');
          }
        } catch (error) {
          errorCount++;
          const errorMessage = error instanceof Error ? error.message : 'Erreur inconnue';
          errorMessages.push(errorMessage);
        }
      }
      
      // Rafraîchir les données après les suppressions
      const data = await ifsArticlesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data as TableData);
      
      // Afficher un résumé des résultats
      const message = `${successCount} enregistrement(s) supprimé(s) avec succès. ` +
                      (errorCount > 0 ? `${errorCount} erreur(s) rencontrée(s).` : '');
      
      alert(message);
      
      if (errorCount > 0 && errorMessages.length > 0) {
        console.error('Erreurs lors de la suppression multiple:', errorMessages);
      }
      
    } catch (error) {
      console.error('Erreur globale lors de la suppression multiple:', error);
      alert('Une erreur est survenue lors de la suppression multiple des enregistrements.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 1 }}>
      <Box sx={{ 
        mb: 1, 
        backgroundColor: '#1a237e',
        borderRadius: '4px',
        p: 1.5,
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <Typography variant="h5" component="h1" sx={{ 
          color: 'white', 
          fontWeight: 'bold',
          fontSize: '1.4rem',
          m: 0
        }}>
          DONNÉES ARTICLES IFS
        </Typography>
        
        {selectedTable && (
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Typography variant="body2" sx={{ color: 'white', fontWeight: 'medium' }}>
              Table cible :
            </Typography>
            <Chip 
              label={selectedTable} 
              size="small"
              sx={{ 
                bgcolor: 'white', 
                color: '#1a237e', 
                fontWeight: 'bold',
                fontSize: '0.75rem'
              }} 
            />
          </Box>
        )}
      </Box>
      
      <Card sx={{ mb: 1, bgcolor: '#f5f8ff', border: '1px solid #1a237e' }}>
        <CardContent sx={{ p: 1.5, '&:last-child': { pb: 1.5 } }}>
          <Grid container spacing={1} alignItems="center">
            <Grid item xs={12} md={6}>
              <FormControl fullWidth size="small">
                <InputLabel id="table-select-label" sx={{ 
                  color: '#1a237e', 
                  fontWeight: 'bold',
                  '&.Mui-focused': { color: '#1a237e' }
                }}>
                  Sélectionner une table
                </InputLabel>
                <Select
                  labelId="table-select-label"
                  id="table-select"
                  value={selectedTable}
                  label="Sélectionner une table"
                  onChange={handleTableChange}
                  size="small"
                  sx={{ 
                    bgcolor: 'white',
                    color: '#1a237e',
                    fontWeight: 'medium',
                    border: '1px solid #1a237e',
                    '& .MuiOutlinedInput-notchedOutline': {
                      borderColor: '#1a237e',
                    },
                    '&:hover .MuiOutlinedInput-notchedOutline': {
                      borderColor: '#1a237e',
                    },
                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                      borderColor: '#1a237e',
                    }
                  }}
                >
                  {tables.map((table) => (
                    <MenuItem key={table.id} value={table.id}>
                      {table.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={6} sx={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
              <Button
                variant="contained"
                startIcon={<TableIcon />}
                size="small"
                sx={{ 
                  bgcolor: '#1a237e', 
                  '&:hover': { bgcolor: '#303f9f' },
                  textTransform: 'none',
                  fontWeight: 'bold'
                }}
              >
                Articles actifs avec fournisseurs
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Card sx={{ mb: 1, p: 1.5, bgcolor: '#f5f8ff', border: '1px solid #1a237e' }}>
        <form onSubmit={handleSearchSubmit}>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
            <TextField
              fullWidth
              placeholder="Rechercher..."
              value={searchTerm}
              onChange={handleSearchChange}
              variant="outlined"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchIcon color="primary" sx={{ color: '#1a237e' }} />
                  </InputAdornment>
                )
              }}
              sx={{ 
                bgcolor: 'white',
                '& .MuiOutlinedInput-root': {
                  '& fieldset': {
                    borderColor: '#1a237e',
                    borderWidth: '2px',
                  },
                  '&:hover fieldset': {
                    borderColor: '#1a237e',
                    borderWidth: '2px',
                  },
                  '&.Mui-focused fieldset': {
                    borderColor: '#1a237e',
                    borderWidth: '2px',
                  },
                },
                '& .MuiInputBase-input': {
                  color: '#1a237e',
                  fontWeight: 'medium',
                }
              }}
            />
            
            <Button
              variant="contained"
              onClick={toggleAdvancedFilter}
              startIcon={advancedFilterOpen ? <ExpandLessIcon /> : <ExpandMoreIcon />}
              size="small"
              sx={{ 
                minWidth: '140px', 
                bgcolor: '#1a237e', 
                '&:hover': { bgcolor: '#303f9f' },
                height: '40px',
                fontWeight: 'bold',
                color: 'white',
                textTransform: 'none',
                fontSize: '0.875rem'
              }}
            >
              FILTRES
            </Button>
            
            <Button
              variant="contained"
              color="error"
              onClick={clearAllFilters}
              disabled={!searchTerm && Object.keys(filters).length === 0}
              size="small"
              sx={{ 
                minWidth: '100px', 
                height: '40px',
                fontWeight: 'bold',
                textTransform: 'none',
                fontSize: '0.875rem'
              }}
            >
              Reset
            </Button>
            
            <Button
              variant="contained"
              color="primary"
              startIcon={<DownloadIcon />}
              onClick={handleExportClick}
              disabled={!tableData || loading || exporting}
              size="small"
              sx={{ 
                minWidth: '120px', 
                bgcolor: '#1a237e', 
                '&:hover': { bgcolor: '#303f9f' },
                height: '40px',
                fontWeight: 'bold',
                color: 'white',
                textTransform: 'none',
                fontSize: '0.875rem'
              }}
            >
              EXPORTER
            </Button>
          </Box>
          
          {/* Menu d'export */}
          <Menu
            anchorEl={exportMenuAnchor}
            open={Boolean(exportMenuAnchor)}
            onClose={handleExportClose}
          >
            <MenuItem onClick={() => handleExport('csv')} disabled={exporting}>
              <ListItemIcon>
                <TableIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText>Exporter en CSV</ListItemText>
            </MenuItem>
            <MenuItem onClick={() => handleExport('excel')} disabled={exporting}>
              <ListItemIcon>
                <FileIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText>Exporter en Excel</ListItemText>
            </MenuItem>
          </Menu>
          
          {/* Filtres avancés */}
          <Collapse in={advancedFilterOpen}>
            <Box sx={{ 
              mt: 2, 
              p: 3, 
              bgcolor: '#e3f2fd', 
              borderRadius: 1, 
              border: '2px solid #1a237e',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
            }}>
              <Typography variant="subtitle1" gutterBottom fontWeight="bold" sx={{ 
                color: '#1a237e', 
                fontSize: '1.1rem',
                borderBottom: '2px solid #1a237e',
                paddingBottom: '8px',
                marginBottom: '16px'
              }}>
                FILTRES AVANCÉS
              </Typography>
              
              <Grid container spacing={2} alignItems="flex-end">
                <Grid item xs={12} md={3}>
                  <FormControl fullWidth size="small">
                    <InputLabel id="filter-column-label" sx={{ 
                      color: '#1a237e',
                      fontWeight: 'bold',
                      '&.Mui-focused': { color: '#1a237e' }
                    }}>Colonne</InputLabel>
                    <Select
                      labelId="filter-column-label"
                      value={selectedFilterColumn}
                      label="Colonne"
                      onChange={handleFilterColumnChange}
                      sx={{ 
                        bgcolor: 'white', 
                        '& .MuiSelect-select': { color: '#1a237e', fontWeight: 'bold' },
                        border: '1px solid #1a237e',
                        '& .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        },
                        '&:hover .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        },
                        '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        }
                      }}
                    >
                      {availableColumns.map((column) => (
                        <MenuItem key={column} value={column}>
                          {tableData?.columns.find(c => c.name === column)?.label || column}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                </Grid>
                
                <Grid item xs={12} md={2.5}>
                  <FormControl fullWidth size="small">
                    <InputLabel id="operator-label" sx={{ 
                      color: '#1a237e',
                      fontWeight: 'bold',
                      '&.Mui-focused': { color: '#1a237e' }
                    }}>Opérateur</InputLabel>
                    <Select
                      labelId="operator-label"
                      value={selectedOperator}
                      label="Opérateur"
                      onChange={handleOperatorChange}
                      sx={{ 
                        bgcolor: 'white', 
                        '& .MuiSelect-select': { color: '#1a237e', fontWeight: 'bold' },
                        border: '1px solid #1a237e',
                        '& .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        },
                        '&:hover .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        },
                        '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                          borderColor: '#1a237e',
                        }
                      }}
                    >
                      {filterOperators.map((operator) => (
                        <MenuItem key={operator.value} value={operator.value}>
                          {operator.label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                </Grid>
                
                <Grid item xs={12} md={4.5}>
                  <TextField
                    fullWidth
                    size="small"
                    label="Valeur"
                    value={filterValue}
                    onChange={handleFilterValueChange}
                    disabled={['is_null', 'is_not_null'].includes(selectedOperator)}
                    placeholder={['is_null', 'is_not_null'].includes(selectedOperator) ? 'Non requis' : 'Entrez une valeur'}
                    sx={{ 
                      bgcolor: 'white',
                      '& .MuiInputBase-input': { color: '#1a237e', fontWeight: 'medium' },
                      '& .MuiInputLabel-root': { color: '#1a237e', fontWeight: 'bold' },
                      '& .MuiOutlinedInput-root': {
                        '& fieldset': {
                          borderColor: '#1a237e',
                        },
                        '&:hover fieldset': {
                          borderColor: '#1a237e',
                        },
                        '&.Mui-focused fieldset': {
                          borderColor: '#1a237e',
                        }
                      }
                    }}
                  />
                </Grid>
                
                <Grid item xs={12} md={2}>
                  <Button
                    variant="contained"
                    onClick={addFilter}
                    disabled={!selectedFilterColumn || (!filterValue && !['is_null', 'is_not_null'].includes(selectedOperator))}
                    fullWidth
                    sx={{ 
                      bgcolor: '#1a237e', 
                      '&:hover': { bgcolor: '#303f9f' },
                      fontWeight: 'bold',
                      color: 'white',
                      textTransform: 'uppercase'
                    }}
                  >
                    Ajouter
                  </Button>
                </Grid>
              </Grid>
              
              {/* Affichage des filtres actifs */}
              {Object.keys(filters).length > 0 && (
                <Box sx={{ mt: 3 }}>
                  <Divider sx={{ mb: 2, borderColor: '#1a237e' }} />
                  <Typography variant="subtitle2" gutterBottom sx={{ 
                    color: '#1a237e', 
                    fontWeight: 'bold',
                    fontSize: '1rem',
                    marginBottom: '12px'
                  }}>
                    FILTRES ACTIFS:
                  </Typography>
                  <Grid container spacing={1}>
                    {Object.entries(filters).map(([column, filterData]) => {
                      const { value, operator } = filterData as { value: string, operator: string };
                      const operatorLabel = filterOperators.find(op => op.value === operator)?.label || operator;
                      return (
                        <Grid item key={column}>
                          <Chip 
                            label={`${tableData?.columns.find(c => c.name === column)?.label || column} ${operatorLabel} ${value || ''}`}
                            onDelete={() => removeFilter(column)}
                            color="primary"
                          variant="outlined"
                          sx={{ 
                            bgcolor: '#e8eaf6', 
                            color: '#1a237e', 
                            fontWeight: 'bold',
                            border: '1px solid #1a237e',
                            '& .MuiChip-deleteIcon': {
                              color: '#f44336',
                              '&:hover': {
                                color: '#d32f2f'
                              }
                            }
                          }}
                                                  />
                        </Grid>
                      );
                    })}
                  </Grid>
                </Box>
              )}
            </Box>
          </Collapse>
        </form>
      </Card>

      {/* Contenu principal */}
      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 400 }}>
          <CircularProgress size={60} sx={{ color: '#1a237e' }} />
        </Box>
      ) : tableData ? (
        <IfsDataTable
          data={tableData}
          onPageChange={handlePageChange}
          onRowsPerPageChange={handleRowsPerPageChange}
          onSortChange={handleSortChange}
          currentPage={page}
          currentRowsPerPage={rowsPerPage}
          currentSortField={sortField}
          currentSortDirection={sortDirection}
          loading={loading}
          onView={handleViewRow}
          onEdit={handleEditRow}
          onDelete={handleDeleteRow}
          onDeleteMultiple={handleDeleteMultiple}
        />
      ) : (
        <Alert severity="info" sx={{ mt: 2 }}>
          Sélectionnez une table pour afficher les données
        </Alert>
      )}

      {/* Dialog pour visualiser un enregistrement */}
      <Dialog 
        open={viewDialogOpen} 
        onClose={handleViewDialogClose} 
        maxWidth="md" 
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle sx={{ bgcolor: '#1a237e', color: 'white' }}>
          Détails de l'enregistrement
        </DialogTitle>
        <DialogContent sx={{ mt: 2 }}>
          {currentRow && (
            <Grid container spacing={2}>
              {Object.entries(currentRow).map(([key, value]) => (
                <Grid item xs={12} sm={6} key={key}>
                  <TextField
                    fullWidth
                    label={tableData?.columns.find(c => c.name === key)?.label || key}
                    value={value || ''}
                    variant="outlined"
                    InputProps={{ readOnly: true }}
                    sx={{ mb: 1 }}
                  />
                </Grid>
              ))}
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleViewDialogClose} color="primary">
            Fermer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog pour éditer un enregistrement */}
      <Dialog 
        open={editDialogOpen} 
        onClose={handleEditDialogClose} 
        maxWidth="md" 
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle sx={{ bgcolor: '#1a237e', color: 'white' }}>
          Modifier l'enregistrement
        </DialogTitle>
        <DialogContent sx={{ mt: 2 }}>
          {currentRow && (
            <Grid container spacing={2}>
              {Object.entries(editedValues).map(([key, value]) => (
                <Grid item xs={12} sm={6} key={key}>
                  <TextField
                    fullWidth
                    label={tableData?.columns.find(c => c.name === key)?.label || key}
                    value={value || ''}
                    onChange={(e) => handleInputChange(key, e.target.value)}
                    variant="outlined"
                    sx={{ mb: 1 }}
                  />
                </Grid>
              ))}
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleEditDialogClose} color="secondary">
            Annuler
          </Button>
          <Button onClick={handleSaveEdit} color="primary" variant="contained">
            Sauvegarder
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog pour confirmer la suppression */}
      <Dialog 
        open={deleteDialogOpen} 
        onClose={handleDeleteDialogClose}
        disableRestoreFocus
      >
        <DialogTitle sx={{ bgcolor: '#f44336', color: 'white' }}>
          Confirmer la suppression
        </DialogTitle>
        <DialogContent sx={{ mt: 2 }}>
          <Typography>
            Êtes-vous sûr de vouloir supprimer cet enregistrement ? Cette action est irréversible.
          </Typography>
          {currentRow && (
            <Box sx={{ mt: 2, p: 2, bgcolor: '#f5f5f5', borderRadius: 1 }}>
              <Typography variant="subtitle2">
                <strong>Code article:</strong> {currentRow['Code article'] || 'N/A'}
              </Typography>
              <Typography variant="subtitle2">
                <strong>Désignation:</strong> {currentRow['Désignation'] || 'N/A'}
              </Typography>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDeleteDialogClose} color="secondary">
            Annuler
          </Button>
          <Button onClick={handleConfirmDelete} color="error" variant="contained">
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default IfsDataArticles; 