import React, { useState } from 'react';
import {
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Checkbox,
  IconButton,
  Tooltip,
  Chip,
  TablePagination,
  Typography,
  TableSortLabel,
  Menu,
  MenuItem,
  Divider
} from '@mui/material';
import {
  Edit as EditIcon,
  Delete as DeleteIcon,
  MoreVert as MoreVertIcon,
  CheckCircle as ActiveIcon,
  Cancel as InactiveIcon,
  Key as KeyIcon,
  ContentCopy as CopyIcon
} from '@mui/icons-material';
import { FieldMapping } from '../../services/fieldMappingService';

interface MappingTableProps {
  mappings: FieldMapping[];
  selectedMappings: number[];
  onSelectMapping: (id: number, selected: boolean) => void;
  onSelectAllMappings: (selected: boolean) => void;
  onEditMapping: (id: number) => void;
  onDeleteMapping: (id: number) => void;
  onCopyMapping: (id: number) => void;
  onToggleActive: (id: number, active: boolean) => void;
  onPageChange: (page: number) => void;
  onRowsPerPageChange: (rowsPerPage: number) => void;
  page: number;
  rowsPerPage: number;
  total: number;
  loading: boolean;
}

const MappingTable: React.FC<MappingTableProps> = ({
  mappings,
  selectedMappings,
  onSelectMapping,
  onSelectAllMappings,
  onEditMapping,
  onDeleteMapping,
  onCopyMapping,
  onToggleActive,
  onPageChange,
  onRowsPerPageChange,
  page,
  rowsPerPage,
  total,
  loading
}) => {
  // État pour le menu contextuel des actions par ligne
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [currentMappingId, setCurrentMappingId] = useState<number | null>(null);
  
  // Ouvrir le menu contextuel
  const handleMenuOpen = (event: React.MouseEvent<HTMLButtonElement>, mappingId: number) => {
    setAnchorEl(event.currentTarget);
    setCurrentMappingId(mappingId);
  };
  
  // Fermer le menu contextuel
  const handleMenuClose = () => {
    setAnchorEl(null);
    setCurrentMappingId(null);
  };
  
  // Gérer les actions du menu contextuel
  const handleMenuAction = (action: 'edit' | 'delete' | 'copy' | 'toggle') => {
    if (currentMappingId === null) return;
    
    if (action === 'edit') {
      onEditMapping(currentMappingId);
    } else if (action === 'delete') {
      onDeleteMapping(currentMappingId);
    } else if (action === 'copy') {
      onCopyMapping(currentMappingId);
    } else if (action === 'toggle') {
      const mapping = mappings.find(m => m.id === currentMappingId);
      if (mapping) {
        onToggleActive(currentMappingId, !mapping.is_active);
      }
    }
    
    handleMenuClose();
  };
  
  // Vérifier si tous les mappings de la page sont sélectionnés
  const isAllSelected = mappings.length > 0 && selectedMappings.length === mappings.length;
  
  // Gérer le changement de page de la pagination
  const handleChangePage = (event: unknown, newPage: number) => {
    onPageChange(newPage);
  };
  
  // Gérer le changement du nombre de lignes par page
  const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
    onRowsPerPageChange(parseInt(event.target.value, 10));
    onPageChange(0);
  };
  
  // Formatter la date pour l'affichage
  const formatDate = (dateString?: string) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };
  
  return (
    <Box sx={{ width: '100%' }}>
      <TableContainer 
        component={Paper} 
        sx={{ 
          mb: 2, 
          width: '100%', 
          maxWidth: '100%',
          overflowX: 'auto'
        }}
      >
        <Table 
          sx={{ 
            width: '100%', 
            tableLayout: 'auto' 
          }} 
          aria-labelledby="mappingsTable" 
          size="medium"
        >
          <TableHead>
            <TableRow>
              <TableCell padding="checkbox">
                <Checkbox
                  indeterminate={selectedMappings.length > 0 && !isAllSelected}
                  checked={isAllSelected}
                  onChange={(event) => onSelectAllMappings(event.target.checked)}
                  disabled={loading || mappings.length === 0}
                />
              </TableCell>
              <TableCell>Table source</TableCell>
              <TableCell>Champ source</TableCell>
              <TableCell>Table cible</TableCell>
              <TableCell>Champ cible</TableCell>
              <TableCell>Type de données</TableCell>
              <TableCell align="center">Clé</TableCell>
              <TableCell>Transformation</TableCell>
              <TableCell>Dernière modification</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {mappings.length === 0 ? (
              <TableRow>
                <TableCell colSpan={10} align="center">
                  <Typography variant="body1" sx={{ py: 2 }}>
                    {loading ? 'Chargement...' : 'Aucun mapping trouvé'}
                  </Typography>
                </TableCell>
              </TableRow>
            ) : (
              mappings.map((mapping) => {
                const isSelected = selectedMappings.includes(mapping.id || 0);
                
                return (
                  <TableRow
                    hover
                    role="checkbox"
                    aria-checked={isSelected}
                    tabIndex={-1}
                    key={mapping.id}
                    selected={isSelected}
                    sx={{ '&:hover': { cursor: 'pointer' } }}
                  >
                    <TableCell padding="checkbox">
                      <Checkbox
                        checked={isSelected}
                        onChange={(event) => {
                          const id = mapping.id || 0;
                          onSelectMapping(id, event.target.checked);
                        }}
                        disabled={loading}
                      />
                    </TableCell>
                    <TableCell>{mapping.source_table_name}</TableCell>
                    <TableCell>{mapping.source_field_name}</TableCell>
                    <TableCell>{mapping.target_table}</TableCell>
                    <TableCell>{mapping.target_field_name}</TableCell>
                    <TableCell>{mapping.data_type || '-'}</TableCell>
                    <TableCell align="center">
                      {mapping.is_key && (
                        <Tooltip title="Clé primaire">
                          <KeyIcon color="primary" />
                        </Tooltip>
                      )}
                    </TableCell>
                    <TableCell>
                      {mapping.transformation_rule ? (
                        <Tooltip title={mapping.transformation_rule}>
                          <Typography noWrap sx={{ maxWidth: 150 }}>
                            {mapping.transformation_rule}
                          </Typography>
                        </Tooltip>
                      ) : (
                        'Directe'
                      )}
                    </TableCell>
                    <TableCell>
                      {formatDate(mapping.updated_at)}
                      <Typography variant="caption" display="block">
                        par {mapping.updated_by || '-'}
                      </Typography>
                    </TableCell>
                    <TableCell align="center">
                      <Box sx={{ display: 'flex', justifyContent: 'center' }}>
                        <Tooltip title={mapping.is_active ? 'Actif' : 'Inactif'}>
                          {mapping.is_active ? (
                            <ActiveIcon color="success" sx={{ mr: 1 }} />
                          ) : (
                            <InactiveIcon color="error" sx={{ mr: 1 }} />
                          )}
                        </Tooltip>
                        <Tooltip title="Éditer">
                          <IconButton
                            size="small"
                            color="primary"
                            onClick={() => onEditMapping(mapping.id || 0)}
                            disabled={loading}
                          >
                            <EditIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        <IconButton
                          size="small"
                          onClick={(event) => handleMenuOpen(event, mapping.id || 0)}
                          disabled={loading}
                        >
                          <MoreVertIcon fontSize="small" />
                        </IconButton>
                      </Box>
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </TableContainer>
      
      <TablePagination
        component="div"
        count={total}
        page={page}
        onPageChange={handleChangePage}
        rowsPerPage={rowsPerPage}
        onRowsPerPageChange={handleChangeRowsPerPage}
        rowsPerPageOptions={[10, 25, 50, 100]}
        labelRowsPerPage="Lignes par page :"
        labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count !== -1 ? count : `plus de ${to}`}`}
        disabled={loading}
        sx={{ width: '100%' }}
      />
      
      {/* Menu contextuel pour les actions */}
      <Menu
        anchorEl={anchorEl}
        open={Boolean(anchorEl)}
        onClose={handleMenuClose}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
      >
        <MenuItem onClick={() => handleMenuAction('edit')}>
          <EditIcon fontSize="small" sx={{ mr: 1 }} />
          Éditer
        </MenuItem>
        <MenuItem onClick={() => handleMenuAction('copy')}>
          <CopyIcon fontSize="small" sx={{ mr: 1 }} />
          Dupliquer
        </MenuItem>
        <MenuItem onClick={() => handleMenuAction('toggle')}>
          {mappings.find(m => m.id === currentMappingId)?.is_active ? (
            <>
              <InactiveIcon fontSize="small" sx={{ mr: 1 }} />
              Désactiver
            </>
          ) : (
            <>
              <ActiveIcon fontSize="small" sx={{ mr: 1 }} />
              Activer
            </>
          )}
        </MenuItem>
        <Divider />
        <MenuItem onClick={() => handleMenuAction('delete')} sx={{ color: 'error.main' }}>
          <DeleteIcon fontSize="small" sx={{ mr: 1 }} />
          Supprimer
        </MenuItem>
      </Menu>
    </Box>
  );
};

export default MappingTable;