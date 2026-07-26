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
    Inventory as ArticleIcon,
    MenuBook as CatalogIcon,
    People as ClientIcon,
    Business as FournisseurIcon,
    Handyman as MaintenanceIcon,
    Assignment as ProjetIcon,
    AccountTree as StructureIcon
} from '@mui/icons-material';

// Type pour les éléments du menu de données IFS
interface IfsMenuItem {
  id: string;
  title: string;
  description: string;
  path: string;
  icon: JSX.Element;
  color: string;
}

const IfsData = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  
  // Menu des données IFS avec items organisés en catégories
  const ifsMenuItems: IfsMenuItem[] = [
    {
      id: 'catalog',
      title: 'Catalogue IFS',
      description: 'Dictionnaire des specs IFS : lots, entités, champs et règles de gestion',
      path: '/ifs-data/catalog',
      icon: <CatalogIcon sx={{ fontSize: 36 }} />,
      color: '#009688' // Teal
    },
    {
      id: 'fournisseurs',
      title: 'Fournisseurs',
      description: 'Données des fournisseurs IFS',
      path: '/ifs-data/fournisseurs',
      icon: <FournisseurIcon sx={{ fontSize: 36 }} />,
      color: '#3f51b5' // Bleu indigo
    },
    {
      id: 'articles',
      title: 'Articles',
      description: 'Catalogue des articles et références',
      path: '/ifs-data/articles',
      icon: <ArticleIcon sx={{ fontSize: 36 }} />,
      color: '#4caf50' // Vert
    },
    {
      id: 'clients',
      title: 'Clients',
      description: 'Données clients IFS',
      path: '/ifs-data/clients',
      icon: <ClientIcon sx={{ fontSize: 36 }} />,
      color: '#ff9800' // Orange
    },
    {
      id: 'maintenance',
      title: 'Maintenance',
      description: 'Données de maintenance IFS',
      path: '/ifs-data/maintenance',
      icon: <MaintenanceIcon sx={{ fontSize: 36 }} />,
      color: '#9c27b0' // Violet
    },
    {
      id: 'projets',
      title: 'Projets',
      description: 'Gestion des projets IFS',
      path: '/ifs-data/projets',
      icon: <ProjetIcon sx={{ fontSize: 36 }} />,
      color: '#f44336' // Rouge
    },
    {
      id: 'structure',
      title: 'Structure',
      description: 'Structure organisationnelle',
      path: '/ifs-data/structure',
      icon: <StructureIcon sx={{ fontSize: 36 }} />,
      color: '#2196f3' // Bleu
    }
  ];

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        Données IFS
      </Typography>
      
      <Typography variant="body1" paragraph sx={{ mb: 4 }}>
        Accédez aux différentes catégories de données IFS pour consultation et modification.
      </Typography>
      
      <Grid container spacing={3}>
        {ifsMenuItems.map((item) => (
          <Grid item xs={12} sm={6} md={4} key={item.id}>
            <Card 
              sx={{ 
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                cursor: 'pointer',
                transition: 'transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out',
                '&:hover': {
                  transform: 'translateY(-4px)',
                  boxShadow: theme.shadows[6],
                },
                borderLeft: `6px solid ${item.color}`,
                boxShadow: theme.shadows[3]
              }}
              onClick={() => navigate(item.path)}
            >
              <Box
                sx={{
                  p: 3,
                  display: 'flex',
                  flexDirection: 'column',
                  height: '100%'
                }}
              >
                <Box
                  sx={{
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center',
                    backgroundColor: alpha(item.color, 0.1),
                    borderRadius: '50%',
                    width: 64,
                    height: 64,
                    mb: 2,
                    color: item.color
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

export default IfsData; 