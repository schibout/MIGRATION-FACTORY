import {
    History as HistoryIcon,
    Home as HomeIcon,
    Assessment as StatsIcon,
    Upload as UploadIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Breadcrumbs,
    Button,
    Card,
    Container,
    Grid,
    Link,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

// Composants d'import
import ImportDashboard from '../components/import/ImportDashboard';
import ImportHistory from '../components/import/ImportHistory';

// Types et hooks
import { useImport } from '../hooks/useImport';
import {
    FileTypeStats,
    ImportFilters,
    ImportStats,
    TopError
} from '../types/import.types';

const ImportHistoryPage: React.FC = () => {
    const navigate = useNavigate();
    const location = useLocation();
    
    // États pour la pagination et les filtres
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(25);
    const [filters, setFilters] = useState<ImportFilters>({});
    const [showStats, setShowStats] = useState(true);

    // Hook d'import
    const {
        jobs,
        stats,
        loading,
        error,
        refreshJobs,
        refreshStats,
        cancelJob,
        retryJob
    } = useImport({ autoRefresh: true });

    // Statistiques du dashboard
    const [dashboardStats, setDashboardStats] = useState<ImportStats | null>(null);
    const [topErrors, setTopErrors] = useState<TopError[]>([]);
    const [fileTypeStats, setFileTypeStats] = useState<FileTypeStats[]>([]);

    // Calcul des statistiques filtrées
    useEffect(() => {
        if (stats) {
            setDashboardStats(stats);
            
            // Simuler les top erreurs (normalement du backend)
            setTopErrors([
                { error_message: 'Format email invalide', count: 28, percentage: 42.4 },
                { error_message: 'Valeur requise manquante', count: 18, percentage: 27.3 },
                { error_message: 'Type de données incorrect', count: 12, percentage: 18.2 },
                { error_message: 'Contrainte de longueur', count: 8, percentage: 12.1 }
            ]);
            
            // Simuler les stats par type
            setFileTypeStats([
                { file_type: 'customers', count: 45, success_rate: 87.8, avg_rows: 1340 },
                { file_type: 'products', count: 32, success_rate: 94.1, avg_rows: 920 },
                { file_type: 'orders', count: 28, success_rate: 82.1, avg_rows: 2280 }
            ]);
        }
    }, [stats]);

    // Gestion de la navigation vers les détails
    const handleViewDetails = (jobUuid: string) => {
        navigate(`/import/details/${jobUuid}`);
    };

    // Gestion de l'annulation
    const handleCancel = async (jobUuid: string) => {
        try {
            await cancelJob(jobUuid);
            // Confirmation visuelle déjà gérée par le hook
        } catch (error) {
            console.error('Erreur annulation:', error);
        }
    };

    // Gestion de la relance
    const handleRetry = async (jobUuid: string) => {
        try {
            await retryJob(jobUuid);
            // Actualisation automatique par le hook
        } catch (error) {
            console.error('Erreur relance:', error);
        }
    };

    // Gestion de la pagination
    const handlePageChange = (newPage: number) => {
        setPage(newPage);
    };

    const handleRowsPerPageChange = (newRowsPerPage: number) => {
        setRowsPerPage(newRowsPerPage);
        setPage(0);
    };

    // Navigation vers la page d'import
    const handleGoToImport = () => {
        navigate('/import');
    };

    // Calculs pour l'affichage
    const totalJobs = jobs.length;
    const pendingJobs = jobs.filter(job => job.status === 'pending').length;
    const processingJobs = jobs.filter(job => job.status === 'processing').length;
    const completedJobs = jobs.filter(job => ['completed', 'completed_with_errors'].includes(job.status)).length;
    const failedJobs = jobs.filter(job => job.status === 'failed').length;

    return (
        <Container maxWidth="xl" sx={{ py: 4 }}>
            {/* Breadcrumbs */}
            <Breadcrumbs separator="›" sx={{ mb: 3 }}>
                <Link
                    underline="hover"
                    color="inherit"
                    href="#"
                    onClick={(e) => {
                        e.preventDefault();
                        navigate('/');
                    }}
                    sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}
                >
                    <HomeIcon fontSize="small" />
                    Accueil
                </Link>
                <Link
                    underline="hover"
                    color="inherit"
                    href="#"
                    onClick={(e) => {
                        e.preventDefault();
                        navigate('/import');
                    }}
                    sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}
                >
                    <UploadIcon fontSize="small" />
                    Import
                </Link>
                <Typography 
                    color="text.primary" 
                    sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}
                >
                    <HistoryIcon fontSize="small" />
                    Historique
                </Typography>
            </Breadcrumbs>

            {/* En-tête */}
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 4 }}>
                <Box>
                    <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
                        Historique des Imports
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Consultez l'historique complet de tous vos imports avec détails et statistiques
                    </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <Button
                        variant="outlined"
                        startIcon={<StatsIcon />}
                        onClick={() => setShowStats(!showStats)}
                        color={showStats ? 'primary' : 'inherit'}
                    >
                        {showStats ? 'Masquer Stats' : 'Voir Stats'}
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<UploadIcon />}
                        onClick={handleGoToImport}
                    >
                        Nouvel Import
                    </Button>
                </Box>
            </Box>

            {/* Alertes d'erreur */}
            {error && (
                <Alert severity="error" sx={{ mb: 3 }}>
                    {error}
                </Alert>
            )}

            {/* Statistiques rapides */}
            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} sm={6} md={2.4}>
                    <Card sx={{ p: 2, textAlign: 'center', border: '1px solid', borderColor: 'divider' }}>
                        <Typography variant="h4" sx={{ fontWeight: 700, color: 'primary.main' }}>
                            {totalJobs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Total Imports
                        </Typography>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={6} md={2.4}>
                    <Card sx={{ p: 2, textAlign: 'center', border: '1px solid', borderColor: 'warning.main' }}>
                        <Typography variant="h4" sx={{ fontWeight: 700, color: 'warning.main' }}>
                            {pendingJobs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            En Attente
                        </Typography>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={6} md={2.4}>
                    <Card sx={{ p: 2, textAlign: 'center', border: '1px solid', borderColor: 'info.main' }}>
                        <Typography variant="h4" sx={{ fontWeight: 700, color: 'info.main' }}>
                            {processingJobs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            En Cours
                        </Typography>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={6} md={2.4}>
                    <Card sx={{ p: 2, textAlign: 'center', border: '1px solid', borderColor: 'success.main' }}>
                        <Typography variant="h4" sx={{ fontWeight: 700, color: 'success.main' }}>
                            {completedJobs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Terminés
                        </Typography>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={6} md={2.4}>
                    <Card sx={{ p: 2, textAlign: 'center', border: '1px solid', borderColor: 'error.main' }}>
                        <Typography variant="h4" sx={{ fontWeight: 700, color: 'error.main' }}>
                            {failedJobs}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Échoués
                        </Typography>
                    </Card>
                </Grid>
            </Grid>

            {/* Contenu principal */}
            <Grid container spacing={4}>
                {/* Table d'historique */}
                <Grid item xs={12} lg={showStats ? 8 : 12}>
                    <ImportHistory
                        jobs={jobs}
                        loading={loading}
                        onRefresh={refreshJobs}
                        onViewDetails={handleViewDetails}
                        onCancel={handleCancel}
                        onRetry={handleRetry}
                        totalCount={totalJobs}
                        page={page}
                        rowsPerPage={rowsPerPage}
                        onPageChange={handlePageChange}
                        onRowsPerPageChange={handleRowsPerPageChange}
                    />
                </Grid>

                {/* Dashboard des statistiques */}
                {showStats && (
                    <Grid item xs={12} lg={4}>
                        <Box sx={{ position: 'sticky', top: 24 }}>
                            {dashboardStats && (
                                <ImportDashboard
                                    stats={dashboardStats}
                                    topErrors={topErrors}
                                    fileTypeStats={fileTypeStats}
                                    loading={loading}
                                    onRefresh={refreshStats}
                                    onViewAllImports={() => setShowStats(false)}
                                />
                            )}
                        </Box>
                    </Grid>
                )}
            </Grid>

            {/* Message si aucun import */}
            {jobs.length === 0 && !loading && (
                <Card sx={{ p: 6, textAlign: 'center', mt: 4 }}>
                    <HistoryIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
                    <Typography variant="h6" sx={{ mb: 2 }}>
                        Aucun import trouvé
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                        Vous n'avez pas encore effectué d'import. Commencez par importer votre premier fichier.
                    </Typography>
                    <Button
                        variant="contained"
                        startIcon={<UploadIcon />}
                        onClick={handleGoToImport}
                        size="large"
                    >
                        Commencer un Import
                    </Button>
                </Card>
            )}
        </Container>
    );
};

export default ImportHistoryPage; 