import {
  Add as AddIcon,
  Clear as ClearIcon,
  Delete as DeleteIcon,
  Edit as EditIcon,
  Refresh as RefreshIcon,
  LockReset as ResetPasswordIcon,
  Search as SearchIcon,
} from '@mui/icons-material';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { withBase } from '../basePath';
import api from '../services/api';
import { handleAuthError, isTokenValid, tryMultipleEndpoints } from '../utils/authErrorHandler';

interface User {
  id: string;
  username: string;
  email: string;
  role: string;
  is_active: boolean;
  created_at: string;
  last_login: string | null;
}

interface UserFormData {
  username: string;
  email: string;
  password?: string;
  role: string;
  is_active: boolean;
}

const UsersManagement: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(10);

  // Filtres de recherche
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Dialog states
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [resetPasswordDialogOpen, setResetPasswordDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  // Form states
  const [formData, setFormData] = useState<UserFormData>({
    username: '',
    email: '',
    password: '',
    role: 'operator',
    is_active: true,
  });
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  useEffect(() => {
    fetchUsers();
  }, []);

  // Revenir à la première page quand un filtre change
  useEffect(() => {
    setPage(0);
  }, [search, roleFilter, statusFilter]);

  const filteredUsers = users.filter((user) => {
    if (roleFilter && user.role !== roleFilter) return false;
    if (statusFilter && String(user.is_active) !== statusFilter) return false;
    if (search) {
      const term = search.toLowerCase();
      return (
        user.username.toLowerCase().includes(term) ||
        user.email.toLowerCase().includes(term)
      );
    }
    return true;
  });

  const hasActiveFilters = Boolean(search || roleFilter || statusFilter);

  const clearFilters = () => {
    setSearch('');
    setRoleFilter('');
    setStatusFilter('');
  };

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      console.log('🔄 Début fetchUsers...');
      
      // Vérifier si le token est valide avant d'essayer les requêtes
      if (!isTokenValid()) {
        setError('Session expirée. Veuillez vous reconnecter.');
        localStorage.clear();
        window.location.href = withBase('/login');
        return;
      }
      
      // Utiliser la stratégie de fallback entre endpoints
      const response = await tryMultipleEndpoints(
        () => api.get('/users'),
        () => api.get('/auth/users'),
        { setError }
      ) as any; // Temporary type assertion for axios response
      
      console.log('📦 Données reçues dans fetchUsers:', response.data);
      console.log('📊 Nombre d\'utilisateurs:', response.data.length);
      setUsers(response.data);
      console.log('✅ setState(users) effectué avec:', response.data);
    } catch (err: any) {
      console.error('Error fetching users:', err);
      
      // Le gestionnaire d'erreurs s'occupe des erreurs 401/422/403
      if (!handleAuthError(err, { setError })) {
        setError('Erreur lors du chargement des utilisateurs');
      }
    } finally {
      setLoading(false);
      console.log('🏁 Fin fetchUsers');
    }
  };

  const handleCreateUser = async () => {
    try {
      if (!formData.username || !formData.email || !formData.password) {
        setError('Tous les champs sont requis');
        return;
      }

      // Essayer d'abord l'endpoint principal /users
      try {
        await api.post('/users', formData);
      } catch (firstError: any) {
        if (firstError.response?.status === 401) {
          setError('Session expirée. Veuillez vous reconnecter.');
          localStorage.clear();
          window.location.href = withBase('/login');
          return;
        }
        // Si l'endpoint /users échoue, essayer /auth/users
        await api.post('/auth/users', formData);
      }
      
      setCreateDialogOpen(false);
      setFormData({
        username: '',
        email: '',
        password: '',
        role: 'operator',
        is_active: true,
      });
      await fetchUsers();
    } catch (err: any) {
      console.error('Error creating user:', err);
      if (err.response?.status === 401) {
        setError('Session expirée. Veuillez vous reconnecter.');
        localStorage.clear();
        window.location.href = withBase('/login');
      } else if (err.response?.status === 403) {
        setError('Vous n\'avez pas les permissions nécessaires pour créer un utilisateur.');
      } else {
        setError('Erreur lors de la création de l\'utilisateur');
      }
    }
  };

  const handleUpdateUser = async () => {
    if (!selectedUser) return;

    try {
      console.log('🔧 Début mise à jour utilisateur:', selectedUser.id);
      const updateData = {
        username: formData.username,
        email: formData.email,
        role: formData.role,
        is_active: formData.is_active,
      };
      console.log('📝 Données à envoyer:', updateData);

      // Essayer d'abord l'endpoint principal /users
      try {
        await api.put(`/users/${selectedUser.id}`, updateData);
      } catch (firstError: any) {
        if (firstError.response?.status === 401) {
          setError('Session expirée. Veuillez vous reconnecter.');
          localStorage.clear();
          window.location.href = withBase('/login');
          return;
        }
        // Si l'endpoint /users échoue, essayer /auth/users
        await api.put(`/auth/users/${selectedUser.id}`, updateData);
      }
      
      console.log('✅ PUT réussi, fermeture du dialog...');
      setEditDialogOpen(false);
      setSelectedUser(null);
      console.log('🔄 Appel de fetchUsers après mise à jour...');
      await fetchUsers();
      console.log('✅ Mise à jour terminée');
    } catch (err: any) {
      console.error('Error updating user:', err);
      if (err.response?.status === 401) {
        setError('Session expirée. Veuillez vous reconnecter.');
        localStorage.clear();
        window.location.href = withBase('/login');
      } else if (err.response?.status === 403) {
        setError('Vous n\'avez pas les permissions nécessaires pour modifier cet utilisateur.');
      } else {
        setError('Erreur lors de la modification de l\'utilisateur');
      }
    }
  };

  const handleDeleteUser = async () => {
    if (!selectedUser) return;

    try {
      // Essayer d'abord l'endpoint principal /users
      try {
        await api.delete(`/users/${selectedUser.id}`);
      } catch (firstError: any) {
        if (firstError.response?.status === 401) {
          setError('Session expirée. Veuillez vous reconnecter.');
          localStorage.clear();
          window.location.href = withBase('/login');
          return;
        }
        // Si l'endpoint /users échoue, essayer /auth/users
        await api.delete(`/auth/users/${selectedUser.id}`);
      }
      
      setDeleteDialogOpen(false);
      setSelectedUser(null);
      await fetchUsers();
    } catch (err: any) {
      console.error('Error deleting user:', err);
      if (err.response?.status === 401) {
        setError('Session expirée. Veuillez vous reconnecter.');
        localStorage.clear();
        window.location.href = withBase('/login');
      } else if (err.response?.status === 403) {
        setError('Vous n\'avez pas les permissions nécessaires pour supprimer cet utilisateur.');
      } else {
        setError('Erreur lors de la suppression de l\'utilisateur');
      }
    }
  };

  const handleResetPassword = async () => {
    if (!selectedUser || newPassword !== confirmPassword) {
      setError('Les mots de passe ne correspondent pas');
      return;
    }

    try {
      await api.post(`/users/${selectedUser.id}/reset-password`, {
        newPassword: newPassword,
      });
      setResetPasswordDialogOpen(false);
      setSelectedUser(null);
      setNewPassword('');
      setConfirmPassword('');
    } catch (err: any) {
      console.error('Error resetting password:', err);
      setError('Erreur lors de la réinitialisation du mot de passe');
    }
  };

  const handleOpenCreateDialog = () => {
    setFormData({
      username: '',
      email: '',
      password: '',
      role: 'operator',
      is_active: true,
    });
    setCreateDialogOpen(true);
  };

  const handleOpenEditDialog = (user: User) => {
    setSelectedUser(user);
    setFormData({
      username: user.username,
      email: user.email,
      role: user.role,
      is_active: user.is_active,
    });
    setEditDialogOpen(true);
  };

  const handleOpenDeleteDialog = (user: User) => {
    setSelectedUser(user);
    setDeleteDialogOpen(true);
  };

  const handleOpenResetPasswordDialog = (user: User) => {
    setSelectedUser(user);
    setNewPassword('');
    setConfirmPassword('');
    setResetPasswordDialogOpen(true);
  };

  const renderRoleChip = (role: string) => {
    const color = role === 'admin' ? 'primary' : 'default';
    return <Chip label={role} color={color} size="small" />;
  };

  const renderStatusChip = (isActive: boolean) => {
    return (
      <Chip
        label={isActive ? 'Actif' : 'Inactif'}
        color={isActive ? 'success' : 'default'}
        size="small"
      />
    );
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" p={4}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h6">Gestion des utilisateurs</Typography>
        <Stack direction="row" spacing={1}>
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={fetchUsers}
          >
            Actualiser
          </Button>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleOpenCreateDialog}
          >
            Nouvel utilisateur
          </Button>
        </Stack>
      </Box>

      <Paper variant="outlined" sx={{ p: 2, mb: 2 }}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'center' }}>
          <TextField
            size="small"
            placeholder="Rechercher par nom d'utilisateur ou email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            sx={{ flexGrow: 1, minWidth: 240 }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" />
                </InputAdornment>
              ),
            }}
          />
          <FormControl size="small" sx={{ minWidth: 160 }}>
            <InputLabel id="role-filter-label">Rôle</InputLabel>
            <Select
              labelId="role-filter-label"
              label="Rôle"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
            >
              <MenuItem value="">Tous les rôles</MenuItem>
              <MenuItem value="admin">Administrateur</MenuItem>
              <MenuItem value="operator">Opérateur</MenuItem>
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel id="status-filter-label">Statut</InputLabel>
            <Select
              labelId="status-filter-label"
              label="Statut"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <MenuItem value="">Tous les statuts</MenuItem>
              <MenuItem value="true">Actif</MenuItem>
              <MenuItem value="false">Inactif</MenuItem>
            </Select>
          </FormControl>
          {hasActiveFilters && (
            <Button size="small" color="inherit" startIcon={<ClearIcon />} onClick={clearFilters}>
              Effacer
            </Button>
          )}
          <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'nowrap' }}>
            {filteredUsers.length} / {users.length} utilisateur(s)
          </Typography>
        </Stack>
      </Paper>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Nom d'utilisateur</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Rôle</TableCell>
              <TableCell>Statut</TableCell>
              <TableCell>Créé le</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filteredUsers.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} align="center" sx={{ py: 4 }}>
                  <Typography variant="body2" color="text.secondary">
                    {hasActiveFilters
                      ? 'Aucun utilisateur ne correspond aux filtres.'
                      : 'Aucun utilisateur.'}
                  </Typography>
                </TableCell>
              </TableRow>
            ) : filteredUsers
              .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
              .map((user) => (
                <TableRow key={user.id}>
                  <TableCell>{user.username}</TableCell>
                  <TableCell>{user.email}</TableCell>
                  <TableCell>{renderRoleChip(user.role)}</TableCell>
                  <TableCell>{renderStatusChip(user.is_active)}</TableCell>
                  <TableCell>
                    {new Date(user.created_at).toLocaleDateString('fr-FR')}
                  </TableCell>
                  <TableCell>
                    <Stack direction="row" spacing={1}>
                      <Tooltip title="Modifier">
                        <IconButton
                          size="small"
                          onClick={() => handleOpenEditDialog(user)}
                        >
                          <EditIcon />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Réinitialiser le mot de passe">
                        <IconButton
                          size="small"
                          onClick={() => handleOpenResetPasswordDialog(user)}
                        >
                          <ResetPasswordIcon />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Supprimer">
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => handleOpenDeleteDialog(user)}
                        >
                          <DeleteIcon />
                        </IconButton>
                      </Tooltip>
                    </Stack>
                  </TableCell>
                </TableRow>
              ))}
          </TableBody>
        </Table>
      </TableContainer>

      <TablePagination
        rowsPerPageOptions={[5, 10, 25]}
        component="div"
        count={filteredUsers.length}
        rowsPerPage={rowsPerPage}
        page={page}
        onPageChange={(_, newPage) => setPage(newPage)}
        onRowsPerPageChange={(e) => {
          setRowsPerPage(parseInt(e.target.value, 10));
          setPage(0);
        }}
      />

      {/* Create User Dialog */}
      <Dialog 
        open={createDialogOpen} 
        onClose={() => setCreateDialogOpen(false)} 
        maxWidth="sm" 
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>Créer un nouvel utilisateur</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Nom d'utilisateur"
            fullWidth
            value={formData.username}
            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
          />
          <TextField
            margin="dense"
            label="Email"
            type="email"
            fullWidth
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
          />
          <TextField
            margin="dense"
            label="Mot de passe"
            type="password"
            fullWidth
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
          />
          <FormControl fullWidth margin="dense">
            <InputLabel>Rôle</InputLabel>
            <Select
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value })}
            >
              <MenuItem value="admin">Administrateur</MenuItem>
              <MenuItem value="operator">Opérateur</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateDialogOpen(false)}>Annuler</Button>
          <Button onClick={handleCreateUser} variant="contained">Créer</Button>
        </DialogActions>
      </Dialog>

      {/* Edit User Dialog */}
      <Dialog 
        open={editDialogOpen} 
        onClose={() => setEditDialogOpen(false)} 
        maxWidth="sm" 
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>Modifier l'utilisateur</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Nom d'utilisateur"
            fullWidth
            value={formData.username}
            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
          />
          <TextField
            margin="dense"
            label="Email"
            type="email"
            fullWidth
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
          />
          <FormControl fullWidth margin="dense">
            <InputLabel>Rôle</InputLabel>
            <Select
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value })}
            >
              <MenuItem value="admin">Administrateur</MenuItem>
              <MenuItem value="operator">Opérateur</MenuItem>
            </Select>
          </FormControl>
          <FormControl fullWidth margin="dense">
            <InputLabel>Statut</InputLabel>
            <Select
              value={formData.is_active ? 'active' : 'inactive'}
              onChange={(e) => setFormData({ ...formData, is_active: e.target.value === 'active' })}
            >
              <MenuItem value="active">Actif</MenuItem>
              <MenuItem value="inactive">Inactif</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Annuler</Button>
          <Button onClick={handleUpdateUser} variant="contained">Modifier</Button>
        </DialogActions>
      </Dialog>

      {/* Delete User Dialog */}
      <Dialog 
        open={deleteDialogOpen} 
        onClose={() => setDeleteDialogOpen(false)}
        disableRestoreFocus
      >
        <DialogTitle>Confirmer la suppression</DialogTitle>
        <DialogContent>
          <Typography>
            Êtes-vous sûr de vouloir supprimer l'utilisateur "{selectedUser?.username}" ?
            Cette action est irréversible.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialogOpen(false)}>Annuler</Button>
          <Button onClick={handleDeleteUser} color="error" variant="contained">
            Supprimer
          </Button>
        </DialogActions>
      </Dialog>

      {/* Reset Password Dialog */}
      <Dialog 
        open={resetPasswordDialogOpen} 
        onClose={() => setResetPasswordDialogOpen(false)} 
        maxWidth="sm" 
        fullWidth
        disableRestoreFocus
      >
        <DialogTitle>Réinitialiser le mot de passe</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Réinitialiser le mot de passe pour "{selectedUser?.username}"
          </Typography>
          <TextField
            margin="dense"
            label="Nouveau mot de passe"
            type="password"
            fullWidth
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
          />
          <TextField
            margin="dense"
            label="Confirmer le mot de passe"
            type="password"
            fullWidth
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setResetPasswordDialogOpen(false)}>Annuler</Button>
          <Button 
            onClick={handleResetPassword} 
            variant="contained"
            disabled={!newPassword || newPassword !== confirmPassword}
          >
            Réinitialiser
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default UsersManagement; 