import {
  Box,
  Card,
  CardContent,
  Checkbox,
  FormControlLabel,
  Grid,
  Typography
} from '@mui/material';
import React from 'react';

interface ExportConfigurationProps {
  includeHeaders: boolean;
  includeInactive: boolean;
  onIncludeHeadersChange: (include: boolean) => void;
  onIncludeInactiveChange: (include: boolean) => void;
  showIncludeInactive?: boolean; // Nouveau prop pour contrôler l'affichage
}

const ExportConfiguration: React.FC<ExportConfigurationProps> = ({
  includeHeaders,
  includeInactive,
  onIncludeHeadersChange,
  onIncludeInactiveChange,
  showIncludeInactive = true // Par défaut, afficher l'option
}) => {
  return (
    <Card sx={{ mb: 3 }}>
      <CardContent>
        <Typography variant="h6" sx={{ mb: 3 }}>
          Configuration de l'export
        </Typography>

        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Box sx={{ p: 2, backgroundColor: 'primary.50', borderRadius: 1, mb: 2 }}>
              <Typography variant="body2" color="primary.main" fontWeight="medium">
                📦 Format d'export : ZIP contenant un fichier CSV par table
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Chaque table sera exportée dans un fichier CSV séparé, regroupés dans une archive ZIP nommée d'après la catégorie principale.
              </Typography>
            </Box>
          </Grid>

          <Grid item xs={12} md={6}>
            <FormControlLabel
              control={
                <Checkbox
                  checked={includeHeaders}
                  onChange={(e) => onIncludeHeadersChange(e.target.checked)}
                />
              }
              label="Inclure les en-têtes de colonne dans chaque fichier CSV"
            />
          </Grid>

          {showIncludeInactive && (
            <Grid item xs={12} md={6}>
              <FormControlLabel
                control={
                  <Checkbox
                    checked={includeInactive}
                    onChange={(e) => onIncludeInactiveChange(e.target.checked)}
                  />
                }
                label="Inclure les fournisseurs inactifs"
              />
            </Grid>
          )}
        </Grid>
      </CardContent>
    </Card>
  );
};

export default ExportConfiguration; 