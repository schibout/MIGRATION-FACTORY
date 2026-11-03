import {
    ArrowBack as BackIcon,
    ArrowForward as NextIcon,
    Inventory2 as ArticleIcon,
    PlayArrow as PlayIcon,
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
    TextField,
    Typography,
} from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { useGenericImport } from './ImportGeneric/hooks/useGenericImport';
import { StepImport, StepMapping, StepUpload, StepValidation } from './ImportGeneric/steps';

// Import du fichier validé (Finance > Articles) : mêmes étapes et composants que /import/generic,
// table cible imposée (clean_data.article_perimetre_validation, routes /finance/articles/import/*).
// L'étape « Cible » est passée automatiquement : le mapping est généré dès le fichier analysé.

const TABLE = 'clean_data.article_perimetre_validation';

const STEPS = [
  { label: 'Upload', description: 'Sélectionner le fichier' },
  { label: 'Cible', description: 'Périmètre articles (imposée)' },
  { label: 'Mapping', description: 'Associer les colonnes' },
  { label: 'Validation', description: 'Vérifier les données' },
  { label: 'Import', description: 'Charger et recalculer' },
];

const FinanceArticlesImport: React.FC = () => {
  const navigate = useNavigate();
  const [dateArrete, setDateArrete] = useState('');
  const extra = useMemo(() => ({ date_arrete: dateArrete }), [dateArrete]);
  const {
    state, loading, error, analyzeFile, generateMapping, updateMapping, toggleIgnore,
    validateMapping, setImportOptions, executeImport, goToStep, reset, setError,
  } = useGenericImport({ baseUrl: '/finance/articles/import', fixedTable: TABLE, extra });

  // Toujours une mise à jour par N° article (pas de choix de mode)
  useEffect(() => {
    setImportOptions({ mode: 'upsert', conflictColumns: ['numero_article'] });
  }, [setImportOptions, state.fileId]);

  // Pas de choix de table : mapping généré dès l'analyse du fichier
  useEffect(() => {
    if (state.step === 1 && state.fileId) generateMapping().catch(() => goToStep(0));
  }, [state.step, state.fileId, generateMapping, goToStep]);

  const canGoNext = () => {
    if (state.step === 2) return state.mappings.some((m) => m.target === 'numero_article' && !m.ignored);
    if (state.step === 3) return state.validationErrors.length === 0 && !!dateArrete;
    return false;
  };

  const handleNext = async () => {
    try {
      if (state.step === 2) await validateMapping();
      else if (state.step === 3) await executeImport();
    } catch {
      // erreur affichée par le hook
    }
  };

  // Retour depuis le mapping = nouveau fichier (l'étape Cible n'a rien à choisir)
  const handleBack = () => (state.step === 2 ? reset() : goToStep(state.step - 1));

  return (
    <Container maxWidth="xl" sx={{ py: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
        <IconButton onClick={() => navigate('/finance/articles')} sx={{ mr: 2 }} disabled={state.importing}>
          <BackIcon />
        </IconButton>
        <ArticleIcon sx={{ fontSize: 40, color: '#00838f', mr: 2 }} />
        <Box>
          <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
            Import du fichier articles validé
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Associer la colonne du N° article (obligatoire) ; les autres colonnes associées sont conservées et affichées
            « Fichier · &lt;nom&gt; » dans l'écran Articles. Les articles du fichier passent en FICHIER.
          </Typography>
        </Box>
      </Box>

      <Stepper activeStep={state.step} sx={{ mb: 4 }}>
        {STEPS.map((s, i) => (
          <Step key={s.label} completed={state.step > i}>
            <StepLabel optional={<Typography variant="caption" color="text.secondary">{s.description}</Typography>}>
              {s.label}
            </StepLabel>
          </Step>
        ))}
      </Stepper>

      {error && <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>{error}</Alert>}

      <Card sx={{ mb: 3 }}>
        <CardContent sx={{ p: 4 }}>
          {state.step === 0 && <StepUpload loading={loading} onFileSelect={analyzeFile} />}
          {state.step === 1 && (
            <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}><CircularProgress /></Box>
          )}
          {state.step === 2 && (
            <StepMapping
              mappings={state.mappings}
              targetColumns={state.targetColumns}
              loading={loading}
              onUpdateMapping={updateMapping}
              onToggleIgnore={toggleIgnore}
              onRegenerate={generateMapping}
            />
          )}
          {state.step === 3 && (
            <>
              <TextField
                type="date"
                label="Date d'arrêté (date de validation du fichier)"
                value={dateArrete}
                onChange={(e) => setDateArrete(e.target.value)}
                InputLabelProps={{ shrink: true }}
                required
                helperText="Devient la date d'arrêté par défaut de l'écran Articles ; le périmètre est recalculé avec cette date."
                sx={{ mb: 3, minWidth: 360 }}
              />
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
                modeFixe
              />
            </>
          )}
          {state.step === 4 && (
            <StepImport
              importing={state.importing}
              importResult={state.importResult}
              rowCount={state.rowCount}
              selectedTable={state.selectedTable}
              onNavigateBack={() => navigate('/finance/articles')}
              onReset={reset}
            />
          )}
        </CardContent>
      </Card>

      {state.step >= 2 && state.step < 4 && (
        <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
          <Button variant="outlined" startIcon={<BackIcon />} onClick={handleBack} disabled={loading}>
            Précédent
          </Button>
          <Button
            variant="contained"
            endIcon={loading ? <CircularProgress size={20} color="inherit" /> : state.step === 3 ? <PlayIcon /> : <NextIcon />}
            onClick={handleNext}
            disabled={!canGoNext() || loading}
            sx={{ minWidth: 180 }}
          >
            {loading ? 'Chargement...' : state.step === 3 ? "Lancer l'import" : 'Valider'}
          </Button>
        </Box>
      )}
    </Container>
  );
};

export default FinanceArticlesImport;
