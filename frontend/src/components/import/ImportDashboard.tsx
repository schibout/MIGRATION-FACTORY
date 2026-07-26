import {
    Assessment as AssessmentIcon,
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    Refresh as RefreshIcon,
    Schedule as ScheduleIcon,
    TrendingUp as TrendingIcon,
    Upload as UploadIcon
} from '@mui/icons-material';
import {
    Avatar,
    Box,
    Button,
    Card,
    Chip,
    Divider,
    Grid,
    IconButton,
    LinearProgress,
    Tooltip,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { FileTypeStats, ImportStats, TopError } from '../../types/import.types';

interface ImportDashboardProps {
    stats?: ImportStats;
    topErrors?: TopError[];
    fileTypeStats?: FileTypeStats[];
    onRefresh?: () => void;
    onViewAllImports?: () => void;
    loading?: boolean;
}

const ImportDashboard: React.FC<ImportDashboardProps> = ({
    stats,
    topErrors = [],
    fileTypeStats = [],
    onRefresh,
    onViewAllImports,
    loading = false
}) => {
    const theme = useTheme();
    const [refreshing, setRefreshing] = useState(false);

    // Gestion du rafraîchissement
    const handleRefresh = async () => {
        if (onRefresh && !refreshing) {
            setRefreshing(true);
            await onRefresh();
            setTimeout(() => setRefreshing(false), 1000);
        }
    };

    // Auto-refresh toutes les 30 secondes
    useEffect(() => {
        const interval = setInterval(() => {
            if (!refreshing && onRefresh) {
                onRefresh();
            }
        }, 30000);

        return () => clearInterval(interval);
    }, [onRefresh, refreshing]);

    // Couleurs pour les types de fichiers
    const getFileTypeColor = (type: string) => {
        switch (type) {
            case 'customers': return '#ff9800';
            case 'products': return '#4caf50';
            case 'orders': return '#2196f3';
            default: return theme.palette.primary.main;
        }
    };

    // Formatage des nombres avec protection contre undefined/null
    const formatNumber = (num: number | undefined | null) => {
        const value = Number(num);
        if (isNaN(value) || !isFinite(value)) return '0';
        return new Intl.NumberFormat('fr-FR').format(value);
    };

    // Formatage du temps (minutes) avec protection
    const formatTime = (minutes: number | undefined | null) => {
        const value = Number(minutes);
        if (isNaN(value) || !isFinite(value) || value <= 0) return '0s';
        
        if (value < 1) return `${Math.round(value * 60)}s`;
        if (value < 60) return `${Math.round(value)}m`;
        const hours = Math.floor(value / 60);
        const mins = Math.round(value % 60);
        return `${hours}h ${mins}m`;
    };

    // Formatage des pourcentages avec protection
    const formatPercentage = (value: number | undefined | null, fallback: string = '0.0') => {
        const num = Number(value);
        if (isNaN(num) || !isFinite(num)) return fallback;
        return num.toFixed(1);
    };

    // Protection pour les statistiques
    const safeStats = {
        total_imports: stats?.total_imports || 0,
        successful_imports: stats?.successful_imports || 0,
        failed_imports: stats?.failed_imports || 0,
        pending_imports: stats?.pending_imports || 0,
        total_rows_processed: stats?.total_rows_processed || 0,
        avg_processing_time: stats?.avg_processing_time || 0,
        imports_this_week: stats?.imports_this_week || 0,
        imports_this_month: stats?.imports_this_month || 0,
        success_rate: stats?.success_rate || 0
    };

    return (
        <Box>
            {/* En-tête avec actions */}
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
                <Typography variant="h4" sx={{ fontWeight: 600 }}>
                    Dashboard d'Import
                </Typography>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <Tooltip title="Actualiser les données">
                        <IconButton
                            onClick={handleRefresh}
                            disabled={refreshing || loading}
                            sx={{
                                backgroundColor: alpha(theme.palette.primary.main, 0.1),
                                '&:hover': {
                                    backgroundColor: alpha(theme.palette.primary.main, 0.2)
                                }
                            }}
                        >
                            <RefreshIcon sx={{ 
                                animation: refreshing ? 'spin 1s linear infinite' : 'none',
                                '@keyframes spin': {
                                    '0%': { transform: 'rotate(0deg)' },
                                    '100%': { transform: 'rotate(360deg)' }
                                }
                            }} />
                        </IconButton>
                    </Tooltip>
                    {onViewAllImports && (
                        <Button
                            variant="outlined"
                            onClick={onViewAllImports}
                            startIcon={<AssessmentIcon />}
                        >
                            Voir tous les imports
                        </Button>
                    )}
                </Box>
            </Box>

            {loading && (
                <LinearProgress sx={{ mb: 3, borderRadius: 2 }} />
            )}

            {/* Message si aucune donnée */}
            {!loading && (!stats || safeStats.total_imports === 0) && (
                <Card sx={{ p: 4, textAlign: 'center', mb: 4 }}>
                    <UploadIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
                    <Typography variant="h6" color="text.secondary" gutterBottom>
                        Aucun import disponible
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Commencez par importer des fichiers pour voir les statistiques ici.
                    </Typography>
                </Card>
            )}

            {/* Statistiques principales */}
            {(stats && safeStats.total_imports > 0) && (
                <Grid container spacing={3} sx={{ mb: 4 }}>
                    {/* Total des imports */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                <Avatar
                                    sx={{
                                        backgroundColor: alpha(theme.palette.primary.main, 0.1),
                                        color: theme.palette.primary.main,
                                        width: 56,
                                        height: 56
                                    }}
                                >
                                    <UploadIcon sx={{ fontSize: 28 }} />
                                </Avatar>
                                <Box sx={{ flex: 1 }}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                        {formatNumber(safeStats.total_imports)}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Total imports
                                    </Typography>
                                </Box>
                            </Box>
                        </Card>
                    </Grid>

                    {/* Terminés */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                <Avatar
                                    sx={{
                                        backgroundColor: alpha(theme.palette.success.main, 0.1),
                                        color: theme.palette.success.main,
                                        width: 56,
                                        height: 56
                                    }}
                                >
                                    <CheckIcon sx={{ fontSize: 28 }} />
                                </Avatar>
                                <Box sx={{ flex: 1 }}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                        {formatNumber(safeStats.successful_imports)}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Terminés
                                    </Typography>
                                    <Typography variant="caption" color="success.main">
                                        {formatPercentage(safeStats.success_rate)}% de succès
                                    </Typography>
                                </Box>
                            </Box>
                        </Card>
                    </Grid>

                    {/* Échoués */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                <Avatar
                                    sx={{
                                        backgroundColor: alpha(theme.palette.error.main, 0.1),
                                        color: theme.palette.error.main,
                                        width: 56,
                                        height: 56
                                    }}
                                >
                                    <ErrorIcon sx={{ fontSize: 28 }} />
                                </Avatar>
                                <Box sx={{ flex: 1 }}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                        {formatNumber(safeStats.failed_imports)}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Échoués
                                    </Typography>
                                    <Typography variant="caption" color="error.main">
                                        {safeStats.total_imports > 0 ? 
                                            formatPercentage((safeStats.failed_imports / safeStats.total_imports) * 100) : 
                                            '0.0'
                                        }% d'échec
                                    </Typography>
                                </Box>
                            </Box>
                        </Card>
                    </Grid>

                    {/* En attente */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                <Avatar
                                    sx={{
                                        backgroundColor: alpha(theme.palette.warning.main, 0.1),
                                        color: theme.palette.warning.main,
                                        width: 56,
                                        height: 56
                                    }}
                                >
                                    <ScheduleIcon sx={{ fontSize: 28 }} />
                                </Avatar>
                                <Box sx={{ flex: 1 }}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                        {formatNumber(safeStats.pending_imports)}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        En attente
                                    </Typography>
                                    <Typography variant="caption" color="warning.main">
                                        À traiter
                                    </Typography>
                                </Box>
                            </Box>
                        </Card>
                    </Grid>
                </Grid>
            )}

            <Grid container spacing={3}>
                {/* Métriques de performance */}
                {(stats && safeStats.total_imports > 0) && (
                    <Grid item xs={12} md={6}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 3 }}>
                                <TrendingIcon color="primary" />
                                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                    Métriques de Performance
                                </Typography>
                            </Box>

                            <Grid container spacing={3}>
                                <Grid item xs={6}>
                                    <Box sx={{ textAlign: 'center' }}>
                                        <Typography variant="h5" sx={{ fontWeight: 700, color: 'primary.main' }}>
                                            {formatNumber(safeStats.total_rows_processed)}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Lignes traitées
                                        </Typography>
                                    </Box>
                                </Grid>
                                <Grid item xs={6}>
                                    <Box sx={{ textAlign: 'center' }}>
                                        <Typography variant="h5" sx={{ fontWeight: 700, color: 'info.main' }}>
                                            {formatTime(safeStats.avg_processing_time)}
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary">
                                            Temps moyen
                                        </Typography>
                                    </Box>
                                </Grid>
                            </Grid>

                            <Divider sx={{ my: 2 }} />

                            <Grid container spacing={2}>
                                <Grid item xs={4}>
                                    <Box sx={{ textAlign: 'center' }}>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            {formatNumber(safeStats.imports_this_week)}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Cette semaine
                                        </Typography>
                                    </Box>
                                </Grid>
                                <Grid item xs={4}>
                                    <Box sx={{ textAlign: 'center' }}>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            {formatNumber(safeStats.imports_this_month)}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Ce mois
                                        </Typography>
                                    </Box>
                                </Grid>
                                <Grid item xs={4}>
                                    <Box sx={{ textAlign: 'center' }}>
                                        <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                            {formatPercentage(safeStats.success_rate)}%
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Taux succès
                                        </Typography>
                                    </Box>
                                </Grid>
                            </Grid>
                        </Card>
                    </Grid>
                )}

                {/* Répartition par type */}
                {fileTypeStats && fileTypeStats.length > 0 && (
                    <Grid item xs={12} md={6}>
                        <Card sx={{ p: 3, height: '100%' }}>
                            <Typography variant="h6" sx={{ fontWeight: 600, mb: 3 }}>
                                Répartition par Type
                            </Typography>

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                {fileTypeStats.map((stat: FileTypeStats, index: number) => (
                                    <Box key={index} sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                                        <Chip
                                            label={stat.file_type || 'Non défini'}
                                            sx={{
                                                backgroundColor: alpha(getFileTypeColor(stat.file_type || ''), 0.1),
                                                color: getFileTypeColor(stat.file_type || ''),
                                                fontWeight: 600,
                                                minWidth: 120
                                            }}
                                        />
                                        <Box sx={{ flex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                            <Typography variant="body2">
                                                {formatNumber(stat.count || 0)} imports
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                {formatPercentage(stat?.success_rate || 0)}%
                                            </Typography>
                                        </Box>
                                    </Box>
                                ))}
                            </Box>
                        </Card>
                    </Grid>
                )}

                {/* Top erreurs */}
                {topErrors && topErrors.length > 0 && (
                    <Grid item xs={12}>
                        <Card sx={{ p: 3 }}>
                            <Typography variant="h6" sx={{ fontWeight: 600, mb: 3 }}>
                                Erreurs les Plus Fréquentes
                            </Typography>

                            <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                                {topErrors.slice(0, 5).map((error: TopError, index: number) => (
                                    <Box 
                                        key={index} 
                                        sx={{ 
                                            display: 'flex', 
                                            justifyContent: 'space-between', 
                                            alignItems: 'center',
                                            p: 2,
                                            backgroundColor: alpha(theme.palette.error.main, 0.05),
                                            borderRadius: 1,
                                            border: `1px solid ${alpha(theme.palette.error.main, 0.2)}`
                                        }}
                                    >
                                        <Typography variant="body2" sx={{ flex: 1 }}>
                                            {error.error_message || 'Erreur inconnue'}
                                        </Typography>
                                        <Chip 
                                            label={`${formatNumber(error.count || 0)} fois`}
                                            size="small"
                                            color="error"
                                            variant="outlined"
                                        />
                                    </Box>
                                ))}
                            </Box>
                        </Card>
                    </Grid>
                )}
            </Grid>
        </Box>
    );
};

export default ImportDashboard; 