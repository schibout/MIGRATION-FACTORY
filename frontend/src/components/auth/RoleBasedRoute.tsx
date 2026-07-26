import { Home as HomeIcon, Lock as LockIcon } from '@mui/icons-material';
import { Box, Button, Paper, Typography } from '@mui/material';
import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';

interface RoleBasedRouteProps {
  children: React.ReactElement;
  requiredRoles?: ('admin' | 'operator')[];
  fallbackPath?: string;
  showFallback?: boolean;
}

const RoleBasedRoute: React.FC<RoleBasedRouteProps> = ({
  children,
  requiredRoles = [],
  fallbackPath = '/',
  showFallback = true
}) => {
  const { user, isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  // Afficher un loading pendant la vérification
  if (isLoading) {
    return <Box>Chargement...</Box>;
  }

  // Rediriger vers login si non authentifié
  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  // Vérifier les rôles requis
  if (requiredRoles.length > 0 && user) {
    const hasRequiredRole = requiredRoles.includes(user.role);
    if (!hasRequiredRole) {
      if (!showFallback) {
        return <Navigate to={fallbackPath} replace />;
      }
      
      return (
        <Box
          sx={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            minHeight: '60vh',
            p: 3
          }}
        >
          <Paper
            elevation={3}
            sx={{
              p: 4,
              textAlign: 'center',
              maxWidth: 500,
              width: '100%'
            }}
          >
            <LockIcon sx={{ fontSize: 60, color: 'warning.main', mb: 2 }} />
            <Typography variant="h5" gutterBottom color="warning.main">
              Accès Restreint
            </Typography>
            <Typography variant="body1" sx={{ mb: 3 }}>
              Vous n'avez pas les permissions nécessaires pour accéder à cette page.
            </Typography>
            <Typography variant="body2" sx={{ mb: 3, color: 'text.secondary' }}>
              Rôles requis: {requiredRoles.join(', ')}
              <br />
              Votre rôle: {user.role}
            </Typography>
            <Button
              variant="contained"
              startIcon={<HomeIcon />}
              onClick={() => window.location.href = fallbackPath}
              sx={{ mt: 2 }}
            >
              Retour à l'accueil
            </Button>
          </Paper>
        </Box>
      );
    }
  }

  // Rendre le composant enfant si toutes les vérifications passent
  return children;
};

export default RoleBasedRoute; 