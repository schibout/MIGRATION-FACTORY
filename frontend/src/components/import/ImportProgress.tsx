import {
    Cancel as CancelIcon,
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    Pause as PauseIcon,
    PlayArrow as PlayIcon,
    Schedule as ScheduleIcon
} from '@mui/icons-material';
import {
    Avatar,
    Box,
    Button,
    Card,
    Chip,
    Grid,
    LinearProgress,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';

interface ImportJob {
    job_uuid: string;
    file_name: string;
    file_type: string;
    status: string;
    total_rows?: number;
    processed_rows?: number;
    success_rows?: number;
    error_rows?: number;
    progress_percent?: number;
    created_at: string;
    started_at?: string;
    completed_at?: string;
    error_message?: string;
}

interface ImportProgressProps {
    job: ImportJob;
    onCancel?: (jobUuid: string) => void;
    onRetry?: (jobUuid: string) => void;
    onViewDetails?: (jobUuid: string) => void;
    showActions?: boolean;
}

const ImportProgress: React.FC<ImportProgressProps> = ({
    job,
    onCancel,
    onRetry,
    onViewDetails,
    showActions = true
}) => {
    const theme = useTheme();

    // Configuration des couleurs selon le type
    const getFileTypeColor = () => {
        switch (job.file_type) {
            case 'customers': return '#ff9800';
            case 'products': return '#4caf50';
            case 'orders': return '#2196f3';
            default: return theme.palette.primary.main;
        }
    };

    // Configuration du statut
    const getStatusConfig = () => {
        switch (job.status) {
            case 'pending':
                return {
                    icon: <ScheduleIcon />,
                    color: theme.palette.warning.main,
                    label: 'En attente',
                    bgColor: alpha(theme.palette.warning.main, 0.1)
                };
            case 'processing':
                return {
                    icon: <PlayIcon />,
                    color: theme.palette.info.main,
                    label: 'En cours',
                    bgColor: alpha(theme.palette.info.main, 0.1)
                };
            case 'completed':
                return {
                    icon: <CheckIcon />,
                    color: theme.palette.success.main,
                    label: 'Terminé',
                    bgColor: alpha(theme.palette.success.main, 0.1)
                };
            case 'completed_with_errors':
                return {
                    icon: <ErrorIcon />,
                    color: theme.palette.warning.main,
                    label: 'Terminé avec erreurs',
                    bgColor: alpha(theme.palette.warning.main, 0.1)
                };
            case 'failed':
                return {
                    icon: <ErrorIcon />,
                    color: theme.palette.error.main,
                    label: 'Échec',
                    bgColor: alpha(theme.palette.error.main, 0.1)
                };
            case 'cancelled':
                return {
                    icon: <CancelIcon />,
                    color: theme.palette.grey[500],
                    label: 'Annulé',
                    bgColor: alpha(theme.palette.grey[500], 0.1)
                };
            default:
                return {
                    icon: <PauseIcon />,
                    color: theme.palette.grey[500],
                    label: 'Inconnu',
                    bgColor: alpha(theme.palette.grey[500], 0.1)
                };
        }
    };

    const color = getFileTypeColor();
    const statusConfig = getStatusConfig();

    // Calcul du pourcentage de progression
    const progressPercent = job.progress_percent || 0;

    // Calcul du taux de succès
    const successRate = job.total_rows && job.total_rows > 0 
        ? Math.round((job.success_rows || 0) / job.total_rows * 100)
        : 0;

    // Formater la durée
    const formatDuration = (startDate?: string, endDate?: string) => {
        if (!startDate) return null;
        
        const start = new Date(startDate);
        const end = endDate ? new Date(endDate) : new Date();
        const diffMs = end.getTime() - start.getTime();
        
        const minutes = Math.floor(diffMs / 60000);
        const seconds = Math.floor((diffMs % 60000) / 1000);
        
        if (minutes > 0) {
            return `${minutes}m ${seconds}s`;
        }
        return `${seconds}s`;
    };

    // Actions disponibles selon le statut
    const canCancel = ['pending', 'processing'].includes(job.status);
    const canRetry = ['failed', 'cancelled'].includes(job.status);
    const canViewDetails = ['completed', 'completed_with_errors', 'failed'].includes(job.status);

    return (
        <Card sx={{ p: 3, mb: 2 }}>
            <Grid container spacing={3} alignItems="center">
                {/* Icône et info du fichier */}
                <Grid item xs={12} md={4}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <Avatar
                            sx={{
                                backgroundColor: statusConfig.bgColor,
                                color: statusConfig.color,
                                width: 48,
                                height: 48
                            }}
                        >
                            {statusConfig.icon}
                        </Avatar>
                        <Box sx={{ flex: 1, minWidth: 0 }}>
                            <Typography 
                                variant="h6" 
                                noWrap 
                                sx={{ fontWeight: 600 }}
                                title={job.file_name}
                            >
                                {job.file_name}
                            </Typography>
                            <Box sx={{ display: 'flex', gap: 1, mt: 0.5 }}>
                                <Chip
                                    size="small"
                                    label={job.file_type}
                                    sx={{
                                        backgroundColor: alpha(color, 0.1),
                                        color,
                                        fontSize: '0.75rem'
                                    }}
                                />
                                <Chip
                                    size="small"
                                    label={statusConfig.label}
                                    sx={{
                                        backgroundColor: statusConfig.bgColor,
                                        color: statusConfig.color,
                                        fontSize: '0.75rem'
                                    }}
                                />
                            </Box>
                        </Box>
                    </Box>
                </Grid>

                {/* Progression */}
                <Grid item xs={12} md={4}>
                    <Box>
                        {job.status === 'processing' && (
                            <>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                    <Typography variant="body2" color="text.secondary">
                                        Progression
                                    </Typography>
                                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                        {progressPercent}%
                                    </Typography>
                                </Box>
                                <LinearProgress
                                    variant="determinate"
                                    value={progressPercent}
                                    sx={{
                                        height: 8,
                                        borderRadius: 4,
                                        backgroundColor: alpha(color, 0.2),
                                        '& .MuiLinearProgress-bar': {
                                            backgroundColor: color,
                                            borderRadius: 4
                                        }
                                    }}
                                />
                            </>
                        )}

                        {/* Statistiques */}
                        {job.total_rows && job.total_rows > 0 && (
                            <Box sx={{ mt: 2 }}>
                                <Grid container spacing={2}>
                                    <Grid item xs={4}>
                                        <Typography variant="caption" color="text.secondary">
                                            Total
                                        </Typography>
                                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                            {job.total_rows.toLocaleString()}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={4}>
                                        <Typography variant="caption" color="text.secondary">
                                            Succès
                                        </Typography>
                                        <Typography 
                                            variant="body2" 
                                            sx={{ 
                                                fontWeight: 600,
                                                color: theme.palette.success.main
                                            }}
                                        >
                                            {(job.success_rows || 0).toLocaleString()}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={4}>
                                        <Typography variant="caption" color="text.secondary">
                                            Erreurs
                                        </Typography>
                                        <Typography 
                                            variant="body2" 
                                            sx={{ 
                                                fontWeight: 600,
                                                color: job.error_rows && job.error_rows > 0 
                                                    ? theme.palette.error.main 
                                                    : 'inherit'
                                            }}
                                        >
                                            {(job.error_rows || 0).toLocaleString()}
                                        </Typography>
                                    </Grid>
                                </Grid>
                            </Box>
                        )}

                        {/* Durée */}
                        {job.started_at && (
                            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                                Durée: {formatDuration(job.started_at, job.completed_at)}
                            </Typography>
                        )}
                    </Box>
                </Grid>

                {/* Actions */}
                {showActions && (
                    <Grid item xs={12} md={4}>
                        <Box sx={{ display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                            {canViewDetails && onViewDetails && (
                                <Button
                                    size="small"
                                    variant="outlined"
                                    onClick={() => onViewDetails(job.job_uuid)}
                                >
                                    Détails
                                </Button>
                            )}
                            
                            {canCancel && onCancel && (
                                <Button
                                    size="small"
                                    variant="outlined"
                                    color="error"
                                    onClick={() => onCancel(job.job_uuid)}
                                >
                                    Annuler
                                </Button>
                            )}
                            
                            {canRetry && onRetry && (
                                <Button
                                    size="small"
                                    variant="contained"
                                    sx={{
                                        backgroundColor: color,
                                        '&:hover': {
                                            backgroundColor: alpha(color, 0.8)
                                        }
                                    }}
                                    onClick={() => onRetry(job.job_uuid)}
                                >
                                    Relancer
                                </Button>
                            )}
                        </Box>
                    </Grid>
                )}
            </Grid>

            {/* Message d'erreur */}
            {job.error_message && (
                <Box sx={{ mt: 2, p: 2, backgroundColor: alpha(theme.palette.error.main, 0.1), borderRadius: 1 }}>
                    <Typography variant="body2" color="error">
                        <strong>Erreur :</strong> {job.error_message}
                    </Typography>
                </Box>
            )}
        </Card>
    );
};

export default ImportProgress; 