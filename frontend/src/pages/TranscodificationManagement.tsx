import React, { useEffect, useRef, useState } from 'react';
// Import Material-UI components individually
import Alert from '@mui/material/Alert';
import Backdrop from '@mui/material/Backdrop';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogContentText from '@mui/material/DialogContentText';
import DialogTitle from '@mui/material/DialogTitle';
import IconButton from '@mui/material/IconButton';
import Snackbar from '@mui/material/Snackbar';
import SpeedDial from '@mui/material/SpeedDial';
import SpeedDialAction from '@mui/material/SpeedDialAction';
import SpeedDialIcon from '@mui/material/SpeedDialIcon';
import { useTheme } from '@mui/material/styles';
import Typography from '@mui/material/Typography';
import useMediaQuery from '@mui/material/useMediaQuery';
// Import Material-UI icons
import {
  CheckCircle as ActivateIcon,
  Add as AddIcon,
  Close as CloseIcon,
  CloudUpload as CloudUploadIcon,
  Cancel as DeactivateIcon,
  Delete as DeleteIcon,
  Download as DownloadIcon,
  Upload as UploadIcon
} from '@mui/icons-material';

import TranscodificationFilter from '../components/transcodification/TranscodificationFilter';
import TranscodificationForm from '../components/transcodification/TranscodificationForm';
import TranscodificationTable from '../components/transcodification/TranscodificationTable';
import transcodificationService, {
  BulkActionRequest,
  Transcodification
} from '../services/transcodificationService';

