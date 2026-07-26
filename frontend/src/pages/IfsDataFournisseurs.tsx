import {
    Close as CloseIcon,
    FileDownload as DownloadIcon,
    ExpandLess as ExpandLessIcon,
    ExpandMore as ExpandMoreIcon,
    Description as FileIcon,
    Search as SearchIcon,
    TableChart as TableIcon
} from '@mui/icons-material';
import {
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
    IconButton,
    InputAdornment,
    InputLabel,
    ListItemIcon,
    ListItemText,
    Menu,
    MenuItem,
    Paper,
    Select,
    SelectChangeEvent,
    TextField,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import IfsDataTable from '../components/ifs/IfsDataTable';
import ifsTablesService, { ExportOptions, IfsTable, TableData } from '../services/ifsTablesService';

const IfsDataFournisseurs = () => {
  // Données principales
  const [tables, setTables] = useState<IfsTable[]>([]);
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
        const tablesData = await ifsTablesService.getTables();
        setTables(tablesData);
        if (tablesData.length > 0) {
          setSelectedTable(tablesData[0].id);
        }
      } catch (error) {
        console.error('Erreur lors du chargement des tables:', error);
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
        const data = await ifsTablesService.getTableData(
          selectedTable,
          page,
          rowsPerPage,
          sortField,
          sortDirection,
          searchTerm,
          filters
        );
        setTableData(data);
      } catch (error) {
        console.error('Erreur lors du chargement des données:', error);
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
    
    try {
      setExporting(true);
      
      // Préparer les colonnes à exporter (filtrer les colonnes système)
      const fields = tableData.columns
        .filter(col => !['created_timestamp', 'updated_timestamp', 'created_by', 'updated_by', 'is_deleted'].includes(col.name))
        .map(column => column.name);
      
      // Options d'export avec les filtres actuels
      const options: ExportOptions = {
        format,
        filename: `${selectedTable}_${new Date().toISOString().split('T')[0]}.${format === 'csv' ? 'csv' : 'xlsx'}`,
        includeHeaders: true,
        useColumnNames: true,  // Utiliser les noms de colonnes plutôt que les descriptions
        searchTerm,
        filters
      };
      
      // Exécuter l'export
      const blob = await ifsTablesService.exportTableData(selectedTable, fields, options);
      
      // Télécharger le fichier
      ifsTablesService.downloadExport(blob, options.filename || 'export.csv');
      
    } catch (error) {
      console.error('Erreur lors de l\'export des données:', error);
      alert('Une erreur est survenue lors de l\'export des données.');
    } finally {
      setExporting(false);
      handleExportClose();
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
  };
  
  const handleEditDialogClose = () => {
    setEditDialogOpen(false);
  };
  
  const handleDeleteDialogClose = () => {
    setDeleteDialogOpen(false);
  };
  
  // Mise à jour des valeurs éditées
  const handleInputChange = (fieldName: string, value: any) => {
    setEditedValues((prev) => ({
      ...prev,
      [fieldName]: value
    }));
  };
  
  // Sauvegarde des modifications
  const handleSaveEdit = async () => {
    try {
      if (!currentRow || !tableData) return;
      
      await ifsTablesService.updateRecord(
        selectedTable, 
        currentRow.id || Object.values(currentRow)[0], 
        editedValues
      );
      
      const data = await ifsTablesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data);
      
      setEditDialogOpen(false);
    } catch (error) {
      console.error('Erreur lors de la mise à jour:', error);
      alert('Une erreur est survenue lors de la mise à jour des données.');
    }
  };
  
  // Suppression d'une ligne
  const handleConfirmDelete = async () => {
    try {
      if (!currentRow) {
        alert('Aucune ligne sélectionnée pour suppression.');
        return;
      }
      
      // Déterminer l'identifiant à utiliser pour la suppression
      let recordId;
      
      // Si c'est la table supplier, on utilise spécifiquement vendor_no
      if (selectedTable === 'public.supplier' && currentRow.vendor_no) {
        recordId = currentRow.vendor_no;
      } 
      // Si un champ id est disponible, l'utiliser
      else if (currentRow.id) {
        recordId = currentRow.id;
      }
      // Pour les autres tables, essayer de trouver un identifiant approprié
      else {
        // Rechercher dans l'ordre: champ *_id, vendor_no, premier champ
        const idFields = Object.keys(currentRow).filter(
          key => key.toLowerCase().includes('_id') || 
                 key.toLowerCase() === 'id' ||
                 key.toLowerCase() === 'vendor_no' ||
                 key.toLowerCase().includes('_no')
        );
        
        if (idFields.length > 0) {
          // Trier pour privilégier id, puis *_id, puis vendor_no
          const sortedFields = idFields.sort((a, b) => {
            if (a.toLowerCase() === 'id') return -1;
            if (b.toLowerCase() === 'id') return 1;
            if (a.toLowerCase().includes('_id')) return -1;
            if (b.toLowerCase().includes('_id')) return 1;
            if (a.toLowerCase() === 'vendor_no') return -1;
            if (b.toLowerCase() === 'vendor_no') return 1;
            return 0;
          });
          
          recordId = currentRow[sortedFields[0]];
        } else {
          // Fallback: prendre la première valeur
          recordId = Object.values(currentRow)[0];
        }
      }
      
      if (!recordId) {
        alert('Impossible de déterminer l\'identifiant de l\'enregistrement à supprimer.');
        return;
      }
      
      console.log(`Suppression de l'enregistrement avec ID: ${recordId} dans la table ${selectedTable}`);
      
      const result = await ifsTablesService.deleteRecord(selectedTable, recordId);
      
      if (!result.success) {
        throw new Error(result.message);
      }
      
      // Rafraîchir les données
      const data = await ifsTablesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data);
      
      // Fermer le dialogue et afficher un message de succès
      setDeleteDialogOpen(false);
      
      // Option: afficher un message Toast de succès
      // showToast('Enregistrement supprimé avec succès', 'success');
      
    } catch (error) {
      console.error('Erreur lors de la suppression:', error);
      const errorMessage = error instanceof Error ? error.message : 'Erreur inconnue';
      alert(`Erreur lors de la suppression: ${errorMessage}`);
    }
  };

  // Suppression multiple d'enregistrements
  const handleDeleteMultiple = async (rowsToDelete: any[]) => {
    try {
      if (!rowsToDelete.length) {
        return;
      }
      
      // Confirmation avant suppression
      const confirmDelete = window.confirm(
        `Êtes-vous sûr de vouloir supprimer ${rowsToDelete.length} enregistrement(s) ? Cette action est irréversible.`
      );
      
      if (!confirmDelete) {
        return;
      }
      
      // Afficher un indicateur de chargement ou désactiver l'interface pendant le traitement
      setLoading(true);
      
      // Compteurs pour les statistiques
      let successCount = 0;
      let errorCount = 0;
      let errorMessages: string[] = [];
      
      // Fonction pour obtenir l'identifiant d'un enregistrement
      const getRecordId = (row: any) => {
        // Si c'est la table supplier, on utilise spécifiquement vendor_no
        if (selectedTable === 'public.supplier' && row.vendor_no) {
          return row.vendor_no;
        } 
        // Si un champ id est disponible, l'utiliser
        else if (row.id) {
          return row.id;
        }
        // Pour les autres tables, essayer de trouver un identifiant approprié
        else {
          // Rechercher dans l'ordre: champ *_id, vendor_no, premier champ
          const idFields = Object.keys(row).filter(
            key => key.toLowerCase().includes('_id') || 
                   key.toLowerCase() === 'id' ||
                   key.toLowerCase() === 'vendor_no' ||
                   key.toLowerCase().includes('_no')
          );
          
          if (idFields.length > 0) {
            // Trier pour privilégier id, puis *_id, puis vendor_no
            const sortedFields = idFields.sort((a, b) => {
              if (a.toLowerCase() === 'id') return -1;
              if (b.toLowerCase() === 'id') return 1;
              if (a.toLowerCase().includes('_id')) return -1;
              if (b.toLowerCase().includes('_id')) return 1;
              if (a.toLowerCase() === 'vendor_no') return -1;
              if (b.toLowerCase() === 'vendor_no') return 1;
              return 0;
            });
            
            return row[sortedFields[0]];
          } else {
            // Fallback: prendre la première valeur
            return Object.values(row)[0];
          }
        }
      };
      
      // Traiter les suppressions en série pour éviter de surcharger le serveur
      for (const row of rowsToDelete) {
        try {
          const recordId = getRecordId(row);
          
          if (!recordId) {
            errorCount++;
            errorMessages.push(`Impossible de déterminer l'identifiant d'un enregistrement`);
            continue;
          }
          
          console.log(`Suppression de l'enregistrement avec ID: ${recordId} dans la table ${selectedTable}`);
          
          const result = await ifsTablesService.deleteRecord(selectedTable, recordId);
          
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
      const data = await ifsTablesService.getTableData(
        selectedTable,
        page,
        rowsPerPage,
        sortField,
        sortDirection,
        searchTerm,
        filters
      );
      setTableData(data);
      
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
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 0.5 }}>
      <Box sx={{ 
        mb: 0.5, 
        backgroundColor: '#1a237e',
        borderRadius: '4px',
        p: 1,
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <Typography variant="h5" component="h1" sx={{ 
          color: 'white', 
          fontWeight: 'bold',
          fontSize: '1.2rem',
          m: 0
        }}>
          DONNÉES FOURNISSEURS IFS
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
      
      <Card sx={{ mb: 0.5, bgcolor: '#f5f8ff', border: '1px solid #1a237e' }}>
        <CardContent sx={{ p: 1, '&:last-child': { pb: 1 } }}>
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
                Infos générales fournisseurs
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      <Card sx={{ mb: 0.5, p: 1, bgcolor: '#f5f8ff', border: '1px solid #1a237e' }}>
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
                minWidth: '120px', 
                bgcolor: '#1a237e', 
                '&:hover': { bgcolor: '#303f9f' },
                height: '32px',
                fontWeight: 'bold',
                color: 'white',
                textTransform: 'none',
                fontSize: '0.8rem'
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
                minWidth: '80px', 
                height: '32px',
                fontWeight: 'bold',
                textTransform: 'none',
                fontSize: '0.8rem'
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
                minWidth: '100px', 
                bgcolor: '#1a237e', 
                '&:hover': { bgcolor: '#303f9f' },
                height: '32px',
                fontWeight: 'bold',
                color: 'white',
                textTransform: 'none',
                fontSize: '0.8rem'
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
              mt: 1, 
              p: 2, 
              bgcolor: '#e3f2fd', 
              borderRadius: 1, 
              border: '1px solid #1a237e',
              boxShadow: '0 1px 4px rgba(0,0,0,0.1)'
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

      <Paper elevation={3} sx={{ p: 1, mb: 2, borderRadius: 2, backgroundColor: '#f5f5f5' }}>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
            <CircularProgress />
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
            onEdit={handleEditRow}
            onDelete={handleDeleteRow}
            onView={handleViewRow}
            onDeleteMultiple={handleDeleteMultiple}
          />
        ) : (
          <Typography variant="body1" align="center" sx={{ p: 3 }}>
            Sélectionnez une table pour afficher les données.
          </Typography>
        )}
      </Paper>
      
      {/* Dialogue de visualisation */}
      <Dialog open={viewDialogOpen} onClose={handleViewDialogClose} maxWidth="md" fullWidth disableRestoreFocus>
        <DialogTitle>
          Détails de l'enregistrement
          <IconButton
            aria-label="close"
            onClick={handleViewDialogClose}
            sx={{ position: 'absolute', right: 8, top: 8 }}
          >
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          {currentRow && tableData && (
            <Grid container spacing={2}>
              {tableData.columns.map((column) => (
                <Grid item xs={12} sm={6} key={column.name}>
                  <TextField
                    label={column.label}
                    value={currentRow[column.name] || ''}
                    fullWidth
                    InputProps={{
                      readOnly: true,
                    }}
                    variant="outlined"
                    margin="normal"
                  />
                </Grid>
              ))}
            </Grid>
          )}
        </DialogContent>
      </Dialog>
      
      {/* Dialogue d'édition */}
      <Dialog open={editDialogOpen} onClose={handleEditDialogClose} maxWidth="md" fullWidth disableRestoreFocus>
        <DialogTitle>
          Modifier l'enregistrement
          <IconButton
            aria-label="close"
            onClick={handleEditDialogClose}
            sx={{ position: 'absolute', right: 8, top: 8 }}
          >
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          {currentRow && tableData && (
            <Grid container spacing={2}>
              {tableData.columns.map((column) => (
                <Grid item xs={12} sm={6} key={column.name}>
                  <TextField
                    label={column.label}
                    value={editedValues[column.name] || ''}
                    onChange={(e) => handleInputChange(column.name, e.target.value)}
                    fullWidth
                    variant="outlined"
                    margin="normal"
                  />
                </Grid>
              ))}
            </Grid>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={handleEditDialogClose} color="primary">
            Annuler
          </Button>
          <Button onClick={handleSaveEdit} color="primary" variant="contained">
            Enregistrer
          </Button>
        </DialogActions>
      </Dialog>
      
      {/* Dialogue de suppression */}
      <Dialog open={deleteDialogOpen} onClose={handleDeleteDialogClose} disableRestoreFocus>
        <DialogTitle>Confirmer la suppression</DialogTitle>
        <DialogContent>
          <Typography>
            Êtes-vous sûr de vouloir supprimer cet enregistrement ? Cette action est irréversible.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleDeleteDialogClose} color="primary">
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

export default IfsDataFournisseurs; 