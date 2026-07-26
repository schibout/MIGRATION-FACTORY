import React, { useEffect, useState } from 'react';
import { Box, Typography, Card, CardContent, CardActionArea, Grid, useTheme, alpha, Chip } from '@mui/material';
import {
  Build as EquipmentIcon,
  Engineering as IH02Icon,
  Inventory2 as ArticleIcon,
  Layers as LayersIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

const cards = [
  {
    title: 'Équipements',
    description: 'Consulter la liste des équipements SAP, leurs caractéristiques et rattachements.',
    path: '/maintenance/equipment',
    icon: EquipmentIcon,
    color: 'warning' as const,
    tag: 'SAP',
  },
  {
    title: 'Hiérarchie technique & Équipements',
    description: 'Explorer l\'arborescence complète des postes techniques avec leurs équipements rattachés (IH02).',
    path: '/maintenance/ih02',
    icon: IH02Icon,
    color: 'secondary' as const,
    tag: 'IH02',
  },
  {
    title: 'Articles maintenance',
    description: 'Consulter tous les articles de maintenance (ERSA, IBAU, NLAG) avec stocks et divisions.',
    path: '/maintenance/articles',
    icon: ArticleIcon,
    color: 'primary' as const,
    tag: 'MARA',
  },
];

// Blocs dédiés par type d'article (pages séparées). Les articles inactifs
// (indicateur de suppression SAP) sont exclus des compteurs côté backend.
const typeCards = [
  { code: 'ERSA', title: 'Pièces de rechange', path: '/maintenance/articles/ersa', color: 'warning' as const },
  { code: 'IBAU', title: 'Ensembles de maintenance', path: '/maintenance/articles/ibau', color: 'info' as const },
  { code: 'NLAG', title: 'Articles non stockés', path: '/maintenance/articles/nlag', color: 'secondary' as const },
];

const MaintenancePage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const [counts, setCounts] = useState<Record<string, number>>({});

  useEffect(() => {
    (async () => {
      try {
        const res = await api.get('/maintenance/articles/stats?st_jean=1');
        if (res.data?.success) {
          const map: Record<string, number> = {};
          (res.data.data?.by_type || []).forEach((r: any) => { map[r.mtart] = Number(r.nb); });
          setCounts(map);
        }
      } catch { /* compteurs facultatifs */ }
    })();
  }, []);

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Maintenance</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Gestion de la structure de maintenance, des postes techniques et des équipements.
      </Typography>

      <Grid container spacing={3}>
        {cards.map((card) => {
          const Icon = card.icon;
          return (
            <Grid item xs={12} sm={6} md={4} key={card.path}>
              <Card
                elevation={0}
                sx={{
                  border: `1px solid ${theme.palette.divider}`,
                  borderRadius: 3,
                  height: '100%',
                  transition: 'all 0.2s ease',
                  '&:hover': {
                    borderColor: theme.palette[card.color].main,
                    boxShadow: `0 4px 20px ${alpha(theme.palette[card.color].main, 0.15)}`,
                    transform: 'translateY(-2px)',
                  },
                }}
              >
                <CardActionArea onClick={() => navigate(card.path)} sx={{ height: '100%', p: 1 }}>
                  <CardContent sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <Box
                        sx={{
                          width: 48,
                          height: 48,
                          borderRadius: 2,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          backgroundColor: alpha(theme.palette[card.color].main, 0.1),
                        }}
                      >
                        <Icon sx={{ fontSize: 28, color: theme.palette[card.color].main }} />
                      </Box>
                      <Chip label={card.tag} size="small" variant="outlined" color={card.color} />
                    </Box>
                    <Box>
                      <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.5 }}>{card.title}</Typography>
                      <Typography variant="body2" color="text.secondary">{card.description}</Typography>
                    </Box>
                  </CardContent>
                </CardActionArea>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      {/* Articles de maintenance par type — pages dédiées */}
      <Typography variant="h6" sx={{ fontWeight: 600, mt: 5, mb: 2 }}>
        Articles de maintenance par type
      </Typography>
      <Grid container spacing={3}>
        {typeCards.map((card) => (
          <Grid item xs={12} sm={6} md={4} key={card.code}>
            <Card
              elevation={0}
              sx={{
                border: `1px solid ${theme.palette.divider}`,
                borderRadius: 3,
                height: '100%',
                transition: 'all 0.2s ease',
                '&:hover': {
                  borderColor: theme.palette[card.color].main,
                  boxShadow: `0 4px 20px ${alpha(theme.palette[card.color].main, 0.15)}`,
                  transform: 'translateY(-2px)',
                },
              }}
            >
              <CardActionArea onClick={() => navigate(card.path)} sx={{ height: '100%', p: 1 }}>
                <CardContent sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  <Box
                    sx={{
                      width: 56,
                      height: 56,
                      borderRadius: 2,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      backgroundColor: alpha(theme.palette[card.color].main, 0.1),
                      flexShrink: 0,
                    }}
                  >
                    <LayersIcon sx={{ fontSize: 30, color: theme.palette[card.color].main }} />
                  </Box>
                  <Box sx={{ minWidth: 0 }}>
                    <Typography variant="h4" sx={{ fontWeight: 700, lineHeight: 1.1 }}>
                      {counts[card.code] !== undefined ? counts[card.code].toLocaleString() : '—'}
                    </Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>{card.code}</Typography>
                    <Typography variant="caption" color="text.secondary" noWrap>{card.title}</Typography>
                  </Box>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};

export default MaintenancePage;
