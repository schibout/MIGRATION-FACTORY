import {
    CheckCircle as CheckIcon,
    Error as ErrorIcon,
    Info as InfoIcon,
    Warning as WarningIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Card,
    CardContent,
    Checkbox,
    Chip,
    FormControl,
    FormControlLabel,
    Grid,
    InputLabel,
    MenuItem,
    Paper,
    Select,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Tooltip,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';
import { ColumnMapping, ImportMode, ImportOptions, PreviewRow, TargetColumn, ValidationError } from '../types';

interface StepValidationProps {
    validationErrors: ValidationError[];
    validationWarnings: ValidationError[];
    previewData: PreviewRow[];
    rowCount: number;
    mappings: ColumnMapping[];
    selectedTable: string | null;
    targetColumns: TargetColumn[];
    importOptions: ImportOptions;
    onImportOptionsChange: (options: Partial<ImportOptions>) => void;
}

const StepValidation: React.FC<StepValidationProps> = ({
    validationErrors,
    validationWarnings,
    previewData,
    rowCount,
    mappings,
    selectedTable,
    targetColumns,
    importOptions,
    onImportOptionsChange
}) => {
    const theme = useTheme();

    const activeMappings = mappings.filter(m => m.target && !m.ignored);
    const isValid = validationErrors.length === 0;

    // Get columns that can be used as conflict keys (primary keys or unique)
    const conflictCandidates = (targetColumns || []).filter(
        col => col?.isPrimaryKey || (col?.constraints || []).includes('UNIQUE')
    );

    // Get mapped target column names
    const mappedTargetCols = activeMappings.map(m => m.target).filter(Boolean) as string[];

    const handleModeChange = (mode: ImportMode) => {
        onImportOptionsChange({ 
            mode,
            // Reset conflict columns when switching to insert
            conflictColumns: mode === 'insert' ? [] : importOptions.conflictColumns
        });
    };

    const handleConflictColumnToggle = (colName: string) => {
        const current = importOptions.conflictColumns;
        const newCols = current.includes(colName)
            ? current.filter(c => c !== colName)
            : [...current, colName];
        onImportOptionsChange({ conflictColumns: newCols });
    };

    return (
        <Box>
            {/* Summary cards */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={12} md={4}>
                    <Card 
                        sx={{ 
                            backgroundColor: alpha(
                                validationErrors.length > 0 
                                    ? theme.palette.error.main 
                                    : theme.palette.success.main, 
                                0.1
                            ),
                            border: `1px solid ${alpha(
                                validationErrors.length > 0 
                                    ? theme.palette.error.main 
                                    : theme.palette.success.main, 
                                0.3
                            )}`
                        }}
                    >
                        <CardContent sx={{ textAlign: 'center', py: 3 }}>
                            <ErrorIcon 
                                sx={{ 
                                    fontSize: 50, 
                                    color: validationErrors.length > 0 
                                        ? theme.palette.error.main 
                                        : theme.palette.success.main 
                                }} 
                            />
                            <Typography 
                                variant="h3" 
                                color={validationErrors.length > 0 ? 'error.main' : 'success.main'}
                                sx={{ fontWeight: 700 }}
                            >
                                {validationErrors.length}
                            </Typography>
                            <Typography variant="body1" color="text.secondary">
                                Erreurs bloquantes
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12} md={4}>
                    <Card 
                        sx={{ 
                            backgroundColor: alpha(theme.palette.warning.main, 0.1),
                            border: `1px solid ${alpha(theme.palette.warning.main, 0.3)}`
                        }}
                    >
                        <CardContent sx={{ textAlign: 'center', py: 3 }}>
                            <WarningIcon sx={{ fontSize: 50, color: theme.palette.warning.main }} />
                            <Typography variant="h3" color="warning.main" sx={{ fontWeight: 700 }}>
                                {validationWarnings.length}
                            </Typography>
                            <Typography variant="body1" color="text.secondary">
                                Avertissements
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12} md={4}>
                    <Card 
                        sx={{ 
                            backgroundColor: alpha(theme.palette.success.main, 0.1),
                            border: `1px solid ${alpha(theme.palette.success.main, 0.3)}`
                        }}
                    >
                        <CardContent sx={{ textAlign: 'center', py: 3 }}>
                            <CheckIcon sx={{ fontSize: 50, color: theme.palette.success.main }} />
                            <Typography variant="h3" color="success.main" sx={{ fontWeight: 700 }}>
                                {rowCount.toLocaleString()}
                            </Typography>
                            <Typography variant="body1" color="text.secondary">
                                Lignes à importer
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* Import options */}
            <Paper sx={{ p: 3, mb: 3, backgroundColor: alpha(theme.palette.primary.main, 0.03) }}>
                <Typography variant="h6" sx={{ mb: 2, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 1 }}>
                    <InfoIcon color="primary" />
                    Options d'import
                </Typography>
                
                <Grid container spacing={3}>
                    <Grid item xs={12} md={4}>
                        <FormControl fullWidth size="small">
                            <InputLabel>Mode d'import</InputLabel>
                            <Select
                                value={importOptions.mode}
                                label="Mode d'import"
                                onChange={(e) => handleModeChange(e.target.value as ImportMode)}
                            >
                                <MenuItem value="insert">
                                    <Box>
                                        <Typography variant="body2">INSERT</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Insérer uniquement (erreur si doublon)
                                        </Typography>
                                    </Box>
                                </MenuItem>
                                <MenuItem value="upsert">
                                    <Box>
                                        <Typography variant="body2">UPSERT</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Insérer ou mettre à jour si existe
                                        </Typography>
                                    </Box>
                                </MenuItem>
                                <MenuItem value="update_only">
                                    <Box>
                                        <Typography variant="body2">UPDATE ONLY</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            Mettre à jour uniquement (pas d'insertion)
                                        </Typography>
                                    </Box>
                                </MenuItem>
                            </Select>
                        </FormControl>
                    </Grid>
                    
                    {(importOptions.mode === 'upsert' || importOptions.mode === 'update_only') && (
                        <Grid item xs={12} md={8}>
                            <Typography variant="subtitle2" sx={{ mb: 1 }}>
                                Colonnes de conflit (clé de détection)
                                <Tooltip title="Sélectionnez les colonnes qui identifient de manière unique chaque enregistrement">
                                    <InfoIcon sx={{ fontSize: 16, ml: 1, color: 'text.secondary', verticalAlign: 'middle' }} />
                                </Tooltip>
                            </Typography>
                            <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                {mappedTargetCols.map(colName => {
                                    const colInfo = (targetColumns || []).find(c => c.name === colName);
                                    const isConflict = importOptions.conflictColumns.includes(colName);
                                    const isPK = colInfo?.isPrimaryKey;
                                    
                                    return (
                                        <Chip
                                            key={colName}
                                            label={
                                                <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                    {colName}
                                                    {isPK && (
                                                        <Typography variant="caption" sx={{ ml: 0.5, opacity: 0.7 }}>
                                                            (PK)
                                                        </Typography>
                                                    )}
                                                </Box>
                                            }
                                            onClick={() => handleConflictColumnToggle(colName)}
                                            color={isConflict ? 'primary' : 'default'}
                                            variant={isConflict ? 'filled' : 'outlined'}
                                            sx={{ cursor: 'pointer' }}
                                        />
                                    );
                                })}
                            </Box>
                            {importOptions.conflictColumns.length === 0 && (
                                <Typography variant="caption" color="error" sx={{ mt: 1, display: 'block' }}>
                                    Sélectionnez au moins une colonne de conflit pour le mode {importOptions.mode}
                                </Typography>
                            )}
                        </Grid>
                    )}
                </Grid>
                
                <Box sx={{ mt: 2, pt: 2, borderTop: `1px solid ${alpha(theme.palette.divider, 0.5)}` }}>
                    <FormControlLabel
                        control={
                            <Checkbox
                                checked={importOptions.commitPartial}
                                onChange={(e) => onImportOptionsChange({ commitPartial: e.target.checked })}
                                size="small"
                            />
                        }
                        label={
                            <Typography variant="body2">
                                Commit partiel (sauvegarder les lignes réussies même en cas d'erreurs)
                            </Typography>
                        }
                    />
                </Box>
            </Paper>

            {/* Import info */}
            <Paper sx={{ p: 2, mb: 3, backgroundColor: alpha(theme.palette.info.main, 0.05) }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>Résumé de l'import :</Typography>
                <Box sx={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                    <Typography variant="body2">
                        <strong>Table cible :</strong> {selectedTable}
                    </Typography>
                    <Typography variant="body2">
                        <strong>Colonnes mappées :</strong> {activeMappings.length}
                    </Typography>
                    <Typography variant="body2">
                        <strong>Lignes totales :</strong> {rowCount.toLocaleString()}
                    </Typography>
                    <Typography variant="body2">
                        <strong>Mode :</strong>{' '}
                        <Chip 
                            label={importOptions.mode.toUpperCase()} 
                            size="small" 
                            color={importOptions.mode === 'insert' ? 'default' : 'primary'}
                        />
                    </Typography>
                </Box>
            </Paper>

            {/* Errors section */}
            {validationErrors.length > 0 && (
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" color="error.main" sx={{ mb: 2, fontWeight: 600 }}>
                        Erreurs bloquantes
                    </Typography>
                    {validationErrors.map((err, idx) => (
                        <Alert 
                            key={idx} 
                            severity="error" 
                            sx={{ mb: 1 }}
                            icon={<ErrorIcon />}
                        >
                            <Typography variant="body2">
                                {err.message}
                            </Typography>
                            {err.count && (
                                <Typography variant="caption" color="text.secondary">
                                    Concerne {err.count} ligne(s)
                                </Typography>
                            )}
                        </Alert>
                    ))}
                </Box>
            )}

            {/* Warnings section */}
            {validationWarnings.length > 0 && (
                <Box sx={{ mb: 3 }}>
                    <Typography variant="h6" color="warning.main" sx={{ mb: 2, fontWeight: 600 }}>
                        Avertissements
                    </Typography>
                    {validationWarnings.map((warn, idx) => (
                        <Alert 
                            key={idx} 
                            severity="warning" 
                            sx={{ mb: 1 }}
                            icon={<WarningIcon />}
                        >
                            <Typography variant="body2">
                                {warn.message}
                            </Typography>
                            {warn.count && (
                                <Typography variant="caption" color="text.secondary">
                                    Concerne {warn.count} ligne(s)
                                </Typography>
                            )}
                        </Alert>
                    ))}
                </Box>
            )}

            {/* Data preview */}
            <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                Aperçu des données transformées
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Voici les premières lignes telles qu'elles seront insérées dans la base de données.
            </Typography>
            
            <TableContainer 
                component={Paper} 
                sx={{ 
                    maxHeight: 350, 
                    boxShadow: 2,
                    '& .MuiTableCell-head': {
                        backgroundColor: alpha(theme.palette.primary.main, 0.1),
                        fontWeight: 600
                    }
                }}
            >
                <Table size="small" stickyHeader>
                    <TableHead>
                        <TableRow>
                            <TableCell sx={{ minWidth: 50 }}>#</TableCell>
                            {activeMappings.map(m => (
                                <TableCell key={m.target} sx={{ minWidth: 120 }}>
                                    {m.target}
                                </TableCell>
                            ))}
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {previewData.map((row) => (
                            <TableRow key={row.rowNumber} hover>
                                <TableCell>
                                    <Typography variant="caption" color="text.secondary">
                                        {row.rowNumber}
                                    </Typography>
                                </TableCell>
                                {activeMappings.map(m => (
                                    <TableCell key={m.target}>
                                        <Typography 
                                            variant="caption" 
                                            sx={{ 
                                                fontFamily: 'monospace',
                                                color: row.data[m.target!] === null 
                                                    ? theme.palette.text.disabled 
                                                    : 'inherit'
                                            }}
                                        >
                                            {row.data[m.target!] ?? <em>NULL</em>}
                                        </Typography>
                                    </TableCell>
                                ))}
                            </TableRow>
                        ))}
                        {previewData.length === 0 && (
                            <TableRow>
                                <TableCell colSpan={activeMappings.length + 1} sx={{ textAlign: 'center', py: 4 }}>
                                    <Typography color="text.secondary">
                                        Aucune donnée à prévisualiser
                                    </Typography>
                                </TableCell>
                            </TableRow>
                        )}
                    </TableBody>
                </Table>
            </TableContainer>

            {/* Validation status */}
            <Paper 
                sx={{ 
                    mt: 3, 
                    p: 2, 
                    backgroundColor: alpha(
                        isValid ? theme.palette.success.main : theme.palette.error.main, 
                        0.1
                    ),
                    border: `1px solid ${alpha(
                        isValid ? theme.palette.success.main : theme.palette.error.main, 
                        0.3
                    )}`
                }}
            >
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    {isValid ? (
                        <>
                            <CheckIcon sx={{ fontSize: 30, color: theme.palette.success.main }} />
                            <Box>
                                <Typography variant="subtitle1" color="success.main" fontWeight={600}>
                                    Validation réussie
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Les données sont prêtes à être importées.
                                </Typography>
                            </Box>
                        </>
                    ) : (
                        <>
                            <ErrorIcon sx={{ fontSize: 30, color: theme.palette.error.main }} />
                            <Box>
                                <Typography variant="subtitle1" color="error.main" fontWeight={600}>
                                    Validation échouée
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Corrigez les erreurs avant de procéder à l'import.
                                </Typography>
                            </Box>
                        </>
                    )}
                </Box>
            </Paper>
        </Box>
    );
};

export default StepValidation;
