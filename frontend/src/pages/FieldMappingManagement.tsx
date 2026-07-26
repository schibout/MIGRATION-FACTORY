import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Button,
  Snackbar,
  Alert,
  Backdrop,
  CircularProgress,
  Divider,
  SpeedDial,
  SpeedDialIcon,
  SpeedDialAction,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  IconButton,
  useTheme,
  useMediaQuery
} from '@mui/material';
import {
  Add as AddIcon,
  Delete as DeleteIcon,
  CheckCircle as ActivateIcon,
  Cancel as DeactivateIcon,
  Upload as UploadIcon,
  Download as DownloadIcon,
  Close as CloseIcon
} from '@mui/icons-material';

import MappingFilter from '../components/fieldmapping/MappingFilter';
import MappingTable from '../components/fieldmapping/MappingTable';
import MappingForm from '../components/fieldmapping/MappingForm';
import fieldMappingService, {
  FieldMapping,
  TableInfo,
  BulkActionRequest
} from '../services/fieldMappingService';

const FieldMappingManagement: React.FC = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // États pour les données
  const [mappings, setMappings] = useState<FieldMapping[]>([]);
  const [sourceTables, setSourceTables] = useState<TableInfo[]>([]);
  const [targetTables, setTargetTables] = useState<TableInfo[]>([]);
  const [selectedMappings, setSelectedMappings] = useState<number[]>([]);
  const [currentMapping, setCurrentMapping] = useState<FieldMapping | null>(null);
  
  // États pour la pagination et le filtrage
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(25);
  const [totalMappings, setTotalMappings] = useState<number>(0);
  const [filters, setFilters] = useState({
    sourceTable: '',
    targetTable: '',
    status: 'all',
    search: ''
  });
  
  // États pour les UI components
  const [loading, setLoading] = useState<boolean>(false);
  const [showForm, setShowForm] = useState<boolean>(false);
  const [isEditMode, setIsEditMode] = useState<boolean>(false);
  const [snackbar, setSnackbar] = useState<{
    open: boolean;
    message: string;
    severity: 'success' | 'error' | 'info' | 'warning';
  }>({
    open: false,
    message: '',
    severity: 'info'
  });
  const [showDeleteDialog, setShowDeleteDialog] = useState<boolean>(false);
  const [showImportDialog, setShowImportDialog] = useState<boolean>(false);
  const [dialogAction, setDialogAction] = useState<{
    type: 'delete' | 'activate' | 'deactivate';
    ids: number[];
  }>({
    type: 'delete',
    ids: []
  });
  
  // Récupérer les mappings
  const fetchMappings = async () => {
    try {
      setLoading(true);
      const response = await fieldMappingService.getMappings(
        page + 1, // API utilise des pages à partir de 1
        rowsPerPage,
        filters.sourceTable,
        filters.targetTable,
        filters.status,
        filters.search
      );
      setMappings(response.mappings);
      setTotalMappings(response.total);
    } catch (error) {
      showSnackbar('Erreur lors de la récupération des mappings', 'error');
      console.error('Error fetching mappings:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Récupérer les tables source et cible
  const fetchTablesInfo = async () => {
    try {
      setLoading(true);
      const response = await fieldMappingService.getTablesInfo();
      setSourceTables(response.source_tables);
      setTargetTables(response.target_tables);
    } catch (error) {
      showSnackbar('Erreur lors de la récupération des tables', 'error');
      console.error('Error fetching tables info:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Charger les données initiales
  useEffect(() => {
    fetchTablesInfo();
  }, []);
  
  // Rafraîchir les mappings quand les filtres ou la pagination changent
  useEffect(() => {
    fetchMappings();
  }, [page, rowsPerPage, filters]);
  
  // Gérer la sélection d'un mapping
  const handleSelectMapping = (id: number, selected: boolean) => {
    if (selected) {
      setSelectedMappings([...selectedMappings, id]);
    } else {
      setSelectedMappings(selectedMappings.filter(mappingId => mappingId !== id));
    }
  };
  
  // Gérer la sélection de tous les mappings
  const handleSelectAllMappings = (selected: boolean) => {
    if (selected) {
      const allIds = mappings.map(mapping => mapping.id || 0);
      setSelectedMappings(allIds);
    } else {
      setSelectedMappings([]);
    }
  };
  
  // Gérer l'édition d'un mapping
  const handleEditMapping = (id: number) => {
    const mapping = mappings.find(m => m.id === id);
    if (mapping) {
      setCurrentMapping(mapping);
      setIsEditMode(true);
      setShowForm(true);
    }
  };
  
  // Gérer l'ajout d'un nouveau mapping
  const handleAddMapping = () => {
    setCurrentMapping(null);
    setIsEditMode(false);
    setShowForm(true);
  };
  
  // Gérer la suppression d'un mapping
  const handleDeleteMapping = (id: number) => {
    setDialogAction({
      type: 'delete',
      ids: [id]
    });
    setShowDeleteDialog(true);
  };
  
  // Gérer la duplication d'un mapping
  const handleCopyMapping = async (id: number) => {
    try {
      setLoading(true);
      const mapping = await fieldMappingService.getMapping(id);
      
      // Modifier pour indiquer que c'est une copie
      const copyMapping: FieldMapping = {
        ...mapping,
        id: undefined,
        source_field_name: `${mapping.source_field_name}_COPY`,
        target_field_name: `${mapping.target_field_name}_COPY`,
      };
      
      await fieldMappingService.createMapping(copyMapping);
      showSnackbar('Mapping dupliqué avec succès', 'success');
      fetchMappings();
    } catch (error) {
      showSnackbar('Erreur lors de la duplication du mapping', 'error');
      console.error('Error copying mapping:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Gérer l'activation/désactivation d'un mapping
  const handleToggleActive = async (id: number, active: boolean) => {
    try {
      setLoading(true);
      await fieldMappingService.updateMapping(id, { is_active: active });
      showSnackbar(`Mapping ${active ? 'activé' : 'désactivé'} avec succès`, 'success');
      fetchMappings();
    } catch (error) {
      showSnackbar(`Erreur lors de ${active ? 'l\'activation' : 'la désactivation'} du mapping`, 'error');
      console.error('Error toggling mapping:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Confirmer la suppression
  const confirmDelete = async () => {
    try {
      setLoading(true);
      
      if (dialogAction.ids.length === 1) {
        // Suppression simple
        await fieldMappingService.deleteMapping(dialogAction.ids[0]);
        showSnackbar('Mapping supprimé avec succès', 'success');
      } else {
        // Suppression en masse
        const bulkRequest: BulkActionRequest = {
          action: 'delete',
          mapping_ids: dialogAction.ids
        };
        await fieldMappingService.bulkAction(bulkRequest);
        showSnackbar(`${dialogAction.ids.length} mappings supprimés avec succès`, 'success');
      }
      
      setSelectedMappings([]);
      fetchMappings();
    } catch (error) {
      showSnackbar('Erreur lors de la suppression des mappings', 'error');
      console.error('Error deleting mappings:', error);
    } finally {
      setLoading(false);
      setShowDeleteDialog(false);
    }
  };
  
  // Gérer les actions en masse
  const handleBulkAction = async (action: 'delete' | 'activate' | 'deactivate') => {
    if (selectedMappings.length === 0) return;
    
    if (action === 'delete') {
      setDialogAction({
        type: 'delete',
        ids: selectedMappings
      });
      setShowDeleteDialog(true);
      return;
    }
    
    try {
      setLoading(true);
      
      const bulkRequest: BulkActionRequest = {
        action: action === 'activate' ? 'activate' : 'deactivate',
        mapping_ids: selectedMappings
      };
      
      const result = await fieldMappingService.bulkAction(bulkRequest);
      showSnackbar(result.message, 'success');
      
      setSelectedMappings([]);
      fetchMappings();
    } catch (error) {
      showSnackbar(`Erreur lors de ${action === 'activate' ? 'l\'activation' : 'la désactivation'} des mappings`, 'error');
      console.error('Error with bulk action:', error);
    } finally {
      setLoading(false);
    }
  };
    // Gérer l'export des mappings
  const handleExport = async () => {
    try {
      setLoading(true);
      
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `field_mappings_${timestamp}.csv`;
      
      const blob = await fieldMappingService.exportMappings(
        filters.sourceTable,
        filters.targetTable,
        filters.status,
        true // useColumnNames = true
      );
      
      fieldMappingService.downloadExport(blob, filename);
      showSnackbar('Export réussi', 'success');
    } catch (error) {
      showSnackbar('Erreur lors de l\'export des mappings', 'error');
      console.error('Error exporting mappings:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Gérer l'import des mappings
  const handleImport = (file: File) => {
    // Implémentation à venir pour l'upload de fichier
    console.log('Import file:', file);
  };

  // Sauvegarder un mapping (création ou mise à jour)
  const handleSaveMapping = async (data: FieldMapping) => {
    try {
      setLoading(true);
      
      if (isEditMode && data.id) {
        // Mise à jour
        await fieldMappingService.updateMapping(data.id, data);
        showSnackbar('Mapping mis à jour avec succès', 'success');
      } else {
        // Création
        await fieldMappingService.createMapping(data);
        showSnackbar('Mapping créé avec succès', 'success');
      }
      
      fetchMappings();
      handleCloseForm();
    } catch (error) {
      showSnackbar('Erreur lors de la sauvegarde du mapping', 'error');
      console.error('Error saving mapping:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Fermer le formulaire
  const handleCloseForm = () => {
    setShowForm(false);
    setCurrentMapping(null);
  };
  
  // Afficher un message toast
  const showSnackbar = (message: string, severity: 'success' | 'error' | 'info' | 'warning') => {
    setSnackbar({
      open: true,
      message,
      severity
    });
  };
  
  // Fermer le message toast
  const handleCloseSnackbar = () => {
    setSnackbar({
      ...snackbar,
      open: false
    });
  };
  
  return (
    <Box sx={{ 
      width: '100%',
      maxWidth: '100%',
      overflowX: 'hidden'
    }}>
      <Typography variant="h4" sx={{ mb: 3 }}>
        GESTION DES MAPPINGS DE CHAMPS
      </Typography>
      
      <Card sx={{ mb: 4, width: '100%' }}>
        <CardContent>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, width: '100%' }}>
            <Typography variant="h6">Filtres</Typography>
            
            {!isMobile && (
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button
                  variant="contained"
                  color="primary"
                  startIcon={<AddIcon />}
                  onClick={handleAddMapping}
                >
                  Ajouter
                </Button>
                <Button
                  variant="outlined"
                  color="primary"
                  startIcon={<UploadIcon />}
                  onClick={() => setShowImportDialog(true)}
                >
                  Importer
                </Button>
                <Button
                  variant="outlined"
                  color="primary"
                  startIcon={<DownloadIcon />}
                  onClick={handleExport}
                  disabled={loading}
                >
                  Exporter
                </Button>
              </Box>
            )}
          </Box>
          
          <MappingFilter
            onFilter={setFilters}
            loading={loading}
            sourceTables={sourceTables}
            targetTables={targetTables}
          />
        </CardContent>
      </Card>
      
      {selectedMappings.length > 0 && (
        <Card sx={{ mb: 2, width: '100%' }}>
          <CardContent>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
              <Typography variant="body1">
                {selectedMappings.length} mapping(s) sélectionné(s)
              </Typography>
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button
                  variant="outlined"
                  color="primary"
                  startIcon={<ActivateIcon />}
                  onClick={() => handleBulkAction('activate')}
                  disabled={loading}
                >
                  Activer
                </Button>
                <Button
                  variant="outlined"
                  color="primary"
                  startIcon={<DeactivateIcon />}
                  onClick={() => handleBulkAction('deactivate')}
                  disabled={loading}
                >
                  Désactiver
                </Button>
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<DeleteIcon />}
                  onClick={() => handleBulkAction('delete')}
                  disabled={loading}
                >
                  Supprimer
                </Button>
              </Box>
            </Box>
          </CardContent>
        </Card>
      )}
      
      <Box sx={{ width: '100%', overflowX: 'auto' }}>
        <MappingTable
          mappings={mappings}
          selectedMappings={selectedMappings}
          onSelectMapping={handleSelectMapping}
          onSelectAllMappings={handleSelectAllMappings}
          onEditMapping={handleEditMapping}
          onDeleteMapping={handleDeleteMapping}
          onCopyMapping={handleCopyMapping}
          onToggleActive={handleToggleActive}
          onPageChange={setPage}
          onRowsPerPageChange={setRowsPerPage}
          page={page}
          rowsPerPage={rowsPerPage}
          total={totalMappings}
          loading={loading}
        />
      </Box>
      
      {/* FAB pour les actions sur mobile */}
      {isMobile && (
        <SpeedDial
          ariaLabel="Actions rapides"
          sx={{ position: 'fixed', bottom: 16, right: 16 }}
          icon={<SpeedDialIcon />}
        >
          <SpeedDialAction
            icon={<AddIcon />}
            tooltipTitle="Ajouter"
            onClick={handleAddMapping}
          />
          <SpeedDialAction
            icon={<UploadIcon />}
            tooltipTitle="Importer"
            onClick={() => setShowImportDialog(true)}
          />
          <SpeedDialAction
            icon={<DownloadIcon />}
            tooltipTitle="Exporter"
            onClick={handleExport}
          />
        </SpeedDial>
      )}
      
      {/* Dialog de confirmation de suppression */}
      <Dialog
        open={showDeleteDialog}
        onClose={() => setShowDeleteDialog(false)}
        aria-labelledby="alert-dialog-title"
        aria-describedby="alert-dialog-description"
        disableRestoreFocus
      >
        <DialogTitle id="alert-dialog-title">
          Confirmer la suppression
        </DialogTitle>
        <DialogContent>
          <DialogContentText id="alert-dialog-description">
            {dialogAction.ids.length === 1
              ? 'Êtes-vous sûr de vouloir supprimer ce mapping ? Cette action est irréversible.'
              : `Êtes-vous sûr de vouloir supprimer ces ${dialogAction.ids.length} mappings ? Cette action est irréversible.`}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setShowDeleteDialog(false)} color="primary">
            Annuler
          </Button>
          <Button onClick={confirmDelete} color="error" autoFocus>
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>
      
      {/* Dialog pour le formulaire */}
      <Dialog
        open={showForm}
        onClose={handleCloseForm}
        fullWidth
        maxWidth="md"
        disableRestoreFocus
      >
        <DialogContent sx={{ p: 0 }}>
          <Box sx={{ position: 'absolute', top: 8, right: 8, zIndex: 1 }}>
            <IconButton onClick={handleCloseForm} size="small">
              <CloseIcon />
            </IconButton>
          </Box>
          <MappingForm
            initialData={currentMapping || undefined}
            sourceTables={sourceTables}
            targetTables={targetTables}
            onSave={handleSaveMapping}
            onCancel={handleCloseForm}
            isEdit={isEditMode}
          />
        </DialogContent>
      </Dialog>
      
      {/* Backdrop de chargement */}
      <Backdrop
        sx={{ color: '#fff', zIndex: (theme) => theme.zIndex.drawer + 1 }}
        open={loading}
      >
        <CircularProgress color="inherit" />
      </Backdrop>
      
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

export default FieldMappingManagement;