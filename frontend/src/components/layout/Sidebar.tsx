import {
    CompareArrows as CompareArrowsIcon,
    List as ListIcon,
    Rule as RuleIcon,
    Storage as StorageIcon,
    Transform as TransformIcon,
    Tune as TuneIcon
} from '@mui/icons-material';
import {
    ListItem,
    ListItemIcon,
    ListItemText,
    ListSubheader,
} from '@mui/material';
import React from 'react';
import { Link } from 'react-router-dom';

const Sidebar = () => {
  return (
    <>
      {/* Configuration */}
      <ListSubheader component="div" sx={{ bgcolor: 'transparent', color: '#FFF', fontWeight: 'bold', mt: 2 }}>
        Configuration
      </ListSubheader>
      
      {/* Éléments de menu Configuration */}
      <ListItem button component={Link} to="/transcodification">
        <ListItemIcon>
          <TransformIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Transcodification" />
      </ListItem>
      
      <ListItem button component={Link} to="/mapping-champs">
        <ListItemIcon>
          <CompareArrowsIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Mapping des champs" />
      </ListItem>
      
      <ListItem button component={Link} to="/regles-gestion">
        <ListItemIcon>
          <RuleIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Règles de gestion" />
      </ListItem>
      
      <ListItem button component={Link} to="/parametres">
        <ListItemIcon>
          <TuneIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Paramètres" />
      </ListItem>
      
      <ListItem button component={Link} to="/listes-valeurs">
        <ListItemIcon>
          <ListIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Listes de valeurs" />
      </ListItem>
      
      <ListItem button component={Link} to="/admin/export-queries">
        <ListItemIcon>
          <StorageIcon sx={{ color: '#FFF' }} />
        </ListItemIcon>
        <ListItemText primary="Requêtes d'export" />
      </ListItem>
    </>
  );
};

export default Sidebar; 