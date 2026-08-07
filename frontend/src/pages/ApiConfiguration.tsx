import React, { useState } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  TextField,
  Button,
  Switch,
  FormControlLabel,
  Divider,
  Alert,
  Chip,
  Stack,
  IconButton,
  useTheme
} from '@mui/material';
import {
  Save as SaveIcon,
  Refresh as RefreshIcon,
  PlayArrow as TestIcon,
  CheckCircle as CheckIcon,
  Error as ErrorIcon
} from '@mui/icons-material';
import { API_URL } from '../config';

interface ApiEndpoint {
  name: string;
  url: string;
  method: string;
  status: 'active' | 'inactive' | 'error';
}

const ApiConfiguration: React.FC = () => {
  const theme = useTheme();
  
  // État pour les configurations API
  const [apiConfig, setApiConfig] = useState({
    // L'API est servie sur la meme origine que le frontend (reverse proxy nginx).
    baseUrl: window.location.origin,
    timeout: 30000,
    retryAttempts: 3,
    enableLogging: true,
    enableCache: false
  });

  const [testResults, setTestResults] = useState<{ [key: string]: boolean }>({});
  const [isLoading, setIsLoading] = useState(false);

  // Endpoints API principaux
  const apiEndpoints: ApiEndpoint[] = [
    { name: 'SAP Views', url: '/api/v1/data/sap-views', method: 'GET', status: 'active' },
    { name: 'IFS Data', url: '/api/v1/data/ifs-data', method: 'GET', status: 'active' },
    { name: 'Field Mappings', url: '/api/v1/mappings', method: 'GET', status: 'active' },
    { name: 'Transcodifications', url: '/api/v1/transcodifications', method: 'GET', status: 'active' },
    { name: 'Health Check', url: '/api/v1/health', method: 'GET', status: 'active' }
  ];

  const handleConfigChange = (field: string, value: any) => {
    setApiConfig(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const handleSaveConfig = () => {
    setIsLoading(true);
    // Simuler une sauvegarde
    setTimeout(() => {
      setIsLoading(false);
      alert('Configuration sauvegardée avec succès !');
    }, 1000);
  };

  const handleTestEndpoint = async (endpoint: ApiEndpoint) => {
    setIsLoading(true);
    try {
      // Simulation d'un test d'endpoint
      const response = await fetch(apiConfig.baseUrl + endpoint.url);
      const isSuccess = response.ok;
      setTestResults(prev => ({
        ...prev,
        [endpoint.name]: isSuccess
      }));
    } catch (error) {
      setTestResults(prev => ({
        ...prev,
        [endpoint.name]: false
      }));
    } finally {
      setIsLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'success';
      case 'inactive': return 'warning';
      case 'error': return 'error';
      default: return 'default';
    }
  };

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        Configuration API
      </Typography>
      
      <Grid container spacing={3}>
        {/* Configuration générale */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Configuration générale
              </Typography>
              
              <Stack spacing={3}>
                <TextField
                  fullWidth
                  label="URL de base"
                  value={apiConfig.baseUrl}
                  onChange={(e) => handleConfigChange('baseUrl', e.target.value)}
                  helperText="URL de base pour toutes les requêtes API"
                />
                
                <TextField
                  fullWidth
                  label="Timeout (ms)"
                  type="number"
                  value={apiConfig.timeout}
                  onChange={(e) => handleConfigChange('timeout', parseInt(e.target.value))}
                  helperText="Délai d'expiration des requêtes en millisecondes"
                />
                
                <TextField
                  fullWidth
                  label="Tentatives de retry"
                  type="number"
                  value={apiConfig.retryAttempts}
                  onChange={(e) => handleConfigChange('retryAttempts', parseInt(e.target.value))}
                  helperText="Nombre de tentatives en cas d'échec"
                />
                
                <FormControlLabel
                  control={
                    <Switch
                      checked={apiConfig.enableLogging}
                      onChange={(e) => handleConfigChange('enableLogging', e.target.checked)}
                    />
                  }
                  label="Activer les logs détaillés"
                />
                
                <FormControlLabel
                  control={
                    <Switch
                      checked={apiConfig.enableCache}
                      onChange={(e) => handleConfigChange('enableCache', e.target.checked)}
                    />
                  }
                  label="Activer le cache des réponses"
                />
                
                <Button
                  variant="contained"
                  startIcon={<SaveIcon />}
                  onClick={handleSaveConfig}
                  disabled={isLoading}
                  fullWidth
                >
                  Sauvegarder la configuration
                </Button>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        {/* État des endpoints */}
        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                État des endpoints
              </Typography>
              
              <Stack spacing={2}>
                {apiEndpoints.map((endpoint) => (
                  <Box key={endpoint.name}>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1 }}>
                      <Typography variant="subtitle2">
                        {endpoint.name}
                      </Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip
                          label={endpoint.status}
                          color={getStatusColor(endpoint.status) as any}
                          size="small"
                        />
                        <IconButton
                          size="small"
                          onClick={() => handleTestEndpoint(endpoint)}
                          disabled={isLoading}
                        >
                          <TestIcon />
                        </IconButton>
                        {testResults[endpoint.name] !== undefined && (
                          testResults[endpoint.name] ? 
                            <CheckIcon color="success" /> : 
                            <ErrorIcon color="error" />
                        )}
                      </Box>
                    </Box>
                    
                    <Typography variant="caption" color="text.secondary">
                      {endpoint.method} {endpoint.url}
                    </Typography>
                    
                    <Divider sx={{ mt: 1 }} />
                  </Box>
                ))}
              </Stack>
              
              <Button
                variant="outlined"
                startIcon={<RefreshIcon />}
                fullWidth
                sx={{ mt: 2 }}
                onClick={() => {
                  apiEndpoints.forEach(endpoint => handleTestEndpoint(endpoint));
                }}
                disabled={isLoading}
              >
                Tester tous les endpoints
              </Button>
            </CardContent>
          </Card>
        </Grid>

        {/* Informations système */}
        <Grid item xs={12}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Informations système
              </Typography>
              
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6} md={3}>
                  <Alert severity="info">
                    <Typography variant="caption">URL API actuelle</Typography>
                    <Typography variant="body2">{API_URL}</Typography>
                  </Alert>
                </Grid>
                
                <Grid item xs={12} sm={6} md={3}>
                  <Alert severity="success">
                    <Typography variant="caption">Mode</Typography>
                    <Typography variant="body2">Développement</Typography>
                  </Alert>
                </Grid>
                
                <Grid item xs={12} sm={6} md={3}>
                  <Alert severity="warning">
                    <Typography variant="caption">Dernière synchronisation</Typography>
                    <Typography variant="body2">{new Date().toLocaleString()}</Typography>
                  </Alert>
                </Grid>
                
                <Grid item xs={12} sm={6} md={3}>
                  <Alert severity="info">
                    <Typography variant="caption">Version API</Typography>
                    <Typography variant="body2">v1.0.0</Typography>
                  </Alert>
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default ApiConfiguration; 