const TranscodificationManagement: React.FC = () => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // États pour les données
  const [transcodifications, setTranscodifications] = useState<Transcodification[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [selectedTranscodifications, setSelectedTranscodifications] = useState<number[]>([]);
  const [currentTranscodification, setCurrentTranscodification] = useState<Transcodification | null>(null);
  
  // États pour la pagination et le filtrage
  const [page, setPage] = useState<number>(0);
  const [rowsPerPage, setRowsPerPage] = useState<number>(25);
  const [totalTranscodifications, setTotalTranscodifications] = useState<number>(0);
  const [filters, setFilters] = useState({
    category: '',
    sourceSystem: '',
    targetSystem: '',
    status: 'all',
    search: ''
  });
  
  // États pour les UI components
  const [loading, setLoading] = useState<boolean>(false);
  const [showForm, setShowForm] = useState<boolean>(false);
  const [showDeleteDialog, setShowDeleteDialog] = useState<boolean>(false);
  const [showImportDialog, setShowImportDialog] = useState<boolean>(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isEditMode, setIsEditMode] = useState<boolean>(false);
  const [dialogAction, setDialogAction] = useState<{
    type: 'delete' | 'activate' | 'deactivate';
    ids: number[];
  }>({
    type: 'delete',
    ids: []
  });
  const [snackbar, setSnackbar] = useState<{
    open: boolean;
    message: string;
    severity: 'success' | 'error' | 'info' | 'warning';
  }>({
    open: false,
    message: '',
    severity: 'info'
  });
  
  // Ref pour l'input de fichier
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  // Récupérer les transcodifications
  const fetchTranscodifications = async () => {
    try {
      setLoading(true);
      const response = await transcodificationService.getTranscodifications(
        page + 1, // API utilise des pages à partir de 1
        rowsPerPage,
        filters.category,
        filters.sourceSystem,
        filters.targetSystem,
        filters.status,
        filters.search
      );
      setTranscodifications(response.transcodifications);
      setTotalTranscodifications(response.total);
    } catch (error) {
      showSnackbar('Erreur lors de la récupération des transcodifications', 'error');
      console.error('Error fetching transcodifications:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Récupérer les catégories disponibles
  const fetchCategories = async () => {
    try {
      setLoading(true);
      const categoryList = await transcodificationService.getCategories();
      setCategories(categoryList);
    } catch (error) {
      showSnackbar('Erreur lors de la récupération des catégories', 'error');
      console.error('Error fetching categories:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Charger les données initiales
  useEffect(() => {
    fetchCategories();
  }, []);
  
  // Rafraîchir les transcodifications quand les filtres ou la pagination changent
  useEffect(() => {
    fetchTranscodifications();
  }, [page, rowsPerPage, filters]);
  
  // Gérer le changement de filtres
  const handleFilterChange = (newFilters: typeof filters) => {
    setFilters(newFilters);
    setPage(0); // Retour à la première page lors du changement de filtres
  };
  
  // Gérer la pagination
  const handlePageChange = (newPage: number) => {
    setPage(newPage);
  };
  
  // Gérer le changement du nombre de lignes par page
  const handleRowsPerPageChange = (newRowsPerPage: number) => {
    setRowsPerPage(newRowsPerPage);
    setPage(0);
  };
  
  // Gérer la sélection d'une transcodification
  const handleSelectTranscodification = (id: number, selected: boolean) => {
    if (selected) {
      setSelectedTranscodifications([...selectedTranscodifications, id]);
    } else {
      setSelectedTranscodifications(selectedTranscodifications.filter(tid => tid !== id));
    }
  };
  
  // Gérer la sélection de toutes les transcodifications
  const handleSelectAllTranscodifications = (selected: boolean) => {
    if (selected) {
      const allIds = transcodifications.map(t => t.id || 0);
      setSelectedTranscodifications(allIds);
    } else {
      setSelectedTranscodifications([]);
    }
  };
  
  // Gérer l'édition d'une transcodification
  const handleEditTranscodification = (id: number) => {
    const transcodification = transcodifications.find(t => t.id === id);
    if (transcodification) {
      setCurrentTranscodification(transcodification);
      setIsEditMode(true);
      setShowForm(true);
    }
  };
  
  // Gérer l'ajout d'une nouvelle transcodification
  const handleAddTranscodification = () => {
    setCurrentTranscodification(null);
    setIsEditMode(false);
    setShowForm(true);
  };
  
  // Gérer la suppression d'une transcodification
  const handleDeleteTranscodification = (id: number) => {
    setDialogAction({
      type: 'delete',
      ids: [id]
    });
    setShowDeleteDialog(true);
  };
  
  // Gérer la duplication d'une transcodification
  const handleDuplicateTranscodification = async (id: number) => {
    try {
      setLoading(true);
      const transcodification = await transcodificationService.getTranscodification(id);
      
      // Modifier pour indiquer que c'est une copie
      const copyTranscodification: Transcodification = {
        ...transcodification,
        id: undefined,
        source_value: `${transcodification.source_value}_COPY`,
        target_value: `${transcodification.target_value}_COPY`,
      };
      
      await transcodificationService.createTranscodification(copyTranscodification);
      showSnackbar('Transcodification dupliquée avec succès', 'success');
      fetchTranscodifications();
    } catch (error) {
      showSnackbar('Erreur lors de la duplication de la transcodification', 'error');
      console.error('Error copying transcodification:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Gérer l'activation/désactivation d'une transcodification
  const handleToggleActive = async (id: number, active: boolean) => {
    try {
      setLoading(true);
      await transcodificationService.updateTranscodification(id, { is_active: active });
      showSnackbar(`Transcodification ${active ? 'activée' : 'désactivée'} avec succès`, 'success');
      fetchTranscodifications();
    } catch (error) {
      showSnackbar(`Erreur lors de ${active ? 'l\'activation' : 'la désactivation'} de la transcodification`, 'error');
      console.error('Error toggling transcodification:', error);
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
        await transcodificationService.deleteTranscodification(dialogAction.ids[0]);
        showSnackbar('Transcodification supprimée avec succès', 'success');
      } else {
        // Suppression en masse
        const bulkRequest: BulkActionRequest = {
          action: 'delete',
          transcodification_ids: dialogAction.ids
        };
        await transcodificationService.bulkAction(bulkRequest);
        showSnackbar(`${dialogAction.ids.length} transcodifications supprimées avec succès`, 'success');
      }
      
      setSelectedTranscodifications([]);
      fetchTranscodifications();
    } catch (error) {
      showSnackbar('Erreur lors de la suppression des transcodifications', 'error');
      console.error('Error deleting transcodifications:', error);
    } finally {
      setLoading(false);
      setShowDeleteDialog(false);
    }
  };
  
  // Gérer les actions en masse
  const handleBulkAction = async (action: 'delete' | 'activate' | 'deactivate' | 'duplicate') => {
    if (selectedTranscodifications.length === 0) return;
    
    if (action === 'delete') {
      setDialogAction({
        type: 'delete',
        ids: selectedTranscodifications
      });
      setShowDeleteDialog(true);
      return;
    }
    
    try {
      setLoading(true);
      
      const bulkRequest: BulkActionRequest = {
        action,
        transcodification_ids: selectedTranscodifications
      };
      
      const response = await transcodificationService.bulkAction(bulkRequest);
      
      let message = '';
      switch (action) {
        case 'activate':
          message = 'Transcodifications activées avec succès';
          break;
        case 'deactivate':
          message = 'Transcodifications désactivées avec succès';
          break;
        case 'duplicate':
          message = 'Transcodifications dupliquées avec succès';
          break;
      }
      
      showSnackbar(message, 'success');
      setSelectedTranscodifications([]);
      fetchTranscodifications();
    } catch (error) {
      showSnackbar(`Erreur lors de l'action en masse`, 'error');
      console.error('Error performing bulk action:', error);
    } finally {
      setLoading(false);
    }
  };
    // Gérer l'exportation des transcodifications
  const handleExport = async () => {
    try {
      setLoading(true);
      
      // Utiliser un nom de fichier qui contient simplement 'transcodifications'
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `transcodifications_${timestamp}.csv`;
      
      const blob = await transcodificationService.exportTranscodifications(
        filters.category,
        filters.sourceSystem,
        filters.targetSystem,
        filters.status,
        true // useColumnNames = true
      );
      
      // Télécharger le fichier
      transcodificationService.downloadExport(blob, filename);
      
      showSnackbar('Export réalisé avec succès', 'success');
    } catch (error) {
      showSnackbar('Erreur lors de l\'export', 'error');
      console.error('Error exporting transcodifications:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Gérer la sélection de fichier
  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // Vérifier que c'est un fichier CSV
      if (!file.name.endsWith('.csv')) {
        showSnackbar('Veuillez sélectionner un fichier CSV', 'error');
        return;
      }
      setSelectedFile(file);
    }
  };
  
  // Gérer l'ouverture du dialog d'import
  const handleOpenImportDialog = () => {
    setSelectedFile(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
    setShowImportDialog(true);
  };
  
  // Gérer la fermeture du dialog d'import
  const handleCloseImportDialog = () => {
    setShowImportDialog(false);
    setSelectedFile(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };
  
  // Gérer l'import de transcodifications
  const handleImport = async () => {
    if (!selectedFile) {
      showSnackbar('Veuillez sélectionner un fichier', 'error');
      return;
    }
    
    try {
      setLoading(true);
      const response = await transcodificationService.importTranscodifications(selectedFile);
      
      if (response.errors && response.errors.length > 0) {
        showSnackbar(`${response.message}. ${response.errors.length} erreur(s) détectée(s)`, 'warning');
        console.warn('Import errors:', response.errors);
      } else {
        showSnackbar(response.message || 'Import réussi', 'success');
      }
      
      handleCloseImportDialog();
      fetchTranscodifications();
    } catch (error) {
      showSnackbar('Erreur lors de l\'import des transcodifications', 'error');
      console.error('Error importing transcodifications:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Gérer la sauvegarde d'une transcodification (création ou mise à jour)
  const handleSaveTranscodification = async (data: Transcodification) => {
    try {
      setLoading(true);
      
      if (isEditMode && data.id) {
        // Mise à jour
        await transcodificationService.updateTranscodification(data.id, data);
        showSnackbar('Transcodification mise à jour avec succès', 'success');
      } else {
        // Création
        await transcodificationService.createTranscodification(data);
        showSnackbar('Transcodification créée avec succès', 'success');
      }
      
      fetchTranscodifications();
    } catch (error) {
      showSnackbar('Erreur lors de la sauvegarde de la transcodification', 'error');
      console.error('Error saving transcodification:', error);
    } finally {
      setLoading(false);
    }
  };
  
  // Fermer le formulaire
  const handleCloseForm = () => {
    setShowForm(false);
    setCurrentTranscodification(null);
  };
  
  // Afficher une notification
  const showSnackbar = (message: string, severity: 'success' | 'error' | 'info' | 'warning') => {
    setSnackbar({
      open: true,
      message,
      severity
    });
  };
  
  // Fermer la notification
  const handleCloseSnackbar = () => {
    setSnackbar({
      ...snackbar,
      open: false
    });
  };
  
  // Actions pour le SpeedDial
  const actions = [
    { icon: <AddIcon />, name: 'Ajouter', action: handleAddTranscodification },
    { icon: <UploadIcon />, name: 'Importer', action: handleOpenImportDialog },
    { icon: <DownloadIcon />, name: 'Exporter', action: handleExport }
  ];
  
  return (
    <Box sx={{ 
      width: '100%',
      maxWidth: '100%',
      overflowX: 'hidden' 
    }}>
      {/* En-tête */}
      <Box sx={{ mb: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
        <Typography variant="h5" component="h1">
          Gestion des Transcodifications
        </Typography>
        
        {!isMobile && (
          <Box>
            <Button
              variant="contained"
              startIcon={<AddIcon />}
              onClick={handleAddTranscodification}
              sx={{ mr: 1 }}
            >
              Ajouter
            </Button>
            <Button
              variant="outlined"
              startIcon={<UploadIcon />}
              onClick={handleOpenImportDialog}
              sx={{ mr: 1 }}
            >
              Importer
            </Button>
            <Button
              variant="outlined"
              startIcon={<DownloadIcon />}
              onClick={handleExport}
            >
              Exporter
            </Button>
          </Box>
        )}
      </Box>
      
      {/* Filtres */}
      <Card sx={{ mb: 2, width: '100%' }}>
        <CardContent>
          <TranscodificationFilter onFilterChange={handleFilterChange} />
        </CardContent>
      </Card>
      
      {/* Actions en masse */}
      {selectedTranscodifications.length > 0 && (
        <Card sx={{ mb: 2, width: '100%' }}>
          <CardContent sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
            <Typography variant="body2" sx={{ mr: 2 }}>
              {selectedTranscodifications.length} élément(s) sélectionné(s)
            </Typography>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button
                size="small"
                startIcon={<ActivateIcon />}
                onClick={() => handleBulkAction('activate')}
                sx={{ mr: 1 }}
              >
                Activer
              </Button>
              <Button
                size="small"
                startIcon={<DeactivateIcon />}
                onClick={() => handleBulkAction('deactivate')}
                sx={{ mr: 1 }}
              >
                Désactiver
              </Button>
              <Button
                size="small"
                startIcon={<DeleteIcon />}
                color="error"
                onClick={() => handleBulkAction('delete')}
              >
                Supprimer
              </Button>
            </Box>
          </CardContent>
        </Card>
      )}
      
      {/* Tableau des transcodifications */}
      <Box sx={{ width: '100%', overflowX: 'auto' }}>
        <TranscodificationTable
          transcodifications={transcodifications}
          totalItems={totalTranscodifications}
          page={page}
          rowsPerPage={rowsPerPage}
          selectedItems={selectedTranscodifications}
          onPageChange={handlePageChange}
          onRowsPerPageChange={handleRowsPerPageChange}
          onSelectAll={handleSelectAllTranscodifications}
          onSelectItem={handleSelectTranscodification}
          onEditItem={handleEditTranscodification}
          onDeleteItem={handleDeleteTranscodification}
          onDuplicateItem={handleDuplicateTranscodification}
          onToggleActive={handleToggleActive}
        />
      </Box>
      
      {/* SpeedDial pour mobile */}
      {isMobile && (
        <SpeedDial
          ariaLabel="Actions rapides"
          sx={{ position: 'fixed', bottom: 16, right: 16 }}
          icon={<SpeedDialIcon />}
        >
          {actions.map((action) => (
            <SpeedDialAction
              key={action.name}
              icon={action.icon}
              tooltipTitle={action.name}
              onClick={action.action}
            />
          ))}
        </SpeedDial>
      )}
      
      {/* Dialog de confirmation de suppression */}
      <Dialog
        open={showDeleteDialog}
        onClose={() => setShowDeleteDialog(false)}
        disableRestoreFocus
      >
        <DialogTitle>
          Confirmer la suppression
        </DialogTitle>
        <DialogContent>
          <DialogContentText>
            {dialogAction.ids.length === 1
              ? 'Êtes-vous sûr de vouloir supprimer cette transcodification?'
              : `Êtes-vous sûr de vouloir supprimer ces ${dialogAction.ids.length} transcodifications?`}
            Cette action est irréversible.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setShowDeleteDialog(false)}>Annuler</Button>
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
          <TranscodificationForm
            initialData={currentTranscodification || undefined}
            categories={categories}
            onSave={handleSaveTranscodification}
            onCancel={handleCloseForm}
            isEdit={isEditMode}
          />
        </DialogContent>
      </Dialog>
      
      {/* Dialog d'import */}
      <Dialog
        open={showImportDialog}
        onClose={handleCloseImportDialog}
        fullWidth
        maxWidth="sm"
        disableRestoreFocus
      >
        <DialogTitle>
          Importer des transcodifications
        </DialogTitle>
        <DialogContent>
          <DialogContentText sx={{ mb: 2 }}>
            Sélectionnez un fichier CSV contenant les transcodifications à importer.
            Le fichier doit contenir les colonnes suivantes : category, source_system, target_system, source_value, target_value, description, is_active.
          </DialogContentText>
          
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv"
            style={{ display: 'none' }}
            onChange={handleFileSelect}
          />
          
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <Button
              variant="outlined"
              startIcon={<CloudUploadIcon />}
              onClick={() => fileInputRef.current?.click()}
              fullWidth
            >
              Sélectionner un fichier CSV
            </Button>
            
            {selectedFile && (
              <Card variant="outlined">
                <CardContent>
                  <Typography variant="body2" color="text.secondary">
                    Fichier sélectionné :
                  </Typography>
                  <Typography variant="body1" sx={{ fontWeight: 'medium' }}>
                    {selectedFile.name}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {(selectedFile.size / 1024).toFixed(2)} KB
                  </Typography>
                </CardContent>
              </Card>
            )}
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseImportDialog}>Annuler</Button>
          <Button 
            onClick={handleImport} 
            variant="contained"
            disabled={!selectedFile}
            startIcon={<UploadIcon />}
          >
            Importer
          </Button>
        </DialogActions>
      </Dialog>
      
      {/* Backdrop de chargement */}
      <Backdrop
        sx={{ color: '#fff', zIndex: (theme) => theme.zIndex.drawer + 1 }}
        open={loading}
      >
        <CircularProgress color="inherit" />
      </Backdrop>
      
      {/* Snackbar de notification */}
      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
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

export default TranscodificationManagement;