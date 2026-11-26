import React, { useEffect, useState } from 'react';
import { Box, Typography, Card, CardContent, CardActionArea, Grid, useTheme, alpha, Chip, Button } from '@mui/material';
import { LinkOff as SansArticleIcon, ArrowBack } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

// Chaque controle ouvre l'ecran Equipements filtre sur une anomalie
// (cles ANOMALIES de backend/api/equipment_browser.py) : tableau, correction et export Excel.
const controles = [
  {
    cle: 'sans_article',
    title: 'Équipements sans article',
    description: 'Équipements liés ni à un article ni à un type de construction. Exporter la liste pour la compléter, puis la réimporter ou lier chaque équipement depuis le tableau.',
    icon: SansArticleIcon,
    color: 'warning' as const,
  },
];

const MaintenanceControlesPage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const [counts, setCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    controles.forEach(async (c) => {
      try {
        const res = await api.get('/maintenance/equipment-browser', { params: { anomalie: c.cle, page_size: 1 } });
        setCounts((prev) => ({ ...prev, [c.cle]: Number(res.data?.total ?? 0) }));
      } catch { /* compteur facultatif */ }
    });
  }, []);

  return (
    <Box sx={{ p: 3 }}>
      <Button startIcon={<ArrowBack />} onClick={() => navigate('/maintenance')} sx={{ mb: 1 }}>Maintenance</Button>
      <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Contrôles maintenance</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Contrôles de cohérence des données de maintenance avant leur envoi vers IFS.
      </Typography>

      <Grid container spacing={3}>
        {controles.map((c) => {
          const Icon = c.icon;
          const main = theme.palette[c.color].main;
          return (
            <Grid item xs={12} sm={6} md={4} key={c.cle}>
              <Card elevation={0} sx={{
                border: `1px solid ${theme.palette.divider}`, borderRadius: 3, height: '100%', transition: 'all 0.2s ease',
                '&:hover': { borderColor: main, boxShadow: `0 4px 20px ${alpha(main, 0.15)}`, transform: 'translateY(-2px)' },
              }}>
                <CardActionArea onClick={() => navigate(`/maintenance/equipment?anomalie=${c.cle}`)} sx={{ height: '100%', p: 1 }}>
                  <CardContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Box sx={{ width: 48, height: 48, borderRadius: 2, display: 'flex', alignItems: 'center',
                        justifyContent: 'center', backgroundColor: alpha(main, 0.1) }}>
                        <Icon sx={{ fontSize: 28, color: main }} />
                      </Box>
                      <Chip size="small" color={c.color}
                        label={counts[c.cle] !== undefined ? counts[c.cle].toLocaleString() : '…'} />
                    </Box>
                    <Box>
                      <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.5 }}>{c.title}</Typography>
                      <Typography variant="body2" color="text.secondary">{c.description}</Typography>
                    </Box>
                  </CardContent>
                </CardActionArea>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
};

export default MaintenanceControlesPage;
