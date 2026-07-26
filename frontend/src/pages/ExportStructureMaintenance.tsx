import { AccountTree as StructureIcon, Refresh as RefreshIcon } from '@mui/icons-material';
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
    exportStructureMaintenanceData,
    loadExportQueries,
    refreshQueriesCache
} from '../services/exportService';

const ExportStructureMaintenance: React.FC = () => {
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

  const loadTables = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await loadExportQueries('Structure Maintenance');
      setAvailableTables(response.queries);
      setSelectedTables(response.queries.map(q => q.table_name));
    } catch (err) {
      setError('Erreur lors du chargement des tables disponibles');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTables();
  }, [loadTables]);

  const handleRefreshQueries = async () => {
    try {
      setLoading(true);
      setError(null);
      await refreshQueriesCache();
      await loadTables();
      setSuccess('Cache des requêtes rafraîchi avec succès');
    } catch (err) {
      setError('Erreur lors du rafraîchissement du cache');
    } finally {
      setLoading(false);
    }
  };

  const handleExport = async () => {
    if (selectedTables.length === 0) {
      setError('Veuillez sélectionner au moins une table');
      return;
    }

    try {
      setExporting(true);
      setError(null);
      setSuccess(null);

      await exportStructureMaintenanceData({
        selectedTables,
        format: 'zip',
        includeHeaders,
        includeInactive
      });
      
      setSuccess('Export terminé avec succès! Le fichier a été téléchargé.');
    } catch (err) {
      setError('Erreur lors de l\'export des données');
    } finally {
      setExporting(false);
    }
  };

  const handlePreview = async (tableName: string) => {
    try {
      setPreviewLoading(true);
      setPreviewError(null);
      setPreviewData([]);
    } catch (err) {
      setPreviewError('Erreur lors de la prévisualisation');
    } finally {
      setPreviewLoading(false);
    }
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        <StructureIcon sx={{ fontSize: 32, mr: 2, color: '#00897b' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Export Structure Maintenance
        </Typography>
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={handleRefreshQueries}
          disabled={loading}
          sx={{ ml: 'auto' }}
        >
          Rafraîchir
        </Button>
      </Box>

      <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
        Exportez la structure de maintenance (postes techniques et équipements) en format ZIP contenant des fichiers CSV.
      </Typography>

      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}
      {success && <Alert severity="success" sx={{ mb: 3 }}>{success}</Alert>}

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
                prev.length === availableTables.length ? [] : availableTables.map(t => t.table_name)
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
          {previewData.length > 0 && (
            <ExportPreview
              data={previewData}
              loading={previewLoading}
              error={previewError}
            />
          )}
        </>
      )}
    </Box>
  );
};

export default ExportStructureMaintenance;
