import {
    Add as AddIcon,
    SupervisorAccount as AdminIcon,
    Delete as DeleteIcon,
    Edit as EditIcon,
    Person as OperatorIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    FormControl,
    Grid,
    IconButton,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TextField,
    Typography,
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import RoleBasedRoute from '../components/auth/RoleBasedRoute';
import { useAuth } from '../hooks/useAuth';

interface User {
  id: string;
  username: string;
  email: string;
  role: 'admin' | 'operator';
  is_active: boolean;
  created_at: string;
  last_login: string | null;
}

const UserManagement: React.FC = () => {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    role: 'operator' as 'admin' | 'operator',
    is_active: true,
  });

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async () => {
    try {
      setLoading(true);
      // Simuler un appel API - à remplacer par le vrai appel
      setTimeout(() => {
        setUsers([
          {
            id: 'admin01',
            username: 'admin',
            email: 'admin@example.com',
            role: 'admin',
            is_active: true,
            created_at: '2025-05-02T23:29:35.296Z',
            last_login: null,
          },
          {
            id: 'f67622ce-44d3-4172-b6e7-27ebfee52699',
            username: 'operator1',
            email: 'operator@example.com',
            role: 'operator',
            is_active: true,
            created_at: '2025-05-13T19:36:46.740Z',
            last_login: null,
          }
        ]);
        setLoading(false);
      }, 1000);
    } catch (err) {
      setError('Erreur lors du chargement des utilisateurs');
      setLoading(false);
    }
  };

  const handleOpenDialog = (user?: User) => {
    if (user) {
      setEditingUser(user);
      setFormData({
        username: user.username,
        email: user.email,
        password: '',
        role: user.role,
        is_active: user.is_active,
      });
    } else {
      setEditingUser(null);
      setFormData({
        username: '',
        email: '',
        password: '',
        role: 'operator',
        is_active: true,
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingUser(null);
    setFormData({
      username: '',
      email: '',
      password: '',
      role: 'operator',
      is_active: true,
    });
  };

  const handleSubmit = async () => {
    try {
      if (editingUser) {
        // Mise à jour utilisateur
        console.log('Mise à jour utilisateur:', formData);
      } else {
        // Création utilisateur
        console.log('Création utilisateur:', formData);
      }
      handleCloseDialog();
      await loadUsers();
    } catch (err) {
      setError('Erreur lors de la sauvegarde');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (userId === currentUser?.id) {
      setError('Vous ne pouvez pas supprimer votre propre compte');
      return;
    }
    
    if (window.confirm('Êtes-vous sûr de vouloir supprimer cet utilisateur ?')) {
      try {
        console.log('Suppression utilisateur:', userId);
        await loadUsers();
      } catch (err) {
        setError('Erreur lors de la suppression');
      }
    }
  };

  const getRoleIcon = (role: string) => {
    return role === 'admin' ? <AdminIcon fontSize="small" /> : <OperatorIcon fontSize="small" />;
  };

  const getRoleColor = (role: string) => {
    return role === 'admin' ? 'error' : 'primary';
  };

  const getRoleText = (role: string) => {
    return role === 'admin' ? 'Administrateur' : 'Opérateur';
  };

  return (
    <RoleBasedRoute requiredRoles={['admin']}>
      <Box sx={{ p: 3 }}>
        <Grid container spacing={3}>
          <Grid item xs={12}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
              <Typography variant="h4" component="h1">
                Gestion des utilisateurs
              </Typography>
              <Button
                variant="contained"
                startIcon={<AddIcon />}
                onClick={() => handleOpenDialog()}
              >
                Nouvel utilisateur
              </Button>
            </Box>
          </Grid>

          {error && (
            <Grid item xs={12}>
              <Alert severity="error" onClose={() => setError(null)}>
                {error}
              </Alert>
            </Grid>
          )}

          <Grid item xs={12}>
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Liste des utilisateurs
                </Typography>
                
                <TableContainer component={Paper} sx={{ mt: 2 }}>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>Nom d'utilisateur</TableCell>
                        <TableCell>Email</TableCell>
                        <TableCell>Rôle</TableCell>
                        <TableCell>Statut</TableCell>
                        <TableCell>Dernière connexion</TableCell>
                        <TableCell align="center">Actions</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {loading ? (
                        <TableRow>
                          <TableCell colSpan={6} align="center">
                            Chargement...
                          </TableCell>
                        </TableRow>
                      ) : users.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={6} align="center">
                            Aucun utilisateur trouvé
                          </TableCell>
                        </TableRow>
                      ) : (
                        users.map((user) => (
                          <TableRow key={user.id}>
                            <TableCell>
                              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                                {getRoleIcon(user.role)}
                                <Typography sx={{ ml: 1 }}>{user.username}</Typography>
                              </Box>
                            </TableCell>
                            <TableCell>{user.email}</TableCell>
                            <TableCell>
                              <Chip 
                                label={getRoleText(user.role)}
                                color={getRoleColor(user.role)}
                                size="small"
                                icon={getRoleIcon(user.role)}
                              />
                            </TableCell>
                            <TableCell>
                              <Chip 
                                label={user.is_active ? 'Actif' : 'Inactif'}
                                color={user.is_active ? 'success' : 'default'}
                                size="small"
                              />
                            </TableCell>
                            <TableCell>
                              {user.last_login 
                                ? new Date(user.last_login).toLocaleDateString()
                                : 'Jamais connecté'
                              }
                            </TableCell>
                            <TableCell align="center">
                              <IconButton 
                                onClick={() => handleOpenDialog(user)}
                                size="small"
                                color="primary"
                              >
                                <EditIcon />
                              </IconButton>
                              <IconButton 
                                onClick={() => handleDeleteUser(user.id)}
                                size="small"
                                color="error"
                                disabled={user.id === currentUser?.id}
                              >
                                <DeleteIcon />
                              </IconButton>
                            </TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          </Grid>
        </Grid>

        {/* Dialog pour créer/modifier un utilisateur */}
        <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth disableRestoreFocus>
          <DialogTitle>
            {editingUser ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur'}
          </DialogTitle>
          <DialogContent>
            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
              <TextField
                label="Nom d'utilisateur"
                value={formData.username}
                onChange={(e) => setFormData({ ...formData, username: e.target.value })}
                fullWidth
                required
              />
              <TextField
                label="Email"
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                fullWidth
                required
              />
              {!editingUser && (
                <TextField
                  label="Mot de passe"
                  type="password"
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  fullWidth
                  required
                />
              )}
              <FormControl fullWidth>
                <InputLabel>Rôle</InputLabel>
                <Select
                  value={formData.role}
                  onChange={(e) => setFormData({ ...formData, role: e.target.value as 'admin' | 'operator' })}
                  label="Rôle"
                >
                  <MenuItem value="operator">Opérateur</MenuItem>
                  <MenuItem value="admin">Administrateur</MenuItem>
                </Select>
              </FormControl>
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCloseDialog}>Annuler</Button>
            <Button onClick={handleSubmit} variant="contained">
              {editingUser ? 'Modifier' : 'Créer'}
            </Button>
          </DialogActions>
        </Dialog>
      </Box>
    </RoleBasedRoute>
  );
};

export default UserManagement; 