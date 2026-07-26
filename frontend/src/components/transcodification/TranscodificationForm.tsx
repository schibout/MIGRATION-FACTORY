import React, { useState, useEffect } from 'react';
// Import Material-UI components individually
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import Button from '@mui/material/Button';
import FormHelperText from '@mui/material/FormHelperText';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import Switch from '@mui/material/Switch';
import FormControlLabel from '@mui/material/FormControlLabel';
import Divider from '@mui/material/Divider';
import Stack from '@mui/material/Stack';
import { Transcodification } from '../../services/transcodificationService';

// Étendre l'interface Transcodification pour le formulaire
interface TranscodificationFormData extends Transcodification {
  newCategory?: string;
}

interface TranscodificationFormProps {
  initialData?: Partial<Transcodification>;
  categories: string[];
  onSave: (data: Transcodification) => void;
  onCancel: () => void;
  isEdit?: boolean;
}

const DEFAULT_DATA: TranscodificationFormData = {
  category: '',
  source_system: 'SAP',
  target_system: 'IFS',
  source_value: '',
  target_value: '',
  description: '',
  is_active: true
};

const TranscodificationForm: React.FC<TranscodificationFormProps> = ({
  initialData,
  categories,
  onSave,
  onCancel,
  isEdit = false
}) => {
  // État du formulaire
  const [formData, setFormData] = useState<TranscodificationFormData>({
    ...DEFAULT_DATA,
    ...initialData
  });
  
  // État des erreurs de validation
  const [errors, setErrors] = useState<Partial<Record<keyof TranscodificationFormData, string>>>({});
  
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
  const handleChange = (field: keyof TranscodificationFormData) => (
    e: React.ChangeEvent<HTMLInputElement | { name?: string; value: unknown }>
  ) => {
    const value = 
      field === 'is_active' 
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
    const newErrors: Partial<Record<keyof TranscodificationFormData, string>> = {};
    
    // Valider les champs obligatoires
    if (!formData.category) {
      newErrors.category = 'La catégorie est obligatoire';
    }
    
    if (!formData.source_value) {
      newErrors.source_value = 'La valeur source est obligatoire';
    }
    
    if (!formData.target_value) {
      newErrors.target_value = 'La valeur cible est obligatoire';
    }
    
    setErrors(newErrors);
    
    // Le formulaire est valide si aucune erreur n'est présente
    return Object.keys(newErrors).length === 0;
  };
  
  // Soumettre le formulaire
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // Si une nouvelle catégorie a été saisie, la transférer à category
    if (formData.category === 'NOUVELLE_CATÉGORIE' && formData.newCategory) {
      setFormData({
        ...formData,
        category: formData.newCategory
      });
      // Quitter la fonction pour permettre au state de se mettre à jour
      // Une seconde soumission sera nécessaire
      return;
    }
    
    if (validateForm()) {
      // Supprimer le champ newCategory avant de sauvegarder
      const { newCategory, ...dataToSave } = formData;
      onSave(dataToSave);
      if (!saveAndStay) {
        onCancel();
      }
    }
  };
  
  return (
    <Paper sx={{ p: 2 }}>
      <Box component="form" onSubmit={handleSubmit}>
        <Typography variant="h6" gutterBottom>
          {isEdit ? 'Modifier la transcodification' : 'Ajouter une nouvelle transcodification'}
        </Typography>
        
        <Divider sx={{ mb: 3 }} />
        
        <Grid container spacing={2}>
          {/* Catégorie */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth error={!!errors.category}>
              <InputLabel id="category-label">Catégorie *</InputLabel>
              <Select
                labelId="category-label"
                value={formData.category}
                label="Catégorie *"
                onChange={handleChange('category')}
              >
                {categories.map((category) => (
                  <MenuItem key={category} value={category}>
                    {category}
                  </MenuItem>
                ))}
                <MenuItem value="NOUVELLE_CATÉGORIE">
                  + Ajouter une nouvelle catégorie
                </MenuItem>
              </Select>
              {errors.category && <FormHelperText>{errors.category}</FormHelperText>}
            </FormControl>
          </Grid>
          
          {/* Nouvelle catégorie (si sélectionnée) */}
          {formData.category === 'NOUVELLE_CATÉGORIE' && (
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                autoFocus
                label="Nouvelle catégorie *"
                variant="outlined"
                value={formData.newCategory || ''}
                onChange={(e) => {
                  setFormData({
                    ...formData,
                    newCategory: e.target.value
                  });
                }}
                error={!!errors.category}
                helperText={errors.category || "Saisissez une nouvelle catégorie puis validez le formulaire"}
              />
            </Grid>
          )}
          
          {/* Système source */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth>
              <InputLabel id="source-system-label">Système source *</InputLabel>
              <Select
                labelId="source-system-label"
                value={formData.source_system}
                label="Système source *"
                onChange={handleChange('source_system')}
              >
                <MenuItem value="SAP">SAP</MenuItem>
                <MenuItem value="LEGACY">Legacy</MenuItem>
                <MenuItem value="EXTERNAL">Externe</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          
          {/* Système cible */}
          <Grid item xs={12} sm={6}>
            <FormControl fullWidth>
              <InputLabel id="target-system-label">Système cible *</InputLabel>
              <Select
                labelId="target-system-label"
                value={formData.target_system}
                label="Système cible *"
                onChange={handleChange('target_system')}
              >
                <MenuItem value="IFS">IFS</MenuItem>
                <MenuItem value="IFS_V2">IFS V2</MenuItem>
                <MenuItem value="OTHER">Autre</MenuItem>
              </Select>
            </FormControl>
          </Grid>
          
          {/* Valeur source */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Valeur source *"
              variant="outlined"
              value={formData.source_value}
              onChange={handleChange('source_value')}
              error={!!errors.source_value}
              helperText={errors.source_value}
            />
          </Grid>
          
          {/* Valeur cible */}
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Valeur cible *"
              variant="outlined"
              value={formData.target_value}
              onChange={handleChange('target_value')}
              error={!!errors.target_value}
              helperText={errors.target_value}
            />
          </Grid>
          
          {/* Description */}
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Description"
              variant="outlined"
              value={formData.description || ''}
              onChange={handleChange('description')}
              multiline
              rows={3}
            />
          </Grid>
          
          {/* Statut */}
          <Grid item xs={12}>
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

export default TranscodificationForm; 