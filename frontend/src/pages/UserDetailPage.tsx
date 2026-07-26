import {
    ArrowBack as ArrowBackIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon,
    AdminPanelSettings as AdminIcon,
    OpenInNew as OpenInNewIcon,
    Person as PersonIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    CircularProgress,
    Divider,
    Grid,
    Chip,
    Link,
    Snackbar,
    Tooltip,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom';
import IfsPersonAutocomplete from '../components/IfsPersonAutocomplete';
import api from '../services/api';

interface SharePointUser {
    id: number;
    sharepoint_user_id: number;
    login_name: string;
    title: string;
    person_id: string | null;
    email: string;
    principal_type: number;
    is_site_admin: boolean;
    is_hidden_in_ui: boolean;
    name_id: string;
    name_id_issuer: string;
    created_at: string;
    updated_at: string;
    imported_at: string;
}

const UserDetailPage: React.FC = () => {
    const navigate = useNavigate();
    const { userId } = useParams<{ userId: string }>();
    const [user, setUser] = useState<SharePointUser | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [snack, setSnack] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
        open: false,
        message: '',
        severity: 'success',
    });

    // Mise à jour de l'association IFS Person (auto-save à la sélection, optimiste + rollback)
    const updatePersonId = async (newPersonId: string | null) => {
        if (!user) return;
        const previous = user.person_id;
        if (previous === newPersonId) return;

        setUser((prev) => (prev ? { ...prev, person_id: newPersonId } : prev));
        try {
            await api.put(`/data/sharepoint-users/${user.sharepoint_user_id}`, {
                person_id: newPersonId,
            });
            setSnack({
                open: true,
                message: newPersonId ? `IFS Person mis à jour : ${newPersonId}` : 'IFS Person dissocié',
                severity: 'success',
            });
        } catch (err: any) {
            setUser((prev) => (prev ? { ...prev, person_id: previous } : prev));
            setSnack({
                open: true,
                message: err.response?.data?.message || 'Échec de la mise à jour de l\'IFS Person',
                severity: 'error',
            });
        }
    };

    useEffect(() => {
        const loadUserDetail = async () => {
            if (!userId) {
                setError('ID utilisateur manquant');
                setLoading(false);
                return;
            }

            try {
                setLoading(true);
                setError(null);
                const response = await api.get(`/data/sharepoint-users/${userId}`);
                
                if (response.data.success) {
                    setUser(response.data.data);
                } else {
                    setError(response.data.message || 'Erreur lors du chargement des détails');
                }
            } catch (err: any) {
                setError(err.response?.data?.message || 'Erreur lors du chargement des détails');
                console.error('Erreur:', err);
            } finally {
                setLoading(false);
            }
        };

        loadUserDetail();
    }, [userId]);

    const formatDateTime = (dateString: string | null | undefined) => {
        if (!dateString) return '-';
        try {
            return new Date(dateString).toLocaleString('fr-FR', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch {
            return dateString;
        }
    };

    const getPrincipalTypeLabel = (type: number) => {
        switch (type) {
            case 1: return 'Utilisateur';
            case 4: return 'Groupe de sécurité';
            case 8: return 'Groupe SharePoint';
            default: return `Type ${type}`;
        }
    };

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '400px' }}>
                <CircularProgress />
            </Box>
        );
    }

    if (error || !user) {
        return (
            <Box sx={{ p: 3 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/import/sharepoint-users')}
                    sx={{ mb: 2 }}
                >
                    Retour à la liste
                </Button>
                <Alert severity="error">{error || 'Utilisateur non trouvé'}</Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 2 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/import/sharepoint-users')}
                    variant="outlined"
                >
                    Retour à la liste
                </Button>
                <Typography variant="h4" component="h1">
                    Détails de l'utilisateur
                </Typography>
            </Box>

            <Grid container spacing={3}>
                {/* Informations principales */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                <PersonIcon sx={{ mr: 1, color: 'primary.main' }} />
                                <Typography variant="h6">
                                    Informations Générales
                                </Typography>
                            </Box>
                            <Divider sx={{ mb: 2 }} />
                            
                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Nom complet
                                </Typography>
                                <Typography variant="body1" fontWeight="medium">
                                    {user.title || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    ID SharePoint
                                </Typography>
                                <Typography variant="body1">
                                    {user.sharepoint_user_id}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary" gutterBottom>
                                    Identifiant IFS
                                </Typography>
                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <IfsPersonAutocomplete
                                        value={user.person_id}
                                        onChange={updatePersonId}
                                        minWidth={260}
                                    />
                                    {user.person_id && (
                                        <Tooltip title="Voir la fiche IFS Person">
                                            <Link
                                                component={RouterLink}
                                                to={`/ressources/ifs-person?search=${encodeURIComponent(user.person_id)}`}
                                                sx={{ display: 'flex', alignItems: 'center' }}
                                            >
                                                <OpenInNewIcon fontSize="small" />
                                            </Link>
                                        </Tooltip>
                                    )}
                                </Box>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Email
                                </Typography>
                                <Typography variant="body1">
                                    {user.email || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Nom de connexion
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all', fontFamily: 'monospace', fontSize: '0.9rem' }}>
                                    {user.login_name || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Type de principal
                                </Typography>
                                <Box sx={{ mt: 0.5 }}>
                                    <Chip 
                                        label={getPrincipalTypeLabel(user.principal_type)} 
                                        color={user.principal_type === 1 ? 'primary' : 'default'}
                                        size="small"
                                    />
                                </Box>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Permissions et sécurité */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                                <AdminIcon sx={{ mr: 1, color: 'warning.main' }} />
                                <Typography variant="h6">
                                    Permissions & Sécurité
                                </Typography>
                            </Box>
                            <Divider sx={{ mb: 2 }} />

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Administrateur du site
                                </Typography>
                                <Box sx={{ mt: 0.5 }}>
                                    {user.is_site_admin ? (
                                        <Chip 
                                            icon={<CheckCircleIcon />} 
                                            label="Oui" 
                                            color="warning" 
                                            size="small"
                                        />
                                    ) : (
                                        <Chip 
                                            icon={<CancelIcon />} 
                                            label="Non" 
                                            color="default" 
                                            size="small"
                                        />
                                    )}
                                </Box>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Caché dans l'interface
                                </Typography>
                                <Box sx={{ mt: 0.5 }}>
                                    {user.is_hidden_in_ui ? (
                                        <Chip 
                                            icon={<CheckCircleIcon />} 
                                            label="Oui" 
                                            color="default" 
                                            size="small"
                                        />
                                    ) : (
                                        <Chip 
                                            icon={<CancelIcon />} 
                                            label="Non" 
                                            color="success" 
                                            size="small"
                                        />
                                    )}
                                </Box>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Name ID (SID)
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all', fontFamily: 'monospace', fontSize: '0.85rem' }}>
                                    {user.name_id || '-'}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="body2" color="text.secondary">
                                    Name ID Issuer
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all', fontSize: '0.9rem' }}>
                                    {user.name_id_issuer || '-'}
                                </Typography>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Métadonnées */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Métadonnées d'import
                            </Typography>
                            <Divider sx={{ mb: 2 }} />

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Date de création
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(user.created_at)}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Dernière modification
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(user.updated_at)}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="body2" color="text.secondary">
                                    Importé le
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(user.imported_at)}
                                </Typography>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

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

export default UserDetailPage;

