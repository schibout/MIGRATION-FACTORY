import {
    Add as AddIcon,
    CheckCircle as CheckIcon,
    CloudDone as CloudDoneIcon,
    Download as DownloadIcon,
    Edit as EditIcon,
    Error as ErrorIcon,
    ExpandMore as ExpandMoreIcon,
    Refresh as RefreshIcon,
    Storage as TableIcon,
    Timer as TimerIcon
} from '@mui/icons-material';
import {
    Accordion,
    AccordionDetails,
    AccordionSummary,
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Divider,
    Grid,
    LinearProgress,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useState } from 'react';
import { ImportResult } from '../types';

interface StepImportProps {
    importing: boolean;
    importResult: ImportResult | null;
    rowCount: number;
    selectedTable: string | null;
    onNavigateBack: () => void;
    onReset: () => void;
}

const StepImport: React.FC<StepImportProps> = ({
    importing,
    importResult,
    rowCount,
    selectedTable,
    onNavigateBack,
    onReset
}) => {
    const theme = useTheme();
    const [errorsExpanded, setErrorsExpanded] = useState(false);

    // Render importing state
    if (importing) {
        return (
            <Box sx={{ textAlign: 'center', py: 6 }}>
                <CircularProgress 
                    size={100} 
                    thickness={3}
                    sx={{ mb: 4 }}
                />
                
                <Typography variant="h4" sx={{ mb: 2, fontWeight: 600 }}>
                    Import en cours...
                </Typography>
                
                <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                    Chargement de {rowCount.toLocaleString()} lignes vers <strong>{selectedTable}</strong>
                </Typography>
                
                <Box sx={{ maxWidth: 400, mx: 'auto' }}>
                    <LinearProgress 
                        sx={{ 
                            height: 10, 
                            borderRadius: 5,
                            backgroundColor: alpha(theme.palette.primary.main, 0.2)
                        }} 
                    />
                    <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                        Veuillez patienter, ne fermez pas cette page.
                    </Typography>
                </Box>

                {/* Import animation */}
                <Box 
                    sx={{ 
                        mt: 4, 
                        display: 'flex', 
                        justifyContent: 'center', 
                        gap: 2,
                        '& > div': {
                            width: 12,
                            height: 12,
                            borderRadius: '50%',
                            backgroundColor: theme.palette.primary.main,
                            animation: 'pulse 1.5s ease-in-out infinite',
                        },
                        '& > div:nth-of-type(2)': {
                            animationDelay: '0.2s'
                        },
                        '& > div:nth-of-type(3)': {
                            animationDelay: '0.4s'
                        },
                        '@keyframes pulse': {
                            '0%, 100%': { opacity: 0.3, transform: 'scale(1)' },
                            '50%': { opacity: 1, transform: 'scale(1.2)' }
                        }
                    }}
                >
                    <div />
                    <div />
                    <div />
                </Box>
            </Box>
        );
    }

    // Render results
    if (importResult) {
        const isSuccess = importResult.success && importResult.errorCount === 0;
        const isPartialSuccess = importResult.success && importResult.errorCount > 0;
        const importMode = importResult.mode || 'insert';
        const insertedCount = importResult.insertedCount || importResult.successCount;
        const updatedCount = importResult.updatedCount || 0;

        // Export errors to CSV
        const exportErrorsToCSV = () => {
            if (!importResult.errors || importResult.errors.length === 0) return;
            
            const csv = [
                'Ligne,Erreur',
                ...importResult.errors.map(e => `${e.row},"${e.error.replace(/"/g, '""')}"`)
            ].join('\n');
            
            const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `import_errors_${importResult.targetTable}_${new Date().toISOString().slice(0,10)}.csv`;
            link.click();
            URL.revokeObjectURL(url);
        };

        return (
            <Box sx={{ py: 2 }}>
                {/* Header with status */}
                <Box sx={{ textAlign: 'center', mb: 4 }}>
                    {isSuccess ? (
                        <CloudDoneIcon 
                            sx={{ 
                                fontSize: 100, 
                                color: theme.palette.success.main, 
                                mb: 2,
                                filter: 'drop-shadow(0 4px 8px rgba(76, 175, 80, 0.3))'
                            }} 
                        />
                    ) : isPartialSuccess ? (
                        <CheckIcon 
                            sx={{ 
                                fontSize: 100, 
                                color: theme.palette.warning.main, 
                                mb: 2 
                            }} 
                        />
                    ) : (
                        <ErrorIcon 
                            sx={{ 
                                fontSize: 100, 
                                color: theme.palette.error.main, 
                                mb: 2 
                            }} 
                        />
                    )}

                    <Typography 
                        variant="h4" 
                        sx={{ mb: 1, fontWeight: 700 }}
                        color={isSuccess ? 'success.main' : isPartialSuccess ? 'warning.main' : 'error.main'}
                    >
                        {isSuccess 
                            ? 'Import réussi !' 
                            : isPartialSuccess 
                                ? 'Import terminé avec des erreurs'
                                : 'Import échoué'
                        }
                    </Typography>

                    <Typography variant="body1" color="text.secondary">
                        {importResult.message}
                    </Typography>
                </Box>

                {/* Stats cards */}
                <Grid container spacing={2} sx={{ mb: 4 }}>
                    {/* Total traité */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ height: '100%' }}>
                            <CardContent sx={{ textAlign: 'center', py: 3 }}>
                                <CheckIcon sx={{ fontSize: 40, color: theme.palette.success.main, mb: 1 }} />
                                <Typography variant="h3" color="success.main" sx={{ fontWeight: 700 }}>
                                    {importResult.successCount.toLocaleString()}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Lignes traitées
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    {/* Insérées */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ height: '100%' }}>
                            <CardContent sx={{ textAlign: 'center', py: 3 }}>
                                <AddIcon sx={{ fontSize: 40, color: theme.palette.info.main, mb: 1 }} />
                                <Typography variant="h3" color="info.main" sx={{ fontWeight: 700 }}>
                                    {insertedCount.toLocaleString()}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Lignes insérées
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    {/* Mises à jour (for upsert) */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ height: '100%' }}>
                            <CardContent sx={{ textAlign: 'center', py: 3 }}>
                                <EditIcon sx={{ fontSize: 40, color: theme.palette.warning.main, mb: 1 }} />
                                <Typography variant="h3" color="warning.main" sx={{ fontWeight: 700 }}>
                                    {updatedCount.toLocaleString()}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Lignes mises à jour
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>

                    {/* Erreurs */}
                    <Grid item xs={12} sm={6} md={3}>
                        <Card sx={{ height: '100%' }}>
                            <CardContent sx={{ textAlign: 'center', py: 3 }}>
                                <ErrorIcon sx={{ fontSize: 40, color: theme.palette.error.main, mb: 1 }} />
                                <Typography variant="h3" color="error.main" sx={{ fontWeight: 700 }}>
                                    {importResult.errorCount.toLocaleString()}
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Erreurs
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                </Grid>

                {/* Import details */}
                <Paper sx={{ p: 3, mb: 3, backgroundColor: alpha(theme.palette.background.default, 0.5) }}>
                    <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                        Détails de l'import
                    </Typography>
                    <Grid container spacing={3}>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <TableIcon color="action" />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">
                                        Table de destination
                                    </Typography>
                                    <Typography variant="body1" fontWeight={600}>
                                        {importResult.targetTable}
                                    </Typography>
                                </Box>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <TimerIcon color="action" />
                                <Box>
                                    <Typography variant="caption" color="text.secondary">
                                        Mode d'import
                                    </Typography>
                                    <Box>
                                        <Chip 
                                            label={importMode.toUpperCase()} 
                                            size="small"
                                            color={importMode === 'upsert' ? 'primary' : importMode === 'update_only' ? 'warning' : 'default'}
                                        />
                                    </Box>
                                </Box>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box>
                                <Typography variant="caption" color="text.secondary">
                                    Date d'import
                                </Typography>
                                <Typography variant="body1" fontWeight={600}>
                                    {new Date().toLocaleString('fr-FR')}
                                </Typography>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box>
                                <Typography variant="caption" color="text.secondary">
                                    Taux de succès
                                </Typography>
                                <Typography variant="body1" fontWeight={600} color={
                                    importResult.errorCount === 0 ? 'success.main' : 
                                    importResult.successCount > importResult.errorCount ? 'warning.main' : 'error.main'
                                }>
                                    {rowCount > 0 
                                        ? `${((importResult.successCount / rowCount) * 100).toFixed(1)}%`
                                        : '0%'
                                    }
                                </Typography>
                            </Box>
                        </Grid>
                    </Grid>
                </Paper>

                {/* Progress bar visualization */}
                <Paper sx={{ p: 3, mb: 3 }}>
                    <Typography variant="subtitle2" sx={{ mb: 2 }}>
                        Répartition des résultats
                    </Typography>
                    <Box sx={{ display: 'flex', height: 40, borderRadius: 2, overflow: 'hidden', mb: 2 }}>
                        {insertedCount > 0 && (
                            <Box 
                                sx={{ 
                                    width: `${(insertedCount / rowCount) * 100}%`,
                                    backgroundColor: theme.palette.success.main,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center'
                                }}
                            >
                                {insertedCount > rowCount * 0.1 && (
                                    <Typography variant="caption" color="white" fontWeight={600}>
                                        {insertedCount} insérées
                                    </Typography>
                                )}
                            </Box>
                        )}
                        {updatedCount > 0 && (
                            <Box 
                                sx={{ 
                                    width: `${(updatedCount / rowCount) * 100}%`,
                                    backgroundColor: theme.palette.warning.main,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center'
                                }}
                            >
                                {updatedCount > rowCount * 0.1 && (
                                    <Typography variant="caption" color="white" fontWeight={600}>
                                        {updatedCount} mises à jour
                                    </Typography>
                                )}
                            </Box>
                        )}
                        {importResult.errorCount > 0 && (
                            <Box 
                                sx={{ 
                                    width: `${(importResult.errorCount / rowCount) * 100}%`,
                                    backgroundColor: theme.palette.error.main,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center'
                                }}
                            >
                                {importResult.errorCount > rowCount * 0.1 && (
                                    <Typography variant="caption" color="white" fontWeight={600}>
                                        {importResult.errorCount} erreurs
                                    </Typography>
                                )}
                            </Box>
                        )}
                    </Box>
                    <Box sx={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Box sx={{ width: 16, height: 16, borderRadius: 1, backgroundColor: theme.palette.success.main }} />
                            <Typography variant="caption">Insérées</Typography>
                        </Box>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Box sx={{ width: 16, height: 16, borderRadius: 1, backgroundColor: theme.palette.warning.main }} />
                            <Typography variant="caption">Mises à jour</Typography>
                        </Box>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Box sx={{ width: 16, height: 16, borderRadius: 1, backgroundColor: theme.palette.error.main }} />
                            <Typography variant="caption">Erreurs</Typography>
                        </Box>
                    </Box>
                </Paper>

                {/* Error details accordion */}
                {importResult.errors && importResult.errors.length > 0 && (
                    <Accordion 
                        expanded={errorsExpanded} 
                        onChange={() => setErrorsExpanded(!errorsExpanded)}
                        sx={{ mb: 3 }}
                    >
                        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, width: '100%' }}>
                                <ErrorIcon color="error" />
                                <Typography variant="subtitle1" fontWeight={600} color="error.main">
                                    Détail des erreurs ({importResult.errors.length})
                                </Typography>
                                <Box sx={{ flex: 1 }} />
                                <Button
                                    size="small"
                                    startIcon={<DownloadIcon />}
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        exportErrorsToCSV();
                                    }}
                                    sx={{ mr: 2 }}
                                >
                                    Exporter CSV
                                </Button>
                            </Box>
                        </AccordionSummary>
                        <AccordionDetails>
                            <TableContainer sx={{ maxHeight: 300 }}>
                                <Table size="small" stickyHeader>
                                    <TableHead>
                                        <TableRow>
                                            <TableCell sx={{ fontWeight: 600, width: 100 }}>Ligne</TableCell>
                                            <TableCell sx={{ fontWeight: 600 }}>Message d'erreur</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {importResult.errors.map((err, idx) => (
                                            <TableRow key={idx} hover>
                                                <TableCell>
                                                    <Chip label={err.row} size="small" color="error" variant="outlined" />
                                                </TableCell>
                                                <TableCell>
                                                    <Typography variant="body2" sx={{ fontFamily: 'monospace', fontSize: 12 }}>
                                                        {err.error}
                                                    </Typography>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                            {importResult.errors.length >= 100 && (
                                <Alert severity="info" sx={{ mt: 2 }}>
                                    Seules les 100 premières erreurs sont affichées. Exportez en CSV pour voir toutes les erreurs.
                                </Alert>
                            )}
                        </AccordionDetails>
                    </Accordion>
                )}

                <Divider sx={{ my: 3 }} />

                {/* Action buttons */}
                <Box sx={{ display: 'flex', justifyContent: 'center', gap: 2 }}>
                    <Button
                        variant="contained"
                        size="large"
                        onClick={onNavigateBack}
                        sx={{ minWidth: 180 }}
                    >
                        Retour au menu
                    </Button>
                    <Button
                        variant="outlined"
                        size="large"
                        startIcon={<RefreshIcon />}
                        onClick={onReset}
                        sx={{ minWidth: 180 }}
                    >
                        Nouvel import
                    </Button>
                </Box>
            </Box>
        );
    }

    // Default state (should not happen normally)
    return (
        <Box sx={{ textAlign: 'center', py: 6 }}>
            <Typography variant="h5" color="text.secondary">
                Prêt à lancer l'import
            </Typography>
        </Box>
    );
};

export default StepImport;
