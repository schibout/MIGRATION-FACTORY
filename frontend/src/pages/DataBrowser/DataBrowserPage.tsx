import {
    Download as DownloadIcon,
    FilterList as FilterIcon,
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
import api from '../../services/api';

interface Schema {
    schema_name: string;
    table_count: number;
}

interface TableInfo {
    table_name: string;
    table_schema: string;
    description: string | null;
    column_count: number;
    row_estimate: number;
}

interface Column {
    name: string;
    data_type: string;
    is_nullable: string;
    isPrimaryKey: boolean;
}

interface PaginationInfo {
    page: number;
    pageSize: number;
    totalRows: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
}

const DataBrowserPage: React.FC = () => {
    const theme = useTheme();
    
    // State
    const [schemas, setSchemas] = useState<Schema[]>([]);
    const [selectedSchema, setSelectedSchema] = useState<string>('clean_data');
    const [tables, setTables] = useState<TableInfo[]>([]);
    const [selectedTable, setSelectedTable] = useState<string | null>(null);
    const [tableSearch, setTableSearch] = useState('');
    const [columns, setColumns] = useState<Column[]>([]);
    const [data, setData] = useState<Record<string, any>[]>([]);
    const [pagination, setPagination] = useState<PaginationInfo | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    
    // Filters & Sort
    const [globalSearch, setGlobalSearch] = useState('');
    const [sortColumn, setSortColumn] = useState<string | null>(null);
    const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
    const [pageSize, setPageSize] = useState(50);
    const [currentPage, setCurrentPage] = useState(1);
    
    // Load schemas on mount
    useEffect(() => {
        loadSchemas();
    }, []);
    
    // Load tables when schema changes
    useEffect(() => {
        if (selectedSchema) {
            loadTables();
            setSelectedTable(null);
            setData([]);
            setColumns([]);
        }
    }, [selectedSchema]);
    
    // Load data when table or filters change
    useEffect(() => {
        if (selectedTable) {
            loadTableData();
        }
    }, [selectedTable, currentPage, pageSize, sortColumn, sortDirection]);
    
    const loadSchemas = async () => {
        try {
            const response = await api.get('/data-browser/schemas');
            setSchemas(response.data.schemas || []);
        } catch (err: any) {
            console.error('Erreur chargement schémas:', err);
        }
    };
    
    const loadTables = async () => {
        try {
            const response = await api.get(`/data-browser/tables?schema=${selectedSchema}&search=${tableSearch}`);
            setTables(response.data.tables || []);
        } catch (err: any) {
            console.error('Erreur chargement tables:', err);
        }
    };
    
    const loadTableColumns = async (tableName: string) => {
        try {
            const response = await api.get(`/data-browser/tables/${tableName}/columns?schema=${selectedSchema}`);
            setColumns(response.data.columns || []);
        } catch (err: any) {
            console.error('Erreur chargement colonnes:', err);
        }
    };
    
    const loadTableData = async () => {
        if (!selectedTable) return;
        
        setLoading(true);
        setError(null);
        
        try {
            const params = new URLSearchParams({
                schema: selectedSchema,
                page: currentPage.toString(),
                pageSize: pageSize.toString(),
                search: globalSearch
            });
            
            if (sortColumn) {
                params.append('sortColumn', sortColumn);
                params.append('sortDirection', sortDirection);
            }
            
            const response = await api.get(`/data-browser/tables/${selectedTable}/data?${params}`);
            setData(response.data.data || []);
            setPagination(response.data.pagination);
        } catch (err: any) {
            setError(err.response?.data?.error || 'Erreur lors du chargement des données');
        } finally {
            setLoading(false);
        }
    };
    
    const handleTableSelect = useCallback(async (tableName: string) => {
        setSelectedTable(tableName);
        setCurrentPage(1);
        setSortColumn(null);
        setGlobalSearch('');
        await loadTableColumns(tableName);
    }, [selectedSchema]);
    
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
                `/data-browser/tables/${selectedTable}/export?schema=${selectedSchema}`,
                { responseType: 'blob' }
            );
            
            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `${selectedSchema}_${selectedTable}.csv`);
            document.body.appendChild(link);
            link.click();
            link.remove();
        } catch (err: any) {
            setError('Erreur lors de l\'export');
        }
    };
    
    const formatCellValue = (value: any): string => {
        if (value === null || value === undefined) return '-';
        if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
        const str = String(value);
        return str.length > 100 ? str.substring(0, 100) + '...' : str;
    };
    
    return (
        <Container maxWidth="xl" sx={{ py: 3 }}>
            {/* Header */}
            <Box sx={{ display: 'flex', alignItems: 'center', mb: 4 }}>
                <StorageIcon sx={{ fontSize: 40, color: theme.palette.primary.main, mr: 2 }} />
                <Box>
                    <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
                        Explorateur de Données
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                        Consultez les données de n'importe quelle table
                    </Typography>
                </Box>
            </Box>
            
            {/* Filters */}
            <Card sx={{ mb: 3 }}>
                <CardContent>
                    <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', alignItems: 'center' }}>
                        {/* Schema selector */}
                        <FormControl size="small" sx={{ minWidth: 150 }}>
                            <InputLabel>Schéma</InputLabel>
                            <Select
                                value={selectedSchema}
                                label="Schéma"
                                onChange={(e) => setSelectedSchema(e.target.value)}
                            >
                                {schemas.map((schema) => (
                                    <MenuItem key={schema.schema_name} value={schema.schema_name}>
                                        {schema.schema_name} ({schema.table_count})
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>
                        
                        {/* Table selector */}
                        <Autocomplete
                            size="small"
                            sx={{ minWidth: 300 }}
                            options={tables}
                            getOptionLabel={(option) => option.table_name}
                            value={tables.find(t => t.table_name === selectedTable) || null}
                            onChange={(_, newValue) => newValue && handleTableSelect(newValue.table_name)}
                            renderInput={(params) => (
                                <TextField {...params} label="Table" placeholder="Rechercher une table..." />
                            )}
                            renderOption={(props, option) => (
                                <li {...props}>
                                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                                        <TableIcon fontSize="small" color="action" />
                                        <Box sx={{ flexGrow: 1 }}>
                                            <Typography variant="body2">{option.table_name}</Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                {option.column_count} colonnes • ~{option.row_estimate?.toLocaleString()} lignes
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
                                    placeholder="Rechercher..."
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
                                
                                <Tooltip title="Rafraîchir">
                                    <IconButton onClick={loadTableData}>
                                        <RefreshIcon />
                                    </IconButton>
                                </Tooltip>
                                
                                <Tooltip title="Exporter en CSV">
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
                                label={`Table: ${selectedSchema}.${selectedTable}`} 
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
                                label={`${columns.length} colonnes`} 
                                size="small" 
                                variant="outlined"
                            />
                        </Box>
                    )}
                </CardContent>
            </Card>
            
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
                        Sélectionnez une table pour afficher ses données
                    </Typography>
                </Paper>
            )}
            
            {/* Data table */}
            {selectedTable && (
                <>
                    <TableContainer component={Paper} sx={{ maxHeight: 'calc(100vh - 400px)' }}>
                        {loading ? (
                            <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
                                <CircularProgress />
                            </Box>
                        ) : (
                            <Table stickyHeader size="small">
                                <TableHead>
                                    <TableRow>
                                        {columns.map((column) => (
                                            <TableCell
                                                key={column.name}
                                                sx={{ 
                                                    fontWeight: 600,
                                                    backgroundColor: theme.palette.primary.main,
                                                    color: theme.palette.primary.contrastText,
                                                    whiteSpace: 'nowrap',
                                                    borderBottom: 'none'
                                                }}
                                            >
                                                <TableSortLabel
                                                    active={sortColumn === column.name}
                                                    direction={sortColumn === column.name ? sortDirection : 'asc'}
                                                    onClick={() => handleSort(column.name)}
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
                                                    {column.name}
                                                    {column.isPrimaryKey && (
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
                                                <Typography 
                                                    variant="caption" 
                                                    display="block" 
                                                    sx={{ 
                                                        color: 'rgba(255,255,255,0.7)',
                                                        fontSize: '0.7rem'
                                                    }}
                                                >
                                                    {column.data_type}
                                                </Typography>
                                            </TableCell>
                                        ))}
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {data.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={columns.length} align="center" sx={{ py: 4 }}>
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
                                                {columns.map((column) => (
                                                    <TableCell 
                                                        key={column.name}
                                                        sx={{ 
                                                            maxWidth: 300,
                                                            overflow: 'hidden',
                                                            textOverflow: 'ellipsis',
                                                            whiteSpace: 'nowrap'
                                                        }}
                                                    >
                                                        <Tooltip title={String(row[column.name] ?? '')} placement="top">
                                                            <span>{formatCellValue(row[column.name])}</span>
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
        </Container>
    );
};

export default DataBrowserPage;
