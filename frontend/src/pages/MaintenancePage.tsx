import React, { useEffect, useState } from 'react';
import { Box, Typography, Card, CardContent, CardActionArea, Grid, useTheme, alpha, Chip } from '@mui/material';
import {
  Build as EquipmentIcon,
  Engineering as IH02Icon,
  Inventory2 as ArticleIcon,
  Handyman as PeToolsIcon,
  Layers as LayersIcon,
  SettingsBackupRestore as BackupIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

const sections = [
  {
    title: 'Structure technique et référentiels',
    cards: [
      {
        title: 'Explorer la hiérarchie des postes techniques',
        description: 'Parcourir l\'arborescence des postes techniques et les équipements qui leur sont rattachés.',
        path: '/maintenance/ih02',
        icon: IH02Icon,
        color: 'secondary' as const,
        tag: 'IH02',
      },
      {
        title: 'Liste des équipements',
        description: 'Rechercher un équipement, consulter ses caractéristiques et modifier ses données.',
        path: '/maintenance/equipment',
        icon: EquipmentIcon,
        color: 'secondary' as const,
        tag: 'SAP',
      },
      {
        title: 'Catalogue des articles',
        description: 'Consulter tous les articles de maintenance SAP : ERSA, IBAU et NLAG.',
        path: '/maintenance/articles',
        icon: ArticleIcon,
        color: 'primary' as const,
        tag: 'SAP',
      },
      {
        title: 'Pièces de rechange',
        description: 'Consulter les pièces de rechange ERSA avec leurs stocks et divisions.',
        path: '/maintenance/articles/ersa',
        icon: ArticleIcon,
        color: 'warning' as const,
        tag: 'ERSA',
      },
      {
        title: 'Référentiel IBAU équipe',
        description: 'Gérer la liste IBAU manuelle, distincte des articles provenant de SAP.',
        path: '/maintenance/ibau',
        icon: LayersIcon,
        color: 'primary' as const,
        tag: 'ÉDITABLE',
      },
    ],
  },
  {
    title: 'Maintenance préventive',
    cards: [
      {
        title: 'Gammes préventives',
        description: 'Filtrer, exporter et modifier les plans, fréquences et charges de maintenance.',
        path: '/maintenance/pe-tools',
        icon: PeToolsIcon,
        color: 'success' as const,
        tag: 'PE TOOLS',
      },
    ],
  },
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
      try {
        const res = await api.get('/maintenance/ibau/stats');
        if (res.data?.success) {
          setCounts((prev) => ({ ...prev, LISTE_IBAU: Number(res.data.data?.total ?? 0) }));
        }
      } catch { /* compteur facultatif (migration 030 pas encore jouee) */ }
    })();
  }, []);

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>Maintenance</Typography>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Gérez la structure technique, les articles et la maintenance préventive.
      </Typography>

      {sections.map((section) => (
        <Box
          component="section"
          key={section.title}
          sx={{ mb: 4 }}
        >
          <Typography
            variant="overline"
            color="text.secondary"
            sx={{ display: 'block', fontWeight: 700, letterSpacing: '0.08em', mb: 1.5 }}
          >
            {section.title}
          </Typography>
          <Grid container spacing={3}>
            {section.cards.map((card) => {
              const Icon = card.icon;
              return (
                <Grid item xs={12} md={4} key={card.path}>
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
        </Box>
      ))}

      <Box
        component="section"
        sx={{ mt: 5, pt: 3, borderTop: `1px solid ${theme.palette.divider}` }}
      >
        <Typography
          variant="overline"
          color="text.secondary"
          sx={{ display: 'block', fontWeight: 700, letterSpacing: '0.08em', mb: 1.5 }}
        >
          Administration des données
        </Typography>
        <Grid container spacing={3}>
          <Grid item xs={12} md={4}>
            <Card
              elevation={0}
              sx={{
                border: `1px solid ${theme.palette.divider}`,
                borderRadius: 3,
                transition: 'all 0.2s ease',
                '&:hover': {
                  borderColor: theme.palette.warning.main,
                  boxShadow: `0 4px 20px ${alpha(theme.palette.warning.main, 0.15)}`,
                  transform: 'translateY(-2px)',
                },
              }}
            >
              <CardActionArea onClick={() => navigate('/maintenance/backups')} sx={{ p: 1 }}>
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
                        backgroundColor: alpha(theme.palette.warning.main, 0.1),
                      }}
                    >
                      <BackupIcon sx={{ fontSize: 28, color: theme.palette.warning.main }} />
                    </Box>
                    <Chip label="SENSIBLE" size="small" variant="outlined" color="warning" />
                  </Box>
                  <Box>
                    <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.5 }}>
                      États sauvegardés et rechargement SAP
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Sauvegarder le travail, restaurer un état antérieur ou recharger les données depuis SAP.
                    </Typography>
                  </Box>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
};

export default MaintenancePage;
