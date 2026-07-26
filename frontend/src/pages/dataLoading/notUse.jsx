import React from 'react';
import { Link } from 'react-router-dom';
import { Box, Typography, Grid, Paper, Icon } from '@mui/material';
import StorageIcon from '@mui/icons-material/Storage';
import InventoryIcon from '@mui/icons-material/Inventory';
import BusinessIcon from '@mui/icons-material/Business';
import EngineeringIcon from '@mui/icons-material/Engineering';
import ShoppingCartIcon from '@mui/icons-material/ShoppingCart';
import AccountBalanceIcon from '@mui/icons-material/AccountBalance';

const DataLoadingPage = () => {
  // Définition des différentes cartes de données
  const dataCards = [
    {
      title: 'FOURNISSEURS',
      description: 'Données relatives aux fournisseurs extraites de SAP',
      icon: <BusinessIcon sx={{ fontSize: 60, color: '#4dabf5' }} />,
      link: '/sap-data/fournisseurs',
      color: '#1e293b'
    },
    {
      title: 'MAINTENANCE PRODUCTION',
      description: 'Données de maintenance et production extraites de SAP',
      icon: <EngineeringIcon sx={{ fontSize: 60, color: '#81c784' }} />,
      link: '/sap-data/maintenance',
      color: '#1e293b'
    },
    {
      title: 'ARTICLES',
      description: 'Catalogue des articles extraits de SAP',
      icon: <InventoryIcon sx={{ fontSize: 60, color: '#e57373' }} />,
      link: '/sap-data/articles',
      color: '#1e293b'
    },
    {
      title: 'COMPTABILITÉ',
      description: 'Données comptables extraites de SAP',
      icon: <AccountBalanceIcon sx={{ fontSize: 60, color: '#9575cd' }} />,
      link: '/sap-data/comptabilite',
      color: '#1e293b'
    },
    {
      title: 'ACHATS',
      description: 'Données d\'achats extraites de SAP',
      icon: <ShoppingCartIcon sx={{ fontSize: 60, color: '#7986cb' }} />,
      link: '/sap-data/achats',
      color: '#1e293b'
    }
  ];

  return (
    <Box sx={{ p: 3, maxWidth: '100%' }}>
      <Typography variant="h4" component="h1" gutterBottom>
        DONNÉES SAP
      </Typography>

      <Grid container spacing={3} sx={{ mt: 3 }}>
        {dataCards.map((card, index) => (
          <Grid item xs={12} sm={6} md={4} key={index}>
            <Paper
              component={Link}
              to={card.link}
              sx={{
                p: 3,
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                textAlign: 'center',
                backgroundColor: card.color,
                color: '#fff',
                borderRadius: 2,
                transition: 'transform 0.3s, box-shadow 0.3s',
                textDecoration: 'none',
                '&:hover': {
                  transform: 'translateY(-5px)',
                  boxShadow: '0 10px 20px rgba(0,0,0,0.2)',
                }
              }}
            >
              <Box sx={{ mb: 2 }}>
                {card.icon}
              </Box>
              <Typography variant="h6" component="h2" gutterBottom>
                {card.title}
              </Typography>
              <Typography variant="body2">
                {card.description}
              </Typography>
            </Paper>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};

export default DataLoadingPage; 