import { Alert, Box, Chip, Paper, Typography } from '@mui/material';
import React from 'react';
import { useSelector } from 'react-redux';
import { RootState } from '../../store';

const AuthDebugger: React.FC = () => {
  const { isAuthenticated, token, user, status } = useSelector((state: RootState) => state.auth);

  // Ne pas afficher en production
  if (process.env.NODE_ENV === 'production') {
    return null;
  }

  const tokenInfo = token ? {
    length: token.length,
    startsWith: token.substring(0, 20) + '...',
    hasExp: token.includes('.') && token.split('.').length === 3
  } : null;

  return (
    <Paper sx={{ p: 2, m: 2, bgcolor: 'grey.50', border: '1px solid grey.300' }}>
      <Typography variant="h6" gutterBottom>
        🔍 Debug Authentification
      </Typography>
      
      <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mb: 2 }}>
        <Chip 
          label={`Status: ${status}`} 
          color={status === 'succeeded' ? 'success' : status === 'loading' ? 'warning' : 'error'}
          size="small"
        />
        <Chip 
          label={`Authentifié: ${isAuthenticated ? 'Oui' : 'Non'}`} 
          color={isAuthenticated ? 'success' : 'error'}
          size="small"
        />
        <Chip 
          label={`Token: ${token ? 'Présent' : 'Absent'}`} 
          color={token ? 'success' : 'error'}
          size="small"
        />
      </Box>

      {user && (
        <Alert severity="info" sx={{ mb: 2 }}>
          <strong>Utilisateur:</strong> {user.username} ({user.role})
        </Alert>
      )}

      {tokenInfo && (
        <Box sx={{ mb: 2 }}>
          <Typography variant="body2" color="text.secondary">
            <strong>Token JWT:</strong>
          </Typography>
          <Typography variant="caption" component="div">
            Longueur: {tokenInfo.length} caractères
          </Typography>
          <Typography variant="caption" component="div">
            Début: {tokenInfo.startsWith}
          </Typography>
          <Typography variant="caption" component="div">
            Format valide: {tokenInfo.hasExp ? '✅' : '❌'}
          </Typography>
        </Box>
      )}

      {!token && (
        <Alert severity="warning">
          Aucun token JWT trouvé dans le localStorage
        </Alert>
      )}

      {!isAuthenticated && (
        <Alert severity="error">
          L'utilisateur n'est pas authentifié
        </Alert>
      )}
    </Paper>
  );
};

export default AuthDebugger;







