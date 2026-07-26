import React, { useState, useEffect } from 'react';
// Import Material-UI components individually to avoid bundling issues
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import Button from '@mui/material/Button';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import IconButton from '@mui/material/IconButton';
import Tooltip from '@mui/material/Tooltip';
import { useTheme } from '@mui/material/styles';
import useMediaQuery from '@mui/material/useMediaQuery';
// Import Material-UI icons
import {
  FilterAlt as FilterIcon,
  Clear as ClearIcon,
  Search as SearchIcon
} from '@mui/icons-material';
import transcodificationService from '../../services/transcodificationService';

interface FilterProps {
  onFilterChange: (filters: {
    category: string;
    sourceSystem: string;
    targetSystem: string;
    status: string;
    search: string;
  }) => void;
}

const TranscodificationFilter: React.FC<FilterProps> = ({ onFilterChange }) => {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  const [categories, setCategories] = useState<string[]>([]);
  const [filters, setFilters] = useState({
    category: '',
    sourceSystem: 'SAP',
    targetSystem: 'IFS',
    status: 'all',
    search: ''
  });
  
  // Récupérer les catégories disponibles
  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const categoryList = await transcodificationService.getCategories();
        setCategories(categoryList);
      } catch (error) {
        console.error('Erreur lors de la récupération des catégories:', error);
      }
    };
    
    fetchCategories();
  }, []);
  
  // Handler pour les changements de filtres
  const handleFilterChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement | { name?: string; value: unknown }>) => {
    const newFilters = {
      ...filters,
      [field]: e.target.value
    };
    
    setFilters(newFilters);
  };
  
  // Handler pour la touche Entrée dans le champ de recherche
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      applyFilters();
    }
  };
  
  // Appliquer les filtres
  const applyFilters = () => {
    onFilterChange(filters);
  };
  
  // Réinitialiser les filtres
  const resetFilters = () => {
    const defaultFilters = {
      category: '',
      sourceSystem: 'SAP',
      targetSystem: 'IFS',
      status: 'all',
      search: ''
    };
    
    setFilters(defaultFilters);
    onFilterChange(defaultFilters);
  };
  
  return (
    <Paper sx={{ p: 2, mb: 2 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
        <FilterIcon color="primary" sx={{ mr: 1 }} />
        <Typography variant="h6">Filtres</Typography>
        
        <Tooltip title="Réinitialiser les filtres">
          <IconButton
            size="small"
            onClick={resetFilters}
            sx={{ ml: 'auto' }}
          >
            <ClearIcon />
          </IconButton>
        </Tooltip>
      </Box>
      
      <Grid container spacing={2}>
        <Grid item xs={12} sm={6} md={3}>
          <FormControl fullWidth size="small">
            <InputLabel id="category-label">Catégorie</InputLabel>
            <Select
              labelId="category-label"
              value={filters.category}
              label="Catégorie"
              onChange={handleFilterChange('category')}
            >
              <MenuItem value="">Toutes</MenuItem>
              {categories.map((category) => (
                <MenuItem key={category} value={category}>
                  {category}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <FormControl fullWidth size="small">
            <InputLabel id="source-system-label">Système source</InputLabel>
            <Select
              labelId="source-system-label"
              value={filters.sourceSystem}
              label="Système source"
              onChange={handleFilterChange('sourceSystem')}
            >
              <MenuItem value="">Tous</MenuItem>
              <MenuItem value="SAP">SAP</MenuItem>
              <MenuItem value="LEGACY">Legacy</MenuItem>
              <MenuItem value="EXTERNAL">Externe</MenuItem>
            </Select>
          </FormControl>
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <FormControl fullWidth size="small">
            <InputLabel id="target-system-label">Système cible</InputLabel>
            <Select
              labelId="target-system-label"
              value={filters.targetSystem}
              label="Système cible"
              onChange={handleFilterChange('targetSystem')}
            >
              <MenuItem value="">Tous</MenuItem>
              <MenuItem value="IFS">IFS</MenuItem>
              <MenuItem value="IFS_V2">IFS V2</MenuItem>
              <MenuItem value="OTHER">Autre</MenuItem>
            </Select>
          </FormControl>
        </Grid>
        
        <Grid item xs={12} sm={6} md={2}>
          <FormControl fullWidth size="small">
            <InputLabel id="status-label">Statut</InputLabel>
            <Select
              labelId="status-label"
              value={filters.status}
              label="Statut"
              onChange={handleFilterChange('status')}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="active">Actifs</MenuItem>
              <MenuItem value="inactive">Inactifs</MenuItem>
            </Select>
          </FormControl>
        </Grid>
        
        <Grid item xs={12} md={3}>
          <Box sx={{ display: 'flex' }}>
            <TextField
              fullWidth
              size="small"
              label="Recherche"
              variant="outlined"
              value={filters.search}
              onChange={handleFilterChange('search')}
              onKeyPress={handleKeyPress}
              placeholder="Rechercher..."
              InputProps={{
                endAdornment: (
                  <IconButton
                    size="small"
                    onClick={applyFilters}
                    edge="end"
                  >
                    <SearchIcon />
                  </IconButton>
                )
              }}
            />
          </Box>
        </Grid>
        
        {isMobile && (
          <Grid item xs={12}>
            <Button
              fullWidth
              variant="contained"
              color="primary"
              onClick={applyFilters}
              startIcon={<FilterIcon />}
            >
              Appliquer les filtres
            </Button>
          </Grid>
        )}
      </Grid>
    </Paper>
  );
};

export default TranscodificationFilter; 