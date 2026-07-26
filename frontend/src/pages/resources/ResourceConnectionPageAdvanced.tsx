import {
    Close as CloseIcon,
    FileDownload as DownloadIcon,
    ExpandLess as ExpandLessIcon,
    ExpandMore as ExpandMoreIcon,
    Description as FileIcon,
    Search as SearchIcon,
    TableChart as TableIcon,
    ViewColumn as ViewColumnIcon,
    FilterAlt as FilterIcon,
    RestartAlt as ResetIcon,
    Link as LinkIcon,
} from '@mui/icons-material';
import {
    Box,
    Button,
    Card,
    Checkbox,
    Chip,
    CircularProgress,
    Collapse,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Divider,
    FormControl,
    FormControlLabel,
    Grid,
    IconButton,
    InputAdornment,
    InputLabel,
    ListItemIcon,
    ListItemText,
    Menu,
    MenuItem,
    Paper,
    Select,
    SelectChangeEvent,
    TextField,
    Typography,
    alpha,
    useTheme
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import ResourceDataTable from '../../components/resources/ResourceDataTable';
import resourcesService, { ExportOptions, ResourceTableData } from '../../services/resourcesService';

const ResourceConnectionPageAdvanced = () => {
    const theme = useTheme();
    
    const endpoint = 'connections';
    const pageTitle = 'Resource Connections';
    const pageDescription = 'Gestion des connexions entre ressources';
    const tableName = 'clean_data.resource_connection';
    
    const [tableData, setTableData] = useState<ResourceTableData | null>(null);
    const [loading, setLoading] = useState<boolean>(false);
    const [page, setPage] = useState<number>(0);
    const [rowsPerPage, setRowsPerPage] = useState<number>(25);
    const [sortField, setSortField] = useState<string>('');
    const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
    const [searchTerm, setSearchTerm] = useState<string>('');
    const [advancedFilterOpen, setAdvancedFilterOpen] = useState<boolean>(false);
    const [filters, setFilters] = useState<Record<string, {value: string, operator: string}>>({});
    const [availableColumns, setAvailableColumns] = useState<string[]>([]);
    const [selectedFilterColumn, setSelectedFilterColumn] = useState<string>('');
    const [filterValue, setFilterValue] = useState<string>('');
    const [selectedOperator, setSelectedOperator] = useState<string>('contains');
    const [exportMenuAnchor, setExportMenuAnchor] = useState<null | HTMLElement>(null);
    const [exporting, setExporting] = useState<boolean>(false);
    const [columnMenuAnchor, setColumnMenuAnchor] = useState<null | HTMLElement>(null);
    const [visibleColumns, setVisibleColumns] = useState<string[]>([]);
    const [viewDialogOpen, setViewDialogOpen] = useState<boolean>(false);
    const [editDialogOpen, setEditDialogOpen] = useState<boolean>(false);
    const [deleteDialogOpen, setDeleteDialogOpen] = useState<boolean>(false);
    const [currentRow, setCurrentRow] = useState<any>(null);
    const [editedValues, setEditedValues] = useState<Record<string, any>>({});

    const filterOperators = [
        { value: 'contains', label: 'Contient' },
        { value: 'equals', label: '=' },
        { value: 'not_equals', label: '≠' },
        { value: 'greater_than', label: '>' },
        { value: 'greater_equal', label: '>=' },
        { value: 'less_than', label: '<' },
        { value: 'less_equal', label: '<=' },
        { value: 'starts_with', label: 'Commence par' },
        { value: 'ends_with', label: 'Finit par' },
        { value: 'is_null', label: 'Est vide' },
        { value: 'is_not_null', label: 'N\'est pas vide' }
    ];

    useEffect(() => {
        if (tableData && tableData.columns) {
            const columns = tableData.columns.map(col => col.name);
            setAvailableColumns(columns);
            if (visibleColumns.length === 0) setVisibleColumns(columns);
            if (columns.length > 0 && !selectedFilterColumn) setSelectedFilterColumn(columns[0]);
        }
    }, [tableData]);
    
    useEffect(() => {
        const loadTableData = async () => {
            setLoading(true);
            try {
                const data = await resourcesService.getTableData(endpoint, page, rowsPerPage, sortField, sortDirection, searchTerm, filters);
                setTableData(data);
            } catch (error) {
                console.error('Erreur:', error);
            } finally {
                setLoading(false);
            }
        };
        loadTableData();
    }, [page, rowsPerPage, sortField, sortDirection, searchTerm, filters]);
    
    const handlePageChange = (newPage: number) => setPage(newPage);
    const handleRowsPerPageChange = (newRowsPerPage: number) => { setRowsPerPage(newRowsPerPage); setPage(0); };
    const handleSortChange = (field: string, direction: 'asc' | 'desc') => { setSortField(field); setSortDirection(direction); };
    const handleSearchChange = (event: React.ChangeEvent<HTMLInputElement>) => { setSearchTerm(event.target.value); setPage(0); };
    const toggleAdvancedFilter = () => setAdvancedFilterOpen(!advancedFilterOpen);
    const handleFilterColumnChange = (event: SelectChangeEvent) => setSelectedFilterColumn(event.target.value);
    const handleFilterValueChange = (event: React.ChangeEvent<HTMLInputElement>) => setFilterValue(event.target.value);
    const handleOperatorChange = (event: SelectChangeEvent) => setSelectedOperator(event.target.value);
    
    const addFilter = () => {
        if (selectedFilterColumn && (filterValue || ['is_null', 'is_not_null'].includes(selectedOperator))) {
            setFilters(prev => ({ ...prev, [selectedFilterColumn]: { value: filterValue, operator: selectedOperator } }));
            setFilterValue('');
            setPage(0);
        }
    };
    
    const removeFilter = (columnName: string) => {
        const newFilters = { ...filters };
        delete newFilters[columnName];
        setFilters(newFilters);
        setPage(0);
    };
    
    const clearAllFilters = () => { setFilters({}); setSearchTerm(''); setPage(0); };
    const handleExportClick = (event: React.MouseEvent<HTMLButtonElement>) => setExportMenuAnchor(event.currentTarget);
    const handleExportClose = () => setExportMenuAnchor(null);
    
    const handleExport = async (format: 'csv' | 'excel') => {
        if (!tableData) return;
        try {
            setExporting(true);
            const options: ExportOptions = {
                format,
                filename: `${endpoint}_${new Date().toISOString().split('T')[0]}.${format === 'csv' ? 'csv' : 'xlsx'}`,
                includeHeaders: true,
                searchTerm,
                filters
            };
            const blob = await resourcesService.exportTableData(endpoint, visibleColumns, options);
            resourcesService.downloadExport(blob, options.filename || 'export.csv');
        } catch (error) {
            alert('Erreur lors de l\'export.');
        } finally {
            setExporting(false);
            handleExportClose();
        }
    };
    
    const handleColumnMenuClick = (event: React.MouseEvent<HTMLButtonElement>) => setColumnMenuAnchor(event.currentTarget);
    const handleColumnMenuClose = () => setColumnMenuAnchor(null);
    const handleToggleColumn = (columnName: string) => {
        setVisibleColumns(prev => prev.includes(columnName) ? prev.filter(col => col !== columnName) : [...prev, columnName]);
    };
    const handleSelectAllColumns = () => setVisibleColumns(availableColumns);
    const handleDeselectAllColumns = () => setVisibleColumns([]);
    
    const handleViewRow = (row: any) => { setCurrentRow(row); setViewDialogOpen(true); };
    const handleEditRow = (row: any) => { setCurrentRow(row); setEditedValues(row); setEditDialogOpen(true); };
    const handleDeleteRow = (row: any) => { setCurrentRow(row); setDeleteDialogOpen(true); };
    const handleViewDialogClose = () => setViewDialogOpen(false);
    const handleEditDialogClose = () => setEditDialogOpen(false);
    const handleDeleteDialogClose = () => setDeleteDialogOpen(false);
    const handleInputChange = (fieldName: string, value: any) => setEditedValues(prev => ({ ...prev, [fieldName]: value }));
    
    const handleSaveEdit = async () => {
        try {
            if (!currentRow || !tableData) return;
            const recordId = currentRow.resource_connection_seq || currentRow.id || Object.values(currentRow)[0];
            await resourcesService.updateRecord(endpoint, recordId, editedValues);
            const data = await resourcesService.getTableData(endpoint, page, rowsPerPage, sortField, sortDirection, searchTerm, filters);
            setTableData(data);
            setEditDialogOpen(false);
            alert('Enregistrement mis à jour');
        } catch (error) {
            alert('Erreur lors de la mise à jour.');
        }
    };
    
    const handleConfirmDelete = async () => {
        try {
            if (!currentRow) return;
            const recordId = currentRow.resource_connection_seq || currentRow.id || Object.values(currentRow)[0];
            await resourcesService.deleteRecord(endpoint, recordId);
            const data = await resourcesService.getTableData(endpoint, page, rowsPerPage, sortField, sortDirection, searchTerm, filters);
            setTableData(data);
            setDeleteDialogOpen(false);
            alert('Enregistrement supprimé');
        } catch (error) {
            alert('Erreur lors de la suppression.');
        }
    };

    const handleDeleteMultiple = async (rowsToDelete: any[]) => {
        if (!window.confirm(`Supprimer ${rowsToDelete.length} enregistrement(s) ?`)) return;
        setLoading(true);
        let successCount = 0;
        for (const row of rowsToDelete) {
            try {
                const recordId = row.resource_connection_seq || row.id || Object.values(row)[0];
                await resourcesService.deleteRecord(endpoint, recordId);
                successCount++;
            } catch (error) { /* ignore */ }
        }
        const data = await resourcesService.getTableData(endpoint, page, rowsPerPage, sortField, sortDirection, searchTerm, filters);
        setTableData(data);
        setLoading(false);
        alert(`${successCount} enregistrement(s) supprimé(s).`);
    };

    return (
        <Box sx={{ 
            width: '100%', 
            minHeight: '100vh',
            background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.02)} 0%, ${alpha(theme.palette.secondary.main, 0.02)} 100%)`,
            p: 3 
        }}>
            {/* Header */}
            <Paper 
                elevation={0}
                sx={{ 
                    mb: 3, 
                    background: 'linear-gradient(135deg, #00695c 0%, #00897b 100%)',
                    borderRadius: 3,
                    p: 3,
                    position: 'relative',
                    overflow: 'hidden',
                    '&::before': {
                        content: '""',
                        position: 'absolute',
                        top: 0,
                        right: 0,
                        width: '40%',
                        height: '100%',
                        background: 'linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0) 100%)',
                        borderRadius: '0 0 0 100%'
                    }
                }}
            >
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'relative', zIndex: 1 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                        <Box sx={{ p: 1.5, borderRadius: 2, bgcolor: 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            <LinkIcon sx={{ fontSize: 32, color: 'white' }} />
                        </Box>
                        <Box>
                            <Typography variant="h4" sx={{ color: 'white', fontWeight: 700, letterSpacing: '-0.5px' }}>
                                {pageTitle}
                            </Typography>
                            <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)', mt: 0.5 }}>
                                {pageDescription}
                            </Typography>
                        </Box>
                    </Box>
                    <Chip 
                        icon={<TableIcon sx={{ color: '#00695c !important' }} />}
                        label={tableName}
                        sx={{ bgcolor: 'white', color: '#00695c', fontWeight: 600, fontSize: '0.85rem', py: 2.5, px: 1 }} 
                    />
                </Box>
                
                <Box sx={{ display: 'flex', gap: 4, mt: 3 }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="h5" sx={{ color: 'white', fontWeight: 700 }}>{tableData?.total || 0}</Typography>
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>enregistrements</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="h5" sx={{ color: 'white', fontWeight: 700 }}>{visibleColumns.length}/{availableColumns.length}</Typography>
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>colonnes visibles</Typography>
                    </Box>
                    {Object.keys(filters).length > 0 && (
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Typography variant="h5" sx={{ color: '#ffd700', fontWeight: 700 }}>{Object.keys(filters).length}</Typography>
                            <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>filtre(s) actif(s)</Typography>
                        </Box>
                    )}
                </Box>
            </Paper>
            
            {/* Toolbar */}
            <Card sx={{ mb: 3, borderRadius: 2, boxShadow: '0 2px 12px rgba(0,0,0,0.08)' }}>
                <Box sx={{ p: 2.5 }}>
                    <Box sx={{ display: 'flex', gap: 2, alignItems: 'center', flexWrap: 'wrap' }}>
                        <TextField
                            placeholder="Rechercher dans toutes les colonnes..."
                            value={searchTerm}
                            onChange={handleSearchChange}
                            sx={{ flex: 1, minWidth: 300, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f8f9fa', '&:hover': { bgcolor: '#f0f1f2' }, '&.Mui-focused': { bgcolor: 'white' } } }}
                            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon sx={{ color: '#666' }} /></InputAdornment> }}
                        />
                        
                        <Button variant={advancedFilterOpen ? "contained" : "outlined"} onClick={toggleAdvancedFilter} startIcon={<FilterIcon />} endIcon={advancedFilterOpen ? <ExpandLessIcon /> : <ExpandMoreIcon />} sx={{ borderRadius: 2, px: 3, textTransform: 'none', fontWeight: 600 }}>
                            Filtres {Object.keys(filters).length > 0 && <Chip size="small" label={Object.keys(filters).length} sx={{ ml: 1, bgcolor: 'rgba(255,255,255,0.3)', height: 20, fontSize: '0.7rem' }} />}
                        </Button>
                        
                        <Button variant="contained" onClick={clearAllFilters} disabled={!searchTerm && Object.keys(filters).length === 0} startIcon={<ResetIcon />} sx={{ borderRadius: 2, px: 2, textTransform: 'none', fontWeight: 600, bgcolor: '#e53935', color: 'white', '&:hover': { bgcolor: '#c62828' }, '&.Mui-disabled': { bgcolor: '#ccc', color: '#888' } }}>
                            Reset
                        </Button>
                        
                        <Divider orientation="vertical" flexItem sx={{ mx: 1 }} />
                        
                        <Button variant="contained" onClick={handleColumnMenuClick} startIcon={<ViewColumnIcon />} sx={{ borderRadius: 2, px: 2, textTransform: 'none', fontWeight: 600, bgcolor: '#1e3c72', color: 'white', '&:hover': { bgcolor: '#2a5298' } }}>
                            Colonnes
                        </Button>
                        
                        <Button variant="contained" onClick={handleExportClick} disabled={!tableData || loading || exporting} startIcon={exporting ? <CircularProgress size={18} color="inherit" /> : <DownloadIcon />} sx={{ borderRadius: 2, px: 3, textTransform: 'none', fontWeight: 600, background: 'linear-gradient(135deg, #00b09b 0%, #96c93d 100%)', '&:hover': { background: 'linear-gradient(135deg, #009688 0%, #8bc34a 100%)' } }}>
                            Exporter
                        </Button>
                    </Box>
                    
                    <Menu anchorEl={columnMenuAnchor} open={Boolean(columnMenuAnchor)} onClose={handleColumnMenuClose} PaperProps={{ sx: { maxHeight: 400, width: 280, borderRadius: 2 } }}>
                        <Box sx={{ px: 2, py: 1, display: 'flex', gap: 1 }}>
                            <Button size="small" onClick={handleSelectAllColumns} sx={{ flex: 1, fontSize: '0.75rem' }}>Tout</Button>
                            <Button size="small" onClick={handleDeselectAllColumns} sx={{ flex: 1, fontSize: '0.75rem' }}>Aucun</Button>
                        </Box>
                        <Divider />
                        {availableColumns.map((column) => (
                            <MenuItem key={column} dense onClick={() => handleToggleColumn(column)}>
                                <Checkbox checked={visibleColumns.includes(column)} size="small" />
                                <ListItemText primary={tableData?.columns.find(c => c.name === column)?.label || column} primaryTypographyProps={{ fontSize: '0.85rem' }} />
                            </MenuItem>
                        ))}
                    </Menu>
                    
                    <Menu anchorEl={exportMenuAnchor} open={Boolean(exportMenuAnchor)} onClose={handleExportClose} PaperProps={{ sx: { borderRadius: 2 } }}>
                        <MenuItem onClick={() => handleExport('csv')} disabled={exporting}>
                            <ListItemIcon><TableIcon fontSize="small" sx={{ color: '#4caf50' }} /></ListItemIcon>
                            <ListItemText primary="Export CSV" secondary="Fichier .csv" />
                        </MenuItem>
                        <MenuItem onClick={() => handleExport('excel')} disabled={exporting}>
                            <ListItemIcon><FileIcon fontSize="small" sx={{ color: '#2196f3' }} /></ListItemIcon>
                            <ListItemText primary="Export Excel" secondary="Fichier .xlsx" />
                        </MenuItem>
                    </Menu>
                    
                    <Collapse in={advancedFilterOpen}>
                        <Box sx={{ mt: 2.5, p: 3, bgcolor: alpha(theme.palette.primary.main, 0.03), borderRadius: 2, border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}` }}>
                            <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 700, color: '#00695c', display: 'flex', alignItems: 'center', gap: 1 }}>
                                <FilterIcon fontSize="small" /> FILTRES AVANCÉS
                            </Typography>
                            
                            <Grid container spacing={2} alignItems="flex-end">
                                <Grid item xs={12} md={3}>
                                    <FormControl fullWidth size="small">
                                        <InputLabel>Colonne</InputLabel>
                                        <Select value={selectedFilterColumn} label="Colonne" onChange={handleFilterColumnChange}>
                                            {availableColumns.map((column) => <MenuItem key={column} value={column}>{tableData?.columns.find(c => c.name === column)?.label || column}</MenuItem>)}
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid item xs={12} md={2.5}>
                                    <FormControl fullWidth size="small">
                                        <InputLabel>Opérateur</InputLabel>
                                        <Select value={selectedOperator} label="Opérateur" onChange={handleOperatorChange}>
                                            {filterOperators.map((op) => <MenuItem key={op.value} value={op.value}>{op.label}</MenuItem>)}
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid item xs={12} md={4.5}>
                                    <TextField fullWidth size="small" label="Valeur" value={filterValue} onChange={handleFilterValueChange} disabled={['is_null', 'is_not_null'].includes(selectedOperator)} />
                                </Grid>
                                <Grid item xs={12} md={2}>
                                    <Button variant="contained" onClick={addFilter} disabled={!selectedFilterColumn || (!filterValue && !['is_null', 'is_not_null'].includes(selectedOperator))} fullWidth sx={{ borderRadius: 2, textTransform: 'none', fontWeight: 600, background: 'linear-gradient(135deg, #00695c 0%, #00897b 100%)' }}>
                                        Ajouter
                                    </Button>
                                </Grid>
                            </Grid>
                            
                            {Object.keys(filters).length > 0 && (
                                <Box sx={{ mt: 2.5 }}>
                                    <Divider sx={{ mb: 2 }} />
                                    <Typography variant="caption" sx={{ color: '#666', fontWeight: 600, display: 'block', mb: 1 }}>FILTRES ACTIFS</Typography>
                                    <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                                        {Object.entries(filters).map(([column, filterData]) => (
                                            <Chip key={column} label={`${tableData?.columns.find(c => c.name === column)?.label || column} ${filterOperators.find(op => op.value === filterData.operator)?.label || filterData.operator} ${filterData.value || ''}`} onDelete={() => removeFilter(column)} sx={{ bgcolor: alpha('#00695c', 0.1), color: '#00695c', fontWeight: 500, '& .MuiChip-deleteIcon': { color: '#d32f2f' } }} />
                                        ))}
                                    </Box>
                                </Box>
                            )}
                        </Box>
                    </Collapse>
                </Box>
            </Card>

            {/* Table */}
            <Card sx={{ borderRadius: 2, boxShadow: '0 2px 12px rgba(0,0,0,0.08)', overflow: 'hidden' }}>
                {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', p: 8, flexDirection: 'column', gap: 2 }}>
                        <CircularProgress size={48} />
                        <Typography color="text.secondary">Chargement des données...</Typography>
                    </Box>
                ) : tableData ? (
                    <ResourceDataTable 
                        data={tableData}
                        onPageChange={handlePageChange}
                        onRowsPerPageChange={handleRowsPerPageChange}
                        onSortChange={handleSortChange}
                        currentPage={page}
                        currentRowsPerPage={rowsPerPage}
                        currentSortField={sortField}
                        currentSortDirection={sortDirection}
                        loading={loading}
                        onEdit={handleEditRow}
                        onDelete={handleDeleteRow}
                        onView={handleViewRow}
                        onDeleteMultiple={handleDeleteMultiple}
                        visibleColumns={visibleColumns}
                    />
                ) : (
                    <Box sx={{ p: 8, textAlign: 'center' }}>
                        <LinkIcon sx={{ fontSize: 64, color: '#ccc', mb: 2 }} />
                        <Typography color="text.secondary">Aucune donnée disponible</Typography>
                    </Box>
                )}
            </Card>
            
            {/* Dialogs */}
            <Dialog open={viewDialogOpen} onClose={handleViewDialogClose} maxWidth="md" fullWidth PaperProps={{ sx: { borderRadius: 3 } }}>
                <DialogTitle sx={{ background: 'linear-gradient(135deg, #00695c 0%, #00897b 100%)', color: 'white', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>Détails de l'enregistrement</Typography>
                    <IconButton onClick={handleViewDialogClose} sx={{ color: 'white' }}><CloseIcon /></IconButton>
                </DialogTitle>
                <DialogContent dividers sx={{ p: 3 }}>
                    {currentRow && tableData && (
                        <Grid container spacing={2}>
                            {tableData.columns.map((column) => (
                                <Grid item xs={12} sm={6} key={column.name}>
                                    <TextField label={column.label} value={currentRow[column.name] || '-'} fullWidth InputProps={{ readOnly: true }} variant="filled" size="small" />
                                </Grid>
                            ))}
                        </Grid>
                    )}
                </DialogContent>
            </Dialog>
            
            <Dialog open={editDialogOpen} onClose={handleEditDialogClose} maxWidth="md" fullWidth PaperProps={{ sx: { borderRadius: 3 } }}>
                <DialogTitle sx={{ background: 'linear-gradient(135deg, #ff9800 0%, #ff5722 100%)', color: 'white', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>Modifier l'enregistrement</Typography>
                    <IconButton onClick={handleEditDialogClose} sx={{ color: 'white' }}><CloseIcon /></IconButton>
                </DialogTitle>
                <DialogContent dividers sx={{ p: 3 }}>
                    {currentRow && tableData && (
                        <Grid container spacing={2}>
                            {tableData.columns.map((column) => (
                                <Grid item xs={12} sm={6} key={column.name}>
                                    <TextField label={column.label} value={editedValues[column.name] || ''} onChange={(e) => handleInputChange(column.name, e.target.value)} fullWidth variant="outlined" size="small" />
                                </Grid>
                            ))}
                        </Grid>
                    )}
                </DialogContent>
                <DialogActions sx={{ p: 2, gap: 1 }}>
                    <Button onClick={handleEditDialogClose} sx={{ borderRadius: 2 }}>Annuler</Button>
                    <Button onClick={handleSaveEdit} variant="contained" sx={{ borderRadius: 2, px: 3 }}>Enregistrer</Button>
                </DialogActions>
            </Dialog>
            
            <Dialog open={deleteDialogOpen} onClose={handleDeleteDialogClose} PaperProps={{ sx: { borderRadius: 3 } }}>
                <DialogTitle sx={{ background: 'linear-gradient(135deg, #f44336 0%, #d32f2f 100%)', color: 'white' }}>Confirmer la suppression</DialogTitle>
                <DialogContent sx={{ p: 3, mt: 2 }}>
                    <Typography>Êtes-vous sûr de vouloir supprimer cet enregistrement ?</Typography>
                    <Typography variant="body2" color="error" sx={{ mt: 1 }}>Cette action est irréversible.</Typography>
                </DialogContent>
                <DialogActions sx={{ p: 2, gap: 1 }}>
                    <Button onClick={handleDeleteDialogClose} sx={{ borderRadius: 2 }}>Annuler</Button>
                    <Button onClick={handleConfirmDelete} color="error" variant="contained" sx={{ borderRadius: 2, px: 3 }}>Supprimer</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default ResourceConnectionPageAdvanced;










