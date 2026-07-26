import {
    CloudDownload as CloudDownloadIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Visibility as VisibilityIcon
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
import { projectService, SharePointProject } from '../services/projectService';

const SharePointProjectsPage: React.FC = () => {
    const navigate = useNavigate();
    const [projects, setProjects] = useState<SharePointProject[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalProjects, setTotalProjects] = useState(0);
    const [search, setSearch] = useState('');
    const [importing, setImporting] = useState(false);

    // Charger les projets
    const loadProjects = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await projectService.getProjects(page + 1, rowsPerPage, search);
            
            if (response.success) {
                setProjects(response.data);
                setTotalProjects(response.total);
            } else {
                setError(response.message || 'Erreur lors du chargement des projets');
            }
        } catch (err) {
            setError('Erreur lors du chargement des projets');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    // Importer les projets depuis SharePoint
    const handleImport = async () => {
        try {
            setImporting(true);
            setError(null);
            const response = await projectService.importProjects();
            
            if (response.success) {
                // Recharger les projets après l'import
                await loadProjects();
                alert(`${response.imported_count} projets importés avec succès !`);
            } else {
                setError(response.message || 'Erreur lors de l\'import');
            }
        } catch (err) {
            setError('Erreur lors de l\'import des projets');
            console.error(err);
        } finally {
            setImporting(false);
        }
    };

    // Charger les projets au montage et quand la page change
    useEffect(() => {
        loadProjects();
    }, [page, rowsPerPage]);

    // Recherche avec debounce
    useEffect(() => {
        const timer = setTimeout(() => {
            if (page === 0) {
                loadProjects();
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

    // Obtenir la couleur du statut
    const getStatusColor = (status: string): 'success' | 'warning' | 'error' | 'info' | 'default' => {
        if (!status) return 'default';
        const statusLower = status.toLowerCase();
        if (statusLower.includes('clôturé') || statusLower.includes('terminé')) return 'success';
        if (statusLower.includes('cours') || statusLower.includes('actif')) return 'info';
        if (statusLower.includes('pause') || statusLower.includes('attente')) return 'warning';
        if (statusLower.includes('annulé') || statusLower.includes('échec')) return 'error';
        return 'default';
    };

    // Obtenir la couleur pour les indicateurs (health, planning, cost)
    const getIndicatorColor = (indicator: string): 'success' | 'warning' | 'error' | 'default' => {
        if (!indicator) return 'default';
        const indicatorLower = indicator.toLowerCase();
        if (indicatorLower.includes('ok') || indicatorLower === 'vert') return 'success';
        if (indicatorLower.includes('attention') || indicatorLower === 'orange') return 'warning';
        if (indicatorLower.includes('alerte') || indicatorLower === 'rouge') return 'error';
        return 'default';
    };

    // Formater le montant
    const formatCurrency = (value: number | null): string => {
        if (value === null || value === undefined) return '-';
        return new Intl.NumberFormat('fr-FR', {
            style: 'currency',
            currency: 'EUR'
        }).format(value);
    };

    // Formater la date
    const formatDate = (dateString: string | null): string => {
        if (!dateString) return '-';
        return new Date(dateString).toLocaleDateString('fr-FR');
    };

    return (
        <Box sx={{ p: 3 }}>
            <Paper sx={{ p: 3, mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        Projets SharePoint
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 2 }}>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={loadProjects}
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
                    placeholder="Rechercher par titre, code, numéro ou statut..."
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
                                <TableCell>ID</TableCell>
                                <TableCell>Code</TableCell>
                                <TableCell>Titre</TableCell>
                                <TableCell>Numéro</TableCell>
                                <TableCell>Statut</TableCell>
                                <TableCell>Phase</TableCell>
                                <TableCell align="right">Avancement</TableCell>
                                <TableCell align="center">Santé</TableCell>
                                <TableCell align="center">Planning</TableCell>
                                <TableCell align="center">Coût</TableCell>
                                <TableCell>Secteur</TableCell>
                                <TableCell align="right">Budget SAP</TableCell>
                                <TableCell>Date Import</TableCell>
                                <TableCell align="center">Actions</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={14} align="center" sx={{ py: 5 }}>
                                        <CircularProgress />
                                        <Typography sx={{ mt: 2 }}>Chargement des projets...</Typography>
                                    </TableCell>
                                </TableRow>
                            ) : projects.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={14} align="center" sx={{ py: 5 }}>
                                        <Typography color="text.secondary">
                                            Aucun projet trouvé. Cliquez sur "Importer depuis SharePoint" pour commencer.
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                projects.map((project) => (
                                    <TableRow
                                        key={project.id}
                                        hover
                                        onClick={() => navigate(`/projets/detail/${project.sharepoint_id}`)}
                                        sx={{ cursor: 'pointer' }}
                                    >
                                        <TableCell>{project.sharepoint_id}</TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight="medium">
                                                {project.code || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Tooltip title={project.description || ''}>
                                                <Typography 
                                                    variant="body2" 
                                                    sx={{ 
                                                        maxWidth: 300, 
                                                        overflow: 'hidden', 
                                                        textOverflow: 'ellipsis',
                                                        whiteSpace: 'nowrap',
                                                        color: 'primary.main',
                                                        textDecoration: 'underline',
                                                        '&:hover': { color: 'primary.dark' }
                                                    }}
                                                >
                                                    {project.title || '-'}
                                                </Typography>
                                            </Tooltip>
                                        </TableCell>
                                        <TableCell>{project.project_number || '-'}</TableCell>
                                        <TableCell>
                                            <Chip 
                                                label={project.global_status || 'N/A'} 
                                                color={getStatusColor(project.global_status)}
                                                size="small"
                                            />
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {project.phase_text || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell align="right">
                                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                                <LinearProgress 
                                                    variant="determinate" 
                                                    value={project.percent_completed * 100 || 0}
                                                    sx={{ flexGrow: 1, height: 6, borderRadius: 3 }}
                                                />
                                                <Typography variant="body2" fontSize="0.85rem" minWidth={40}>
                                                    {project.percent_completed ? `${(project.percent_completed * 100).toFixed(0)}%` : '0%'}
                                                </Typography>
                                            </Box>
                                        </TableCell>
                                        <TableCell align="center">
                                            <Chip 
                                                label={project.health || 'N/A'} 
                                                color={getIndicatorColor(project.health)}
                                                size="small"
                                                variant="outlined"
                                            />
                                        </TableCell>
                                        <TableCell align="center">
                                            <Chip 
                                                label={project.planning || 'N/A'} 
                                                color={getIndicatorColor(project.planning)}
                                                size="small"
                                                variant="outlined"
                                            />
                                        </TableCell>
                                        <TableCell align="center">
                                            <Chip 
                                                label={project.cost || 'N/A'} 
                                                color={getIndicatorColor(project.cost)}
                                                size="small"
                                                variant="outlined"
                                            />
                                        </TableCell>
                                        <TableCell>{project.sector || '-'}</TableCell>
                                        <TableCell align="right">
                                            <Typography variant="body2" fontWeight="medium">
                                                {formatCurrency(project.budget_total_sap)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {formatDate(project.imported_at)}
                                            </Typography>
                                        </TableCell>
                                        <TableCell align="center">
                                            <Tooltip title="Voir les détails">
                                                <IconButton 
                                                    size="small" 
                                                    color="primary"
                                                    onClick={() => navigate(`/projets/detail/${project.sharepoint_id}`)}
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
                    count={totalProjects}
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

export default SharePointProjectsPage;

