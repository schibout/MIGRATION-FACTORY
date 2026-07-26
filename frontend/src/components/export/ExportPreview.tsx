import {
    Box,
    Card,
    CardContent,
    Chip,
    Divider,
    Grid,
    Typography
} from '@mui/material';
import React from 'react';
import { ExportQuery } from '../../services/exportService';

interface ExportPreviewProps {
  selectedTables: string[];
  availableTables: ExportQuery[];
  includeHeaders: boolean;
}

const ExportPreview: React.FC<ExportPreviewProps> = ({
  selectedTables,
  availableTables,
  includeHeaders
}) => {
  // Créer un map pour un accès rapide aux informations des tables
  const tableInfoMap = React.useMemo(() => {
    const map: Record<string, ExportQuery> = {};
    availableTables.forEach(table => {
      map[table.table_name] = table;
    });
    return map;
  }, [availableTables]);

  // Grouper les tables sélectionnées par catégorie
  const selectedTablesByCategory = React.useMemo(() => {
    const grouped: Record<string, ExportQuery[]> = {};
    selectedTables.forEach(tableName => {
      const tableInfo = tableInfoMap[tableName];
      if (tableInfo) {
        if (!grouped[tableInfo.category]) {
          grouped[tableInfo.category] = [];
        }
        grouped[tableInfo.category].push(tableInfo);
      }
    });
    return grouped;
  }, [selectedTables, tableInfoMap]);

  const categoryColors: Record<string, string> = {
    'supplier': '#2196f3',
    'payment': '#4caf50',
    'tax': '#ff9800',
    'communication': '#9c27b0',
    'contact': '#607d8b'
  };

  return (
    <Card sx={{ mb: 3 }}>
      <CardContent>
        <Typography variant="h6" sx={{ mb: 2 }}>
          Aperçu de l'export
        </Typography>
        
        <Grid container spacing={2}>
          <Grid item xs={6} sm={3}>
            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="primary">
                {selectedTables.length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Tables sélectionnées
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={6} sm={3}>
            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="secondary">
                {Object.keys(selectedTablesByCategory).length}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Catégories
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={6} sm={3}>
            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="success.main">
                ZIP
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Format
              </Typography>
            </Box>
          </Grid>
          <Grid item xs={6} sm={3}>
            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="h4" color="info.main">
                {includeHeaders ? '✓' : '✗'}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                En-têtes
              </Typography>
            </Box>
          </Grid>
        </Grid>

        <Divider sx={{ my: 2 }} />

        <Typography variant="body2" color="text.secondary" gutterBottom>
          <strong>Nom du fichier :</strong> [CATÉGORIE]_export_[HORODATAGE].zip
        </Typography>
        <Typography variant="caption" color="text.secondary" gutterBottom>
          <strong>Contenu :</strong> Un fichier CSV par table (ex: SUPPLIER.csv, COMM_METHOD.csv, etc.) + fichier de résumé
        </Typography>
        
        {selectedTables.length > 0 && (
          <Box sx={{ mt: 2 }}>
            <Typography variant="body2" fontWeight="medium" gutterBottom>
              Tables à exporter par catégorie :
            </Typography>
            <Box sx={{ maxHeight: 200, overflow: 'auto' }}>
              {Object.entries(selectedTablesByCategory).map(([category, tables]) => (
                <Box key={category} sx={{ mb: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    <Chip 
                      label={category.toUpperCase()} 
                      size="small" 
                      sx={{ 
                        backgroundColor: categoryColors[category] || '#757575',
                        color: 'white',
                        fontWeight: 'bold',
                        fontSize: '0.7rem'
                      }}
                    />
                  </Box>
                  {(tables as ExportQuery[]).map((table) => (
                    <Typography 
                      key={table.table_name} 
                      variant="caption" 
                      display="block" 
                      color="text.secondary"
                      sx={{ ml: 1, mb: 0.5 }}
                    >
                      • {table.display_name} ({table.table_name})
                    </Typography>
                  ))}
                </Box>
              ))}
            </Box>
          </Box>
        )}

        {selectedTables.length === 0 && (
          <Box sx={{ mt: 2, textAlign: 'center', py: 2 }}>
            <Typography variant="body2" color="text.secondary">
              Aucune table sélectionnée pour l'export
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

export default ExportPreview; 