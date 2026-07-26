import {
    CloudDownload as CloudDownloadIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Visibility as VisibilityIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    CircularProgress,
    IconButton,
    InputAdornment,
    LinearProgress,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Tooltip,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { resourceService, SharePointResource } from '../services/resourceService';

const SharePointResourcesPage: React.FC = () => {
    const navigate = useNavigate();
    const [resources, setResources] = useState<SharePointResource[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalResources, setTotalResources] = useState(0);
    const [search, setSearch] = useState('');
    const [importing, setImporting] = useState(false);

    // Charger les ressources
    const loadResources = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await resourceService.getResources(page + 1, rowsPerPage, search);
            
            if (response.success) {
                setResources(response.data);
                setTotalResources(response.total);
            } else {
                setError(response.message || 'Erreur lors du chargement des ressources');
            }
        } catch (err) {
            setError('Erreur lors du chargement des ressources');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    // Importer les ressources depuis SharePoint
    const handleImport = async () => {
        try {
            setImporting(true);
            setError(null);
            const response = await resourceService.importResources();
            
            if (response.success) {
                // Recharger les ressources après l'import
                await loadResources();
                alert(`${response.imported_count} ressources importées avec succès !`);
            } else {
                setError(response.message || 'Erreur lors de l\'import');
            }
        } catch (err) {
            setError('Erreur lors de l\'import des ressources');
            console.error(err);
        } finally {
            setImporting(false);
        }
    };

    // Charger les ressources au montage et quand la page change
    useEffect(() => {
        loadResources();
    }, [page, rowsPerPage]);

    // Recherche avec debounce
    useEffect(() => {
        const timer = setTimeout(() => {
            if (page === 0) {
                loadResources();
            } else {
                setPage(0); // Reset page quand on recherche
            }
        }, 500); // 500ms de délai

        return () => clearTimeout(timer);
    }, [search]);

    // Gestion du changement de page
    const handleChangePage = (event: unknown, newPage: number) => {
        setPage(newPage);
    };

    // Gestion du changement de lignes par page
    const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
    };

    // Formater la date
    const formatDate = (dateString: string | null): string => {
        if (!dateString) return '-';
        return new Date(dateString).toLocaleDateString('fr-FR');
    };

    // Formater la date et heure
    const formatDateTime = (dateString: string | null): string => {
        if (!dateString) return '-';
        return new Date(dateString).toLocaleString('fr-FR');
    };

    return (
        <Box sx={{ p: 3 }}>
            <Paper sx={{ p: 3, mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        Ressources SharePoint
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 2 }}>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={loadResources}
                            disabled={loading || importing}
                        >
                            Actualiser
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<CloudDownloadIcon />}
                            onClick={handleImport}
                            disabled={loading || importing}
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

                <TextField
                    fullWidth
                    placeholder="Rechercher par ID, titre, type ou compte Windows..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon />
                            </InputAdornment>
                        ),
                    }}
                    sx={{ mb: 3 }}
                />
            </Paper>

            <Paper>
                {importing && <LinearProgress />}
                
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>ID SharePoint</TableCell>
                                <TableCell>Titre</TableCell>
                                <TableCell>Type ID</TableCell>
                                <TableCell align="center">Générique</TableCell>
                                <TableCell align="right">Max Unit</TableCell>
                                <TableCell>Compte Windows</TableCell>
                                <TableCell>Groupe Sécurité</TableCell>
                                <TableCell align="center">Pièces jointes</TableCell>
                                <TableCell>Créé le</TableCell>
                                <TableCell>Modifié le</TableCell>
                                <TableCell>Importé le</TableCell>
                                <TableCell align="center">Actions</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={12} align="center" sx={{ py: 5 }}>
                                        <CircularProgress />
                                        <Typography sx={{ mt: 2 }}>Chargement des ressources...</Typography>
                                    </TableCell>
                                </TableRow>
                            ) : resources.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={12} align="center" sx={{ py: 5 }}>
                                        <Typography color="text.secondary">
                                            Aucune ressource trouvée. Cliquez sur "Importer depuis SharePoint" pour commencer.
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                resources.map((resource) => (
                                    <TableRow key={resource.id} hover>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight="medium">
                                                {resource.sharepoint_item_id}
                                            </Typography>
                                        </TableCell>
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
                                                {resource.title || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2">
                                                {resource.resource_type_id || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell align="center">
                                            {resource.generic ? (
                                                <CheckCircleIcon color="success" fontSize="small" />
                                            ) : (
                                                <CancelIcon color="disabled" fontSize="small" />
                                            )}
                                        </TableCell>
                                        <TableCell align="right">
                                            <Typography variant="body2">
                                                {resource.max_unit || 0}
                                            </Typography>
                                        </TableCell>
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
                                                {resource.windows_account_id || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography 
                                                variant="body2" 
                                                sx={{ 
                                                    maxWidth: 150, 
                                                    overflow: 'hidden', 
                                                    textOverflow: 'ellipsis',
                                                    whiteSpace: 'nowrap'
                                                }}
                                            >
                                                {resource.security_group || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell align="center">
                                            {resource.attachments ? (
                                                <CheckCircleIcon color="info" fontSize="small" />
                                            ) : (
                                                <CancelIcon color="disabled" fontSize="small" />
                                            )}
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {formatDate(resource.created)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {formatDate(resource.modified)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {formatDateTime(resource.imported_at)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell align="center">
                                            <Tooltip title="Voir les détails">
                                                <IconButton 
                                                    size="small" 
                                                    color="primary"
                                                    onClick={() => navigate(`/ressources/detail/${resource.sharepoint_item_id}`)}
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
                    count={totalResources}
                    page={page}
                    onPageChange={handleChangePage}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={handleChangeRowsPerPage}
                    rowsPerPageOptions={[25, 50, 100]}
                    labelRowsPerPage="Lignes par page:"
                    labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
                />
            </Paper>
        </Box>
    );
};

export default SharePointResourcesPage;

