import { ShoppingCart as CommandeAchatIcon, Refresh as RefreshIcon } from '@mui/icons-material';
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
    exportCommandeAchatData,
    loadExportQueries,
    refreshQueriesCache
} from '../services/exportService';

// Page d'export d'une categorie generique de etl_export_queries. Par defaut :
// Commandes d'achat ; reutilisee pour les Immobilisations (cf. App.tsx).
interface ExportCommandeAchatProps {
  category?: string;
  title?: string;
  description?: string;
  fileType?: string;
  icon?: React.ReactNode;
}

const ExportCommandeAchat: React.FC<ExportCommandeAchatProps> = ({
  category = 'Commande Achat',
  title = "Export Commandes d'achat",
  description = "Exportez les commandes d'achat SAP ouvertes (reliquat à livrer) au format de reprise IFS, en ZIP contenant un fichier CSV par table.",
  fileType = 'commande_achat',
  icon = <CommandeAchatIcon sx={{ fontSize: 32, mr: 2, color: '#00897b' }} />,
}) => {
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

  // Chargement des tables disponibles de la catégorie
  const loadTables = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await loadExportQueries(category);
      setAvailableTables(response.queries);

      const tableNames = response.queries.map(q => q.table_name);
      setSelectedTables(tableNames);

    } catch (err) {
      console.error('Erreur lors du chargement des tables:', err);
      setError('Erreur lors du chargement des tables disponibles');
    } finally {
      setLoading(false);
    }
  }, [category]);

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

      console.log('🚀 Début de l\'export Commandes d\'achat avec la configuration:', config);

      await exportCommandeAchatData(config, fileType);
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
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
        {icon}
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          {title}
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
        {description}
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 3 }}>
          {success}
        </Alert>
      )}

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
          <CircularProgress />
        </Box>
      ) : (
        <>
          {availableTables.length === 0 && (
            <Alert severity="info" sx={{ mb: 3 }}>
              Aucune requête d'export n'est encore configurée pour la catégorie « {category} ».
              Ajoutez-en via la page d'administration « Requêtes d'export ».
            </Alert>
          )}

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

export default ExportCommandeAchat;
