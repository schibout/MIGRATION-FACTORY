import React, { useState, useEffect } from 'react';
import {
  Box,
  TextField,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  Button,
  FormHelperText,
  Grid,
  Paper,
  Typography,
  Switch,
  FormControlLabel,
  Divider,
  Stack
} from '@mui/material';
import { FieldMapping, TableInfo } from '../../services/fieldMappingService';

interface MappingFormProps {
  initialData?: Partial<FieldMapping>;
  sourceTables: TableInfo[];
  targetTables: TableInfo[];
  onSave: (data: FieldMapping) => void;
  onCancel: () => void;
  isEdit?: boolean;
}

const DEFAULT_DATA: FieldMapping = {
  source_table_name: '',
  source_field_name: '',
  target_table: '',
  target_field_name: '',
  is_active: true,
  is_key: false,
  data_type: '',
  transformation_rule: '',
  notes: ''
};

const MappingForm: React.FC<MappingFormProps> = ({
  initialData,
  sourceTables,
  targetTables,
  onSave,
  onCancel,
  isEdit = false
}) => {
  // État du formulaire
  const [formData, setFormData] = useState<FieldMapping>({
    ...DEFAULT_DATA,
    ...initialData
  });
  
  // État des erreurs de validation
  const [errors, setErrors] = useState<Partial<Record<keyof FieldMapping, string>>>({});
  
  // Option pour rester sur le formulaire après la sauvegarde
  const [saveAndStay, setSaveAndStay] = useState<boolean>(false);
  
  // Mettre à jour le formulaire si les données initiales changent
  useEffect(() => {
    if (initialData) {
      setFormData({
        ...DEFAULT_DATA,
        ...initialData
      });
    }
  }, [initialData]);
  
  // Gérer les changements de champs
  const handleChange = (field: keyof FieldMapping) => (
    e: React.ChangeEvent<HTMLInputElement | { name?: string; value: unknown }>
  ) => {
    const value = 
      field === 'is_active' || field === 'is_key'
        ? (e.target as HTMLInputElement).checked 
        : e.target.value;
    
    setFormData({
      ...formData,
      [field]: value
    });
    
    // Effacer l'erreur pour ce champ
    if (errors[field]) {
      setErrors({
        ...errors,
        [field]: undefined
      });
    }
  };
  
  // Valider le formulaire
  const validateForm = (): boolean => {
    const newErrors: Partial<Record<keyof FieldMapping, string>> = {};
    
    // Valider les champs obligatoires
    if (!formData.source_table_name) {
      newErrors.source_table_name = 'La table source est obligatoire';
    }
    
    if (!formData.source_field_name) {
      newErrors.source_field_name = 'Le champ source est obligatoire';
    }
    
    if (!formData.target_table) {
      newErrors.target_table = 'La table cible est obligatoire';
    }
    
    if (!formData.target_field_name) {
      newErrors.target_field_name = 'Le champ cible est obligatoire';
    }
    
    setErrors(newErrors);
    
    // Le formulaire est valide si aucune erreur n'est présente
    return Object.keys(newErrors).length === 0;
  };
  
  // Soumettre le formulaire
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (validateForm()) {
      onSave(formData);
      if (!saveAndStay) {
        onCancel();
      }
    }
  };
  
  return (
    <Paper sx={{ p: 2 }}>
      <Box component="form" onSubmit={handleSubmit}>
        <Typography variant="h6" gutterBottom>
          {isEdit ? 'Modifier le mapping de champ' : 'Ajouter un nouveau mapping de champ'}
        </Typography>
        
        <Divider sx={{ mb: 3 }} />
        
        <Grid container spacing={2}>
          {/* Table source */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth error={!!errors.source_table_name}>
              <InputLabel id="source-table-label">Table source *</InputLabel>
              <Select
                labelId="source-table-label"
                value={formData.source_table_name}
                label="Table source *"
                onChange={handleChange('source_table_name')}
              >
                {sourceTables.map((table) => (
                  <MenuItem key={table.name} value={table.name}>
                    {table.name} - {table.description}
                  </MenuItem>
                ))}
              </Select>
              {errors.source_table_name && <FormHelperText>{errors.source_table_name}</FormHelperText>}
            </FormControl>
          </Grid>
          
          {/* Champ source */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Champ source *"
              variant="outlined"
              value={formData.source_field_name}
              onChange={handleChange('source_field_name')}
              error={!!errors.source_field_name}
              helperText={errors.source_field_name}
            />
          </Grid>
          
          {/* Table cible */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth error={!!errors.target_table}>
              <InputLabel id="target-table-label">Table cible *</InputLabel>
              <Select
                labelId="target-table-label"
                value={formData.target_table}
                label="Table cible *"
                onChange={handleChange('target_table')}
              >
                {targetTables.map((table) => (
                  <MenuItem key={table.name} value={table.name}>
                    {table.name} - {table.description}
                  </MenuItem>
                ))}
              </Select>
              {errors.target_table && <FormHelperText>{errors.target_table}</FormHelperText>}
            </FormControl>
          </Grid>
          
          {/* Champ cible */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Champ cible *"
              variant="outlined"
              value={formData.target_field_name}
              onChange={handleChange('target_field_name')}
              error={!!errors.target_field_name}
              helperText={errors.target_field_name}
            />
          </Grid>
          
          {/* Type de donnée */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Type de donnée"
              variant="outlined"
              value={formData.data_type || ''}
              onChange={handleChange('data_type')}
            />
          </Grid>
          
          {/* Règle de transformation */}
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Règle de transformation"
              variant="outlined"
              value={formData.transformation_rule || ''}
              onChange={handleChange('transformation_rule')}
              placeholder="ex: CONCAT(first_name, ' ', last_name)"
              multiline
              rows={2}
            />
          </Grid>
          
          {/* Notes */}
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Notes"
              variant="outlined"
              value={formData.notes || ''}
              onChange={handleChange('notes')}
              multiline
              rows={3}
            />
          </Grid>
          
          {/* Options */}
          <Grid item xs={12} sm={6}>
            <FormControlLabel
              control={
                <Switch
                  checked={formData.is_key}
                  onChange={handleChange('is_key')}
                  color="primary"
                />
              }
              label="Clé primaire"
            />
          </Grid>
          
          <Grid item xs={12} sm={6}>
            <FormControlLabel
              control={
                <Switch
                  checked={formData.is_active}
                  onChange={handleChange('is_active')}
                  color="primary"
                />
              }
              label={formData.is_active ? 'Actif' : 'Inactif'}
            />
          </Grid>
        </Grid>
        
        <Divider sx={{ my: 3 }} />
        
        {/* Options et boutons d'action */}
        <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
          <FormControlLabel
            control={
              <Switch
                checked={saveAndStay}
                onChange={(e) => setSaveAndStay(e.target.checked)}
                color="primary"
              />
            }
            label="Enregistrer et continuer"
          />
          
          <Box>
            <Button
              variant="outlined"
              onClick={onCancel}
              sx={{ mr: 1 }}
            >
              Annuler
            </Button>
            <Button
              type="submit"
              variant="contained"
              color="primary"
            >
              {isEdit ? 'Mettre à jour' : 'Créer'}
            </Button>
          </Box>
        </Stack>
      </Box>
    </Paper>
  );
};

export default MappingForm;