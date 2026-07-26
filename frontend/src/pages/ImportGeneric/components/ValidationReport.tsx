import {
    ExpandLess as CollapseIcon,
    Error as ErrorIcon,
    ExpandMore as ExpandIcon,
    Info as InfoIcon,
    Warning as WarningIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Chip,
    Collapse,
    IconButton,
    List,
    ListItem,
    ListItemIcon,
    ListItemText,
    Paper,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';
import { ValidationError } from '../types';

interface ValidationReportProps {
    errors: ValidationError[];
    warnings: ValidationError[];
    collapsible?: boolean;
}

/**
 * Component displaying validation errors and warnings in a structured format
 */
const ValidationReport: React.FC<ValidationReportProps> = ({
    errors,
    warnings,
    collapsible = true
}) => {
    const theme = useTheme();
    const [errorsExpanded, setErrorsExpanded] = React.useState(true);
    const [warningsExpanded, setWarningsExpanded] = React.useState(true);

    const hasErrors = errors.length > 0;
    const hasWarnings = warnings.length > 0;

    if (!hasErrors && !hasWarnings) {
        return (
            <Alert severity="success" icon={<InfoIcon />}>
                <Typography variant="body2">
                    Aucune erreur ou avertissement détecté
                </Typography>
            </Alert>
        );
    }

    return (
        <Box>
            {/* Errors section */}
            {hasErrors && (
                <Paper
                    sx={{
                        mb: 2,
                        overflow: 'hidden',
                        border: `1px solid ${alpha(theme.palette.error.main, 0.3)}`
                    }}
                >
                    <Box
                        sx={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            p: 2,
                            backgroundColor: alpha(theme.palette.error.main, 0.1),
                            cursor: collapsible ? 'pointer' : 'default'
                        }}
                        onClick={() => collapsible && setErrorsExpanded(!errorsExpanded)}
                    >
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <ErrorIcon color="error" />
                            <Typography variant="subtitle1" fontWeight={600} color="error.main">
                                Erreurs bloquantes
                            </Typography>
                            <Chip
                                label={errors.length}
                                size="small"
                                color="error"
                                sx={{ fontWeight: 600 }}
                            />
                        </Box>
                        {collapsible && (
                            <IconButton size="small">
                                {errorsExpanded ? <CollapseIcon /> : <ExpandIcon />}
                            </IconButton>
                        )}
                    </Box>

                    <Collapse in={errorsExpanded}>
                        <List dense sx={{ p: 0 }}>
                            {errors.map((error, idx) => (
                                <ListItem
                                    key={idx}
                                    sx={{
                                        borderTop: idx > 0 ? `1px solid ${theme.palette.divider}` : 'none'
                                    }}
                                >
                                    <ListItemIcon sx={{ minWidth: 36 }}>
                                        <ErrorIcon fontSize="small" color="error" />
                                    </ListItemIcon>
                                    <ListItemText
                                        primary={error.message}
                                        secondary={
                                            error.count
                                                ? `${error.count} ligne(s) concernée(s)`
                                                : error.source
                                                    ? `Colonne: ${error.source}`
                                                    : null
                                        }
                                        primaryTypographyProps={{ variant: 'body2' }}
                                        secondaryTypographyProps={{ variant: 'caption' }}
                                    />
                                </ListItem>
                            ))}
                        </List>
                    </Collapse>
                </Paper>
            )}

            {/* Warnings section */}
            {hasWarnings && (
                <Paper
                    sx={{
                        overflow: 'hidden',
                        border: `1px solid ${alpha(theme.palette.warning.main, 0.3)}`
                    }}
                >
                    <Box
                        sx={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            p: 2,
                            backgroundColor: alpha(theme.palette.warning.main, 0.1),
                            cursor: collapsible ? 'pointer' : 'default'
                        }}
                        onClick={() => collapsible && setWarningsExpanded(!warningsExpanded)}
                    >
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <WarningIcon color="warning" />
                            <Typography variant="subtitle1" fontWeight={600} color="warning.main">
                                Avertissements
                            </Typography>
                            <Chip
                                label={warnings.length}
                                size="small"
                                color="warning"
                                sx={{ fontWeight: 600 }}
                            />
                        </Box>
                        {collapsible && (
                            <IconButton size="small">
                                {warningsExpanded ? <CollapseIcon /> : <ExpandIcon />}
                            </IconButton>
                        )}
                    </Box>

                    <Collapse in={warningsExpanded}>
                        <List dense sx={{ p: 0 }}>
                            {warnings.map((warning, idx) => (
                                <ListItem
                                    key={idx}
                                    sx={{
                                        borderTop: idx > 0 ? `1px solid ${theme.palette.divider}` : 'none'
                                    }}
                                >
                                    <ListItemIcon sx={{ minWidth: 36 }}>
                                        <WarningIcon fontSize="small" color="warning" />
                                    </ListItemIcon>
                                    <ListItemText
                                        primary={warning.message}
                                        secondary={
                                            warning.count
                                                ? `${warning.count} ligne(s) concernée(s)`
                                                : warning.target
                                                    ? `Colonne: ${warning.target}`
                                                    : null
                                        }
                                        primaryTypographyProps={{ variant: 'body2' }}
                                        secondaryTypographyProps={{ variant: 'caption' }}
                                    />
                                </ListItem>
                            ))}
                        </List>
                    </Collapse>
                </Paper>
            )}
        </Box>
    );
};

export default ValidationReport;
