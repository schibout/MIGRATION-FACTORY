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
    ShoppingCart as AchatsIcon,
    Inventory as ArticleIcon,
    TableChart as CatalogIcon,
    People as ClientIcon,
    Business as FournisseurIcon,
    Handyman as MaintenanceIcon,
    Search as ExplorerIcon,
    AccountBalance as ComptabiliteIcon,
} from '@mui/icons-material';

// Type pour les éléments du menu de données SAP
interface SapDataMenuItem {
  title: string;
  path: string;
  icon: React.ReactNode;
  description: string;
}

const SapData: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isMedium = useMediaQuery(theme.breakpoints.down('md'));

  // Liste des éléments du menu de données SAP
  const sapDataItems: SapDataMenuItem[] = [
    {
      title: 'Fournisseurs',
      path: '/sap-data/fournisseurs',
      icon: <FournisseurIcon sx={{ fontSize: 40, color: theme.palette.primary.main }} />,
      description: 'Données relatives aux fournisseurs extraites de SAP'
    },
    {
      title: 'Articles',
      path: '/sap-data/articles',
      icon: <ArticleIcon sx={{ fontSize: 40, color: '#f48fb1' }} />,
      description: 'Catalogue des articles extraits de SAP'
    },
    {
      title: 'Maintenance',
      path: '/sap-data/catalog?scope=maintenance',
      icon: <MaintenanceIcon sx={{ fontSize: 40, color: theme.palette.secondary.main }} />,
      description: 'Tables SAP liées à la maintenance (équipements, postes techniques…)'
    },
    {
      title: 'Clients',
      path: '/sap-data/catalog?scope=client',
      icon: <ClientIcon sx={{ fontSize: 40, color: '#4fc3f7' }} />,
      description: 'Catalogue des tables SAP liées aux clients (KNA1, extensions…) et consultation des données'
    },
    {
      title: 'Achats',
      path: '/sap-data/catalog?scope=achat',
      icon: <AchatsIcon sx={{ fontSize: 40, color: '#81c784' }} />,
      description: 'Tables SAP liées aux achats (commandes, demandes d\'achat…)'
    },
    {
      title: 'Comptabilité',
      path: '/sap-data/catalog?scope=comptabilite',
      icon: <ComptabiliteIcon sx={{ fontSize: 40, color: '#b39ddb' }} />,
      description: 'Tables SAP FI/CO : documents, GL, immobilisations, CO, paiements…'
    },
    {
      title: 'Catalogue Tables SAP',
      path: '/sap-data/catalog',
      icon: <CatalogIcon sx={{ fontSize: 40, color: '#ff9800' }} />,
      description: 'Structure et métadonnées des tables SAP'
    },
    {
      title: 'Explorateur',
      path: '/sap-data/explorer',
      icon: <ExplorerIcon sx={{ fontSize: 40, color: '#9c27b0' }} />,
      description: 'Explorez les données des tables SAP avec libellés métier'
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
        DONNÉES SAP
      </Typography>
      
      <Grid container spacing={3} sx={{ mt: 1 }}>
        {sapDataItems.map((item) => (
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

export default SapData; 