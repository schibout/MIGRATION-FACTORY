import { Box, Paper, Typography } from '@mui/material';
import React from 'react';
import { useLocation } from 'react-router-dom';

interface PlaceholderPageProps {
  title?: string;
}

const PlaceholderPage: React.FC<PlaceholderPageProps> = ({ title }) => {
  const location = useLocation();
  const pageName = title || location.pathname.split('/').pop()?.replace(/-/g, ' ');
  const capitalizedPageName = pageName?.charAt(0).toUpperCase() + pageName?.slice(1);

  return (
    <Box sx={{ width: '100%', height: '100%', overflow: 'hidden', p: 3 }}>
      <Paper sx={{ p: 4, borderRadius: 2, boxShadow: 3 }}>
        <Box sx={{ textAlign: 'center', my: 4 }}>
          <Typography variant="h4" component="h1" gutterBottom>
            {capitalizedPageName}
          </Typography>
          <Typography variant="subtitle1" color="text.secondary">
            Cette page est en cours de développement.
          </Typography>
        </Box>
      </Paper>
    </Box>
  );
};

export default PlaceholderPage; 