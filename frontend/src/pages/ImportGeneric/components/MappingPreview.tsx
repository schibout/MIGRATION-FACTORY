import {
    Box,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React from 'react';
import { ColumnMapping, PreviewRow } from '../types';

interface MappingPreviewProps {
    mappings: ColumnMapping[];
    previewData: PreviewRow[];
    maxRows?: number;
}

/**
 * Component showing a preview of transformed data based on the current mapping
 */
const MappingPreview: React.FC<MappingPreviewProps> = ({
    mappings,
    previewData,
    maxRows = 5
}) => {
    const theme = useTheme();

    const activeMappings = mappings.filter(m => m.target && !m.ignored);
    const displayData = previewData.slice(0, maxRows);

    if (activeMappings.length === 0) {
        return (
            <Paper sx={{ p: 4, textAlign: 'center' }}>
                <Typography color="text.secondary">
                    Aucune colonne mappée pour l'aperçu
                </Typography>
            </Paper>
        );
    }

    return (
        <Box>
            <Typography variant="subtitle2" sx={{ mb: 1 }}>
                Aperçu des données ({displayData.length} premières lignes)
            </Typography>
            
            <TableContainer
                component={Paper}
                sx={{
                    maxHeight: 300,
                    '& .MuiTableCell-head': {
                        backgroundColor: alpha(theme.palette.primary.main, 0.1),
                        fontWeight: 600,
                        fontSize: '0.75rem'
                    },
                    '& .MuiTableCell-body': {
                        fontSize: '0.75rem',
                        fontFamily: 'monospace'
                    }
                }}
            >
                <Table size="small" stickyHeader>
                    <TableHead>
                        <TableRow>
                            <TableCell sx={{ width: 50 }}>#</TableCell>
                            {activeMappings.map(m => (
                                <TableCell key={m.target}>
                                    {m.target}
                                </TableCell>
                            ))}
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {displayData.map((row) => (
                            <TableRow key={row.rowNumber} hover>
                                <TableCell>
                                    <Typography variant="caption" color="text.secondary">
                                        {row.rowNumber}
                                    </Typography>
                                </TableCell>
                                {activeMappings.map(m => (
                                    <TableCell key={m.target}>
                                        {row.data[m.target!] !== null ? (
                                            <span>{row.data[m.target!]}</span>
                                        ) : (
                                            <Typography
                                                component="span"
                                                color="text.disabled"
                                                fontStyle="italic"
                                            >
                                                NULL
                                            </Typography>
                                        )}
                                    </TableCell>
                                ))}
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </TableContainer>

            {previewData.length > maxRows && (
                <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                    ... et {previewData.length - maxRows} autres lignes
                </Typography>
            )}
        </Box>
    );
};

export default MappingPreview;
