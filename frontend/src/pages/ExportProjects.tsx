import { Assignment as ProjectIcon, Refresh as RefreshIcon } from '@mui/icons-material';
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
  exportProjectsData,
  loadExportQueries,
  refreshQueriesCache
} from '../services/exportService';

const ExportProjects: React.FC = () => {
  const [includeHeaders, setIncludeHeaders] = useState(true);
  const [includeInactive, setIncludeInactive] = useState(false);
  const [selectedTables, setSelectedTables] = useState<string[]>([]);
  const [availableTables, setAvailableTables] = useState<ExportQuery[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [previewData, setPreviewData] = useState<any[]>([]);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState<string | null>(null);

  // Chargement des tables disponibles
  const loadTables = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await loadExportQueries('project');
      setAvailableTables(response.queries);
      
      // Sélectionner toutes les tables par défaut
      const tableNames = response.queries.map(q => q.table_name);
      setSelectedTables(tableNames);
      
    } catch (err) {
      console.error('Erreur lors du chargement des tables:', err);
      setError('Erreur lors du chargement des tables disponibles');
    } finally {
      setLoading(false);
    }
  }, []);

  // Chargement initial
  useEffect(() => {
    loadTables();
  }, [loadTables]);

  // Fonction pour rafraîchir le cache des requêtes
  const handleRefreshQueries = async () => {
    try {
      setLoading(true);
      setError(null);
      await refreshQueriesCache();
      await loadTables();
      setSuccess('Cache des requêtes rafraîchi avec succès');
    } catch (err) {
      console.error('Erreur lors du rafraîchissement:', err);
      setError('Erreur lors du rafraîchissement du cache');
    } finally {
      setLoading(false);
    }
  };


  // Fonction d'export
  const handleExport = async () => {
    if (selectedTables.length === 0) {
      setError('Veuillez sélectionner au moins une table');
      return;
    }

    try {
      setExporting(true);
      setError(null);
      setSuccess(null);

      const config = {
        selectedTables,
        format: 'zip',
        includeHeaders,
        includeInactive
      };

      console.log('🚀 Début de l\'export projets avec la configuration:', config);

      const response = await exportProjectsData(config);
      console.log('✅ Export terminé avec succès');
      
      setSuccess('Export terminé avec succès! Le fichier a été téléchargé.');
      
    } catch (err) {
      console.error('❌ Erreur lors de l\'export:', err);
      setError('Erreur lors de l\'export des données');
    } finally {
      setExporting(false);
    }
  };

  // Fonction de prévisualisation
  const handlePreview = async (tableName: string) => {
    try {
      setPreviewLoading(true);
      setPreviewError(null);
      
      // Ici vous pouvez implémenter la prévisualisation si nécessaire
      console.log(`Prévisualisation de la table: ${tableName}`);
      setPreviewData([]);
      
    } catch (err) {
      console.error('Erreur lors de la prévisualisation:', err);
      setPreviewError('Erreur lors de la prévisualisation');
    } finally {
      setPreviewLoading(false);
    }
  };



  return (
    <Box sx={{ p: 3 }}>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        mb={3}
        flexWrap="wrap"
        gap={2}
      >
        <Box display="flex" alignItems="center" gap={2}>
          <ProjectIcon sx={{ fontSize: 40, color: '#673ab7' }} />
          <Box>
            <Typography variant="h4" component="h1" gutterBottom>
              Export des Projets
            </Typography>
            <Typography variant="body1" color="text.secondary">
              Exportez les données des projets en format ZIP
            </Typography>
          </Box>
        </Box>
        
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={handleRefreshQueries}
          disabled={loading}
        >
          Rafraîchir
        </Button>
      </Box>

      {/* Messages d'erreur et de succès */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 3 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
          <CircularProgress />
        </Box>
      ) : (
        <>
          <TableSelector
            availableTables={availableTables}
            selectedTables={selectedTables}
            onTableSelection={(tableName: string) => {
              setSelectedTables(prev => 
                prev.includes(tableName) 
                  ? prev.filter(name => name !== tableName)
                  : [...prev, tableName]
              );
            }}
            onSelectAll={() => {
              setSelectedTables(prev => 
                prev.length === availableTables.length 
                  ? []
                  : availableTables.map(q => q.table_name)
              );
            }}
          />

          <ExportConfiguration
            includeHeaders={includeHeaders}
            onIncludeHeadersChange={setIncludeHeaders}
            includeInactive={includeInactive}
            onIncludeInactiveChange={setIncludeInactive}
            showIncludeInactive={false}
          />

          <ExportButton
            selectedTables={selectedTables}
            exporting={exporting}
            onExport={handleExport}
          />
        </>
      )}

      {/* Prévisualisation des données */}
      {previewData.length > 0 && (
        <ExportPreview
          data={previewData}
          loading={previewLoading}
          error={previewError}
        />
      )}
    </Box>
  );
};

export default ExportProjects;
