import {
  Box,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  FormControlLabel,
  Grid,
  Typography
} from '@mui/material';
import React from 'react';
import { ExportQuery } from '../../services/exportService';

interface TableSelectorProps {
  selectedTables: string[];
  availableTables: ExportQuery[];
  onTableSelection: (tableName: string) => void;
  onSelectAll: () => void;
}

const TableSelector: React.FC<TableSelectorProps> = ({
  selectedTables,
  availableTables,
  onTableSelection,
  onSelectAll
}) => {
  // Grouper les tables par catégorie
  const tablesByCategory = React.useMemo(() => {
    const grouped: Record<string, ExportQuery[]> = {};
    availableTables.forEach(table => {
      if (!grouped[table.category]) {
        grouped[table.category] = [];
      }
      grouped[table.category].push(table);
    });
    return grouped;
  }, [availableTables]);

  const categoryColors: Record<string, string> = {
    'supplier': '#2196f3',
    'payment': '#4caf50',
    'tax': '#ff9800',
    'communication': '#9c27b0',
    'contact': '#607d8b',
    'project': '#673ab7',
    'inventory': '#4caf50',
    'maintenance': '#9c27b0',
    'customer': '#ff9800'
  };

  return (
    <Card sx={{ mb: 3 }}>
      <CardContent>
        <Typography variant="h6" sx={{ mb: 2 }}>
          Sélection des tables ({selectedTables.length}/{availableTables.length})
        </Typography>
        
        <Box sx={{ mb: 2 }}>
          <Button
            variant="outlined"
            size="small"
            onClick={onSelectAll}
          >
            {selectedTables.length === availableTables.length ? 'Désélectionner tout' : 'Sélectionner tout'}
          </Button>
        </Box>

        {/* Affichage par catégorie */}
        {Object.entries(tablesByCategory).map(([category, tables]) => (
          <Box key={category} sx={{ mb: 3 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
              <Chip 
                label={category.toUpperCase()} 
                size="small" 
                sx={{ 
                  backgroundColor: categoryColors[category] || '#757575',
                  color: 'white',
                  mr: 1,
                  fontWeight: 'bold'
                }}
              />
              <Typography variant="subtitle2" color="text.secondary">
                {tables.length} table{tables.length > 1 ? 's' : ''}
              </Typography>
            </Box>
            
            <Grid container spacing={1}>
              {tables.map((table) => (
                <Grid item xs={12} sm={6} md={4} key={table.table_name}>
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={selectedTables.includes(table.table_name)}
                        onChange={() => onTableSelection(table.table_name)}
                        size="small"
                      />
                    }
                    label={
                      <Box>
                        <Typography variant="body2" fontWeight="medium">
                          {table.display_name}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                          {table.table_name}
                        </Typography>
                        {table.description && (
                          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', fontStyle: 'italic' }}>
                            {table.description}
                          </Typography>
                        )}
                      </Box>
                    }
                    sx={{ 
                      alignItems: 'flex-start',
                      '& .MuiFormControlLabel-label': {
                        pt: 0.5
                      }
                    }}
                  />
                </Grid>
              ))}
            </Grid>
          </Box>
        ))}

        {availableTables.length === 0 && (
          <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center', py: 2 }}>
            Aucune table d'export disponible
          </Typography>
        )}
      </CardContent>
    </Card>
  );
};

export default TableSelector; 