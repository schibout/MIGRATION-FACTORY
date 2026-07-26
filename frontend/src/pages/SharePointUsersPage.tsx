import {
    AutoFixHigh as AssociateIcon,
    Cancel as CancelIcon,
    CloudDownload as CloudDownloadIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Visibility as VisibilityIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    CircularProgress,
    IconButton,
    InputAdornment,
    LinearProgress,
    Paper,
    Snackbar,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TableSortLabel,
    TextField,
    Tooltip,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import IfsPersonAutocomplete from '../components/IfsPersonAutocomplete';
import api from '../services/api';

interface SharePointUser {
    id: number;
    sharepoint_user_id: number;
    login_name: string;
    title: string;
    email: string;
    person_id: string | null;
    principal_type: number;
    is_site_admin: boolean;
    is_hidden_in_ui: boolean;
    name_id: string;
    name_id_issuer: string;
    imported_at: string;
}

const SharePointUsersPage: React.FC = () => {
    const navigate = useNavigate();
    const [users, setUsers] = useState<SharePointUser[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalUsers, setTotalUsers] = useState(0);
    const [search, setSearch] = useState('');
    const [importing, setImporting] = useState(false);
    const [associating, setAssociating] = useState(false);
    const [sortBy, setSortBy] = useState<string>('title');
    const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
    const [snack, setSnack] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
        open: false,
        message: '',
        severity: 'success',
    });

    // Mise à jour de l'association IFS Person d'un utilisateur (optimiste + rollback)
    const updatePersonId = async (user: SharePointUser, newPersonId: string | null) => {
        const previous = user.person_id;
        if (previous === newPersonId) return;

        // Mise à jour optimiste
        setUsers((prev) =>
            prev.map((u) => (u.id === user.id ? { ...u, person_id: newPersonId } : u))
        );

        try {
            await api.put(`/data/sharepoint-users/${user.sharepoint_user_id}`, {
                person_id: newPersonId,
            });
            setSnack({
                open: true,
                message: newPersonId
                    ? `IFS Person mis à jour : ${newPersonId}`
                    : 'IFS Person dissocié',
                severity: 'success',
            });
        } catch (err: any) {
            // Rollback en cas d'échec
            setUsers((prev) =>
                prev.map((u) => (u.id === user.id ? { ...u, person_id: previous } : u))
            );
            setSnack({
                open: true,
                message: err.response?.data?.message || 'Échec de la mise à jour de l\'IFS Person',
                severity: 'error',
            });
        }
    };

    // Charger les utilisateurs
    const loadUsers = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/data/sharepoint-users', {
                params: {
                    page: page + 1,
                    per_page: rowsPerPage,
                    search: search,
                    sort_by: sortBy,
                    sort_order: sortOrder
                }
            });
            
            if (response.data.success) {
                setUsers(response.data.data);
                setTotalUsers(response.data.total);
            } else {
                setError(response.data.message || 'Erreur lors du chargement des utilisateurs');
            }
        } catch (err) {
            setError('Erreur lors du chargement des utilisateurs');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    // Importer les utilisateurs depuis SharePoint
    const importUsers = async () => {
        try {
            setImporting(true);
            setError(null);
            
            const response = await api.post('/import/users', {
                limit: 5000
            });
            
            if (response.data.success) {
                alert(`✅ Import réussi: ${response.data.imported_count} utilisateurs importés`);
                loadUsers();
            } else {
                setError(response.data.error || 'Erreur lors de l\'import');
            }
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors de l\'import');
            console.error(err);
        } finally {
            setImporting(false);
        }
    };

    // Backfill automatique des associations IFS Person (matching par nom)
    const associateIfsPersons = async () => {
        try {
            setAssociating(true);
            const response = await api.post('/data/sharepoint-users/associate-ifs-persons');
            if (response.data.success) {
                setSnack({
                    open: true,
                    message: `${response.data.associated_count} nouvelle(s) association(s) IFS Person`,
                    severity: 'success',
                });
                loadUsers();
            } else {
                setSnack({ open: true, message: response.data.message || 'Échec de l\'association', severity: 'error' });
            }
        } catch (err: any) {
            setSnack({
                open: true,
                message: err.response?.data?.message || 'Erreur lors de l\'association IFS Person',
                severity: 'error',
            });
        } finally {
            setAssociating(false);
        }
    };

    useEffect(() => {
        loadUsers();
    }, [page, rowsPerPage, sortBy, sortOrder]);

    const handleSearch = () => {
        setPage(0);
        loadUsers();
    };

    // Tri : clic sur un en-tête → bascule asc/desc, ou change de colonne
    const handleSort = (column: string) => {
        if (sortBy === column) {
            setSortOrder((prev) => (prev === 'asc' ? 'desc' : 'asc'));
        } else {
            setSortBy(column);
            setSortOrder('asc');
        }
        setPage(0);
    };

    const handleChangePage = (_event: unknown, newPage: number) => {
        setPage(newPage);
    };

    const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
    };

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ mb: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Typography variant="h4" component="h1">
                    Utilisateurs SharePoint ASAP
                </Typography>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadUsers}
                        disabled={loading || importing}
                    >
                        Actualiser
                    </Button>
                    <Button
                        variant="outlined"
                        color="secondary"
                        startIcon={<AssociateIcon />}
                        onClick={associateIfsPersons}
                        disabled={associating || importing}
                    >
                        {associating ? 'Association...' : 'Associer IFS Person'}
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<CloudDownloadIcon />}
                        onClick={importUsers}
                        disabled={importing}
                    >
                        {importing ? 'Import en cours...' : 'Importer depuis SharePoint'}
                    </Button>
                </Box>
            </Box>

            {error && (
                <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
                    {error}
                </Alert>
            )}

            <Paper sx={{ mb: 2, p: 2 }}>
                <TextField
                    fullWidth
                    placeholder="Rechercher par nom, login ou email..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon />
                            </InputAdornment>
                        ),
                        endAdornment: search && (
                            <InputAdornment position="end">
                                <IconButton onClick={() => { setSearch(''); handleSearch(); }} size="small">
                                    <CancelIcon />
                                </IconButton>
                            </InputAdornment>
                        )
                    }}
                />
            </Paper>

            <Paper>
                {importing && <LinearProgress />}
                
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow>
                                {([
                                    { id: 'sharepoint_user_id', label: 'ID SharePoint' },
                                    { id: 'title', label: 'Nom' },
                                    { id: 'login_name', label: 'Login' },
                                    { id: 'email', label: 'Email' },
                                    { id: 'person_id', label: 'IFS Person' },
                                ] as const).map((col) => (
                                    <TableCell
                                        key={col.id}
                                        sortDirection={sortBy === col.id ? sortOrder : false}
                                    >
                                        <TableSortLabel
                                            active={sortBy === col.id}
                                            direction={sortBy === col.id ? sortOrder : 'asc'}
                                            onClick={() => handleSort(col.id)}
                                        >
                                            {col.label}
                                        </TableSortLabel>
                                    </TableCell>
                                ))}
                                <TableCell align="center">Actions</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {
                                loading && !importing ? (
                                    <TableRow>
                                        <TableCell colSpan={6} align="center">
                                            <CircularProgress />
                                        </TableCell>
                                    </TableRow>
                                ) : users.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={6} align="center">
                                            <Typography color="text.secondary">
                                                Aucun utilisateur trouvé
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                users.map((user) => (
                                    <TableRow key={user.id} hover>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight="medium">
                                                {user.sharepoint_user_id}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2">
                                                {user.title || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {user.login_name || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {user.email || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell sx={{ minWidth: 240 }}>
                                            <IfsPersonAutocomplete
                                                value={user.person_id}
                                                onChange={(newPersonId) => updatePersonId(user, newPersonId)}
                                                minWidth={220}
                                            />
                                        </TableCell>
                                        <TableCell align="center">
                                            <Tooltip title="Voir les détails">
                                                <IconButton 
                                                    size="small" 
                                                    color="primary"
                                                    onClick={() => navigate(`/users/detail/${user.sharepoint_user_id}`)}
                                                >
                                                    <VisibilityIcon fontSize="small" />
                                                </IconButton>
                                            </Tooltip>
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>

                <TablePagination
                    component="div"
                    count={totalUsers}
                    page={page}
                    onPageChange={handleChangePage}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={handleChangeRowsPerPage}
                    rowsPerPageOptions={[25, 50, 100]}
                    labelRowsPerPage="Lignes par page:"
                    labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
                />
            </Paper>

            <Snackbar
                open={snack.open}
                autoHideDuration={3000}
                onClose={() => setSnack((s) => ({ ...s, open: false }))}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
            >
                <Alert
                    severity={snack.severity}
                    onClose={() => setSnack((s) => ({ ...s, open: false }))}
                    sx={{ width: '100%' }}
                >
                    {snack.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default SharePointUsersPage;

