import {
    Info as InfoIcon,
    Link as LinkIcon,
    Refresh as RefreshIcon,
    LinkOff as UnlinkIcon
} from '@mui/icons-material';
import {
    Box,
    Button,
    Chip,
    FormControl,
    IconButton,
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
import { ColumnMapping, TargetColumn } from '../types';

interface StepMappingProps {
    mappings: ColumnMapping[];
    targetColumns: TargetColumn[];
    loading: boolean;
    onUpdateMapping: (sourceCol: string, targetCol: string | null) => void;
    onToggleIgnore: (sourceCol: string) => void;
    onRegenerate: () => Promise<void>;
}

const StepMapping: React.FC<StepMappingProps> = ({
    mappings,
    targetColumns,
    loading,
    onUpdateMapping,
    onToggleIgnore,
    onRegenerate
}) => {
    const theme = useTheme();

    const getConfidenceColor = (confidence: number) => {
        if (confidence >= 80) return theme.palette.success.main;
        if (confidence >= 50) return theme.palette.warning.main;
        return theme.palette.error.main;
    };

    const getConfidenceLabel = (confidence: number) => {
        if (confidence >= 80) return 'Excellent';
        if (confidence >= 50) return 'Moyen';
        return 'Faible';
    };

    const mappedCount = mappings.filter(m => m.target && !m.ignored).length;
    const autoMappedCount = mappings.filter(m => m.autoMapped && m.target).length;

    // Get available target columns (not already mapped)
    const getAvailableTargets = (currentSource: string) => {
        const usedTargets = new Set(
            mappings
                .filter(m => m.target && m.source !== currentSource && !m.ignored)
                .map(m => m.target)
        );
        return targetColumns.filter(col => !usedTargets.has(col.name));
    };

    return (
        <Box>
            {/* Header with stats */}
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Box>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>
                        Association des colonnes
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 1, mt: 1 }}>
                        <Chip
                            label={`${mappedCount}/${mappings.length} mappées`}
                            size="small"
                            color="primary"
                        />
                        <Chip
                            label={`${autoMappedCount} auto-détectées`}
                            size="small"
                            variant="outlined"
                            color="success"
                        />
                    </Box>
                </Box>
                <Button
                    variant="outlined"
                    startIcon={<RefreshIcon />}
                    onClick={onRegenerate}
                    disabled={loading}
                >
                    Regénérer
                </Button>
            </Box>

            {/* Legend */}
            <Paper sx={{ p: 2, mb: 3, backgroundColor: alpha(theme.palette.info.main, 0.05) }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>Légende des couleurs de confiance :</Typography>
                <Box sx={{ display: 'flex', gap: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: theme.palette.success.main }} />
                        <Typography variant="caption">&gt;80% - Excellent</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: theme.palette.warning.main }} />
                        <Typography variant="caption">50-80% - Moyen</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: theme.palette.error.main }} />
                        <Typography variant="caption">&lt;50% - Faible</Typography>
                    </Box>
                </Box>
            </Paper>

            {/* Mapping table */}
            <TableContainer component={Paper} sx={{ boxShadow: 2 }}>
                <Table size="small">
                    <TableHead>
                        <TableRow sx={{ backgroundColor: alpha(theme.palette.primary.main, 0.05) }}>
                            <TableCell width={50} align="center">
                                <Tooltip title="Activer/désactiver la colonne">
                                    <InfoIcon fontSize="small" color="action" />
                                </Tooltip>
                            </TableCell>
                            <TableCell sx={{ fontWeight: 600 }}>Colonne source (fichier)</TableCell>
                            <TableCell width={100} align="center" sx={{ fontWeight: 600 }}>
                                Confiance
                            </TableCell>
                            <TableCell sx={{ fontWeight: 600 }}>Colonne cible (base de données)</TableCell>
                            <TableCell width={150} sx={{ fontWeight: 600 }}>Type cible</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {mappings.map((mapping) => {
                            const availableTargets = getAvailableTargets(mapping.source);
                            const targetCol = targetColumns.find(c => c.name === mapping.target);
                            
                            return (
                                <TableRow
                                    key={mapping.source}
                                    sx={{
                                        opacity: mapping.ignored ? 0.5 : 1,
                                        backgroundColor: mapping.ignored 
                                            ? alpha(theme.palette.action.disabled, 0.1) 
                                            : mapping.autoMapped && mapping.target
                                                ? alpha(theme.palette.success.main, 0.03)
                                                : 'inherit',
                                        '&:hover': {
                                            backgroundColor: mapping.ignored
                                                ? alpha(theme.palette.action.disabled, 0.15)
                                                : alpha(theme.palette.action.hover, 0.1)
                                        }
                                    }}
                                >
                                    <TableCell align="center">
                                        <Tooltip title={mapping.ignored ? 'Inclure cette colonne' : 'Ignorer cette colonne'}>
                                            <IconButton
                                                size="small"
                                                onClick={() => onToggleIgnore(mapping.source)}
                                            >
                                                {mapping.ignored ? (
                                                    <UnlinkIcon fontSize="small" color="disabled" />
                                                ) : (
                                                    <LinkIcon fontSize="small" color="primary" />
                                                )}
                                            </IconButton>
                                        </Tooltip>
                                    </TableCell>
                                    <TableCell>
                                        <Box>
                                            <Typography 
                                                variant="body2" 
                                                fontWeight={500}
                                                sx={{ textDecoration: mapping.ignored ? 'line-through' : 'none' }}
                                            >
                                                {mapping.source}
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                {mapping.sourceType}
                                            </Typography>
                                        </Box>
                                    </TableCell>
                                    <TableCell align="center">
                                        {mapping.target && !mapping.ignored && (
                                            <Tooltip title={`${getConfidenceLabel(mapping.confidence)} - ${mapping.autoMapped ? 'Auto-détecté' : 'Manuel'}`}>
                                                <Chip
                                                    label={`${mapping.confidence}%`}
                                                    size="small"
                                                    sx={{
                                                        backgroundColor: alpha(getConfidenceColor(mapping.confidence), 0.15),
                                                        color: getConfidenceColor(mapping.confidence),
                                                        fontWeight: 600,
                                                        minWidth: 60
                                                    }}
                                                />
                                            </Tooltip>
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        <FormControl fullWidth size="small" disabled={mapping.ignored}>
                                            <Select
                                                value={mapping.target || ''}
                                                onChange={(e) => onUpdateMapping(mapping.source, e.target.value || null)}
                                                displayEmpty
                                                sx={{
                                                    '& .MuiSelect-select': {
                                                        py: 1
                                                    }
                                                }}
                                            >
                                                <MenuItem value="">
                                                    <em style={{ color: theme.palette.text.secondary }}>Non mappé</em>
                                                </MenuItem>
                                                {/* Show currently selected even if used elsewhere */}
                                                {mapping.target && !availableTargets.find(t => t.name === mapping.target) && (
                                                    <MenuItem value={mapping.target}>
                                                        {mapping.target}
                                                        {targetColumns.find(c => c.name === mapping.target)?.isRequired && (
                                                            <span style={{ color: theme.palette.error.main, marginLeft: 4 }}>*</span>
                                                        )}
                                                    </MenuItem>
                                                )}
                                                {availableTargets.map((col) => (
                                                    <MenuItem key={col.name} value={col.name}>
                                                        {col.name}
                                                        {col.isRequired && (
                                                            <span style={{ color: theme.palette.error.main, marginLeft: 4 }}>*</span>
                                                        )}
                                                    </MenuItem>
                                                ))}
                                            </Select>
                                        </FormControl>
                                    </TableCell>
                                    <TableCell>
                                        {targetCol && (
                                            <Chip
                                                label={targetCol.data_type}
                                                size="small"
                                                variant="outlined"
                                                sx={{ fontSize: '0.75rem' }}
                                            />
                                        )}
                                    </TableCell>
                                </TableRow>
                            );
                        })}
                    </TableBody>
                </Table>
            </TableContainer>

            {/* Unmapped required columns warning */}
            {(() => {
                const mappedTargets = new Set(mappings.filter(m => m.target && !m.ignored).map(m => m.target));
                const unmappedRequired = targetColumns.filter(c => c.isRequired && !mappedTargets.has(c.name));
                
                if (unmappedRequired.length > 0) {
                    return (
                        <Paper 
                            sx={{ 
                                mt: 2, 
                                p: 2, 
                                backgroundColor: alpha(theme.palette.warning.main, 0.1),
                                border: `1px solid ${alpha(theme.palette.warning.main, 0.3)}`
                            }}
                        >
                            <Typography variant="subtitle2" color="warning.main" sx={{ mb: 1 }}>
                                Colonnes requises non mappées :
                            </Typography>
                            <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                {unmappedRequired.map(col => (
                                    <Chip 
                                        key={col.name}
                                        label={col.name}
                                        size="small"
                                        color="warning"
                                        variant="outlined"
                                    />
                                ))}
                            </Box>
                        </Paper>
                    );
                }
                return null;
            })()}
        </Box>
    );
};

export default StepMapping;
