import { Download as DownloadIcon } from '@mui/icons-material';
import {
    Box,
    Button,
    CircularProgress,
    Typography
} from '@mui/material';
import React from 'react';

interface ExportButtonProps {
  selectedTables?: string[];
  selectedTablesCount?: number;
  exporting: boolean;
  onExport: () => void;
}

const ExportButton: React.FC<ExportButtonProps> = ({
  selectedTables,
  selectedTablesCount,
  exporting,
  onExport
}) => {
  // Détermine le nombre de tables sélectionnées
  const tableCount = selectedTablesCount ?? selectedTables?.length ?? 0;
  
  const getButtonText = () => {
    if (exporting) return 'Export en cours...';
    if (tableCount === 0) return 'Sélectionnez au moins une table';
    return `Exporter ${tableCount} table(s) en ZIP`;
  };

  return (
    <>
      <Box sx={{ display: 'flex', justifyContent: 'center' }}>
        <Button
          variant="contained"
          size="large"
          startIcon={exporting ? <CircularProgress size={20} color="inherit" /> : <DownloadIcon />}
          onClick={onExport}
          disabled={exporting || tableCount === 0}
          sx={{
            minWidth: 200,
            py: 1.5,
            fontSize: '1.1rem',
            fontWeight: 600
          }}
        >
          {getButtonText()}
        </Button>
      </Box>

      {/* Informations additionnelles */}
      <Box sx={{ mt: 4, p: 2, backgroundColor: 'grey.50', borderRadius: 1 }}>
        <Typography variant="body2" color="text.secondary">
          <strong>Note :</strong> L'export peut prendre quelques instants selon la quantité de données. 
          Le fichier sera automatiquement téléchargé une fois l'export terminé.
        </Typography>
      </Box>
    </>
  );
};

export default ExportButton; 