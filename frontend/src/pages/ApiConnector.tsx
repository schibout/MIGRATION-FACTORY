import React from 'react';
import {
  Box,
  Typography,
  Container,
  Card,
  CardContent,
  Paper,
  TextField,
  Button,
  Grid,
  Divider,
  Alert,
} from '@mui/material';

const ApiConnector = () => {
  return (
    <Container maxWidth="xl">
      <Box sx={{ mt: 4, mb: 3 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Connecteur API
        </Typography>
        <Typography variant="subtitle1" color="text.secondary" gutterBottom>
          Configuration des connexions avec les API externes
        </Typography>
      </Box>

      <Card>
        <CardContent>
          <Alert severity="info" sx={{ mb: 3 }}>
            Cette fonctionnalité est en cours de développement. Veuillez consulter la documentation pour plus d'informations.
          </Alert>
          
          <Paper sx={{ p: 3, mb: 4 }}>
            <Typography variant="h6" gutterBottom>
              Configurer une nouvelle connexion API
            </Typography>
            <Divider sx={{ mb: 3 }} />
            
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Nom de la connexion"
                  variant="outlined"
                  placeholder="ex: SAP Production"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="URL de base"
                  variant="outlined"
                  placeholder="ex: https://api.example.com/v1"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Clé API"
                  variant="outlined"
                  type="password"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Secret API"
                  variant="outlined"
                  type="password"
                />
              </Grid>
              <Grid item xs={12}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 2 }}>
                  <Button variant="contained" color="primary">
                    Enregistrer la configuration
                  </Button>
                </Box>
              </Grid>
            </Grid>
          </Paper>
          
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Tester la connexion
            </Typography>
            <Divider sx={{ mb: 3 }} />
            
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Endpoint à tester"
                  variant="outlined"
                  placeholder="ex: /users"
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Méthode"
                  variant="outlined"
                  defaultValue="GET"
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  fullWidth
                  label="Paramètres (JSON)"
                  variant="outlined"
                  multiline
                  rows={4}
                  placeholder='{"param1": "value1", "param2": "value2"}'
                />
              </Grid>
              <Grid item xs={12}>
                <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 2 }}>
                  <Button variant="outlined" color="primary" sx={{ mr: 2 }}>
                    Réinitialiser
                  </Button>
                  <Button variant="contained" color="primary">
                    Tester la connexion
                  </Button>
                </Box>
              </Grid>
            </Grid>
          </Paper>
        </CardContent>
      </Card>
    </Container>
  );
};

export default ApiConnector; 