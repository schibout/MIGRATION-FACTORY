import {
    Cancel as CancelIcon,
    Download as DownloadIcon,
    Error as ErrorIcon,
    GetApp as ExportIcon,
    History as HistoryIcon,
    Home as HomeIcon,
    Info as InfoIcon,
    Replay as RetryIcon,
    Upload as UploadIcon,
    Warning as WarningIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Breadcrumbs,
    Button,
    Card,
    Chip,
    Container,
    Grid,
    LinearProgress,
    Link,
    Tab,
    Tabs,
    Typography
} from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import { DataTable } from '../components/table';
import type { DataTableColumn } from '../components/table';
import { useNavigate, useParams } from 'react-router-dom';

// Types et services
import { importService } from '../services/importService';
import {
    ImportDetail,
    ImportJob,
    ImportLog
} from '../types/import.types';

interface TabPanelProps {
    children?: React.ReactNode;
    index: number;
    value: number;
}

const TabPanel: React.FC<TabPanelProps> = ({ children, value, index, ...other }) => {
    return (
        <div
            role="tabpanel"
            hidden={value !== index}
            id={`simple-tabpanel-${index}`}
            aria-labelledby={`simple-tab-${index}`}
            {...other}
        >
            {value === index && (
                <Box sx={{ p: 3 }}>
                    {children}
                </Box>
            )}
        </div>
    );
};

