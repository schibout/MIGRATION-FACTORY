import {
    alpha,
    Box,
    Card,
    Grid,
    Typography,
    useMediaQuery,
    useTheme,
} from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

import {
    SmartToy as AssistantIcon,
    Tune as ConfigIcon,
    Psychology as HermesIcon,
    TableChart as ResultatsIcon,
} from '@mui/icons-material';

interface AiMenuItem {
  title: string;
  path: string;
  icon: React.ReactNode;
  description: string;
}

const IntelligenceArtificielle: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
  const isMedium = useMediaQuery(theme.breakpoints.down('md'));

  const items: AiMenuItem[] = [
    {
      title: 'Assistant IA',
      path: '/assistant-ia',
      icon: <AssistantIcon sx={{ fontSize: 40, color: theme.palette.primary.main }} />,
      description: 'Posez vos questions en français : l’assistant génère le SQL et affiche les résultats.',
    },
    {
      title: 'Résultats IA',
      path: '/resultats-ia',
      icon: <ResultatsIcon sx={{ fontSize: 40, color: theme.palette.secondary.main }} />,
      description: 'Historique des requêtes, rejeu, édition du SQL et export des résultats.',
    },
    {
      title: 'Configuration IA',
      path: '/configuration-ia',
      icon: <ConfigIcon sx={{ fontSize: 40, color: '#4fc3f7' }} />,
      description: 'Mots-clés ↔ tables, packs de connaissances, few-shots et inspecteur de prompt.',
    },
    {
      title: 'Agent Trimet',
      path: '/hermes',
      icon: <HermesIcon sx={{ fontSize: 40, color: '#ce93d8' }} />,
      description: 'Agent IA outillé (terminal, fichiers, web…) : chat en streaming, analyse de fichiers, jobs planifiés.',
    },
  ];

  const getGridCols = () => {
    if (isMobile) return 12;
    if (isMedium) return 6;
    return 4;
  };

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Typography variant="h4" component="h1" gutterBottom>
        INTELLIGENCE ARTIFICIELLE
      </Typography>

      <Grid container spacing={3} sx={{ mt: 1 }}>
        {items.map((item) => (
          <Grid item xs={getGridCols()} key={item.path}>
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
              <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', p: 3 }}>
                <Box
                  sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    width: 80,
                    height: 80,
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

export default IntelligenceArtificielle;
