import {
    ArrowBack as BackIcon,
    CheckCircle as CompleteIcon,
    CloudUpload as UploadIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Container,
    Divider,
    Paper,
    Step,
    StepLabel,
    Stepper,
    Typography
} from '@mui/material';
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

// Nos nouveaux composants
import ClientFileTypeSelector from '../components/import/ClientFileTypeSelector';
import { ImportTypeConfig } from '../services/importConfigService';

const ImportClientsSimple: React.FC = () => {
    const navigate = useNavigate();
    const [activeStep, setActiveStep] = useState(0);
    const [selectedType, setSelectedType] = useState<ImportTypeConfig | null>(null);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);

    const steps = [
        'Sélection du type',
        'Upload fichier', 
        'Validation',
        'Import'
    ];

    const handleTypeSelect = (typeConfig: ImportTypeConfig) => {
        setSelectedType(typeConfig);
        setActiveStep(1);
    };

    const handleFileSelect = (file: File) => {
        setSelectedFile(file);
        setActiveStep(2);
    };

    const handleBack = () => {
        if (activeStep > 0) {
            setActiveStep(activeStep - 1);
        } else {
            navigate('/import');
        }
    };

    const handleValidateFile = () => {
        // TODO: Valider le fichier selon le type sélectionné
        setActiveStep(3);
    };

    const handleStartImport = () => {
        // TODO: Lancer l'import
        console.log('Import démarré:', { selectedType, selectedFile });
    };

    return (
        <Container maxWidth="lg" sx={{ py: 4 }}>
            {/* En-tête */}
            <Box sx={{ mb: 4 }}>
                <Button 
                    startIcon={<BackIcon />} 
                    onClick={handleBack}
                    sx={{ mb: 2 }}
                >
                    Retour
                </Button>
                
                <Typography variant="h4" gutterBottom>
                    Import Clients
                </Typography>
                <Typography variant="body1" color="text.secondary">
                    Importez vos données clients en suivant les étapes ci-dessous
                </Typography>
            </Box>

            {/* Stepper */}
            <Paper sx={{ p: 3, mb: 4 }}>
                <Stepper activeStep={activeStep} alternativeLabel>
                    {steps.map((label) => (
                        <Step key={label}>
                            <StepLabel>{label}</StepLabel>
                        </Step>
                    ))}
                </Stepper>
            </Paper>

            {/* Contenu des étapes */}
            <Paper sx={{ p: 3 }}>
                {/* Étape 1: Sélection du type */}
                {activeStep === 0 && (
                    <ClientFileTypeSelector
                        onTypeSelect={handleTypeSelect}
                        selectedType={selectedType?.type_code}
                    />
                )}

                {/* Étape 2: Upload fichier */}
                {activeStep === 1 && selectedType && (
                    <Box>
                        <Typography variant="h6" gutterBottom>
                            Upload du fichier {selectedType.display_name}
                        </Typography>
                        
                        <Alert severity="info" sx={{ mb: 3 }}>
                            <strong>Type sélectionné :</strong> {selectedType.display_name}
                            <br />
                            <strong>Colonnes requises :</strong> {selectedType.required_columns.join(', ')}
                            <br />
                            <strong>Formats acceptés :</strong> {selectedType.allowed_extensions.join(', ').toUpperCase()}
                            <br />
                            <strong>Taille maximum :</strong> {selectedType.max_file_size_mb} MB
                        </Alert>

                        <Card variant="outlined" sx={{ textAlign: 'center', p: 6 }}>
                            <CardContent>
                                <UploadIcon sx={{ fontSize: 60, color: 'primary.main', mb: 2 }} />
                                <Typography variant="h6" gutterBottom>
                                    Glissez votre fichier ici ou cliquez pour parcourir
                                </Typography>
                                <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                                    Fichiers acceptés: {selectedType.allowed_extensions.join(', ').toUpperCase()}
                                </Typography>
                                
                                <input
                                    type="file"
                                    accept={selectedType.allowed_extensions.map(ext => `.${ext}`).join(',')}
                                    onChange={(e) => {
                                        const file = e.target.files?.[0];
                                        if (file) handleFileSelect(file);
                                    }}
                                    style={{ display: 'none' }}
                                    id="file-upload"
                                />
                                <label htmlFor="file-upload">
                                    <Button variant="contained" component="span">
                                        Choisir un fichier
                                    </Button>
                                </label>
                            </CardContent>
                        </Card>

                        {selectedFile && (
                            <Alert severity="success" sx={{ mt: 2 }}>
                                Fichier sélectionné: <strong>{selectedFile.name}</strong> ({(selectedFile.size / 1024 / 1024).toFixed(2)} MB)
                            </Alert>
                        )}
                    </Box>
                )}

                {/* Étape 3: Validation */}
                {activeStep === 2 && selectedFile && selectedType && (
                    <Box>
                        <Typography variant="h6" gutterBottom>
                            Validation du fichier
                        </Typography>
                        
                        <Card variant="outlined" sx={{ mb: 3 }}>
                            <CardContent>
                                <Typography variant="subtitle1" gutterBottom>
                                    <strong>Résumé de l'import</strong>
                                </Typography>
                                <Divider sx={{ my: 2 }} />
                                <Typography variant="body2" gutterBottom>
                                    <strong>Type :</strong> {selectedType.display_name}
                                </Typography>
                                <Typography variant="body2" gutterBottom>
                                    <strong>Fichier :</strong> {selectedFile.name}
                                </Typography>
                                <Typography variant="body2" gutterBottom>
                                    <strong>Taille :</strong> {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
                                </Typography>
                                <Typography variant="body2" gutterBottom>
                                    <strong>Table cible :</strong> {selectedType.target_table}
                                </Typography>
                            </CardContent>
                        </Card>

                        <Alert severity="warning" sx={{ mb: 2 }}>
                            Vérifiez que votre fichier contient bien les colonnes requises : 
                            <strong> {selectedType.required_columns.join(', ')}</strong>
                        </Alert>

                        <Button 
                            variant="contained" 
                            onClick={handleValidateFile}
                            fullWidth
                        >
                            Valider et continuer
                        </Button>
                    </Box>
                )}

                {/* Étape 4: Import */}
                {activeStep === 3 && (
                    <Box sx={{ textAlign: 'center' }}>
                        <CompleteIcon sx={{ fontSize: 60, color: 'success.main', mb: 2 }} />
                        <Typography variant="h6" gutterBottom>
                            Prêt pour l'import
                        </Typography>
                        <Typography variant="body1" color="text.secondary" sx={{ mb: 3 }}>
                            Tout est configuré. Cliquez sur "Démarrer l'import" pour commencer le traitement.
                        </Typography>
                        
                        <Button 
                            variant="contained" 
                            size="large"
                            onClick={handleStartImport}
                        >
                            Démarrer l'import
                        </Button>
                    </Box>
                )}
            </Paper>
        </Container>
    );
};

export default ImportClientsSimple; 