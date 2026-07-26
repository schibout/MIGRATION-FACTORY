import React, { useState } from 'react';
// Import Material-UI components individually to avoid bundling issues
import Box from '@mui/material/Box';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TablePagination from '@mui/material/TablePagination';
import TableRow from '@mui/material/TableRow';
import TableSortLabel from '@mui/material/TableSortLabel';
import Paper from '@mui/material/Paper';
import Checkbox from '@mui/material/Checkbox';
import Chip from '@mui/material/Chip';
import IconButton from '@mui/material/IconButton';
import Tooltip from '@mui/material/Tooltip';
import Typography from '@mui/material/Typography';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';
import ListItemIcon from '@mui/material/ListItemIcon';
import ListItemText from '@mui/material/ListItemText';
// Import Material-UI icons
import {
  Edit as EditIcon,
  Delete as DeleteIcon,
  MoreVert as MoreIcon,
  ToggleOn as ActivateIcon,
  ToggleOff as DeactivateIcon,
  ContentCopy as DuplicateIcon
} from '@mui/icons-material';
import { Transcodification } from '../../services/transcodificationService';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

interface TranscodificationTableProps {
  transcodifications: Transcodification[];
  totalItems: number;
  page: number;
  rowsPerPage: number;
  selectedItems: number[];
  onPageChange: (newPage: number) => void;
  onRowsPerPageChange: (newRowsPerPage: number) => void;
  onSelectAll: (selected: boolean) => void;
  onSelectItem: (id: number, selected: boolean) => void;
  onEditItem: (id: number) => void;
  onDeleteItem: (id: number) => void;
  onDuplicateItem: (id: number) => void;
  onToggleActive: (id: number, active: boolean) => void;
}

// Options de tri
type OrderDirection = 'asc' | 'desc';
type OrderField = 'category' | 'source_value' | 'target_value' | 'updated_at';

