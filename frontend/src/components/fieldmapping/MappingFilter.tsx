import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Button,
  InputAdornment,
  Autocomplete
} from '@mui/material';
import { Search as SearchIcon, Refresh as RefreshIcon } from '@mui/icons-material';
import { TableInfo } from '../../services/fieldMappingService';

interface MappingFilterProps {
  onFilter: (filters: {
    sourceTable: string;
    targetTable: string;
    status: string;
    search: string;
  }) => void;
  loading: boolean;
  sourceTables: TableInfo[];
  targetTables: TableInfo[];
}

const MappingFilter: React.FC<MappingFilterProps> = ({
  onFilter,
  loading,
  sourceTables,
  targetTables
}) => {
  const [sourceTable, setSourceTable] = useState<string>('');
  const [targetTable, setTargetTable] = useState<string>('');
  const [status, setStatus] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Appliquer les filtres
  const applyFilters = () => {
    onFilter({
      sourceTable,
      targetTable,
      status,
      search: searchTerm
    });
  };

  // Réinitialiser les filtres
  const resetFilters = () => {
    setSourceTable('');
    setTargetTable('');
    setStatus('all');
    setSearchTerm('');
    onFilter({
      sourceTable: '',
      targetTable: '',
      status: 'all',
      search: ''
    });
  };

  // Appliquer les filtres lorsque le statut change
  useEffect(() => {
    applyFilters();
  }, [status]);

  return (
    <Box 
      component="form" 
      noValidate 
      sx={{ 
        mt: 2, 
        width: '100%', 
        maxWidth: '100%' 
      }}
    >
      <Grid container spacing={2} alignItems="center" sx={{ width: '100%' }}>
        <Grid item xs={12} sm={6} md={3} lg={3}>
          <Autocomplete
            id="source-table-select"
            options={sourceTables}
            getOptionLabel={(option) => option.description || option.name}
            value={sourceTables.find(t => t.name === sourceTable) || null}
            onChange={(_, newValue) => {
              setSourceTable(newValue ? newValue.name : '');
            }}
            renderInput={(params) => (
              <TextField
                {...params}
                label="Table source"
                fullWidth
                variant="outlined"
                placeholder="Toutes les tables"
              />
            )}
            disabled={loading}
            fullWidth
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3} lg={3}>
          <Autocomplete
            id="target-table-select"
            options={targetTables}
            getOptionLabel={(option) => option.description || option.name}
            value={targetTables.find(t => t.name === targetTable) || null}
            onChange={(_, newValue) => {
              setTargetTable(newValue ? newValue.name : '');
            }}
            renderInput={(params) => (
              <TextField
                {...params}
                label="Table cible"
                fullWidth
                variant="outlined"
                placeholder="Toutes les tables"
              />
            )}
            disabled={loading}
            fullWidth
          />
        </Grid>
        <Grid item xs={12} sm={4} md={2} lg={2}>
          <FormControl fullWidth variant="outlined">
            <InputLabel id="status-select-label">Statut</InputLabel>
            <Select
              labelId="status-select-label"
              id="status-select"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              label="Statut"
              disabled={loading}
              fullWidth
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="active">Actifs</MenuItem>
              <MenuItem value="inactive">Inactifs</MenuItem>
            </Select>
          </FormControl>
        </Grid>
        <Grid item xs={12} sm={8} md={3} lg={3}>
          <TextField
            fullWidth
            variant="outlined"
            label="Recherche"
            placeholder="Rechercher..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            InputProps={{
              endAdornment: (
                <InputAdornment position="end">
                  <SearchIcon />
                </InputAdornment>
              ),
            }}
            onKeyPress={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                applyFilters();
              }
            }}
            disabled={loading}
          />
        </Grid>
        <Grid item xs={12} sm={12} md={1} lg={1}>
          <Box sx={{ display: 'flex', gap: 1, width: '100%' }}>
            <Button
              variant="outlined"
              color="primary"
              onClick={applyFilters}
              disabled={loading}
              sx={{ flex: 1 }}
            >
              Filtrer
            </Button>
            <Button
              variant="outlined"
              onClick={resetFilters}
              disabled={loading}
              sx={{ minWidth: '40px', px: 0 }}
            >
              <RefreshIcon />
            </Button>
          </Box>
        </Grid>
      </Grid>
    </Box>
  );
};

export default MappingFilter;