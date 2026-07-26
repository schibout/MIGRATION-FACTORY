import { alpha, Box, Card, Grid, Typography, useTheme } from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  CloudDownload as DataIcon,
  DataObject as MetaIcon,
} from '@mui/icons-material';

interface HubItem {
  title: string;
  path: string;
  icon: React.ReactNode;
  description: string;
}

const ExtractionHub: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();

  const items: HubItem[] = [
    {
      title: 'Chargement des données',
      path: '/extraction/data',
      icon: <DataIcon sx={{ fontSize: 44, color: theme.palette.primary.main }} />,
      description: "Extraire les données des tables SAP vers PostgreSQL (lancement, suivi live, historique).",
    },
    {
      title: 'Chargement des métadonnées',
      path: '/extraction/metadata',
      icon: <MetaIcon sx={{ fontSize: 44, color: '#ff9800' }} />,
      description: "Extraire la structure des tables SAP (types, clés, relations). À faire avant d'extraire une table jamais vue.",
    },
  ];

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        EXTRACTION
      </Typography>

      <Grid container spacing={3} sx={{ mt: 1 }}>
        {items.map((item) => (
          <Grid item xs={12} sm={6} md={5} key={item.path}>
            <Card
              sx={{
                height: '100%',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                '&:hover': {
                  transform: 'translateY(-5px)',
                  boxShadow: '0 8px 24px 0 rgba(0,0,0,0.3)',
                  border: `1px solid ${alpha(theme.palette.primary.main, 0.5)}`,
                },
              }}
              onClick={() => navigate(item.path)}
            >
              <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', p: 4 }}>
                <Box
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    width: 88,
                    height: 88,
                    borderRadius: '50%',
                    backgroundColor: alpha(theme.palette.background.default, 0.8),
                    mb: 2,
                  }}
                >
                  {item.icon}
                </Box>
                <Typography variant="h6" component="h2" sx={{ mb: 1, fontWeight: 500 }}>
                  {item.title}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ fontSize: '0.875rem' }}>
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

export default ExtractionHub;
