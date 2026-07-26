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
    Assignment,
    People as ClientIcon,
    Download as DownloadIcon,
    Business as FournisseurIcon,
    Handyman as MaintenanceIcon,
    Engineering as OperationIcon,
    Build as PmActionIcon,
    AccountTree as StructureIcon
} from '@mui/icons-material';

// Type pour les éléments du menu d'export
interface ExportMenuItem {
  title: string;
  path: string;
  icon: React.ReactNode;
  description: string;
  count?: number;
}

const ExportData: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isMedium = useMediaQuery(theme.breakpoints.down('md'));

  // Liste des éléments du menu d'export
  const exportItems: ExportMenuItem[] = [
    {
      title: 'Export Fournisseurs',
      path: '/export/fournisseurs',
      icon: <FournisseurIcon sx={{ fontSize: 40, color: '#3f51b5' }} />,
      description: 'Exporter les données des fournisseurs en CSV ou Excel'
    },
    {
      title: 'Export Articles',
      path: '/export/articles',
      icon: <ArticleIcon sx={{ fontSize: 40, color: '#4caf50' }} />,
      description: 'Exporter le catalogue d\'articles en CSV ou Excel'
    },
    {
      title: 'Export Clients',
      path: '/export/clients',
      icon: <ClientIcon sx={{ fontSize: 40, color: '#ff9800' }} />,
      description: 'Exporter les données clients en CSV ou Excel'
    },
    {
      title: 'Export Maintenance',
      path: '/export/maintenance',
      icon: <MaintenanceIcon sx={{ fontSize: 40, color: '#9c27b0' }} />,
      description: 'Exporter les données de maintenance en CSV ou Excel'
    },
    {
      title: 'Export Projets',
      path: '/export/projets',
      icon: <Assignment sx={{ fontSize: 40, color: '#673ab7' }} />,
      description: 'Exporter les données des projets en CSV ou Excel'
    },
    {
      title: 'Export Structure Maintenance',
      path: '/export/structure-maintenance',
      icon: <StructureIcon sx={{ fontSize: 40, color: '#00897b' }} />,
      description: 'Exporter la structure maintenance (postes techniques, équipements)'
    },
    {
      title: 'Export PM Action',
      path: '/export/pm-action',
      icon: <PmActionIcon sx={{ fontSize: 40, color: '#e91e63' }} />,
      description: 'Exporter les données PM Action (ordres / actions de maintenance) en CSV ou Excel'
    },
    {
      title: 'Export Opérations',
      path: '/export/operations',
      icon: <OperationIcon sx={{ fontSize: 40, color: '#795548' }} />,
      description: 'Exporter les opérations de maintenance (JT Task, ressources, besoins matière) en CSV ou Excel'
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
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
        <DownloadIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          EXPORT DES DONNÉES
        </Typography>
      </Box>
      
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Exportez vos données dans différents formats (CSV, Excel) pour analyse ou archivage.
      </Typography>
      
      <Grid container spacing={3}>
        {exportItems.map((item) => (
          <Grid item xs={getGridCols()} key={item.path}>
            <Card 
              sx={{ 
                height: '100%', 
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                position: 'relative',
                overflow: 'hidden',
                '&:hover': {
                  transform: 'translateY(-8px)',
                  boxShadow: '0 12px 32px rgba(0,0,0,0.15)',
                  '& .export-overlay': {
                    opacity: 1
                  }
                }
              }}
              onClick={() => navigate(item.path)}
            >
              {/* Overlay pour l'effet hover */}
              <Box 
                className="export-overlay"
                sx={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.1)}, ${alpha(theme.palette.secondary.main, 0.1)})`,
                  opacity: 0,
                  transition: 'opacity 0.3s ease',
                  zIndex: 1
                }}
              />
              
              <Box sx={{ 
                display: 'flex', 
                flexDirection: 'column',
                alignItems: 'center',
                textAlign: 'center',
                p: 4,
                position: 'relative',
                zIndex: 2
              }}>
                <Box 
                  sx={{ 
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    width: 90,
                    height: 90,
                    borderRadius: '50%',
                    backgroundColor: alpha(theme.palette.background.paper, 0.9),
                    mb: 3,
                    boxShadow: '0 4px 16px rgba(0,0,0,0.1)',
                    border: `2px solid ${alpha(theme.palette.divider, 0.1)}`
                  }}
                >
                  {item.icon}
                </Box>
                
                <Typography 
                  variant="h6" 
                  component="h2" 
                  sx={{ 
                    mb: 2,
                    fontWeight: 600,
                    color: theme.palette.text.primary
                  }}
                >
                  {item.title}
                </Typography>
                
                <Typography 
                  variant="body2" 
                  color="text.secondary"
                  sx={{
                    fontSize: '0.875rem',
                    lineHeight: 1.5,
                    maxWidth: '280px'
                  }}
                >
                  {item.description}
                </Typography>

                {/* Badge d'action */}
                <Box
                  sx={{
                    mt: 2,
                    px: 2,
                    py: 0.5,
                    borderRadius: '16px',
                    backgroundColor: alpha(theme.palette.primary.main, 0.1),
                    border: `1px solid ${alpha(theme.palette.primary.main, 0.2)}`
                  }}
                >
                  <Typography
                    variant="caption"
                    sx={{
                      color: theme.palette.primary.main,
                      fontWeight: 500,
                      fontSize: '0.75rem'
                    }}
                  >
                    Cliquez pour exporter
                  </Typography>
                </Box>
              </Box>
            </Card>
          </Grid>
        ))}
      </Grid>

      {/* Section d'information supplémentaire */}
      <Box sx={{ mt: 6, p: 3, backgroundColor: alpha(theme.palette.info.main, 0.05), borderRadius: 2 }}>
        <Typography variant="h6" sx={{ mb: 2, color: theme.palette.info.main }}>
          Informations sur l'export
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <Typography variant="body2" color="text.secondary">
              • Formats supportés : CSV, Excel (XLSX)
            </Typography>
            <Typography variant="body2" color="text.secondary">
              • Filtrage des données par critères
            </Typography>
          </Grid>
          <Grid item xs={12} sm={6}>
            <Typography variant="body2" color="text.secondary">
              • Export avec ou sans en-têtes
            </Typography>
            <Typography variant="body2" color="text.secondary">
              • Téléchargement automatique du fichier
            </Typography>
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
};

export default ExportData; 