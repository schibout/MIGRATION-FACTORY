import {
    alpha,
    Box,
    Card,
    Grid,
    Typography,
    useMediaQuery,
    useTheme
} from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

// Import des icônes
import {
    Email as EmailIcon,
    FileDownload as ExportIcon,
    FileUpload as ImportIcon,
    List as ListesValeursIcon,
    CompareArrows as MappingChampsIcon,
    Tune as ParametresIcon,
    Rule as ReglesGestionIcon,
    Security as SecurityIcon,
    TableChart as TableStructureIcon,
    Compare as TranscodificationIcon,
    SettingsSuggest as ValeursDefautIcon
} from '@mui/icons-material';

// Type pour les éléments du menu de configuration
interface ConfigMenuItem {
  title: string;
  path: string;
  icon: React.ReactNode;
  description: string;
}

const Configuration: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isMedium = useMediaQuery(theme.breakpoints.down('md'));

  // Liste des éléments du menu de configuration
  const configItems: ConfigMenuItem[] = [
    {
      title: 'Transcodification',
      path: '/transcodification',
      icon: <TranscodificationIcon sx={{ fontSize: 40, color: theme.palette.primary.main }} />,
      description: 'Gérez les règles de transcodification des données'
    },
    {
      title: 'Mapping des champs',
      path: '/mapping-champs',
      icon: <MappingChampsIcon sx={{ fontSize: 40, color: theme.palette.secondary.main }} />,
      description: 'Configurer les mappings entre les champs sources et cibles'
    },
    {
      title: 'Configuration des exports',
      path: '/admin/export-queries',
      icon: <ExportIcon sx={{ fontSize: 40, color: '#4caf50' }} />,
      description: 'Gérer les requêtes SQL d\'export et les tables de destination'
    },
    {
      title: 'Configuration des imports',
      path: '/admin/import-types',
      icon: <ImportIcon sx={{ fontSize: 40, color: '#ff7043' }} />,
      description: 'Configurer les types de fichiers d\'import et leurs règles de validation'
    },
    {
      title: 'Règles de gestion',
      path: '/regles-gestion',
      icon: <ReglesGestionIcon sx={{ fontSize: 40, color: '#ffb74d' }} />,
      description: 'Définition des règles métier et validations'
    },
    {
      title: 'Paramètres',
      path: '/parametres',
      icon: <ParametresIcon sx={{ fontSize: 40, color: '#f48fb1' }} />,
      description: 'Paramètres système et configuration générale'
    },
    {
      title: 'Listes de valeurs',
      path: '/listes-valeurs',
      icon: <ListesValeursIcon sx={{ fontSize: 40, color: '#4fc3f7' }} />,
      description: 'Gestion des listes de valeurs et référentiels'
    },
    {
      title: 'Sécurité',
      path: '/configuration/security',
      icon: <SecurityIcon sx={{ fontSize: 40, color: '#81c784' }} />,
      description: 'Gestion des utilisateurs et des permissions'
    },
    {
      title: 'Structure de Tables',
      path: '/configuration/table-structure',
      icon: <TableStructureIcon sx={{ fontSize: 40, color: '#ab47bc' }} />,
      description: 'Importer et gérer les structures de tables depuis Excel'
    },
    {
      title: 'Configuration SMTP',
      path: '/configuration/smtp',
      icon: <EmailIcon sx={{ fontSize: 40, color: '#ef5350' }} />,
      description: 'Configurer le serveur SMTP pour l\'envoi d\'emails (mot de passe oublié)'
    },
    {
      title: 'Valeurs par défaut',
      path: '/configuration/valeurs-defaut',
      icon: <ValeursDefautIcon sx={{ fontSize: 40, color: '#9575cd' }} />,
      description: 'Gérer les valeurs par défaut utilisées par les chargements ETL'
    }
  ];

  // Déterminer le nombre de colonnes en fonction de la taille de l'écran
  const getGridCols = () => {
    if (isMobile) return 12; // 1 carte par ligne sur mobile
    if (isMedium) return 6;  // 2 cartes par ligne sur tablette
    return 4;                // 3 cartes par ligne sur desktop
  };

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        CONFIGURATION
      </Typography>
      
      <Grid container spacing={3} sx={{ mt: 1 }}>
        {configItems.map((item) => (
          <Grid item xs={getGridCols()} key={item.path}>
            <Card 
              sx={{ 
                height: '100%', 
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-5px)',
                  boxShadow: '0 8px 24px 0 rgba(0,0,0,0.3)',
                  border: `1px solid ${alpha(theme.palette.primary.main, 0.5)}`
                }
              }}
              onClick={() => navigate(item.path)}
            >
              <Box sx={{ 
                display: 'flex', 
                flexDirection: 'column',
                alignItems: 'center',
                textAlign: 'center',
                p: 3
              }}>
                <Box 
                  sx={{ 
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    width: 80,
                    height: 80,
                    borderRadius: '50%',
                    backgroundColor: alpha(theme.palette.background.default, 0.8),
                    mb: 2
                  }}
                >
                  {item.icon}
                </Box>
                
                <Typography 
                  variant="h6" 
                  component="h2" 
                  sx={{ 
                    mb: 1,
                    fontWeight: 500
                  }}
                >
                  {item.title}
                </Typography>
                
                <Typography 
                  variant="body2" 
                  color="text.secondary"
                  sx={{
                    fontSize: '0.875rem'
                  }}
                >
                  {item.description}
                </Typography>
              </Box>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};

export default Configuration; 