const ImportDetailsPage: React.FC = () => {
    const navigate = useNavigate();
    const { jobUuid } = useParams<{ jobUuid: string }>();
    
    // États
    const [job, setJob] = useState<ImportJob | null>(null);
    const [details, setDetails] = useState<ImportDetail[]>([]);
    const [logs, setLogs] = useState<ImportLog[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [tabValue, setTabValue] = useState(0);
    const [detailsPage, setDetailsPage] = useState(0);
    const [detailsRowsPerPage, setDetailsRowsPerPage] = useState(25);
    // Nombre total de lignes de l'import : sans lui, impossible d'afficher une
    // pagination utilisable (l'ecran etait bloque sur les 1res lignes).
    const [detailsTotal, setDetailsTotal] = useState(0);

    // Charger les données du job
    useEffect(() => {
        if (!jobUuid) return;

        const loadJobData = async () => {
            setLoading(true);
            setError(null);

            try {
                // Charger les détails du job
                const jobResponse = await importService.getJobDetails(jobUuid);
                if (jobResponse.success && jobResponse.data) {
                    setJob(jobResponse.data);
                } else {
                    setError(jobResponse.message || 'Impossible de charger les détails du job');
                    return;
                }

                // Charger les détails ligne par ligne
                // (le service attend une page a partir de 1, l'etat est a partir de 0)
                const detailsResponse = await importService.getJobLineDetails(jobUuid, {
                    page: detailsPage + 1,
                    per_page: detailsRowsPerPage
                });
                if (detailsResponse.success) {
                    setDetails(detailsResponse.data);
                    setDetailsTotal(detailsResponse.total);
                }

                // Charger les logs
                const logsResponse = await importService.getJobLogs(jobUuid);
                if (logsResponse.success && logsResponse.data) {
                    setLogs(logsResponse.data);
                }

            } catch (err) {
                setError('Erreur lors du chargement des données');
                console.error('Erreur chargement job:', err);
            } finally {
                setLoading(false);
            }
        };

        loadJobData();
    }, [jobUuid, detailsPage, detailsRowsPerPage]);

    // Polling pour jobs en cours
    useEffect(() => {
        if (!job || !['pending', 'processing'].includes(job.status)) return;

        const interval = setInterval(async () => {
            if (jobUuid) {
                const response = await importService.getJobDetails(jobUuid);
                if (response.success && response.data) {
                    setJob(response.data);
                }
            }
        }, 2000);

        return () => clearInterval(interval);
    }, [job, jobUuid]);

    // Actions
    const handleCancel = async () => {
        if (!jobUuid) return;
        
        try {
            const response = await importService.cancelJob(jobUuid);
            if (response.success) {
                setJob(prev => prev ? { ...prev, status: 'cancelled' } : null);
            }
        } catch (err) {
            console.error('Erreur annulation:', err);
        }
    };

    const handleRetry = async () => {
        if (!jobUuid) return;
        
        try {
            const response = await importService.retryJob(jobUuid);
            if (response.success) {
                navigate('/import/history');
            }
        } catch (err) {
            console.error('Erreur relance:', err);
        }
    };

    const handleExportErrors = async () => {
        if (!jobUuid) return;
        
        try {
            const blob = await importService.exportJobErrors(jobUuid, 'excel');
            if (blob) {
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `erreurs-import-${jobUuid}.xlsx`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
            }
        } catch (err) {
            console.error('Erreur export erreurs:', err);
        }
    };

    const handleDownloadReport = async () => {
        if (!jobUuid) return;
        
        try {
            const blob = await importService.downloadJobReport(jobUuid, 'excel');
            if (blob) {
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `rapport-import-${jobUuid}.xlsx`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
            }
        } catch (err) {
            console.error('Erreur téléchargement rapport:', err);
        }
    };

    // Configuration des couleurs par statut
    const getStatusConfig = (status: string) => {
        switch (status) {
            case 'pending': return { color: 'warning', label: 'En attente' };
            case 'processing': return { color: 'info', label: 'En cours' };
            case 'completed': return { color: 'success', label: 'Terminé' };
            case 'completed_with_errors': return { color: 'warning', label: 'Terminé avec erreurs' };
            case 'failed': return { color: 'error', label: 'Échec' };
            case 'cancelled': return { color: 'default', label: 'Annulé' };
            default: return { color: 'default', label: status };
        }
    };

    // Configuration des icônes de logs
    const getLogIcon = (level: string) => {
        switch (level) {
            case 'error': return <ErrorIcon color="error" />;
            case 'warning': return <WarningIcon color="warning" />;
            case 'info': return <InfoIcon color="info" />;
            default: return <InfoIcon />;
        }
    };

    // Formatage des dates
    const formatDateTime = (dateString: string) => {
        return new Date(dateString).toLocaleString('fr-FR');
    };

    // Le backend expose `original_data` ; `row_data` est conserve en repli pour
    // rester compatible avec l'ancienne forme de reponse.
    const rowPayload = (detail: ImportDetail) =>
        JSON.stringify(
            (detail as unknown as Record<string, unknown>).original_data ?? detail.row_data ?? {},
        );

    const detailColumns: DataTableColumn<ImportDetail>[] = useMemo(
        () => [
            { key: 'row_number', label: 'Ligne', width: 90, align: 'right', mono: true, sortable: false },
            {
                key: 'status',
                label: 'Statut',
                width: 110,
                render: (d) => (
                    <Chip
                        size="small"
                        label={d.status === 'success' ? 'Succès' : 'Erreur'}
                        color={d.status === 'success' ? 'success' : 'error'}
                    />
                ),
                csvValue: (d) => (d.status === 'success' ? 'Succès' : 'Erreur'),
            },
            {
                key: 'row_data',
                label: 'Données',
                mono: true,
                ellipsisMaxWidth: 420,
                render: (d) => rowPayload(d),
                csvValue: (d) => rowPayload(d),
            },
            {
                key: 'error_message',
                label: 'Erreur',
                ellipsisMaxWidth: 320,
                render: (d) =>
                    d.error_message ? (
                        <Typography variant="body2" color="error" noWrap title={d.error_message}>
                            {d.error_message}
                        </Typography>
                    ) : (
                        '—'
                    ),
            },
            {
                key: 'processed_at',
                label: 'Traité le',
                width: 170,
                mono: true,
                render: (d) => (d.processed_at ? formatDateTime(d.processed_at) : '—'),
            },
        ],
        // eslint-disable-next-line react-hooks/exhaustive-deps
        [],
    );

    // Formatage de la durée
    const formatDuration = (startDate?: string, endDate?: string) => {
        if (!startDate) return '-';
        
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

    if (loading) {
        return (
            <Container maxWidth="xl" sx={{ py: 4 }}>
                <LinearProgress />
                <Typography variant="h6" sx={{ mt: 2, textAlign: 'center' }}>
                    Chargement des détails...
                </Typography>
            </Container>
        );
    }

    if (error || !job) {
        return (
            <Container maxWidth="xl" sx={{ py: 4 }}>
                <Alert severity="error" sx={{ mb: 3 }}>
                    {error || 'Import introuvable'}
                </Alert>
                <Button onClick={() => navigate('/import/history')}>
                    Retour à l'historique
                </Button>
            </Container>
        );
    }

    const statusConfig = getStatusConfig(job.status);
    const progressPercent = job.progress_percent || 0;
    const successRate = job.total_rows && job.total_rows > 0 
        ? Math.round((job.success_rows || 0) / job.total_rows * 100)
        : 0;

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
                <Link
                    underline="hover"
                    color="inherit"
                    href="#"
                    onClick={(e) => {
                        e.preventDefault();
                        navigate('/import/history');
                    }}
                    sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}
                >
                    <HistoryIcon fontSize="small" />
                    Historique
                </Link>
                <Typography color="text.primary">
                    Détails Import
                </Typography>
            </Breadcrumbs>

            {/* En-tête */}
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 4 }}>
                <Box>
                    <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
                        Détails de l'Import
                    </Typography>
                    <Typography variant="h6" color="text.secondary">
                        {job.file_name}
                    </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    {['completed', 'completed_with_errors', 'failed'].includes(job.status) && (
                        <Button
                            variant="outlined"
                            startIcon={<DownloadIcon />}
                            onClick={handleDownloadReport}
                        >
                            Rapport
                        </Button>
                    )}
                    {job.error_rows && job.error_rows > 0 && (
                        <Button
                            variant="outlined"
                            startIcon={<ExportIcon />}
                            onClick={handleExportErrors}
                            color="error"
                        >
                            Export Erreurs
                        </Button>
                    )}
                    {['pending', 'processing'].includes(job.status) && (
                        <Button
                            variant="outlined"
                            startIcon={<CancelIcon />}
                            onClick={handleCancel}
                            color="error"
                        >
                            Annuler
                        </Button>
                    )}
                    {['failed', 'cancelled'].includes(job.status) && (
                        <Button
                            variant="contained"
                            startIcon={<RetryIcon />}
                            onClick={handleRetry}
                        >
                            Relancer
                        </Button>
                    )}
                </Box>
            </Box>

            {/* Informations générales */}
            <Grid container spacing={3} sx={{ mb: 4 }}>
                <Grid item xs={12} md={8}>
                    <Card sx={{ p: 3 }}>
                        <Typography variant="h6" sx={{ mb: 2 }}>
                            Informations Générales
                        </Typography>
                        
                        <Grid container spacing={2}>
                            <Grid item xs={6}>
                                <Typography variant="caption" color="text.secondary">
                                    Fichier
                                </Typography>
                                <Typography variant="body1" sx={{ fontWeight: 500 }}>
                                    {job.file_name}
                                </Typography>
                            </Grid>
                            <Grid item xs={6}>
                                <Typography variant="caption" color="text.secondary">
                                    Type
                                </Typography>
                                <Typography variant="body1">
                                    <Chip size="small" label={job.file_type} />
                                </Typography>
                            </Grid>
                            <Grid item xs={6}>
                                <Typography variant="caption" color="text.secondary">
                                    Statut
                                </Typography>
                                <Typography variant="body1">
                                    <Chip 
                                        size="small" 
                                        label={statusConfig.label}
                                        color={statusConfig.color as any}
                                    />
                                </Typography>
                            </Grid>
                            <Grid item xs={6}>
                                <Typography variant="caption" color="text.secondary">
                                    Créé le
                                </Typography>
                                <Typography variant="body1">
                                    {formatDateTime(job.created_at)}
                                </Typography>
                            </Grid>
                            {job.started_at && (
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">
                                        Démarré le
                                    </Typography>
                                    <Typography variant="body1">
                                        {formatDateTime(job.started_at)}
                                    </Typography>
                                </Grid>
                            )}
                            {job.completed_at && (
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">
                                        Terminé le
                                    </Typography>
                                    <Typography variant="body1">
                                        {formatDateTime(job.completed_at)}
                                    </Typography>
                                </Grid>
                            )}
                            <Grid item xs={6}>
                                <Typography variant="caption" color="text.secondary">
                                    Durée
                                </Typography>
                                <Typography variant="body1">
                                    {formatDuration(job.started_at, job.completed_at)}
                                </Typography>
                            </Grid>
                            {job.user_name && (
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">
                                        Utilisateur
                                    </Typography>
                                    <Typography variant="body1">
                                        {job.user_name}
                                    </Typography>
                                </Grid>
                            )}
                        </Grid>

                        {/* Message d'erreur */}
                        {job.error_message && (
                            <Alert severity="error" sx={{ mt: 2 }}>
                                <Typography variant="body2">
                                    <strong>Erreur :</strong> {job.error_message}
                                </Typography>
                            </Alert>
                        )}
                    </Card>
                </Grid>

                <Grid item xs={12} md={4}>
                    <Card sx={{ p: 3 }}>
                        <Typography variant="h6" sx={{ mb: 2 }}>
                            Statistiques
                        </Typography>

                        {/* Progression */}
                        {job.status === 'processing' && (
                            <Box sx={{ mb: 3 }}>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                    <Typography variant="body2">Progression</Typography>
                                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                        {progressPercent}%
                                    </Typography>
                                </Box>
                                <LinearProgress variant="determinate" value={progressPercent} />
                            </Box>
                        )}

                        <Grid container spacing={2}>
                            {job.total_rows && (
                                <Grid item xs={6}>
                                    <Typography variant="h4" sx={{ fontWeight: 700 }}>
                                        {job.total_rows.toLocaleString()}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        Total lignes
                                    </Typography>
                                </Grid>
                            )}
                            {job.success_rows !== undefined && (
                                <Grid item xs={6}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, color: 'success.main' }}>
                                        {job.success_rows.toLocaleString()}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        Succès
                                    </Typography>
                                </Grid>
                            )}
                            {job.error_rows !== undefined && (
                                <Grid item xs={6}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, color: 'error.main' }}>
                                        {job.error_rows.toLocaleString()}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        Erreurs
                                    </Typography>
                                </Grid>
                            )}
                            {job.total_rows && job.total_rows > 0 && (
                                <Grid item xs={6}>
                                    <Typography variant="h4" sx={{ fontWeight: 700, color: 'info.main' }}>
                                        {successRate}%
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        Taux de succès
                                    </Typography>
                                </Grid>
                            )}
                        </Grid>
                    </Card>
                </Grid>
            </Grid>

            {/* Onglets pour détails et logs */}
            <Card>
                <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
                    <Tabs value={tabValue} onChange={(_, newValue) => setTabValue(newValue)}>
                        {/* Le compteur affiche le TOTAL, pas la page courante. */}
                        <Tab label={`Détails des lignes (${detailsTotal.toLocaleString('fr-FR')})`} />
                        <Tab label={`Logs (${logs.length})`} />
                    </Tabs>
                </Box>

                <TabPanel value={tabValue} index={0}>
                    <DataTable<ImportDetail>
                        columns={detailColumns}
                        rows={details}
                        getRowKey={(d, i) => d.id ?? `${d.row_number}-${i}`}
                        loading={loading}
                        emptyLabel="Aucun détail de ligne disponible"
                        pagination={{
                            page: detailsPage,
                            pageSize: detailsRowsPerPage,
                            total: detailsTotal,
                            onPageChange: setDetailsPage,
                            onPageSizeChange: setDetailsRowsPerPage,
                        }}
                        toolbar={{ csvExport: { filePrefix: 'lignes_import' } }}
                        maxHeight="calc(100vh - 480px)"
                    />
                </TabPanel>

                <TabPanel value={tabValue} index={1}>
                    {/* Logs */}
                    {logs.map((log) => (
                        <Box 
                            key={log.id} 
                            sx={{ 
                                display: 'flex', 
                                gap: 2, 
                                p: 2, 
                                borderBottom: 1, 
                                borderColor: 'divider' 
                            }}
                        >
                            {getLogIcon(log.level)}
                            <Box sx={{ flex: 1 }}>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                                        {log.message}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary">
                                        {formatDateTime(log.created_at)}
                                    </Typography>
                                </Box>
                                {log.details && (
                                    <Typography 
                                        variant="body2" 
                                        color="text.secondary"
                                        sx={{ fontFamily: 'monospace', fontSize: '0.75rem', mt: 1 }}
                                    >
                                        {JSON.stringify(log.details, null, 2)}
                                    </Typography>
                                )}
                            </Box>
                        </Box>
                    ))}

                    {logs.length === 0 && (
                        <Box sx={{ p: 4, textAlign: 'center' }}>
                            <Typography variant="body2" color="text.secondary">
                                Aucun log disponible
                            </Typography>
                        </Box>
                    )}
                </TabPanel>
            </Card>
        </Container>
    );
};

export default ImportDetailsPage; 