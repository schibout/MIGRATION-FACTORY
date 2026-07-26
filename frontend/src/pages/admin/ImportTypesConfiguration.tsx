import {
    Add as AddIcon,
    Business as BusinessIcon,
    Category as CategoryIcon,
    Delete as DeleteIcon,
    Description as DescriptionIcon,
    Edit as EditIcon,
    LocalShipping as LocalShippingIcon,
    LocationOn as LocationOnIcon,
    Person as PersonIcon,
    Receipt as ReceiptIcon
} from '@mui/icons-material';
import {
    Alert,
    Avatar,
    Box,
    Button,
    Card,
    CardActions,
    CardContent,
    CardHeader,
    Chip,
    Container,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    FormControl,
    Grid,
    InputLabel,
    MenuItem,
    Select,
    Snackbar,
    Switch,
    Tab,
    Tabs,
    TextField,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';

interface ValidationRule {
  [key: string]: string;
}

interface ImportTypeConfig {
  id?: number;
  type_code: string;
  display_name: string;
  description: string;
  category: string;
  max_file_size_mb: number;
  allowed_extensions: string[];
  required_columns: string[];
  optional_columns: string[];
  column_mappings: { [key: string]: string };
  validation_rules: ValidationRule;
  target_table: string;
  processor_class: string;
  is_active: boolean;
  template_url?: string;
  help_text?: string;
  icon: string;
}

const defaultConfig: ImportTypeConfig = {
  type_code: '',
  display_name: '',
  description: '',
  category: 'customer',
  max_file_size_mb: 50,
  allowed_extensions: ['csv', 'xlsx', 'xls'],
  required_columns: [],
  optional_columns: [],
  column_mappings: {},
  validation_rules: {},
  target_table: '',
  processor_class: '',
  is_active: true,
  icon: 'description'
};

const iconMap = {
  'person': <PersonIcon />,
  'location_on': <LocationOnIcon />,
  'category': <CategoryIcon />,
  'receipt': <ReceiptIcon />,
  'local_shipping': <LocalShippingIcon />,
  'business': <BusinessIcon />,
  'description': <DescriptionIcon />
};

const ImportTypesConfiguration: React.FC = () => {
  const [configs, setConfigs] = useState<ImportTypeConfig[]>([]);
  const [selectedConfig, setSelectedConfig] = useState<ImportTypeConfig | null>(null);
  const [isEditing, setIsEditing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState(0);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' as 'success' | 'error' });

  // Données exemple (à remplacer par appels API)
  const sampleConfigs: ImportTypeConfig[] = [
    {
      id: 1,
      type_code: 'customer_info',
      display_name: 'Informations Client',
      description: 'Données principales du client',
      category: 'customer',
      max_file_size_mb: 50,
      allowed_extensions: ['csv', 'xlsx', 'xls'],
      required_columns: ['client_id', 'name', 'email'],
      optional_columns: ['phone', 'company'],
      column_mappings: { 'nom': 'name', 'email': 'email' },
      validation_rules: { 'email': 'email_format', 'client_id': 'unique' },
      target_table: 'clean_data.customer_info',
      processor_class: 'CustomerInfoProcessor',
      is_active: true,
      icon: 'person'
    },
    {
      id: 2,
      type_code: 'customer_info_address',
      display_name: 'Adresses Client',
      description: 'Adresses de facturation et livraison',
      category: 'customer',
      max_file_size_mb: 50,
      allowed_extensions: ['csv', 'xlsx', 'xls'],
      required_columns: ['client_id', 'address_line1', 'city', 'postal_code'],
      optional_columns: ['address_line2', 'country'],
      column_mappings: {},
      validation_rules: { 'postal_code': 'postal_format' },
      target_table: 'clean_data.customer_addresses',
      processor_class: 'CustomerAddressProcessor',
      is_active: true,
      icon: 'location_on'
    }
  ];

  useEffect(() => {
    // Simuler chargement des données
    setTimeout(() => {
      setConfigs(sampleConfigs);
      setLoading(false);
    }, 1000);
  }, []);

  const handleEdit = (config: ImportTypeConfig) => {
    setSelectedConfig(config);
    setIsEditing(true);
    setActiveTab(0);
  };

  const handleCreateNew = () => {
    setSelectedConfig({ ...defaultConfig });
    setIsEditing(true);
    setActiveTab(0);
  };

  const handleSave = () => {
    if (selectedConfig) {
      if (selectedConfig.id) {
        // Mise à jour
        setConfigs(configs.map(c => c.id === selectedConfig.id ? selectedConfig : c));
        setSnackbar({ open: true, message: 'Configuration mise à jour avec succès', severity: 'success' });
      } else {
        // Création
        const newConfig = { ...selectedConfig, id: Date.now() };
        setConfigs([...configs, newConfig]);
        setSnackbar({ open: true, message: 'Configuration créée avec succès', severity: 'success' });
      }
    }
    setIsEditing(false);
    setSelectedConfig(null);
  };

  const handleDelete = (id: number) => {
    if (window.confirm('Êtes-vous sûr de vouloir supprimer cette configuration ?')) {
      setConfigs(configs.filter(c => c.id !== id));
      setSnackbar({ open: true, message: 'Configuration supprimée', severity: 'success' });
    }
  };

  const handleToggleActive = (config: ImportTypeConfig) => {
    const updatedConfig = { ...config, is_active: !config.is_active };
    setConfigs(configs.map(c => c.id === config.id ? updatedConfig : c));
  };

  const ConfigurationCard = ({ config }: { config: ImportTypeConfig }) => (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <CardHeader
        avatar={
          <Avatar sx={{ bgcolor: config.is_active ? 'success.main' : 'grey.400' }}>
            {iconMap[config.icon] || <DescriptionIcon />}
          </Avatar>
        }
        title={config.display_name}
        subheader={`Type: ${config.type_code}`}
        action={
          <Switch
            checked={config.is_active}
            onChange={() => handleToggleActive(config)}
            color="primary"
          />
        }
      />
      
      <CardContent sx={{ flexGrow: 1 }}>
        <Typography variant="body2" color="text.secondary" gutterBottom>
          {config.description}
        </Typography>
        
        <Box sx={{ mt: 2 }}>
          <Chip 
            label={`${config.required_columns.length} col. requises`}
            size="small" 
            sx={{ mr: 1, mb: 1 }}
          />
          <Chip 
            label={`Max ${config.max_file_size_mb}MB`}
            size="small"
            sx={{ mb: 1 }}
          />
        </Box>

        <Typography variant="caption" display="block" sx={{ mt: 2 }}>
          Colonnes requises:
        </Typography>
        <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
          {config.required_columns.join(', ')}
        </Typography>
      </CardContent>

      <CardActions>
        <Button size="small" onClick={() => handleEdit(config)} startIcon={<EditIcon />}>
          Modifier
        </Button>
        <Button 
          size="small" 
          color="error" 
          onClick={() => config.id && handleDelete(config.id)} 
          startIcon={<DeleteIcon />}
        >
          Supprimer
        </Button>
      </CardActions>
    </Card>
  );

  const AddNewTypeCard = () => (
    <Card sx={{ 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: 300,
      cursor: 'pointer',
      '&:hover': { backgroundColor: 'action.hover' }
    }}
    onClick={handleCreateNew}
    >
      <AddIcon sx={{ fontSize: 60, color: 'primary.main', mb: 2 }} />
      <Typography variant="h6" color="primary">
        Ajouter un type
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
        Créer une nouvelle configuration d'import
      </Typography>
    </Card>
  );

  const TabPanel = ({ children, value, index }: { children: React.ReactNode, value: number, index: number }) => (
    <Box sx={{ display: value === index ? 'block' : 'none', pt: 3 }}>
      {children}
    </Box>
  );

  return (
    <Container maxWidth="xl">
      <Typography variant="h4" gutterBottom>
        Configuration des Types d'Import
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Configurez les différents types de fichiers d'import et leurs règles de validation
      </Typography>

      {loading ? (
        <Typography>Chargement...</Typography>
      ) : (
        <Grid container spacing={3}>
          {configs.map((config) => (
            <Grid item xs={12} md={6} lg={4} key={config.id}>
              <ConfigurationCard config={config} />
            </Grid>
          ))}
          
          <Grid item xs={12} md={6} lg={4}>
            <AddNewTypeCard />
          </Grid>
        </Grid>
      )}

      {/* Modal d'édition/création */}
      <Dialog open={isEditing} onClose={() => setIsEditing(false)} maxWidth="md" fullWidth>
        <DialogTitle>
          {selectedConfig?.id ? 'Modifier' : 'Créer'} Type d'Import
        </DialogTitle>
        
        <DialogContent>
          <Tabs value={activeTab} onChange={(_, newValue) => setActiveTab(newValue)}>
            <Tab label="Général" />
            <Tab label="Colonnes" />
            <Tab label="Validation" />
            <Tab label="Traitement" />
          </Tabs>

          <TabPanel value={activeTab} index={0}>
            <TextField
              label="Code du type"
              value={selectedConfig?.type_code || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, type_code: e.target.value } : null)}
              fullWidth
              margin="normal"
              required
            />
            <TextField
              label="Nom d'affichage"
              value={selectedConfig?.display_name || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, display_name: e.target.value } : null)}
              fullWidth
              margin="normal"
              required
            />
            <TextField
              label="Description"
              value={selectedConfig?.description || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, description: e.target.value } : null)}
              fullWidth
              margin="normal"
              multiline
              rows={3}
            />
            <FormControl fullWidth margin="normal">
              <InputLabel>Catégorie</InputLabel>
              <Select
                value={selectedConfig?.category || 'customer'}
                onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, category: e.target.value } : null)}
              >
                <MenuItem value="customer">Client</MenuItem>
                <MenuItem value="product">Produit</MenuItem>
                <MenuItem value="order">Commande</MenuItem>
              </Select>
            </FormControl>
          </TabPanel>

          <TabPanel value={activeTab} index={1}>
            <Typography variant="h6" gutterBottom>Colonnes Requises</Typography>
            <TextField
              label="Colonnes requises (séparées par des virgules)"
              value={selectedConfig?.required_columns.join(', ') || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { 
                ...prev, 
                required_columns: e.target.value.split(',').map(col => col.trim()).filter(col => col)
              } : null)}
              fullWidth
              margin="normal"
              placeholder="client_id, name, email"
            />
            
            <Typography variant="h6" gutterBottom sx={{ mt: 3 }}>Colonnes Optionnelles</Typography>
            <TextField
              label="Colonnes optionnelles (séparées par des virgules)"
              value={selectedConfig?.optional_columns.join(', ') || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { 
                ...prev, 
                optional_columns: e.target.value.split(',').map(col => col.trim()).filter(col => col)
              } : null)}
              fullWidth
              margin="normal"
              placeholder="phone, company"
            />
          </TabPanel>

          <TabPanel value={activeTab} index={2}>
            <Typography variant="h6" gutterBottom>Règles de Validation</Typography>
            <TextField
              label="Règles de validation (JSON)"
              value={JSON.stringify(selectedConfig?.validation_rules || {}, null, 2)}
              onChange={(e) => {
                try {
                  const rules = JSON.parse(e.target.value);
                  setSelectedConfig(prev => prev ? { ...prev, validation_rules: rules } : null);
                } catch (err) {
                  // Ignore invalid JSON during typing
                }
              }}
              fullWidth
              margin="normal"
              multiline
              rows={6}
              placeholder='{"email": "email_format", "client_id": "unique"}'
            />
          </TabPanel>

          <TabPanel value={activeTab} index={3}>
            <TextField
              label="Table de destination"
              value={selectedConfig?.target_table || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, target_table: e.target.value } : null)}
              fullWidth
              margin="normal"
              placeholder="clean_data.customer_info"
            />
            <TextField
              label="Classe processeur"
              value={selectedConfig?.processor_class || ''}
              onChange={(e) => setSelectedConfig(prev => prev ? { ...prev, processor_class: e.target.value } : null)}
              fullWidth
              margin="normal"
              placeholder="CustomerInfoProcessor"
            />
          </TabPanel>
        </DialogContent>

        <DialogActions>
          <Button onClick={() => setIsEditing(false)}>Annuler</Button>
          <Button onClick={handleSave} variant="contained">
            Sauvegarder
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={() => setSnackbar({ ...snackbar, open: false })}
      >
        <Alert severity={snackbar.severity} sx={{ width: '100%' }}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export { ImportTypesConfiguration };
export default ImportTypesConfiguration;