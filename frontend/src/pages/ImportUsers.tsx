import {
    ArrowBack as BackIcon,
    CheckCircle as CompleteIcon,
    Refresh as RefreshIcon,
    People as UsersIcon
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

interface SharePointImportResult {
    success: boolean;
    imported_count: number;
    errors: string[];
}

interface SharePointStatus {
    total_users: number;
    derniere_sync: string | null;
    sync_recente: number;
    status: string;
}

const ImportUsersPage: React.FC = () => {
    const navigate = useNavigate();
    const [activeStep, setActiveStep] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [connectionStatus, setConnectionStatus] = useState<'unknown' | 'success' | 'error'>('unknown');
    const [importResult, setImportResult] = useState<SharePointImportResult | null>(null);
    const [status, setStatus] = useState<SharePointStatus | null>(null);
    const [limitValue, setLimitValue] = useState<number>(5000);

    // Étapes du processus d'import SharePoint
    const steps = [
        {
            label: 'Configuration',
            description: 'Configuration de l\'import SharePoint'
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

    // Test de connexion SharePoint via le backend (proxy pour éviter CORS)
    const testConnection = async () => {
        try {
            console.log('🔍 Test de connexion SharePoint via le backend...');
            const response = await api.get('/import/users/test-connection');
            
            if (response.data.success) {
                setConnectionStatus('success');
                console.log('✅ Connexion SharePoint OK', response.data);
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
            const response = await api.get('/import/users/status');
            setStatus(response.data);
        } catch (err: any) {
            console.error('Erreur chargement statut:', err);
        }
    };

    // Lancer l'import SharePoint via le backend (proxy pour éviter CORS)
    const handleStartImport = async () => {
        setLoading(true);
        setError(null);
        setActiveStep(1);

        try {
            console.log('🚀 Import des utilisateurs SharePoint via le backend...');
            
            // Le backend fait tout : fetch SharePoint + save en DB
            const response = await api.post('/import/users', {
                limit: limitValue
            });

            if (response.data.success) {
                const dbSaved = response.data.db_saved !== false; // true par défaut si non spécifié
                
                setImportResult({
                    success: true,
                    imported_count: response.data.imported_count,
                    errors: response.data.errors || []
                });
                setActiveStep(2);
                
                if (dbSaved) {
                    console.log(`✅ Import terminé: ${response.data.imported_count} utilisateurs sauvegardés en DB`);
                } else {
                    console.log(`⚠️ Import terminé: ${response.data.imported_count} utilisateurs récupérés (non sauvegardés en DB)`);
                }
                
                // Recharger le statut après import (seulement si sauvegardé en DB)
                if (dbSaved) {
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
                    onClick={() => navigate('/projets')}
                    sx={{ mr: 2 }}
                >
                    Retour
                </Button>
                <UsersIcon sx={{ fontSize: 40, color: '#f44336', mr: 2 }} />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Import Utilisateurs ASAP SharePoint
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Importez les utilisateurs depuis SharePoint ASAP vers la base de données
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
                                        URL: http://asap.stjn.local/_api/web/siteusers
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
                                                label={`${status.total_users} utilisateurs`}
                                                color="primary"
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
                                    <TextField
                                        label="Limite d'utilisateurs"
                                        type="number"
                                        value={limitValue}
                                        onChange={(e) => setLimitValue(Number(e.target.value))}
                                        helperText="Nombre maximum d'utilisateurs à importer (recommandé: 5000 pour tous)"
                                        sx={{ width: 300 }}
                                        inputProps={{ min: 1, max: 10000 }}
                                    />
                                </CardContent>
                            </Card>

                            {/* Bouton d'import */}
                            <Box sx={{ textAlign: 'center' }}>
                                <Button
                                    variant="contained"
                                    size="large"
                                    startIcon={loading ? <CircularProgress size={20} /> : <UsersIcon />}
                                    onClick={handleStartImport}
                                    disabled={loading || connectionStatus !== 'success'}
                                    sx={{ px: 4, py: 1.5 }}
                                >
                                    {loading ? 'Import en cours...' : 'Lancer l\'import SharePoint'}
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
                                Récupération des utilisateurs depuis SharePoint
                            </Typography>
                            <Typography variant="body2" color="text.secondary">
                                Limite configurée: {limitValue} utilisateurs
                            </Typography>
                        </Box>
                    )}

                    {activeStep === 2 && importResult && (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <CompleteIcon sx={{ fontSize: 64, color: 'success.main', mb: 2 }} />
                            <Typography variant="h5" gutterBottom>
                                Import SharePoint Terminé !
                            </Typography>
                            
                            {/* Résumé de l'import */}
                            <Card sx={{ mb: 4, mx: 'auto', maxWidth: 500 }}>
                                <CardContent>
                                    <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                                        Résumé de l'import
                                    </Typography>
                                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                        <Typography variant="body2">Utilisateurs importés:</Typography>
                                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                            {importResult.imported_count}
                                        </Typography>
                                    </Box>
                                    {importResult.errors.length > 0 && (
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                                            <Typography variant="body2" color="error">Erreurs:</Typography>
                                            <Typography variant="body2" color="error" sx={{ fontWeight: 600 }}>
                                                {importResult.errors.length}
                                            </Typography>
                                        </Box>
                                    )}
                                    {status && (
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                                            <Typography variant="body2">Total en base:</Typography>
                                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                                {status.total_users}
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
                                            • {error}
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
                                    onClick={() => navigate('/projets')}
                                >
                                    Retour aux Projets
                                </Button>
                            </Box>
                        </Box>
                    )}
                </Box>
            </Paper>
        </Container>
    );
};

export default ImportUsersPage;

