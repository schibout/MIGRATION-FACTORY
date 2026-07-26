import { Business as FournisseurIcon, Refresh as RefreshIcon } from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    CircularProgress,
    Typography
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import ExportButton from '../components/export/ExportButton';
import ExportConfiguration from '../components/export/ExportConfiguration';
import ExportPreview from '../components/export/ExportPreview';
import TableSelector from '../components/export/TableSelector';
import {
    ExportQuery,
    exportSupplierData,
    loadExportQueries,
    refreshQueriesCache
} from '../services/exportService';

const ExportFournisseurs: React.FC = () => {
  const [includeHeaders, setIncludeHeaders] = useState(true);
  const [includeInactive, setIncludeInactive] = useState(false);
  const [selectedTables, setSelectedTables] = useState<string[]>([]);
  const [availableTables, setAvailableTables] = useState<ExportQuery[]>([]);
  const [loadingTables, setLoadingTables] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [exportSuccess, setExportSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Charger les tables disponibles au montage du composant
  useEffect(() => {
    const loadTables = async () => {
      try {
        setLoadingTables(true);
        const data = await loadExportQueries('supplier');
        setAvailableTables(data.queries);
        
        // Sélectionner quelques tables par défaut
        const defaultTables = data.queries
          .filter(q => ['SUPPLIER', 'SUPPLIER_INFO_GENERAL', 'COMM_METHOD'].includes(q.table_name))
          .map(q => q.table_name);
        setSelectedTables(defaultTables);
        
      } catch (error: any) {
        console.error('❌ Erreur lors du chargement des tables:', error);
        setError('Impossible de charger la liste des tables d\'export');
      } finally {
        setLoadingTables(false);
      }
    };

    loadTables();
  }, []);

  // Fonctions mémorisées avec useCallback pour éviter les re-renders
  const handleTableSelection = useCallback((tableName: string) => {
    setSelectedTables(prev => 
      prev.includes(tableName)
        ? prev.filter(t => t !== tableName)
        : [...prev, tableName]
    );
  }, []);

  const handleSelectAllTables = useCallback(() => {
    const allTableNames = availableTables.map(t => t.table_name);
    setSelectedTables(prev => 
      prev.length === allTableNames.length ? [] : allTableNames
    );
  }, [availableTables]);

  const handleRefreshTables = useCallback(async () => {
    try {
      setLoadingTables(true);
      await refreshQueriesCache();
      const data = await loadExportQueries('supplier');
      setAvailableTables(data.queries);
      setError(null);
    } catch (error: any) {
      console.error('❌ Erreur lors du rafraîchissement:', error);
      setError('Impossible de rafraîchir la liste des tables');
    } finally {
      setLoadingTables(false);
    }
  }, []);

  const handleIncludeHeadersChange = useCallback((include: boolean) => {
    setIncludeHeaders(include);
  }, []);

  const handleIncludeInactiveChange = useCallback((include: boolean) => {
    setIncludeInactive(include);
  }, []);


  const handleExport = useCallback(async () => {
    if (selectedTables.length === 0) {
      setError('Veuillez sélectionner au moins une table à exporter');
      return;
    }

    setExporting(true);
    setExportSuccess(false);
    setError(null);

    try {
      // Configuration de l'export avec toutes les tables sélectionnées
      const exportConfig = {
        selectedTables,
        includeHeaders,
        includeInactive
      };
      
      console.log('📋 Configuration d\'export:', exportConfig);
      
      // Appeler le service d'export via l'API backend (téléchargement automatique)
      const result = await exportSupplierData(exportConfig);
      
      console.log('✅ Export terminé avec succès:', result);
      
      if (result.success) {
        setExportSuccess(true);
        console.log(`📦 Fichier téléchargé: ${result.filename}`);
        console.log(`📊 ${result.tablesCount} tables exportées, ${result.sizeBytes} bytes`);
      } else {
        setError('Export échoué - voir la console pour plus de détails');
      }
      
    } catch (error: any) {
      console.error('❌ Erreur lors de l\'export:', error);
      setError(error.message || 'Erreur lors de l\'export des données');
    } finally {
      setExporting(false);
    }
  }, [selectedTables, includeHeaders, includeInactive]);

  // Affichage de chargement initial
  if (loadingTables) {
    return (
      <Box sx={{ p: 3, maxWidth: 800, mx: 'auto', textAlign: 'center' }}>
        <CircularProgress />
        <Typography variant="body1" sx={{ mt: 2 }}>
          Chargement des tables d'export...
        </Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3, maxWidth: 800, mx: 'auto' }}>
      {/* En-tête */}
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 4 }}>
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          <FournisseurIcon sx={{ fontSize: 40, color: '#3f51b5', mr: 2 }} />
          <Box>
            <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
              Export Fournisseurs
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Exportez les données des fournisseurs dans le format de votre choix
            </Typography>
          </Box>
        </Box>
        
        {/* Bouton de rafraîchissement */}
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={handleRefreshTables}
          disabled={loadingTables}
          size="small"
        >
          Actualiser
        </Button>
      </Box>

      {/* Alertes */}
      {exportSuccess && (
        <Alert severity="success" sx={{ mb: 3 }} onClose={() => setExportSuccess(false)}>
          Export terminé avec succès ! Le fichier a été téléchargé.
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Information sur les tables chargées */}
      <Alert severity="info" sx={{ mb: 3 }}>
        {availableTables.length} tables d'export disponibles (chargées dynamiquement depuis la base de données)
      </Alert>

      {/* Configuration de l'export */}
      <ExportConfiguration
        includeHeaders={includeHeaders}
        includeInactive={includeInactive}
        onIncludeHeadersChange={handleIncludeHeadersChange}
        onIncludeInactiveChange={handleIncludeInactiveChange}
      />

      {/* Sélection des tables - maintenant dynamique */}
      <TableSelector
        selectedTables={selectedTables}
        availableTables={availableTables}
        onTableSelection={handleTableSelection}
        onSelectAll={handleSelectAllTables}
      />

      {/* Aperçu de l'export */}
      <ExportPreview
        selectedTables={selectedTables}
        availableTables={availableTables}
        includeHeaders={includeHeaders}
      />

      {/* Bouton d'export */}
      <ExportButton
        selectedTables={selectedTables}
        exporting={exporting}
        onExport={handleExport}
      />
    </Box>
  );
};

export default ExportFournisseurs; 