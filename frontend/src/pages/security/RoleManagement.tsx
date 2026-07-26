import React, { useState } from 'react';
import {
  Box,
  Typography,
  Paper,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  IconButton,
  Chip,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  OutlinedInput,
  SelectChangeEvent,
  Stack,
  Tooltip
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Check as CheckIcon,
  Close as CloseIcon
} from '@mui/icons-material';
import roleService, { Role, RoleCreateData, RoleUpdateData } from '../../services/roleService';

// Liste des permissions disponibles dans le système
const availablePermissions = [
  'utilisateurs:lecture',
  'utilisateurs:ecriture',
  'utilisateurs:suppression',
  'roles:lecture',
  'roles:ecriture',
  'roles:suppression',
  'parametres:lecture',
  'parametres:ecriture',
  'rapports:lecture',
  'rapports:export'
];

interface RoleManagementProps {
  roles: Role[];
  onCreateRole: (roleData: RoleCreateData) => Promise<void>;
  onUpdateRole: (id: string, roleData: RoleUpdateData) => Promise<void>;
  onDeleteRole: (id: string) => Promise<void>;
}

const RoleManagement: React.FC<RoleManagementProps> = ({
  roles,
  onCreateRole,
  onUpdateRole,
  onDeleteRole
}) => {
  const [openDialog, setOpenDialog] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);
  const [roleForm, setRoleForm] = useState<RoleCreateData>({
    name: '',
    permissions: [],
    description: ''
  });

  // Ouvrir le dialog pour créer un nouveau rôle
  const handleOpenCreateDialog = () => {
    setIsEditing(false);
    setRoleForm({
      name: '',
      permissions: [],
      description: ''
    });
    setOpenDialog(true);
  };

  // Ouvrir le dialog pour éditer un rôle existant
  const handleOpenEditDialog = (role: Role) => {
    setIsEditing(true);
    setSelectedRole(role);
    setRoleForm({
      name: role.name,
      permissions: [...role.permissions],
      description: role.description
    });
    setOpenDialog(true);
  };

  // Fermer le dialog
  const handleCloseDialog = () => {
    setOpenDialog(false);
    setSelectedRole(null);
  };

  // Gérer les changements dans le formulaire
  const handleFormChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setRoleForm({
      ...roleForm,
      [name]: value
    });
  };

  // Gérer les changements de permissions sélectionnées
  const handlePermissionsChange = (event: SelectChangeEvent<string[]>) => {
    const { value } = event.target;
    setRoleForm({
      ...roleForm,
      permissions: typeof value === 'string' ? [value] : value
    });
  };

  // Soumettre le formulaire
  const handleSubmit = async () => {
    if (isEditing && selectedRole) {
      await onUpdateRole(selectedRole.id, roleForm);
    } else {
      await onCreateRole(roleForm);
    }
    handleCloseDialog();
  };

  // Confirmer la suppression d'un rôle
  const handleConfirmDelete = async (id: string) => {
    await onDeleteRole(id);
    setConfirmDelete(null);
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h5" component="h2">
          Gestion des rôles et permissions
        </Typography>
        <Button
          variant="contained"
          color="primary"
          startIcon={<AddIcon />}
          onClick={handleOpenCreateDialog}
        >
          Nouveau rôle
        </Button>
      </Box>

      <TableContainer component={Paper} sx={{ mb: 4 }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Nom du rôle</TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Permissions</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {roles.map((role) => (
              <TableRow key={role.id}>
                <TableCell>{role.name}</TableCell>
                <TableCell>{role.description}</TableCell>
                <TableCell>
                  <Stack direction="row" spacing={1} flexWrap="wrap">
                    {role.permissions.slice(0, 3).map((permission) => (
                      <Chip key={permission} label={permission} size="small" />
                    ))}
                    {role.permissions.length > 3 && (
                      <Tooltip title={role.permissions.slice(3).join(', ')}>
                        <Chip label={`+${role.permissions.length - 3}`} size="small" color="primary" />
                      </Tooltip>
                    )}
                  </Stack>
                </TableCell>
                <TableCell align="right">
                  <IconButton
                    color="primary"
                    onClick={() => handleOpenEditDialog(role)}
                  >
                    <EditIcon />
                  </IconButton>
                  {role.name !== 'admin' && (
                    <IconButton
                      color="error"
                      onClick={() => setConfirmDelete(role.id)}
                    >
                      <DeleteIcon />
                    </IconButton>
                  )}
                </TableCell>
              </TableRow>
            ))}
            {roles.length === 0 && (
              <TableRow>
                <TableCell colSpan={4} align="center">
                  Aucun rôle défini. Créez votre premier rôle en cliquant sur "Nouveau rôle".
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Dialog de création/édition de rôle */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="md" fullWidth disableRestoreFocus>
        <DialogTitle>
          {isEditing ? 'Modifier le rôle' : 'Créer un nouveau rôle'}
        </DialogTitle>
        <DialogContent dividers>
          <Box component="form" sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
            <TextField
              name="name"
              label="Nom du rôle"
              value={roleForm.name}
              onChange={handleFormChange}
              fullWidth
              required
            />
            <TextField
              name="description"
              label="Description"
              value={roleForm.description}
              onChange={handleFormChange}
              fullWidth
              multiline
              rows={2}
            />
            <FormControl fullWidth>
              <InputLabel id="permissions-label">Permissions</InputLabel>
              <Select
                labelId="permissions-label"
                multiple
                value={roleForm.permissions}
                onChange={handlePermissionsChange}
                input={<OutlinedInput label="Permissions" />}
                renderValue={(selected) => (
                  <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                    {selected.map((value) => (
                      <Chip key={value} label={value} size="small" />
                    ))}
                  </Box>
                )}
              >
                {availablePermissions.map((permission) => (
                  <MenuItem key={permission} value={permission}>
                    {permission}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Annuler</Button>
          <Button 
            onClick={handleSubmit} 
            variant="contained" 
            color="primary"
            disabled={!roleForm.name}
          >
            {isEditing ? 'Mettre à jour' : 'Créer'}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog de confirmation de suppression */}
      <Dialog open={!!confirmDelete} onClose={() => setConfirmDelete(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirmer la suppression</DialogTitle>
        <DialogContent>
          <Typography>
            Êtes-vous sûr de vouloir supprimer ce rôle ? Cette action ne peut pas être annulée.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button 
            onClick={() => setConfirmDelete(null)}
            startIcon={<CloseIcon />}
          >
            Annuler
          </Button>
          <Button 
            onClick={() => confirmDelete && handleConfirmDelete(confirmDelete)}
            color="error"
            variant="contained"
            startIcon={<CheckIcon />}
          >
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default RoleManagement; 