import {
    ArrowBack as BackIcon,
    ArrowForward as NextIcon,
    PlayArrow as PlayIcon,
    CloudUpload as UploadIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    CircularProgress,
    Container,
    IconButton,
    Step,
    StepLabel,
    Stepper,
    Typography,
    useTheme
} from '@mui/material';
import React, { useCallback } from 'react';
import { useNavigate } from 'react-router-dom';

import { useGenericImport } from './hooks/useGenericImport';
import {
    StepImport,
    StepMapping,
    StepPreviewTarget,
    StepUpload,
    StepValidation
} from './steps';
import { STEPS } from './types';

const ImportGenericPage: React.FC = () => {
    const theme = useTheme();
    const navigate = useNavigate();

    const {
        state,
        loading,
        error,
        analyzeFile,
        loadSchemas,
        setSchema,
        loadTables,
        selectTable,
        generateMapping,
        updateMapping,
        toggleIgnore,
        validateMapping,
        setImportOptions,
        executeImport,
        goToStep,
        reset,
        setError
    } = useGenericImport();

    // Check if we can proceed to next step
    const canGoNext = useCallback(() => {
        switch (state.step) {
            case 0:
                return false; // Handled by file upload
            case 1:
                return !!state.selectedTable;
            case 2:
                return state.mappings.filter(m => m.target && !m.ignored).length > 0;
            case 3:
                // Validation must pass, and for upsert/update_only, conflict columns must be set
                if (state.validationErrors.length > 0) return false;
                if (state.importOptions.mode !== 'insert' && state.importOptions.conflictColumns.length === 0) {
                    return false;
                }
                return true;
            default:
                return false;
        }
    }, [state.step, state.selectedTable, state.mappings, state.validationErrors, state.importOptions]);

    // Handle next button click
    const handleNext = useCallback(async () => {
        try {
            switch (state.step) {
                case 1:
                    await generateMapping();
                    break;
                case 2:
                    await validateMapping();
                    break;
                case 3:
                    await executeImport();
                    break;
            }
        } catch (err) {
            // Error already handled in hook
        }
    }, [state.step, generateMapping, validateMapping, executeImport]);

    // Handle back navigation
    const handleBack = useCallback(() => {
        if (state.step > 0) {
            goToStep(state.step - 1);
        }
    }, [state.step, goToStep]);

    // Handle navigation to import menu
    const handleNavigateBack = useCallback(() => {
        navigate('/data-import');
    }, [navigate]);

    // Render the current step content
    const renderStepContent = () => {
        switch (state.step) {
            case 0:
                return (
                    <StepUpload
                        loading={loading}
                        onFileSelect={analyzeFile}
                    />
                );
            case 1:
                return (
                    <StepPreviewTarget
                        file={state.file}
                        fileColumns={state.fileColumns}
                        rowCount={state.rowCount}
                        availableSchemas={state.availableSchemas}
                        selectedSchema={state.selectedSchema}
                        tables={state.tables}
                        selectedTable={state.selectedTable}
                        onSchemaChange={setSchema}
                        onTableSelect={selectTable}
                        onLoadTables={loadTables}
                        onLoadSchemas={loadSchemas}
                    />
                );
            case 2:
                return (
                    <StepMapping
                        mappings={state.mappings}
                        targetColumns={state.targetColumns}
                        loading={loading}
                        onUpdateMapping={updateMapping}
                        onToggleIgnore={toggleIgnore}
                        onRegenerate={generateMapping}
                    />
                );
            case 3:
                return (
                    <StepValidation
                        validationErrors={state.validationErrors}
                        validationWarnings={state.validationWarnings}
                        previewData={state.previewData}
                        rowCount={state.rowCount}
                        mappings={state.mappings}
                        selectedTable={state.selectedTable}
                        targetColumns={state.targetColumns}
                        importOptions={state.importOptions}
                        onImportOptionsChange={setImportOptions}
                    />
                );
            case 4:
                return (
                    <StepImport
                        importing={state.importing}
                        importResult={state.importResult}
                        rowCount={state.rowCount}
                        selectedTable={state.selectedTable}
                        onNavigateBack={handleNavigateBack}
                        onReset={reset}
                    />
                );
            default:
                return null;
        }
    };

    // Get the button label for next step
    const getNextButtonLabel = () => {
        switch (state.step) {
            case 1:
                return 'Générer le mapping';
            case 2:
                return 'Valider';
            case 3:
                return 'Lancer l\'import';
            default:
                return 'Suivant';
        }
    };

    return (
        <Container maxWidth="xl" sx={{ py: 3 }}>
            {/* Header */}
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
                <IconButton 
                    onClick={handleNavigateBack} 
                    sx={{ mr: 2 }}
                    disabled={state.importing}
                >
                    <BackIcon />
                </IconButton>
                <UploadIcon 
                    sx={{ 
                        fontSize: 40, 
                        color: theme.palette.primary.main, 
                        mr: 2 
                    }} 
                />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Import Générique
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Importez des données vers n'importe quelle table avec mapping automatique
                    </Typography>
                </Box>
            </Box>

            {/* Stepper */}
            <Stepper activeStep={state.step} sx={{ mb: 4 }}>
                {STEPS.map((step, index) => (
                    <Step key={step.label} completed={state.step > index}>
                        <StepLabel
                            optional={
                                <Typography variant="caption" color="text.secondary">
                                    {step.description}
                                </Typography>
                            }
                        >
                            {step.label}
                        </StepLabel>
                    </Step>
                ))}
            </Stepper>

            {/* Global error alert */}
            {error && (
                <Alert 
                    severity="error" 
                    sx={{ mb: 3 }} 
                    onClose={() => setError(null)}
                >
                    {error}
                </Alert>
            )}

            {/* Step content */}
            <Card sx={{ mb: 3 }}>
                <CardContent sx={{ p: 4 }}>
                    {renderStepContent()}
                </CardContent>
            </Card>

            {/* Navigation buttons */}
            {state.step > 0 && state.step < 4 && (
                <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
                    <Button
                        variant="outlined"
                        startIcon={<BackIcon />}
                        onClick={handleBack}
                        disabled={loading || state.importing}
                    >
                        Précédent
                    </Button>
                    <Button
                        variant="contained"
                        endIcon={
                            loading ? (
                                <CircularProgress size={20} color="inherit" />
                            ) : state.step === 3 ? (
                                <PlayIcon />
                            ) : (
                                <NextIcon />
                            )
                        }
                        onClick={handleNext}
                        disabled={!canGoNext() || loading || state.importing}
                        sx={{ minWidth: 180 }}
                    >
                        {loading ? 'Chargement...' : getNextButtonLabel()}
                    </Button>
                </Box>
            )}
        </Container>
    );
};

export default ImportGenericPage;
