import {
    Download as DownloadIcon,
    FilterList as FilterIcon,
    Info as InfoIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Storage as StorageIcon,
    TableChart as TableIcon
} from '@mui/icons-material';
import {
    Alert,
    Autocomplete,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Container,
    Dialog,
    DialogContent,
    DialogTitle,
    FormControl,
    IconButton,
    InputAdornment,
    InputLabel,
    MenuItem,
    Pagination,
    Paper,
    Select,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TableSortLabel,
    TextField,
    Tooltip,
    Typography,
    useTheme
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import api from '../../services/api';

interface SapTable {
    table_name: string;
    table_class: string;
    description: string | null;
    client_dependent: boolean;
    field_count: number;
}

interface SapField {
    field_name: string;
    position: number;
    key_flag: boolean;
    mandatory: boolean;
    data_type: string;
    check_table: string;
    length: number;
    decimals: number;
    abap_type: string;
    field_text: string;
    header_text: string;
    long_description: string;
}

interface PaginationInfo {
    page: number;
    pageSize: number;
    totalRows: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
}

const SapDataExplorerPage: React.FC = () => {
    const theme = useTheme();
    const [searchParams, setSearchParams] = useSearchParams();

    // State
    const [tables, setTables] = useState<SapTable[]>([]);
    const [selectedTable, setSelectedTable] = useState<string | null>(null);
    const [fields, setFields] = useState<SapField[]>([]);
    const [data, setData] = useState<Record<string, any>[]>([]);
    const [pagination, setPagination] = useState<PaginationInfo | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [message, setMessage] = useState<string | null>(null);

    // Filters & Sort
    const [globalSearch, setGlobalSearch] = useState('');
    const [sortColumn, setSortColumn] = useState<string | null>(null);
    const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
    const [pageSize, setPageSize] = useState(50);
    const [currentPage, setCurrentPage] = useState(1);

    // Field info dialog
    const [fieldInfoOpen, setFieldInfoOpen] = useState(false);

    // Load tables on mount
    useEffect(() => {
        loadTables();
    }, []);

    // Load data when table or filters change
    useEffect(() => {
        if (selectedTable) {
            loadTableData();
        }
    }, [selectedTable, currentPage, pageSize, sortColumn, sortDirection]);

    const loadTables = async (search = '') => {
        try {
            const response = await api.get(`/sap-data-explorer/tables?search=${encodeURIComponent(search)}`);
            const list = response.data?.tables ?? [];
            setTables(list);
            if (list.length === 0) {
                setMessage('Aucune table dans les métadonnées (public.sap_table_properties). Alimentez les métadonnées SAP pour utiliser l’explorateur.');
            } else {
                setMessage(null);
            }
        } catch (err: any) {
            console.error('Erreur chargement tables SAP:', err);
            setError(err.response?.data?.error || 'Impossible de charger la liste des tables SAP');
        }
    };

    const loadTableData = async () => {
        if (!selectedTable) return;

        setLoading(true);
        setError(null);
        setMessage(null);

        try {
            const params = new URLSearchParams({
                page: currentPage.toString(),
                pageSize: pageSize.toString(),
                search: globalSearch
            });

            if (sortColumn) {
                params.append('sortColumn', sortColumn);
                params.append('sortDirection', sortDirection);
            }

            const response = await api.get(`/sap-data-explorer/tables/${selectedTable}/data?${params}`);
            setData(response.data.data || []);
            setFields(response.data.fields || []);
            setPagination(response.data.pagination);
            if (response.data.message) {
                setMessage(response.data.message);
            }
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors du chargement des données');
        } finally {
            setLoading(false);
        }
    };

    const handleTableSelect = useCallback(
        (tableName: string) => {
            setSelectedTable(tableName);
            setCurrentPage(1);
            setSortColumn(null);
            setGlobalSearch('');
            setMessage(null);
            setSearchParams(
                (prev) => {
                    const next = new URLSearchParams(prev);
                    next.set('table', tableName);
                    return next;
                },
                { replace: true }
            );
        },
        [setSearchParams]
    );

    // Deep link: /sap-data/explorer?table=ekko
    useEffect(() => {
        const tableParam = (searchParams.get('table') || '').trim();
        if (!tableParam || tables.length === 0) return;
        const match = tables.find(
            (t) => t.table_name.toLowerCase() === tableParam.toLowerCase()
        );
        if (match && selectedTable !== match.table_name) {
            handleTableSelect(match.table_name);
        }
    }, [searchParams, tables, selectedTable, handleTableSelect]);

    const handleSort = (column: string) => {
        if (sortColumn === column) {
            setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
        } else {
            setSortColumn(column);
            setSortDirection('asc');
        }
        setCurrentPage(1);
    };

    const handleSearch = () => {
        setCurrentPage(1);
        loadTableData();
    };

    const handleExport = async () => {
        if (!selectedTable) return;

        try {
            const response = await api.get(
                `/sap-data-explorer/tables/${selectedTable}/export`,
                { responseType: 'blob' }
            );

            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `SAP_${selectedTable}.csv`);
            document.body.appendChild(link);
            link.click();
            link.remove();
        } catch (err: any) {
            setError("Erreur lors de l'export");
        }
    };

    const formatCellValue = (value: any): string => {
        if (value === null || value === undefined) return '-';
        if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
        const str = String(value);
        return str.length > 100 ? str.substring(0, 100) + '...' : str;
    };

    // Build a mapping from field_name (uppercase) to header_text
    const getHeaderText = (columnName: string): string => {
        const col = columnName.trim().toUpperCase();
        const field = fields.find((f) => (f.field_name || '').trim().toUpperCase() === col);
        if (field) {
            return field.header_text || field.field_text || columnName;
        }
        return columnName;
    };

    const getFieldInfo = (columnName: string): SapField | undefined => {
        const col = columnName.trim().toUpperCase();
        return fields.find((f) => (f.field_name || '').trim().toUpperCase() === col);
    };

    // Colonnes : ordre SAP si les clés des lignes correspondent aux métadonnées ; sinon toutes les clés des données
    const dataColumns = (() => {
        if (data.length === 0) return [];
        const first = data[0];
        if (!first || typeof first !== 'object' || Array.isArray(first)) return [];
        const dataKeys = Object.keys(first);
        if (fields.length === 0) return dataKeys;
        const fromMeta = fields
            .map((f) => {
                const fn = (f.field_name || '').trim().toUpperCase();
                if (!fn) return undefined;
                return dataKeys.find((k) => k.toUpperCase() === fn);
            })
            .filter((col): col is string => col !== undefined);
        return fromMeta.length > 0 ? fromMeta : dataKeys;
    })();

    return (
        <Container maxWidth="xl" sx={{ py: 3 }}>
            {/* Header */}
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
                <StorageIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        SAP Data Explorer
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Explorez les données des tables SAP avec les libellés métier
                    </Typography>
                </Box>
            </Box>

            {/* Filters */}
            <Card sx={{ mb: 3 }}>
                <CardContent>
                    <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
                        {/* Table selector */}
                        <Autocomplete
                            size="small"
                            sx={{ minWidth: 400 }}
                            options={tables}
                            getOptionLabel={(option) => `${option.table_name}${option.description ? ` - ${option.description}` : ''}`}
                            filterOptions={(options, { inputValue }) => {
                                const filter = inputValue.toUpperCase();
                                return options.filter(o =>
                                    o.table_name.toUpperCase().includes(filter) ||
                                    (o.description || '').toUpperCase().includes(filter)
                                );
                            }}
                            value={tables.find(t => t.table_name === selectedTable) || null}
                            onChange={(_, newValue) => newValue && handleTableSelect(newValue.table_name)}
                            renderInput={(params) => (
                                <TextField {...params} label="Table SAP" placeholder="Rechercher une table..." />
                            )}
                            renderOption={(props, option) => (
                                <li {...props}>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                                        <TableIcon fontSize="small" color="action" />
                                        <Box sx={{ flexGrow: 1 }}>
                                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                                {option.table_name}
                                                <Typography component="span" variant="body2" color="text.secondary" sx={{ ml: 1, fontWeight: 400 }}>
                                                    {option.description || ''}
                                                </Typography>
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                {option.table_class} | {option.field_count} champs
                                            </Typography>
                                        </Box>
                                    </Box>
                                </li>
                            )}
                        />

                        {selectedTable && (
                            <>
                                {/* Global search */}
                                <TextField
                                    size="small"
                                    placeholder="Rechercher dans les données..."
                                    value={globalSearch}
                                    onChange={(e) => setGlobalSearch(e.target.value)}
                                    onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                                    sx={{ minWidth: 200 }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <SearchIcon fontSize="small" />
                                            </InputAdornment>
                                        )
                                    }}
                                />

                                <Button
                                    variant="outlined"
                                    startIcon={<FilterIcon />}
                                    onClick={handleSearch}
                                >
                                    Filtrer
                                </Button>

                                <Tooltip title="Détails des champs">
                                    <IconButton onClick={() => setFieldInfoOpen(true)} color="info">
                                        <InfoIcon />
                                    </IconButton>
                                </Tooltip>

                                <Tooltip title="Rafraîchir">
                                    <IconButton onClick={loadTableData}>
                                        <RefreshIcon />
                                    </IconButton>
                                </Tooltip>

                                <Tooltip title="Exporter en CSV (avec libellés)">
                                    <IconButton onClick={handleExport} color="primary">
                                        <DownloadIcon />
                                    </IconButton>
                                </Tooltip>
                            </>
                        )}
                    </Box>

                    {/* Table info */}
                    {selectedTable && pagination && (
                        <Box sx={{ mt: 2, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                            <Chip
                                label={`Table: ${selectedTable}`}
                                size="small"
                                color="primary"
                                variant="outlined"
                            />
                            <Chip
                                label={`${pagination.totalRows.toLocaleString()} lignes`}
                                size="small"
                                variant="outlined"
                            />
                            <Chip
                                label={`${fields.length} champs SAP`}
                                size="small"
                                variant="outlined"
                            />
                        </Box>
                    )}
                </CardContent>
            </Card>

            {/* Message info */}
            {message && (
                <Alert severity="info" sx={{ mb: 3 }}>
                    {message}
                </Alert>
            )}

            {/* Error */}
            {error && (
                <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
                    {error}
                </Alert>
            )}

            {/* No table selected */}
            {!selectedTable && (
                <Paper sx={{ p: 6, textAlign: 'center' }}>
                    <TableIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
                    <Typography variant="h6" color="text.secondary">
                        Sélectionnez une table SAP pour explorer ses données
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                        Les en-têtes de colonnes affichent le libellé métier SAP (header_text)
                    </Typography>
                </Paper>
            )}

            {/* Data table */}
            {selectedTable && (
                <>
                    <TableContainer component={Paper} sx={{ maxHeight: 'calc(100vh - 400px)', width: '100%', overflow: 'auto' }}>
                        {loading ? (
                            <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                                <CircularProgress />
                            </Box>
                        ) : (
                            <Table stickyHeader size="small" sx={{ minWidth: 720, tableLayout: 'auto' }}>
                                <TableHead>
                                    <TableRow>
                                        {dataColumns.map((colName) => {
                                            const fieldInfo = getFieldInfo(colName);
                                            return (
                                                <TableCell
                                                    key={colName}
                                                    sx={{
                                                        fontWeight: 600,
                                                        backgroundColor: theme.palette.primary.main,
                                                        color: theme.palette.primary.contrastText,
                                                        whiteSpace: 'nowrap',
                                                        borderBottom: 'none'
                                                    }}
                                                >
                                                    <TableSortLabel
                                                        active={sortColumn === colName}
                                                        direction={sortColumn === colName ? sortDirection : 'asc'}
                                                        onClick={() => handleSort(colName)}
                                                        sx={{
                                                            color: `${theme.palette.primary.contrastText} !important`,
                                                            '&.Mui-active': {
                                                                color: `${theme.palette.primary.contrastText} !important`,
                                                            },
                                                            '& .MuiTableSortLabel-icon': {
                                                                color: `${theme.palette.primary.contrastText} !important`,
                                                            },
                                                        }}
                                                    >
                                                        <Tooltip title={`${colName}${fieldInfo?.long_description ? ` - ${fieldInfo.long_description}` : ''}`}>
                                                            <span>{getHeaderText(colName)}</span>
                                                        </Tooltip>
                                                        {fieldInfo?.key_flag && (
                                                            <Chip
                                                                label="PK"
                                                                size="small"
                                                                sx={{
                                                                    ml: 0.5,
                                                                    height: 16,
                                                                    fontSize: '0.65rem',
                                                                    backgroundColor: theme.palette.warning.main,
                                                                    color: theme.palette.warning.contrastText
                                                                }}
                                                            />
                                                        )}
                                                    </TableSortLabel>
                                                    {fieldInfo?.field_text && fieldInfo.field_text !== fieldInfo.header_text && (
                                                        <Typography
                                                            variant="caption"
                                                            display="block"
                                                            sx={{
                                                                color: 'rgba(255,255,255,0.85)',
                                                                fontSize: '0.65rem',
                                                                fontStyle: 'italic'
                                                            }}
                                                        >
                                                            {fieldInfo.field_text}
                                                        </Typography>
                                                    )}
                                                    <Typography
                                                        variant="caption"
                                                        display="block"
                                                        sx={{
                                                            color: 'rgba(255,255,255,0.5)',
                                                            fontSize: '0.6rem'
                                                        }}
                                                    >
                                                        {fieldInfo ? `${colName} · ${fieldInfo.abap_type}(${fieldInfo.length})` : colName}
                                                    </Typography>
                                                </TableCell>
                                            );
                                        })}
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {data.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={dataColumns.length || 1} align="center" sx={{ py: 4 }}>
                                                <Typography color="text.secondary">Aucune donnée</Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        data.map((row, rowIndex) => (
                                            <TableRow
                                                key={rowIndex}
                                                hover
                                                sx={{ '&:nth-of-type(odd)': { backgroundColor: theme.palette.action.hover } }}
                                            >
                                                {dataColumns.map((colName) => (
                                                    <TableCell
                                                        key={colName}
                                                        sx={{
                                                            maxWidth: 300,
                                                            overflow: 'hidden',
                                                            textOverflow: 'ellipsis',
                                                            whiteSpace: 'nowrap'
                                                        }}
                                                    >
                                                        <Tooltip title={String(row[colName] ?? '')} placement="top">
                                                            <span>{formatCellValue(row[colName])}</span>
                                                        </Tooltip>
                                                    </TableCell>
                                                ))}
                                            </TableRow>
                                        ))
                                    )}
                                </TableBody>
                            </Table>
                        )}
                    </TableContainer>

                    {/* Pagination */}
                    {pagination && pagination.totalPages > 1 && (
                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 2 }}>
                            <FormControl size="small" sx={{ minWidth: 120 }}>
                                <InputLabel>Lignes</InputLabel>
                                <Select
                                    value={pageSize}
                                    label="Lignes"
                                    onChange={(e) => {
                                        setPageSize(Number(e.target.value));
                                        setCurrentPage(1);
                                    }}
                                >
                                    <MenuItem value={25}>25</MenuItem>
                                    <MenuItem value={50}>50</MenuItem>
                                    <MenuItem value={100}>100</MenuItem>
                                    <MenuItem value={200}>200</MenuItem>
                                </Select>
                            </FormControl>

                            <Pagination
                                count={pagination.totalPages}
                                page={currentPage}
                                onChange={(_, page) => setCurrentPage(page)}
                                color="primary"
                                showFirstButton
                                showLastButton
                            />

                            <Typography variant="body2" color="text.secondary">
                                Page {currentPage} sur {pagination.totalPages}
                            </Typography>
                        </Box>
                    )}
                </>
            )}

            {/* Field Info Dialog */}
            <Dialog open={fieldInfoOpen} onClose={() => setFieldInfoOpen(false)} maxWidth="lg" fullWidth>
                <DialogTitle>
                    Détails des champs - {selectedTable}
                </DialogTitle>
                <DialogContent>
                    <TableContainer sx={{ maxHeight: 500 }}>
                        <Table size="small" stickyHeader>
                            <TableHead>
                                <TableRow>
                                    <TableCell sx={{ fontWeight: 600 }}>Pos</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Champ</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Header Text</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Description</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Type</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>ABAP</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Long.</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Clé</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {fields.map((field) => (
                                    <TableRow key={field.field_name} hover>
                                        <TableCell>{field.position}</TableCell>
                                        <TableCell sx={{ fontWeight: 500 }}>{field.field_name}</TableCell>
                                        <TableCell>{field.header_text}</TableCell>
                                        <TableCell>{field.long_description || field.field_text}</TableCell>
                                        <TableCell>
                                            <Chip label={field.data_type} size="small" variant="outlined" />
                                        </TableCell>
                                        <TableCell>{field.abap_type}</TableCell>
                                        <TableCell>{field.length}{field.decimals ? `,${field.decimals}` : ''}</TableCell>
                                        <TableCell>
                                            {field.key_flag && <Chip label="PK" size="small" color="warning" />}
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </TableContainer>
                </DialogContent>
            </Dialog>
        </Container>
    );
};

export default SapDataExplorerPage;