const TranscodificationTable: React.FC<TranscodificationTableProps> = ({
  transcodifications,
  totalItems,
  page,
  rowsPerPage,
  selectedItems,
  onPageChange,
  onRowsPerPageChange,
  onSelectAll,
  onSelectItem,
  onEditItem,
  onDeleteItem,
  onDuplicateItem,
  onToggleActive
}) => {
  // État local pour le tri
  const [orderDirection, setOrderDirection] = useState<OrderDirection>('asc');
  const [orderBy, setOrderBy] = useState<OrderField>('category');
  
  // État pour le menu d'actions
  const [menuAnchorEl, setMenuAnchorEl] = useState<null | HTMLElement>(null);
  const [currentItemId, setCurrentItemId] = useState<number | null>(null);
  
  // Ouvrir le menu d'actions
  const handleOpenMenu = (event: React.MouseEvent<HTMLElement>, id: number) => {
    setMenuAnchorEl(event.currentTarget);
    setCurrentItemId(id);
  };
  
  // Fermer le menu d'actions
  const handleCloseMenu = () => {
    setMenuAnchorEl(null);
    setCurrentItemId(null);
  };
  
  // Gérer le changement de tri
  const handleRequestSort = (property: OrderField) => {
    const isAsc = orderBy === property && orderDirection === 'asc';
    setOrderDirection(isAsc ? 'desc' : 'asc');
    setOrderBy(property);
  };
  
  // Gérer la sélection de toutes les lignes
  const handleSelectAllClick = (event: React.ChangeEvent<HTMLInputElement>) => {
    onSelectAll(event.target.checked);
  };
  
  // Gérer les actions du menu contextuel
  const handleMenuAction = (action: 'edit' | 'delete' | 'duplicate' | 'toggle') => {
    if (currentItemId !== null) {
      handleCloseMenu();
      
      switch (action) {
        case 'edit':
          onEditItem(currentItemId);
          break;
        case 'delete':
          onDeleteItem(currentItemId);
          break;
        case 'duplicate':
          onDuplicateItem(currentItemId);
          break;
        case 'toggle':
          const item = transcodifications.find(t => t.id === currentItemId);
          if (item) {
            onToggleActive(currentItemId, !item.is_active);
          }
          break;
      }
    }
  };
  
  // Formater la date
  const formatDate = (dateString?: string) => {
    if (!dateString) return '-';
    try {
      return format(new Date(dateString), 'dd/MM/yyyy HH:mm', { locale: fr });
    } catch (e) {
      return dateString;
    }
  };
  
  // Vérifier si tous les éléments de la page actuelle sont sélectionnés
  const isAllSelected = transcodifications.length > 0 && 
    transcodifications.every(t => t.id !== undefined && selectedItems.includes(t.id));
  
  return (
    <Paper sx={{ width: '100%', mb: 2 }}>
      <TableContainer>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell padding="checkbox">
                <Checkbox
                  indeterminate={selectedItems.length > 0 && !isAllSelected}
                  checked={isAllSelected}
                  onChange={handleSelectAllClick}
                />
              </TableCell>
              <TableCell>
                <TableSortLabel
                  active={orderBy === 'category'}
                  direction={orderBy === 'category' ? orderDirection : 'asc'}
                  onClick={() => handleRequestSort('category')}
                >
                  Catégorie
                </TableSortLabel>
              </TableCell>
              <TableCell>
                <TableSortLabel
                  active={orderBy === 'source_value'}
                  direction={orderBy === 'source_value' ? orderDirection : 'asc'}
                  onClick={() => handleRequestSort('source_value')}
                >
                  Valeur source
                </TableSortLabel>
              </TableCell>
              <TableCell>
                <TableSortLabel
                  active={orderBy === 'target_value'}
                  direction={orderBy === 'target_value' ? orderDirection : 'asc'}
                  onClick={() => handleRequestSort('target_value')}
                >
                  Valeur cible
                </TableSortLabel>
              </TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Système source</TableCell>
              <TableCell>Système cible</TableCell>
              <TableCell>
                <TableSortLabel
                  active={orderBy === 'updated_at'}
                  direction={orderBy === 'updated_at' ? orderDirection : 'asc'}
                  onClick={() => handleRequestSort('updated_at')}
                >
                  Dernière modification
                </TableSortLabel>
              </TableCell>
              <TableCell>Statut</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {transcodifications.length === 0 ? (
              <TableRow>
                <TableCell colSpan={10} align="center">
                  <Typography variant="body1" sx={{ py: 5, color: 'text.secondary' }}>
                    Aucune transcodification trouvée
                  </Typography>
                </TableCell>
              </TableRow>
            ) : (
              transcodifications.map((transcodification) => {
                const isSelected = transcodification.id !== undefined && selectedItems.includes(transcodification.id);
                
                return (
                  <TableRow
                    hover
                    key={transcodification.id}
                    selected={isSelected}
                    sx={{ '&:last-child td, &:last-child th': { border: 0 } }}
                  >
                    <TableCell padding="checkbox">
                      <Checkbox
                        checked={isSelected}
                        onChange={(e) => transcodification.id && onSelectItem(transcodification.id, e.target.checked)}
                      />
                    </TableCell>
                    <TableCell component="th" scope="row">
                      <Typography variant="body2" fontWeight="medium">
                        {transcodification.category}
                      </Typography>
                    </TableCell>
                    <TableCell>{transcodification.source_value}</TableCell>
                    <TableCell>{transcodification.target_value}</TableCell>
                    <TableCell>
                      <Typography
                        variant="body2"
                        sx={{
                          maxWidth: 200,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}
                      >
                        {transcodification.description || '-'}
                      </Typography>
                    </TableCell>
                    <TableCell>{transcodification.source_system}</TableCell>
                    <TableCell>{transcodification.target_system}</TableCell>
                    <TableCell>{formatDate(transcodification.updated_at)}</TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={transcodification.is_active ? 'Actif' : 'Inactif'}
                        color={transcodification.is_active ? 'success' : 'default'}
                        variant="outlined"
                      />
                    </TableCell>
                    <TableCell align="right">
                      <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                        {/* Actions rapides */}
                        <Tooltip title="Modifier">
                          <IconButton
                            size="small"
                            onClick={() => transcodification.id && onEditItem(transcodification.id)}
                          >
                            <EditIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        
                        {/* Menu d'actions */}
                        <Tooltip title="Plus d'actions">
                          <IconButton
                            size="small"
                            onClick={(e) => transcodification.id && handleOpenMenu(e, transcodification.id)}
                          >
                            <MoreIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
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
        rowsPerPageOptions={[10, 25, 50, 100]}
        component="div"
        count={totalItems}
        rowsPerPage={rowsPerPage}
        page={page}
        onPageChange={(e, newPage) => onPageChange(newPage)}
        onRowsPerPageChange={(e) => onRowsPerPageChange(parseInt(e.target.value, 10))}
        labelRowsPerPage="Lignes par page:"
        labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
      />
      
      {/* Menu contextuel pour les actions supplémentaires */}
      <Menu
        anchorEl={menuAnchorEl}
        open={Boolean(menuAnchorEl)}
        onClose={handleCloseMenu}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
      >
        <MenuItem onClick={() => handleMenuAction('edit')}>
          <ListItemIcon>
            <EditIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Modifier</ListItemText>
        </MenuItem>
        
        <MenuItem onClick={() => handleMenuAction('toggle')}>
          <ListItemIcon>
            {currentItemId !== null && 
             transcodifications.find(t => t.id === currentItemId)?.is_active 
              ? <DeactivateIcon fontSize="small" />
              : <ActivateIcon fontSize="small" />
            }
          </ListItemIcon>
          <ListItemText>
            {currentItemId !== null && 
             transcodifications.find(t => t.id === currentItemId)?.is_active 
              ? 'Désactiver'
              : 'Activer'
            }
          </ListItemText>
        </MenuItem>
        
        <MenuItem onClick={() => handleMenuAction('duplicate')}>
          <ListItemIcon>
            <DuplicateIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Dupliquer</ListItemText>
        </MenuItem>
        
        <MenuItem onClick={() => handleMenuAction('delete')}>
          <ListItemIcon>
            <DeleteIcon fontSize="small" color="error" />
          </ListItemIcon>
          <ListItemText sx={{ color: 'error.main' }}>Supprimer</ListItemText>
        </MenuItem>
      </Menu>
    </Paper>
  );
};

export default TranscodificationTable; 