import {
    ArrowBack as ArrowBackIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon
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
    Paper,
    Typography,
    Chip
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { resourceService, SharePointResource } from '../services/resourceService';

const ResourceDetailPage: React.FC = () => {
    const navigate = useNavigate();
    const { resourceId } = useParams<{ resourceId: string }>();
    const [resource, setResource] = useState<SharePointResource | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const loadResourceDetail = async () => {
            if (!resourceId) {
                setError('ID de ressource manquant');
                setLoading(false);
                return;
            }

            try {
                setLoading(true);
                setError(null);
                const data = await resourceService.getResourceDetail(parseInt(resourceId));
                setResource(data);
            } catch (err: any) {
                setError(err.response?.data?.message || 'Erreur lors du chargement des détails');
                console.error('Erreur:', err);
            } finally {
                setLoading(false);
            }
        };

        loadResourceDetail();
    }, [resourceId]);

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

    if (loading) {
        return (
            <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '400px' }}>
                <CircularProgress />
            </Box>
        );
    }

    if (error || !resource) {
        return (
            <Box sx={{ p: 3 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/import/sharepoint-resources')}
                    sx={{ mb: 2 }}
                >
                    Retour à la liste
                </Button>
                <Alert severity="error">{error || 'Ressource non trouvée'}</Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 2 }}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/import/sharepoint-resources')}
                    variant="outlined"
                >
                    Retour à la liste
                </Button>
                <Typography variant="h4" component="h1">
                    Détails de la ressource
                </Typography>
            </Box>

            <Grid container spacing={3}>
                {/* Informations principales */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Informations Générales
                            </Typography>
                            <Divider sx={{ mb: 2 }} />
                            
                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Titre
                                </Typography>
                                <Typography variant="body1">
                                    {resource.title || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    ID SharePoint
                                </Typography>
                                <Typography variant="body1">
                                    {resource.sharepoint_item_id}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Type ID
                                </Typography>
                                <Typography variant="body1">
                                    {resource.resource_type_id}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Max Unit
                                </Typography>
                                <Typography variant="body1">
                                    {resource.max_unit}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Générique
                                </Typography>
                                <Box sx={{ mt: 0.5 }}>
                                    {resource.generic ? (
                                        <Chip 
                                            icon={<CheckCircleIcon />} 
                                            label="Oui" 
                                            color="success" 
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
                                    Pièces jointes
                                </Typography>
                                <Box sx={{ mt: 0.5 }}>
                                    {resource.attachments ? (
                                        <Chip 
                                            icon={<CheckCircleIcon />} 
                                            label="Oui" 
                                            color="info" 
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
                        </CardContent>
                    </Card>
                </Grid>

                {/* Informations de sécurité et système */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Sécurité & Système
                            </Typography>
                            <Divider sx={{ mb: 2 }} />

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Compte Windows
                                </Typography>
                                <Typography variant="body1">
                                    {resource.windows_account_id || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Groupe de Sécurité
                                </Typography>
                                <Typography variant="body1">
                                    {resource.security_group || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Content Type ID
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all' }}>
                                    {resource.content_type_id || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    UI Version
                                </Typography>
                                <Typography variant="body1">
                                    {resource.ui_version_string || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    File System Object Type
                                </Typography>
                                <Typography variant="body1">
                                    {resource.file_system_object_type}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    GUID
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all' }}>
                                    {resource.guid || '-'}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    ETag
                                </Typography>
                                <Typography variant="body1" sx={{ wordBreak: 'break-all' }}>
                                    {resource.etag || '-'}
                                </Typography>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Informations temporelles */}
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Métadonnées
                            </Typography>
                            <Divider sx={{ mb: 2 }} />

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Auteur ID
                                </Typography>
                                <Typography variant="body1">
                                    {resource.author_id}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Éditeur ID
                                </Typography>
                                <Typography variant="body1">
                                    {resource.editor_id}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Créé le
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(resource.created)}
                                </Typography>
                            </Box>

                            <Box sx={{ mb: 2 }}>
                                <Typography variant="body2" color="text.secondary">
                                    Modifié le
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(resource.modified)}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="body2" color="text.secondary">
                                    Importé le
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(resource.imported_at)}
                                </Typography>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        </Box>
    );
};

export default ResourceDetailPage;


