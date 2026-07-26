import React, { useState, useEffect } from 'react';
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
  useMediaQuery,
  Button,
  Tooltip,
  IconButton,
  Menu,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Checkbox,
  FormControlLabel,
  Snackbar,
  Alert
} from '@mui/material';
import {
  FileDownload as ExportIcon,
  Close as CloseIcon
} from '@mui/icons-material';
import ifsTablesService, { IfsTable, TableData, ExportOptions } from '../services/ifsTablesService';
import IfsDataTable from '../components/ifs/IfsDataTable';

const IfsTargetData = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // États
  const [tables, setTables] = useState<IfsTable[]>([]);
  const [selectedTable, setSelectedTable] = useState<string>('');
  const [selectedTableLabel, setSelectedTableLabel] = useState<string>('');
  const [tableData, setTableData] = useState<TableData | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [exporting, setExporting] = useState<boolean>(false);
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(10);
  const [sortField, setSortField] = useState<string>('');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  
  // États pour le menu d'export
  const [exportMenuAnchor, setExportMenuAnchor] = useState<null | HTMLElement>(null);
  const [exportDialogOpen, setExportDialogOpen] = useState<boolean>(false);
  const [exportFormat, setExportFormat] = useState<'csv' | 'excel'>('csv');
  const [selectedFields, setSelectedFields] = useState<string[]>([]);
  const [includeHeaders, setIncludeHeaders] = useState<boolean>(true);
  
  // État pour les notifications
  const [snackbarOpen, setSnackbarOpen] = useState<boolean>(false);
  const [snackbarMessage, setSnackbarMessage] = useState<string>('');
  const [snackbarSeverity, setSnackbarSeverity] = useState<'success' | 'error'>('success');

  // Récupérer la liste des tables IFS disponibles
  useEffect(() => {
    const fetchTables = async () => {
      try {
        setLoading(true);
        const fetchedTables = await ifsTablesService.getTables();
        setTables(fetchedTables);
        
        // Sélectionner la première table par défaut si aucune n'est déjà sélectionnée
        if (fetchedTables.length > 0 && !selectedTable) {
          setSelectedTable(fetchedTables[0].id);
          setSelectedTableLabel(fetchedTables[0].label);
        }
      } catch (error) {
        console.error('Erreur lors de la récupération des tables IFS:', error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchTables();
  }, []);

  // Récupérer les données de la table sélectionnée
  useEffect(() => {
    if (!selectedTable) return;

    const fetchTableData = async () => {
      try {
        setLoading(true);
        const data = await ifsTablesService.getTableData(
          selectedTable,
          page,
          rowsPerPage,
          sortField,
          sortDirection
        );
        setTableData(data);
        
        // Mettre à jour les champs sélectionnés pour l'export
        if (data.columns.length > 0) {
          setSelectedFields(data.columns.map(col => col.name));
        }
      } catch (error) {
        console.error(`Erreur lors de la récupération des données pour la table ${selectedTable}:`, error);
      } finally {
        setLoading(false);
      }
    };

    fetchTableData();
  }, [selectedTable, page, rowsPerPage, sortField, sortDirection]);

  // Gestion des changements de table
  const handleTableChange = (event: any) => {
    const tableId = event.target.value;
    setSelectedTable(tableId);
    
    // Mettre à jour le label de la table sélectionnée
    const selectedTableInfo = tables.find(table => table.id === tableId);
    setSelectedTableLabel(selectedTableInfo?.label || '');
    
    // Réinitialiser la pagination et le tri
    setPage(0);
    setSortField('');
    setSortDirection('asc');
  };

  // Gestion de la pagination
  const handlePageChange = (newPage: number) => {
    setPage(newPage);
  };

  // Gestion du nombre de lignes par page
  const handleRowsPerPageChange = (newRowsPerPage: number) => {
    setRowsPerPage(newRowsPerPage);
    setPage(0);
  };

  // Gestion du tri
  const handleSortChange = (field: string, direction: 'asc' | 'desc') => {
    setSortField(field);
    setSortDirection(direction);
  };

  // Gestion du menu d'export
  const handleExportClick = (event: React.MouseEvent<HTMLElement>) => {
    setExportMenuAnchor(event.currentTarget);
  };

  const handleExportMenuClose = () => {
    setExportMenuAnchor(null);
  };

  const handleExportTypeSelect = (format: 'csv' | 'excel') => {
    setExportFormat(format);
    setExportMenuAnchor(null);
    setExportDialogOpen(true);
  };

  const handleExportDialogClose = () => {
    setExportDialogOpen(false);
  };

  const handleFieldToggle = (field: string) => {
    setSelectedFields(prev => {
      if (prev.includes(field)) {
        return prev.filter(f => f !== field);
      } else {
        return [...prev, field];
      }
    });
  };

  const handleSelectAllFields = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.checked && tableData) {
      setSelectedFields(tableData.columns.map(col => col.name));
    } else {
      setSelectedFields([]);
    }
  };

  // Fonction d'export
  const handleExport = async () => {
    if (!tableData || !selectedTable || selectedFields.length === 0) {
      showSnackbar('Aucun champ sélectionné pour l\'export', 'error');
      return;
    }

    try {
      setExporting(true);      const options: ExportOptions = {
        format: exportFormat,
        includeHeaders: includeHeaders,
        useColumnNames: true,
        filename: `${selectedTable}_${new Date().toISOString().replace(/[:.]/g, '-')}.${exportFormat === 'csv' ? 'csv' : 'xlsx'}`
      };

      const blob = await ifsTablesService.exportTableData(selectedTable, selectedFields, options);
      ifsTablesService.downloadExport(blob, options.filename!);
      
      showSnackbar('Export réussi', 'success');
      setExportDialogOpen(false);
    } catch (error) {
      console.error('Erreur lors de l\'export:', error);
      showSnackbar(`Erreur lors de l'export: ${(error as Error).message}`, 'error');
    } finally {
      setExporting(false);
    }
  };

  // Afficher une notification
  const showSnackbar = (message: string, severity: 'success' | 'error') => {
    setSnackbarMessage(message);
    setSnackbarSeverity(severity);
    setSnackbarOpen(true);
  };

  const handleSnackbarClose = () => {
    setSnackbarOpen(false);
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 3 }}>
        DONNÉES CIBLE IFS
      </Typography>
      
      <Card sx={{ mb: 4 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={8}>
              <FormControl fullWidth sx={{ minWidth: 400, maxWidth: 600, width: '100%' }}>
                <InputLabel>Sélectionner une table</InputLabel>
                <Select
                  value={selectedTable}
                  label="Sélectionner une table"
                  onChange={handleTableChange}
                  disabled={loading}
                >
                  {tables.map((table) => (
                    <MenuItem key={table.id} value={table.id}>
                      {table.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} md={4} sx={{ display: 'flex', justifyContent: isMobile ? 'flex-start' : 'flex-end' }}>
              <Button
                variant="contained"
                color="primary"
                startIcon={<ExportIcon />}
                onClick={handleExportClick}
                disabled={loading || !tableData}
                sx={{ mr: 1 }}
              >
                Exporter
              </Button>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
      
      {loading && <LinearProgress sx={{ mb: 2 }} />}
      
      {selectedTable && tableData && (
        <>
          <Typography variant="h5" sx={{ mt: 4, mb: 2 }}>
            {selectedTableLabel}
          </Typography>
          
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
          />
        </>
      )}

      {/* Menu d'export */}
      <Menu
        anchorEl={exportMenuAnchor}
        open={Boolean(exportMenuAnchor)}
        onClose={handleExportMenuClose}
      >
        <MenuItem onClick={() => handleExportTypeSelect('csv')}>
          Export CSV
        </MenuItem>
        <MenuItem onClick={() => handleExportTypeSelect('excel')}>
          Export Excel
        </MenuItem>
      </Menu>

      {/* Dialogue pour la configuration de l'export */}
      <Dialog open={exportDialogOpen} onClose={handleExportDialogClose} maxWidth="sm" fullWidth disableRestoreFocus>
        <DialogTitle>
          Export {exportFormat.toUpperCase()}
          <IconButton
            aria-label="close"
            onClick={handleExportDialogClose}
            sx={{
              position: 'absolute',
              right: 8,
              top: 8,
              color: theme.palette.grey[500],
            }}
          >
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          <Typography variant="subtitle1" gutterBottom>
            Sélectionnez les champs à exporter
          </Typography>
          
          <FormControlLabel
            control={
              <Checkbox
                checked={tableData ? selectedFields.length === tableData.columns.length : false}
                onChange={handleSelectAllFields}
                indeterminate={tableData ? selectedFields.length > 0 && selectedFields.length < tableData.columns.length : false}
              />
            }
            label="Tout sélectionner"
          />
          
          <Box sx={{ mt: 2, maxHeight: 300, overflow: 'auto' }}>
            {tableData && tableData.columns.map((column) => (
              <FormControlLabel
                key={column.name}
                control={
                  <Checkbox
                    checked={selectedFields.includes(column.name)}
                    onChange={() => handleFieldToggle(column.name)}
                  />
                }
                label={column.label}
              />
            ))}
          </Box>
          
          <FormControlLabel
            control={
              <Checkbox
                checked={includeHeaders}
                onChange={(e) => setIncludeHeaders(e.target.checked)}
              />
            }
            label="Inclure les en-têtes"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleExportDialogClose} color="inherit">
            Annuler
          </Button>
          <Button 
            onClick={handleExport}
            color="primary"
            variant="contained"
            disabled={exporting || selectedFields.length === 0}
          >
            {exporting ? 'Export en cours...' : 'Exporter'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Notification */}
      <Snackbar
        open={snackbarOpen}
        autoHideDuration={6000}
        onClose={handleSnackbarClose}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert onClose={handleSnackbarClose} severity={snackbarSeverity} variant="filled">
          {snackbarMessage}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default IfsTargetData; 