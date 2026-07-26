import {
  Business as BusinessIcon,
  Category as CategoryIcon,
  Description as DescriptionIcon,
  LocalShipping as LocalShippingIcon,
  LocationOn as LocationOnIcon,
  Person as PersonIcon,
  Receipt as ReceiptIcon
} from '@mui/icons-material';
import {
  Alert,
  Avatar,
  Box,
  Card,
  CardContent,
  CardHeader,
  Chip,
  CircularProgress,
  Grid,
  Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import importConfigService, { ImportTypeConfig } from '../../services/importConfigService';
import { RootState } from '../../store';

interface ClientFileTypeSelectorProps {
  onTypeSelect: (typeConfig: ImportTypeConfig) => void;
  selectedType?: string;
}

const iconMap = {
  'person': PersonIcon,
  'location_on': LocationOnIcon,
  'category': CategoryIcon,
  'receipt': ReceiptIcon,
  'local_shipping': LocalShippingIcon,
  'business': BusinessIcon,
  'description': DescriptionIcon
};

const ClientFileTypeSelector: React.FC<ClientFileTypeSelectorProps> = ({
  onTypeSelect,
  selectedType
}) => {
  const navigate = useNavigate();
  const { isAuthenticated, token } = useSelector((state: RootState) => state.auth);
  const [configs, setConfigs] = useState<ImportTypeConfig[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Vérifier l'authentification avant de charger les données
    if (!isAuthenticated || !token) {
      console.warn('Utilisateur non authentifié, redirection vers login');
      navigate('/login', { state: { from: '/import/clients' } });
      return;
    }

    loadClientTypes();
  }, [isAuthenticated, token, navigate]);

  const loadClientTypes = async () => {
    try {
      setLoading(true);
      setError(null);
      
      // Vérifier à nouveau l'authentification avant l'appel API
      if (!isAuthenticated || !token) {
        throw new Error('Non authentifié');
      }
      
      const clientTypes = await importConfigService.getCustomerImportTypes();
      setConfigs(clientTypes);
    } catch (error: any) {
      console.error('Erreur lors du chargement des types:', error);
      
      if (error.message === 'Non authentifié' || error.response?.status === 401) {
        setError('Session expirée. Veuillez vous reconnecter.');
        // Rediriger vers login après un délai
        setTimeout(() => {
          navigate('/login', { state: { from: '/import/clients' } });
        }, 2000);
      } else {
        setError('Erreur lors du chargement des types de fichiers. Veuillez réessayer.');
      }
    } finally {
      setLoading(false);
    }
  };

  const getIconComponent = (iconName: string) => {
    const IconComponent = iconMap[iconName as keyof typeof iconMap] || DescriptionIcon;
    return <IconComponent />;
  };

  const handleTypeSelect = (config: ImportTypeConfig) => {
    onTypeSelect(config);
  };

  // Afficher un message si l'utilisateur n'est pas authentifié
  if (!isAuthenticated || !token) {
    return (
      <Box sx={{ textAlign: 'center', py: 4 }}>
        <CircularProgress />
        <Typography variant="body1" sx={{ mt: 2 }}>
          Vérification de l'authentification...
        </Typography>
        
        {/* Debug info en développement */}
        {process.env.NODE_ENV === 'development' && (
          <Box sx={{ mt: 2, p: 2, bgcolor: 'grey.100', borderRadius: 1 }}>
            <Typography variant="caption" color="text.secondary">
              Debug: isAuthenticated={String(isAuthenticated)}, token={token ? 'présent' : 'absent'}
            </Typography>
          </Box>
        )}
      </Box>
    );
  }

  // Afficher l'erreur si présente
  if (error) {
    return (
      <Alert severity="error" sx={{ mb: 3 }}>
        {error}
      </Alert>
    );
  }

  // Afficher le loading
  if (loading) {
    return (
      <Box sx={{ textAlign: 'center', py: 4 }}>
        <CircularProgress />
        <Typography variant="body1" sx={{ mt: 2 }}>
          Chargement des types de fichiers...
        </Typography>
      </Box>
    );
  }

  if (configs.length === 0) {
    return (
      <Alert severity="info" sx={{ mb: 3 }}>
        Aucun type de fichier client configuré. Veuillez contacter l'administrateur.
      </Alert>
    );
  }

  return (
    <Box>
      <Typography variant="h6" gutterBottom>
        Sélectionnez le type de fichier client à importer
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Choisissez le type de données client que vous souhaitez importer. Chaque type a ses propres règles de validation.
      </Typography>

      <Grid container spacing={3}>
        {configs.map((config) => (
          <Grid item xs={12} sm={6} md={4} key={config.type_code}>
            <Card 
              sx={{ 
                height: '100%',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                border: selectedType === config.type_code ? '2px solid' : '1px solid',
                borderColor: selectedType === config.type_code ? 'primary.main' : 'divider',
                '&:hover': {
                  transform: 'translateY(-4px)',
                  boxShadow: 4,
                  borderColor: 'primary.main'
                }
              }}
              onClick={() => handleTypeSelect(config)}
            >
              <CardHeader
                avatar={
                  <Avatar sx={{ bgcolor: 'primary.main' }}>
                    {getIconComponent(config.icon)}
                  </Avatar>
                }
                title={config.display_name}
                subheader={`Type: ${config.type_code}`}
                titleTypographyProps={{ variant: 'h6', fontSize: '1rem' }}
                subheaderTypographyProps={{ fontSize: '0.8rem' }}
              />
              
              <CardContent sx={{ pt: 0 }}>
                <Typography variant="body2" color="text.secondary" gutterBottom>
                  {config.description}
                </Typography>
                
                {/* Informations sur les colonnes */}
                <Box sx={{ mt: 2 }}>
                  <Chip 
                    label={`${config.required_columns.length} col. requises`}
                    size="small" 
                    color="primary"
                    variant="outlined"
                    sx={{ mr: 1, mb: 1 }}
                  />
                  <Chip 
                    label={`Max ${config.max_file_size_mb}MB`}
                    size="small"
                    color="secondary"
                    variant="outlined"
                    sx={{ mb: 1 }}
                  />
                </Box>

                {/* Aperçu des colonnes requises */}
                <Box sx={{ mt: 2 }}>
                  <Typography variant="caption" display="block" color="text.secondary">
                    Colonnes requises:
                  </Typography>
                  <Typography 
                    variant="body2" 
                    sx={{ 
                      fontFamily: 'monospace', 
                      fontSize: '0.75rem',
                      backgroundColor: 'grey.100',
                      p: 1,
                      borderRadius: 1,
                      mt: 0.5
                    }}
                  >
                    {config.required_columns.join(', ')}
                  </Typography>
                </Box>

                {/* Extensions supportées */}
                <Box sx={{ mt: 1 }}>
                  <Typography variant="caption" display="block" color="text.secondary">
                    Formats supportés:
                  </Typography>
                  <Box sx={{ mt: 0.5 }}>
                    {config.allowed_extensions.map((ext) => (
                      <Chip
                        key={ext}
                        label={ext.toUpperCase()}
                        size="small"
                        variant="outlined"
                        sx={{ mr: 0.5, fontSize: '0.7rem', height: 20 }}
                      />
                    ))}
                  </Box>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>

      {selectedType && (
        <Box sx={{ mt: 3 }}>
          <Alert severity="info">
            Type sélectionné: <strong>{configs.find(c => c.type_code === selectedType)?.display_name}</strong>
          </Alert>
        </Box>
      )}
    </Box>
  );
};

export default ClientFileTypeSelector; 