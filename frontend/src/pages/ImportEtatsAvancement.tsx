import {
    ArrowBack as BackIcon,
    CheckCircle as CompleteIcon,
    Refresh as RefreshIcon,
    Timeline as TimelineIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Container,
    Paper,
    Step,
    StepLabel,
    Stepper,
    TextField,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

// Services
import api from '../services/api';

interface ImportResult {
    success: boolean;
    imported_count: number;
    errors: string[];
    site_id?: string;
    // Pour l'import de tous les sites
    total_imported?: number;
    sites_processed?: number;
    sites_with_data?: number;
    // Compteurs des listes filles importées en même temps
    related_counts?: {
        phases?: number;
        jalons_ref?: number;
        statut_jalons?: number;
        statut_cfv?: number;
        statut_couts?: number;
    };
}

interface ImportStatus {
    total_etats: number;
    derniere_sync: string | null;
    sync_recente: number;
    nb_sites: number;
    status: string;
}

const ImportEtatsAvancementPage: React.FC = () => {
    const navigate = useNavigate();
    const [activeStep, setActiveStep] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [connectionStatus, setConnectionStatus] = useState<'unknown' | 'success' | 'error'>('unknown');
    const [importResult, setImportResult] = useState<ImportResult | null>(null);
    const [status, setStatus] = useState<ImportStatus | null>(null);
    const [includeRelated, setIncludeRelated] = useState<boolean>(true);
    const [siteId, setSiteId] = useState<string>('863');
    const [importMode, setImportMode] = useState<'single' | 'all'>('all');

    // Étapes du processus d'import
    const steps = [
        {
            label: 'Configuration',
            description: 'Configuration de l\'import États d\'avancement'
        },
        {
            label: 'Import',
            description: 'Récupération des données depuis SharePoint'
        },
        {
            label: 'Terminé',
            description: 'Import terminé avec succès'
        }
    ];

    // Charger le statut au démarrage
    useEffect(() => {
        loadStatus();
        testConnection();
    }, []);

    // Test de connexion SharePoint via le backend
    const testConnection = async () => {
        try {
            console.log('🔍 Test de connexion SharePoint États d\'avancement...');
            const response = await api.get(`/import/etats-avancement/test-connection?site_id=${siteId}`);
            
            if (response.data.success) {
                setConnectionStatus('success');
                console.log('✅ Connexion États d\'avancement OK', response.data);
            } else {
                setConnectionStatus('error');
                setError(response.data.error || 'Erreur de connexion SharePoint');
                console.error('❌ Erreur connexion SharePoint:', response.data);
            }
        } catch (err: any) {
            setConnectionStatus('error');
            setError(err.response?.data?.error || err.message || 'Erreur de connexion SharePoint');
            console.error('❌ Exception connexion SharePoint:', err);
        }
    };

    // Charger le statut des imports
    const loadStatus = async () => {
        try {
            const response = await api.get('/import/etats-avancement/status');
            setStatus(response.data);
        } catch (err: any) {
            console.error('Erreur chargement statut:', err);
        }
    };

    // Lancer l'import (un seul site)
    const handleStartImport = async () => {
        setLoading(true);
        setError(null);
        setActiveStep(1);

        try {
            console.log('🚀 Import des états d\'avancement SharePoint...');
            
            const response = await api.post('/import/etats-avancement', {
                site_id: siteId,
                include_related: includeRelated
            }, { timeout: 7200000 });

            if (response.data.success) {
                const dbSaved = response.data.db_saved !== false;

                setImportResult({
                    success: true,
                    imported_count: response.data.imported_count,
                    errors: response.data.errors || [],
                    site_id: response.data.site_id,
                    related_counts: response.data.related_counts
                });
                setActiveStep(2);
                
                if (dbSaved) {
                    console.log(`✅ Import terminé: ${response.data.imported_count} états sauvegardés en DB`);
                    await loadStatus();
                }
            } else {
                setError(response.data.error || 'Erreur lors de l\'import');
                setActiveStep(0);
            }
        } catch (err: any) {
            console.error('❌ Erreur import:', err);
            setError(err.response?.data?.error || err.message || 'Erreur lors de l\'import');
            setActiveStep(0);
        } finally {
            setLoading(false);
        }
    };

    // Lancer l'import de TOUS les sites
    const handleStartImportAll = async () => {
        setLoading(true);
        setError(null);
        setActiveStep(1);

        try {
            console.log('🚀 Import de TOUS les états d\'avancement SharePoint...');
            
            const response = await api.post('/import/etats-avancement/all', {
                include_related: includeRelated
            }, { timeout: 7200000 });

            if (response.data.success) {
                setImportResult({
                    success: true,
                    imported_count: response.data.total_imported,
                    total_imported: response.data.total_imported,
                    sites_processed: response.data.sites_processed,
                    sites_with_data: response.data.sites_with_data,
                    related_counts: response.data.related_counts,
                    errors: response.data.errors || []
                });
                setActiveStep(2);
                console.log(`✅ Import global terminé: ${response.data.total_imported} états de ${response.data.sites_with_data} sites`);
                await loadStatus();
            } else {
                setError(response.data.error || 'Erreur lors de l\'import');
                setActiveStep(0);
            }
        } catch (err: any) {
            console.error('❌ Erreur import:', err);
            setError(err.response?.data?.error || err.message || 'Erreur lors de l\'import');
            setActiveStep(0);
        } finally {
            setLoading(false);
        }
    };

    // Recommencer le processus
    const handleRestart = () => {
        setActiveStep(0);
        setImportResult(null);
        setError(null);
        loadStatus();
    };

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            {/* En-tête avec retour */}
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
                <Button
                    startIcon={<BackIcon />}
                    onClick={() => navigate('/import')}
                    sx={{ mr: 2 }}
                >
                    Retour
                </Button>
                <TimelineIcon sx={{ fontSize: 40, color: '#4caf50', mr: 2 }} />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Import États d'Avancement
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Importez les états d'avancement depuis SharePoint
                    </Typography>
                </Box>
            </Box>

            {/* Gestion d'erreur */}
            {error && (
                <Alert severity="warning" sx={{ mb: 4 }}>
                    <Typography variant="body2">
                        {error}
                    </Typography>
                </Alert>
            )}

            <Paper sx={{ p: 4 }}>
                {/* Stepper */}
                <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
                    {steps.map((step) => (
                        <Step key={step.label}>
                            <StepLabel>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                    {step.label}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {step.description}
                                </Typography>
                            </StepLabel>
                        </Step>
                    ))}
                </Stepper>

                {/* Contenu des étapes */}
                <Box sx={{ mt: 4 }}>
                    {activeStep === 0 && (
                        <Box>
                            {/* Statut de connexion SharePoint */}
                            <Card sx={{ mb: 3 }}>
                                <CardContent>
                                    <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                                        Connexion SharePoint
                                    </Typography>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                                        <Chip
                                            label={connectionStatus === 'success' ? 'Connecté' : connectionStatus === 'error' ? 'Erreur' : 'Test...'}
                                            color={connectionStatus === 'success' ? 'success' : connectionStatus === 'error' ? 'error' : 'default'}
                                            variant="outlined"
                                        />
                                        <Button
                                            size="small"
                                            startIcon={<RefreshIcon />}
                                            onClick={testConnection}
                                            disabled={loading}
                                        >
                                            Retester
                                        </Button>
                                    </Box>
                                    <Typography variant="body2" color="text.secondary">
                                        URL: http://asap.stjn.local/{siteId}/_api/web/lists(guid'0143FA81-...')/items
                                    </Typography>
                                </CardContent>
                            </Card>

                            {/* Statut actuel */}
                            {status && (
                                <Card sx={{ mb: 3 }}>
                                    <CardContent>
                                        <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                                            Statut actuel
                                        </Typography>
                                        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                                            <Chip
                                                label={`${status.total_etats} états`}
                                                color="primary"
                                                variant="outlined"
                                            />
                                            <Chip
                                                label={`${status.nb_sites} site(s)`}
                                                color="info"
                                                variant="outlined"
                                            />
                                            <Chip
                                                label={status.status === 'ok' ? 'Synchronisé' : 'Nécessite sync'}
                                                color={status.status === 'ok' ? 'success' : 'warning'}
                                                variant="outlined"
                                            />
                                        </Box>
                                        {status.derniere_sync && (
                                            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                                Dernière sync: {new Date(status.derniere_sync).toLocaleString()}
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>
                            )}

                            {/* Configuration d'import */}
                            <Card sx={{ mb: 3 }}>
                                <CardContent>
                                    <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                                        Configuration d'import
                                    </Typography>
                                    
                                    {/* Mode d'import */}
                                    <Box sx={{ display: 'flex', gap: 1, mb: 3 }}>
                                        <Chip
                                            label="Tous les projets"
                                            color={importMode === 'all' ? 'primary' : 'default'}
                                            onClick={() => setImportMode('all')}
                                            sx={{ cursor: 'pointer' }}
                                        />
                                        <Chip
                                            label="Un seul site"
                                            color={importMode === 'single' ? 'primary' : 'default'}
                                            onClick={() => setImportMode('single')}
                                            sx={{ cursor: 'pointer' }}
                                        />
                                    </Box>
                                    
                                    <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'flex-start' }}>
                                        {importMode === 'single' && (
                                            <TextField
                                                label="Site ID"
                                                value={siteId}
                                                onChange={(e) => setSiteId(e.target.value)}
                                                helperText="ID du sous-site SharePoint (ex: 863)"
                                                sx={{ width: 150 }}
                                            />
                                        )}
                                        <Box sx={{ alignSelf: 'center' }}>
                                            <Chip
                                                label={includeRelated ? '✓ Inclure listes liées (Phases, Jalons, CFV, Coûts)' : 'Listes liées désactivées'}
                                                color={includeRelated ? 'success' : 'default'}
                                                variant={includeRelated ? 'filled' : 'outlined'}
                                                onClick={() => setIncludeRelated(!includeRelated)}
                                                sx={{ cursor: 'pointer' }}
                                            />
                                            <Typography variant="caption" display="block" color="text.secondary" sx={{ mt: 0.5 }}>
                                                Importe en plus : Phases, Jalons réf., Statut jalons / CFV / coûts
                                            </Typography>
                                        </Box>
                                    </Box>
                                    
                                    {importMode === 'all' && (
                                        <Alert severity="info" sx={{ mt: 2 }}>
                                            Import de tous les projets (~1100 sites). Cette opération peut prendre plusieurs minutes.
                                        </Alert>
                                    )}
                                </CardContent>
                            </Card>

                            {/* Bouton d'import */}
                            <Box sx={{ textAlign: 'center' }}>
                                <Button
                                    variant="contained"
                                    size="large"
                                    startIcon={loading ? <CircularProgress size={20} /> : <TimelineIcon />}
                                    onClick={importMode === 'all' ? handleStartImportAll : handleStartImport}
                                    disabled={loading || (importMode === 'single' && connectionStatus !== 'success')}
                                    sx={{ px: 4, py: 1.5, bgcolor: importMode === 'all' ? '#2196f3' : '#4caf50', '&:hover': { bgcolor: importMode === 'all' ? '#1976d2' : '#388e3c' } }}
                                >
                                    {loading ? 'Import en cours...' : (importMode === 'all' ? 'Importer TOUS les projets' : 'Importer ce site')}
                                </Button>
                            </Box>
                        </Box>
                    )}

                    {activeStep === 1 && (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <CircularProgress size={64} sx={{ mb: 3 }} />
                            <Typography variant="h5" gutterBottom>
                                Import en cours...
                            </Typography>
                            <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                                {importMode === 'all' 
                                    ? 'Récupération des états de TOUS les projets (~1100 sites)'
                                    : 'Récupération des états d\'avancement depuis SharePoint'}
                            </Typography>
                            <Typography variant="body2" color="text.secondary">
                                {importMode === 'all'
                                    ? 'Tous les projets en cours de traitement'
                                    : `Site: ${siteId}`}
                            </Typography>
                            {importMode === 'all' && (
                                <Alert severity="warning" sx={{ mt: 3, mx: 'auto', maxWidth: 400 }}>
                                    Cette opération peut prendre plusieurs minutes. Veuillez patienter...
                                </Alert>
                            )}
                        </Box>
                    )}

                    {activeStep === 2 && importResult && (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <CompleteIcon sx={{ fontSize: 64, color: 'success.main', mb: 2 }} />
                            <Typography variant="h5" gutterBottom>
                                Import Terminé !
                            </Typography>
                            
                            {/* Résumé de l'import */}
                            <Card sx={{ mb: 4, mx: 'auto', maxWidth: 500 }}>
                                <CardContent>
                                    <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                                        Résumé de l'import
                                    </Typography>
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                        <Typography variant="body2">États importés:</Typography>
                                        <Typography variant="body2" sx={{ fontWeight: 600, color: 'success.main' }}>
                                            {importResult.total_imported || importResult.imported_count}
                                        </Typography>
                                    </Box>
                                    
                                    {/* Affichage pour import "tous les sites" */}
                                    {importResult.sites_processed !== undefined && (
                                        <>
                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                <Typography variant="body2">Sites traités:</Typography>
                                                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                                    {importResult.sites_processed}
                                                </Typography>
                                            </Box>
                                            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                                <Typography variant="body2">Sites avec données:</Typography>
                                                <Typography variant="body2" sx={{ fontWeight: 600, color: 'info.main' }}>
                                                    {importResult.sites_with_data}
                                                </Typography>
                                            </Box>
                                        </>
                                    )}
                                    
                                    {/* Listes filles importées en même temps */}
                                    {importResult.related_counts && (
                                        <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid #eee' }}>
                                            <Typography variant="body2" sx={{ fontWeight: 600, mb: 1 }}>
                                                Listes liées importées:
                                            </Typography>
                                            {Object.entries(importResult.related_counts).map(([key, count]) => (
                                                <Box key={key} sx={{ display: 'flex', justifyContent: 'space-between', mb: 0.5 }}>
                                                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                                        {key}:
                                                    </Typography>
                                                    <Typography variant="body2" sx={{ fontWeight: 500 }}>
                                                        {count}
                                                    </Typography>
                                                </Box>
                                            ))}
                                        </Box>
                                    )}

                                    {/* Affichage pour import "un seul site" */}
                                    {importResult.site_id && (
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                            <Typography variant="body2">Site ID:</Typography>
                                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                                {importResult.site_id}
                                            </Typography>
                                        </Box>
                                    )}
                                    
                                    {importResult.errors.length > 0 && (
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                            <Typography variant="body2" color="error">Erreurs:</Typography>
                                            <Typography variant="body2" color="error" sx={{ fontWeight: 600 }}>
                                                {importResult.errors.length}
                                            </Typography>
                                        </Box>
                                    )}
                                    {status && (
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 2, pt: 2, borderTop: '1px solid #eee' }}>
                                            <Typography variant="body2" sx={{ fontWeight: 600 }}>Total en base:</Typography>
                                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                                {status.total_etats}
                                            </Typography>
                                        </Box>
                                    )}
                                </CardContent>
                            </Card>

                            {/* Erreurs détaillées */}
                            {importResult.errors.length > 0 && (
                                <Alert severity="warning" sx={{ mb: 4, textAlign: 'left' }}>
                                    <Typography variant="body2" sx={{ fontWeight: 600, mb: 1 }}>
                                        Erreurs rencontrées:
                                    </Typography>
                                    {importResult.errors.slice(0, 5).map((error, index) => (
                                        <Typography key={index} variant="body2">
                                            - {error}
                                        </Typography>
                                    ))}
                                    {importResult.errors.length > 5 && (
                                        <Typography variant="body2" sx={{ fontStyle: 'italic' }}>
                                            ... et {importResult.errors.length - 5} autres erreurs
                                        </Typography>
                                    )}
                                </Alert>
                            )}
                            
                            <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center' }}>
                                <Button
                                    variant="outlined"
                                    onClick={handleRestart}
                                >
                                    Nouvel Import
                                </Button>
                                <Button
                                    variant="contained"
                                    onClick={() => navigate('/import')}
                                >
                                    Retour aux Imports
                                </Button>
                            </Box>
                        </Box>
                    )}
                </Box>
            </Paper>
        </Container>
    );
};

export default ImportEtatsAvancementPage;
