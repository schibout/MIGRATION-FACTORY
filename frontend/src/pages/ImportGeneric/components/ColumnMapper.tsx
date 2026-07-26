import { ArrowForward as ArrowIcon } from '@mui/icons-material';
import {
    Box,
    Paper,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';
import { ColumnMapping, TargetColumn } from '../types';

interface ColumnMapperProps {
    mapping: ColumnMapping;
    targetColumn?: TargetColumn;
}

/**
 * Visual component showing a single column mapping connection
 */
const ColumnMapper: React.FC<ColumnMapperProps> = ({ mapping, targetColumn }) => {
    const theme = useTheme();

    const getConfidenceColor = (confidence: number) => {
        if (confidence >= 80) return theme.palette.success.main;
        if (confidence >= 50) return theme.palette.warning.main;
        return theme.palette.error.main;
    };

    const color = mapping.target ? getConfidenceColor(mapping.confidence) : theme.palette.grey[400];

    return (
        <Box
            sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 2,
                p: 1,
                opacity: mapping.ignored ? 0.4 : 1,
                transition: 'all 0.2s ease'
            }}
        >
            {/* Source column */}
            <Paper
                sx={{
                    flex: 1,
                    p: 1.5,
                    backgroundColor: alpha(theme.palette.primary.main, 0.05),
                    border: `1px solid ${alpha(theme.palette.primary.main, 0.2)}`
                }}
            >
                <Typography variant="body2" fontWeight={500}>
                    {mapping.source}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                    {mapping.sourceType}
                </Typography>
            </Paper>

            {/* Arrow */}
            <ArrowIcon
                sx={{
                    color,
                    fontSize: 24,
                    opacity: mapping.target ? 1 : 0.3
                }}
            />

            {/* Target column */}
            <Paper
                sx={{
                    flex: 1,
                    p: 1.5,
                    backgroundColor: mapping.target
                        ? alpha(color, 0.05)
                        : alpha(theme.palette.grey[500], 0.05),
                    border: `1px solid ${mapping.target
                        ? alpha(color, 0.3)
                        : alpha(theme.palette.grey[500], 0.2)
                    }`,
                    borderStyle: mapping.target ? 'solid' : 'dashed'
                }}
            >
                {mapping.target ? (
                    <>
                        <Typography variant="body2" fontWeight={500}>
                            {mapping.target}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                            {targetColumn?.data_type || mapping.targetType}
                        </Typography>
                    </>
                ) : (
                    <Typography variant="body2" color="text.secondary" fontStyle="italic">
                        Non mappé
                    </Typography>
                )}
            </Paper>
        </Box>
    );
};

export default ColumnMapper;
