import {
    Inventory as ArticleIcon,
    ArrowBack as BackIcon,
    CheckCircle as CompleteIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Container,
    Paper,
    Step,
    StepLabel,
    Stepper,
    Typography
} from '@mui/material';
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

// Import des composants d'import
import FileUpload from '../components/import/FileUpload';
import ImportProgress from '../components/import/ImportProgress';

// Types
import { ImportJob } from '../types/import.types';

// Services
import { useImport } from '../hooks/useImport';

const ImportArticlesPage: React.FC = () => {
    const navigate = useNavigate();
    const [activeStep, setActiveStep] = useState(0);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [currentJob, setCurrentJob] = useState<ImportJob | null>(null);

    // Hook personnalisé pour les imports
    const {
        loading,
        error,
        uploadFile,
        cancelJob,
        retryJob
    } = useImport({ autoRefresh: true, refreshInterval: 5000 });

    // Étapes du processus d'import
    const steps = [
        {
            label: 'Upload fichier',
            description: 'Choisissez votre fichier articles'
        },
        {
            label: 'Traitement',
            description: 'Import et validation des données'
        },
        {
            label: 'Terminé',
            description: 'Import terminé avec succès'
        }
    ];

    // Gérer l'upload du fichier
    const handleFileUpload = async (file: File) => {
        setSelectedFile(file);
        setActiveStep(1);

        try {
            const response = await uploadFile(file, 'products');
            if (response.success && response.job_uuid) {
                const newJob: ImportJob = {
                    job_uuid: response.job_uuid,
                    file_name: file.name,
                    file_type: 'products',
                    status: 'pending',
                    created_at: new Date().toISOString()
                };
                setCurrentJob(newJob);
                setActiveStep(2);
            } else {
                console.error('Erreur upload:', response.message);
            }
        } catch (err) {
            console.error('Erreur lors de l\'upload:', err);
        }
    };

    // Gérer l'annulation d'un job
    const handleCancelJob = async (jobUuid: string) => {
        try {
            await cancelJob(jobUuid);
            setActiveStep(0);
            setCurrentJob(null);
        } catch (err) {
            console.error('Erreur annulation:', err);
        }
    };

    // Gérer la relance d'un job
    const handleRetryJob = async (jobUuid: string) => {
        try {
            await retryJob(jobUuid);
        } catch (err) {
            console.error('Erreur relance:', err);
        }
    };

    // Revenir à l'étape précédente
    const handleBack = () => {
        if (activeStep > 0) {
            setActiveStep(activeStep - 1);
        }
    };

    // Recommencer le processus
    const handleRestart = () => {
        setActiveStep(0);
        setSelectedFile(null);
        setCurrentJob(null);
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
                <ArticleIcon sx={{ fontSize: 40, color: '#4caf50', mr: 2 }} />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Import Articles
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Importez vos articles vers IFS Part Catalog
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
                    {steps.map((step, index) => (
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
                            <Typography variant="h6" sx={{ mb: 3, fontWeight: 600 }}>
                                Format attendu pour les articles
                            </Typography>
                            <Alert severity="info" sx={{ mb: 3 }}>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                    Colonnes requises :
                                </Typography>
                                <Typography variant="body2">
                                    • part_no (Numéro d'article - max 25 caractères)
                                </Typography>
                                <Typography variant="body2">
                                    • description (Description - max 200 caractères)
                                </Typography>
                                <Typography variant="body2">
                                    • unit_code (Unité de mesure - max 30 caractères)
                                </Typography>
                                <Typography variant="body2" sx={{ fontWeight: 600, mt: 1 }}>
                                    Colonnes optionnelles :
                                </Typography>
                                <Typography variant="body2">
                                    • info_text, weight_net, volume_net, language_description
                                </Typography>
                            </Alert>
                            <FileUpload
                                fileType="products"
                                onUpload={handleFileUpload}
                                loading={loading}
                            />
                        </Box>
                    )}

                    {activeStep === 1 && currentJob && (
                        <ImportProgress
                            job={currentJob}
                            onCancel={() => handleCancelJob(currentJob.job_uuid)}
                            onRetry={() => handleRetryJob(currentJob.job_uuid)}
                            onBack={handleBack}
                        />
                    )}

                    {activeStep === 2 && (
                        <Box sx={{ textAlign: 'center', py: 4 }}>
                            <CompleteIcon sx={{ fontSize: 64, color: 'success.main', mb: 2 }} />
                            <Typography variant="h5" gutterBottom>
                                Import Articles Terminé !
                            </Typography>
                            <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
                                Vos articles ont été importés avec succès dans IFS Part Catalog.
                            </Typography>
                            <Box sx={{ display: 'flex', gap: 2, justifyContent: 'center' }}>
                                <Button
                                    variant="outlined"
                                    onClick={handleRestart}
                                >
                                    Nouvel Import
                                </Button>
                                <Button
                                    variant="contained"
                                    onClick={() => navigate('/import/history')}
                                >
                                    Voir Historique
                                </Button>
                            </Box>
                        </Box>
                    )}
                </Box>
            </Paper>
        </Container>
    );
};

export default ImportArticlesPage; 