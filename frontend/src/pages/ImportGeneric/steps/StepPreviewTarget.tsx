import {
    CheckCircle as CheckIcon,
    InsertDriveFile as FileIcon,
    Storage as TableIcon
} from '@mui/icons-material';
import {
    Box,
    Card,
    CardContent,
    Chip,
    FormControl,
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
    TextField,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import { FileColumn, SchemaInfo, TableInfo } from '../types';

interface StepPreviewTargetProps {
    file: File | null;
    fileColumns: FileColumn[];
    rowCount: number;
    availableSchemas: SchemaInfo[];
    selectedSchema: string;
    tables: TableInfo[];
    selectedTable: string | null;
    onSchemaChange: (schema: string) => void;
    onTableSelect: (tableName: string) => Promise<void>;
    onLoadTables: (search?: string) => Promise<void>;
    onLoadSchemas: () => Promise<void>;
}

const StepPreviewTarget: React.FC<StepPreviewTargetProps> = ({
    file,
    fileColumns,
    rowCount,
    availableSchemas,
    selectedSchema,
    tables,
    selectedTable,
    onSchemaChange,
    onTableSelect,
    onLoadTables,
    onLoadSchemas
}) => {
    const theme = useTheme();
    const [tableSearch, setTableSearch] = useState('');

    // Load schemas on mount
    useEffect(() => {
        if (availableSchemas.length === 0) {
            onLoadSchemas();
        }
    }, [availableSchemas.length, onLoadSchemas]);

    // Load tables when schema changes or search changes
    useEffect(() => {
        onLoadTables(tableSearch);
    }, [tableSearch, selectedSchema, onLoadTables]);

    const formatFileSize = (bytes: number): string => {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
    };

    const getTypeColor = (type: string): string => {
        switch (type.toLowerCase()) {
            case 'integer':
            case 'numeric':
                return theme.palette.info.main;
            case 'date':
                return theme.palette.warning.main;
            case 'boolean':
                return theme.palette.success.main;
            default:
                return theme.palette.grey[600];
        }
    };

    return (
        <Grid container spacing={3}>
            {/* File info card */}
            <Grid item xs={12}>
                <Card sx={{ mb: 2, backgroundColor: alpha(theme.palette.success.main, 0.05) }}>
                    <CardContent>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                            <FileIcon sx={{ fontSize: 40, color: theme.palette.primary.main }} />
                            <Box sx={{ flex: 1 }}>
                                <Typography variant="h6">{file?.name}</Typography>
                                <Typography variant="body2" color="text.secondary">
                                    {fileColumns.length} colonnes • {rowCount.toLocaleString()} lignes • {formatFileSize(file?.size || 0)}
                                </Typography>
                            </Box>
                            <Chip 
                                label="Fichier analysé" 
                                color="success" 
                                icon={<CheckIcon />} 
                                sx={{ fontWeight: 500 }}
                            />
                        </Box>
                    </CardContent>
                </Card>
            </Grid>

            {/* Detected columns */}
            <Grid item xs={12} md={6}>
                <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                    Colonnes détectées
                </Typography>
                <TableContainer 
                    component={Paper} 
                    sx={{ 
                        maxHeight: 400,
                        boxShadow: 2
                    }}
                >
                    <Table size="small" stickyHeader>
                        <TableHead>
                            <TableRow>
                                <TableCell sx={{ fontWeight: 600 }}>Colonne</TableCell>
                                <TableCell sx={{ fontWeight: 600 }}>Type détecté</TableCell>
                                <TableCell sx={{ fontWeight: 600 }}>Exemple</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {fileColumns.map((col) => (
                                <TableRow key={col.name} hover>
                                    <TableCell>
                                        <Typography variant="body2" fontWeight={500}>
                                            {col.name}
                                        </Typography>
                                        {col.nullCount > 0 && (
                                            <Typography variant="caption" color="text.secondary">
                                                {col.nullCount} valeurs vides
                                            </Typography>
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        <Chip 
                                            label={col.detectedType} 
                                            size="small" 
                                            variant="outlined"
                                            sx={{ 
                                                borderColor: getTypeColor(col.detectedType),
                                                color: getTypeColor(col.detectedType)
                                            }}
                                        />
                                    </TableCell>
                                    <TableCell>
                                        <Typography 
                                            variant="caption" 
                                            color="text.secondary" 
                                            sx={{ 
                                                fontFamily: 'monospace',
                                                backgroundColor: alpha(theme.palette.grey[500], 0.1),
                                                px: 1,
                                                py: 0.5,
                                                borderRadius: 1
                                            }}
                                        >
                                            {col.sampleValues[0] || '-'}
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ))}
                        </TableBody>
                    </Table>
                </TableContainer>
            </Grid>

            {/* Table selection */}
            <Grid item xs={12} md={6}>
                <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                    Table de destination
                </Typography>

                {/* Schema selector */}
                <FormControl fullWidth size="small" sx={{ mb: 2 }}>
                    <InputLabel>Schéma</InputLabel>
                    <Select
                        value={selectedSchema}
                        label="Schéma"
                        onChange={(e) => onSchemaChange(e.target.value)}
                    >
                        {availableSchemas.map((schema) => (
                            <MenuItem key={schema.schema_name} value={schema.schema_name}>
                                <Box sx={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
                                    <span>{schema.schema_name}</span>
                                    <Chip 
                                        label={`${schema.table_count} tables`} 
                                        size="small" 
                                        variant="outlined"
                                        sx={{ ml: 2, height: 20 }}
                                    />
                                </Box>
                            </MenuItem>
                        ))}
                    </Select>
                </FormControl>
                
                <TextField
                    fullWidth
                    size="small"
                    placeholder="Rechercher une table..."
                    value={tableSearch}
                    onChange={(e) => setTableSearch(e.target.value)}
                    sx={{ mb: 2 }}
                />

                <TableContainer 
                    component={Paper} 
                    sx={{ 
                        maxHeight: 350,
                        boxShadow: 2
                    }}
                >
                    <Table size="small" stickyHeader>
                        <TableHead>
                            <TableRow>
                                <TableCell sx={{ fontWeight: 600 }}>Table</TableCell>
                                <TableCell align="right" sx={{ fontWeight: 600 }}>Colonnes</TableCell>
                                <TableCell align="right" sx={{ fontWeight: 600 }}>Lignes</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {tables.map((table) => (
                                <TableRow
                                    key={table.table_name}
                                    hover
                                    selected={selectedTable === table.table_name}
                                    onClick={() => onTableSelect(table.table_name)}
                                    sx={{ 
                                        cursor: 'pointer',
                                        '&.Mui-selected': {
                                            backgroundColor: alpha(theme.palette.primary.main, 0.15),
                                            '&:hover': {
                                                backgroundColor: alpha(theme.palette.primary.main, 0.2),
                                            }
                                        }
                                    }}
                                >
                                    <TableCell>
                                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                            <TableIcon 
                                                fontSize="small" 
                                                color={selectedTable === table.table_name ? 'primary' : 'action'} 
                                            />
                                            <Typography variant="body2" fontWeight={selectedTable === table.table_name ? 600 : 400}>
                                                {table.table_name}
                                            </Typography>
                                        </Box>
                                    </TableCell>
                                    <TableCell align="right">
                                        <Chip 
                                            label={table.column_count} 
                                            size="small" 
                                            variant="outlined"
                                            sx={{ minWidth: 40 }}
                                        />
                                    </TableCell>
                                    <TableCell align="right">
                                        <Typography variant="body2" color="text.secondary">
                                            {table.row_count?.toLocaleString() || '0'}
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ))}
                            {tables.length === 0 && (
                                <TableRow>
                                    <TableCell colSpan={3} sx={{ textAlign: 'center', py: 4 }}>
                                        <Typography color="text.secondary">
                                            Aucune table trouvée
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>

                {selectedTable && (
                    <Box 
                        sx={{ 
                            mt: 2, 
                            p: 2, 
                            backgroundColor: alpha(theme.palette.success.main, 0.1), 
                            borderRadius: 1,
                            border: `1px solid ${alpha(theme.palette.success.main, 0.3)}`
                        }}
                    >
                        <Typography variant="body2" color="success.main" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <CheckIcon sx={{ fontSize: 18 }} />
                            Table sélectionnée: <strong>{selectedTable}</strong>
                        </Typography>
                    </Box>
                )}
            </Grid>
        </Grid>
    );
};

export default StepPreviewTarget;
