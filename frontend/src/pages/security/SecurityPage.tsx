import {
    Person as PersonIcon,
    Settings as SettingsIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Paper,
    Snackbar,
    Tab,
    Tabs,
    Typography,
    useTheme
} from '@mui/material';
import React, { useState } from 'react';
import { useAuth } from '../../hooks/useAuth';
import UsersManagement from '../UsersManagement';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`security-tabpanel-${index}`}
      aria-labelledby={`security-tab-${index}`}
      {...other}
    >
      {value === index && (
        <Box sx={{ p: 3 }}>
          {children}
        </Box>
      )}
    </div>
  );
}

function a11yProps(index: number) {
  return {
    id: `security-tab-${index}`,
    'aria-controls': `security-tabpanel-${index}`,
  };
}

const SecurityPage: React.FC = () => {
  const theme = useTheme();
  const { isAdmin } = useAuth();
  const [value, setValue] = useState(0);
  const [notification, setNotification] = useState<{message: string, type: 'success' | 'error' | 'info'} | null>(null);

  const handleChange = (event: React.SyntheticEvent, newValue: number) => {
    setValue(newValue);
  };

  // Fermeture des notifications
  const handleCloseNotification = () => {
    setNotification(null);
  };

  // Vérifier que l'utilisateur est admin
  if (!isAdmin) {
    return (
      <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 3 }}>
        <Box mt={4}>
          <Alert severity="error">
            Accès refusé. Cette page est réservée aux administrateurs.
          </Alert>
        </Box>
      </Box>
    );
  }

  return (
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 3 }}>
      <Box mb={4}>
        <Typography variant="h4" component="h1" gutterBottom>
          Sécurité
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Gérez les utilisateurs de l'application et leurs accès.
        </Typography>
      </Box>

      <Paper 
        elevation={2} 
        sx={{ 
          borderRadius: '8px',
          mb: 4
        }}
      >
        <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tabs 
            value={value} 
            onChange={handleChange} 
            aria-label="security tabs"
            sx={{ 
              '& .MuiTab-root': { 
                py: 2 
              }
            }}
          >
            <Tab 
              label="Gestion des utilisateurs" 
              icon={<PersonIcon />} 
              iconPosition="start" 
              {...a11yProps(0)} 
              sx={{ textTransform: 'none' }}
            />
            <Tab 
              label="Paramètres de sécurité" 
              icon={<SettingsIcon />} 
              iconPosition="start" 
              {...a11yProps(1)} 
              sx={{ textTransform: 'none' }}
            />
          </Tabs>
        </Box>
        
        <TabPanel value={value} index={0}>
          <UsersManagement />
        </TabPanel>
        
        <TabPanel value={value} index={1}>
          <Box sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              Paramètres de sécurité
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
              Configuration des paramètres de sécurité du système.
            </Typography>
            
            <Alert severity="info">
              Les paramètres de sécurité avancés seront disponibles dans une prochaine version.
              <br />
              Actuellement, la sécurité est gérée via :
              <ul>
                <li>Authentification JWT avec access et refresh tokens</li>
                <li>Système de rôles Admin/Operator</li>
                <li>Protection des routes côté frontend et backend</li>
                <li>Hashage sécurisé des mots de passe</li>
              </ul>
            </Alert>
          </Box>
        </TabPanel>
      </Paper>

      {/* Notifications système */}
      <Snackbar 
        open={!!notification} 
        autoHideDuration={6000} 
        onClose={handleCloseNotification}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        {notification && (
          <Alert onClose={handleCloseNotification} severity={notification.type} sx={{ width: '100%' }}>
            {notification.message}
          </Alert>
        )}
      </Snackbar>
    </Box>
  );
};

export default SecurityPage;
