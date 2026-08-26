import {
  Home as HomeIcon,
  MenuBook as MenuBookIcon,
  OpenInNew as OpenInNewIcon,
} from '@mui/icons-material';
import { Box, Button, Typography } from '@mui/material';
import { useState } from 'react';

// Les modes d'emploi sont des pages HTML autonomes deposees dans
// frontend/public/guides/ (servies par Vite sous /guides/...).
// La page d'entree est le sommaire /guides/index.html : chaque guide y est
// une carte cliquable, la navigation se fait a l'interieur du cadre sans
// quitter l'application. Pour ajouter un guide : copier son HTML dans
// frontend/public/guides/ puis activer sa carte dans index.html.
const SOMMAIRE = '/guides/index.html';

const ModeEmploi = () => {
  // Incrementer la cle recharge l'iframe sur le sommaire (retour "accueil"),
  // quelle que soit la page ouverte a l'interieur du cadre.
  const [resetKey, setResetKey] = useState(0);

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: 'calc(100vh - 112px)' }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1.5 }}>
        <MenuBookIcon color="primary" />
        <Typography variant="h6" sx={{ flexGrow: 1 }}>
          Modes d'emploi
        </Typography>
        <Button
          startIcon={<HomeIcon />}
          size="small"
          variant="outlined"
          onClick={() => setResetKey((k) => k + 1)}
        >
          Sommaire
        </Button>
        <Button
          endIcon={<OpenInNewIcon />}
          size="small"
          onClick={() => window.open(SOMMAIRE, '_blank')}
        >
          Plein écran
        </Button>
      </Box>
      <Box
        key={resetKey}
        component="iframe"
        src={SOMMAIRE}
        title="Modes d'emploi Migration Factory"
        sx={{
          flexGrow: 1,
          width: '100%',
          border: 1,
          borderColor: 'divider',
          borderRadius: 1,
          bgcolor: 'background.paper',
        }}
      />
    </Box>
  );
};

export default ModeEmploi;
