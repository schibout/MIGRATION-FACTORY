import { AccountBalance as ImmobilisationIcon, Euro as FinanceIcon } from '@mui/icons-material';
import { Box, Card, CardActionArea, Grid, Typography } from '@mui/material';
import React from 'react';
import { useNavigate } from 'react-router-dom';

// Menu Finance : une carte par écran.
const financeItems = [
  {
    title: 'Immobilisations',
    path: '/finance/immobilisations',
    icon: <ImmobilisationIcon sx={{ fontSize: 48, color: '#5d4037' }} />,
    description: 'Immobilisations SAP STJN : comptes, amortissement, imputation, valeur d\'acquisition et VNC, synchronisables depuis SAP',
  },
];

const Finance: React.FC = () => {
  const navigate = useNavigate();

  return (
    <Box sx={{ width: '100%', p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
        <FinanceIcon sx={{ fontSize: 40, color: 'primary.main', mr: 2 }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          FINANCE
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {financeItems.map((item) => (
          <Grid item xs={12} md={6} lg={4} key={item.path}>
            <Card sx={{ height: '100%', transition: 'all 0.3s ease', '&:hover': { transform: 'translateY(-8px)', boxShadow: '0 12px 32px rgba(0,0,0,0.15)' } }}>
              <CardActionArea onClick={() => navigate(item.path)} sx={{ height: '100%', p: 4, textAlign: 'center' }}>
                <Box sx={{ mb: 2 }}>{item.icon}</Box>
                <Typography variant="h6" component="h2" sx={{ mb: 1, fontWeight: 600 }}>
                  {item.title}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {item.description}
                </Typography>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};

export default Finance;
