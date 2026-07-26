import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Grid,
    IconButton,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Tooltip,
    Typography
} from '@mui/material';
import {
    Upload as UploadIcon,
    Visibility as ViewIcon,
    TableChart as TableIcon,
    ArrowBack as BackIcon,
    Refresh as RefreshIcon
} from '@mui/icons-material';
import React, { useEffect, useState } from 'react';
import api from '../services/api';

interface TableSummary {
    table_name: string;
    job_name: string;
    column_count: number;
    key_count: number;
    mandatory_count: number;
    imported_at: string;
}

interface TableColumn {
    id: number;
    column_name: string;
    description: string;
    flags: string;
    data_type: string;
    length: number;
    decimal_length: number;
    default_value: string;
    is_key: boolean;
    is_mandatory: boolean;
    is_updatable: boolean;
    is_insertable: boolean;
    attr_seq: number;
}

const TableStructureManagementNew: React.FC = () => {
    const [viewMode, setViewMode] = useState<'tables' | 'columns'>('tables');
    const [tables, setTables] = useState<TableSummary[]>([]);
    const [columns, setColumns] = useState<TableColumn[]>([]);
    const [selectedTable, setSelectedTable] = useState<string | null>(null);
    const [selectedJob, setSelectedJob] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [uploadDialogOpen, setUploadDialogOpen] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [jobName, setJobName] = useState('');
    const [tableName, setTableName] = useState('');
    const [schemaName, setSchemaName] = useState('clean_data');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(25);
    const [totalCount, setTotalCount] = useState(0);
    const [searchTables, setSearchTables] = useState('');
    const [searchColumns, setSearchColumns] = useState('');

    useEffect(() => {
        if (viewMode === 'tables') {
            loadTables();
        }
    }, [viewMode]);

    const loadTables = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/config/table-structure/summary');
            setTables(response.data.data || []);
        } catch (err: any) {
            setError('Erreur lors du chargement des tables');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const loadColumns = async (tableName: string, jobName: string, search?: string) => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/config/table-structure', {
                params: {
                    table_name: tableName,
                    job_name: jobName,
                    page: page + 1,
                    per_page: rowsPerPage,
                    search: search || searchColumns
                }
            });
            setColumns(response.data.data || []);
            setTotalCount(response.data.total || 0);
        } catch (err: any) {
            setError('Erreur lors du chargement des colonnes');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    const handleViewColumns = (tableName: string, jobName: string) => {
        setSelectedTable(tableName);
        setSelectedJob(jobName);
        setViewMode('columns');
        setPage(0);
        loadColumns(tableName, jobName);
    };

    const handleBackToTables = () => {
        setViewMode('tables');
        setSelectedTable(null);
        setSelectedJob(null);
        setColumns([]);
        setSearchColumns('');
    };

    const handleSearchColumns = () => {
        setPage(0);
        loadColumns(selectedTable!, selectedJob!, searchColumns);
    };

    const filteredTables = tables.filter(table => 
        table.table_name.toLowerCase().includes(searchTables.toLowerCase()) ||
        table.job_name.toLowerCase().includes(searchTables.toLowerCase())
    );

    const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0];
        if (file) {
            const validExtensions = ['xls', 'xlsx'];
            const fileExtension = file.name.split('.').pop()?.toLowerCase();
            
            if (fileExtension && validExtensions.includes(fileExtension)) {
                setSelectedFile(file);
                setError(null);
            } else {
                setError('Format de fichier non valide. Veuillez sélectionner un fichier Excel (.xls, .xlsx)');
                setSelectedFile(null);
            }
        }
    };

    const handleUpload = async () => {
        if (!selectedFile || !jobName.trim() || !tableName.trim()) {
            setError('Veuillez remplir tous les champs');
            return;
        }

        try {
            setUploading(true);
            setError(null);

            const formData = new FormData();
            formData.append('file', selectedFile);
            formData.append('job_name', jobName);
            formData.append('table_name', tableName);
            formData.append('schema_name', schemaName);

            const response = await api.post('/config/table-structure/upload', formData, {
                headers: {
                    'Content-Type': 'multipart/form-data'
                }
            });

            if (response.data.success) {
                setSuccess(`✅ ${response.data.imported_count} colonnes importées avec succès`);
                setUploadDialogOpen(false);
                setSelectedFile(null);
                setJobName('');
                setTableName('');
                setSchemaName('clean_data');
                loadTables();
            } else {
                setError(response.data.message || 'Erreur lors de l\'import');
            }
        } catch (err: any) {
            setError(err.response?.data?.message || 'Erreur lors de l\'import');
            console.error(err);
        } finally {
            setUploading(false);
        }
    };

    const getFlagsChips = (flags: string, isKey: boolean, isMandatory: boolean, isUpdatable: boolean, isInsertable: boolean): React.ReactNode => {
        const chips: React.ReactElement[] = [];
        
        if (flags?.includes('K') || isKey) {
            chips.push(<Chip key="K" label="K" size="small" color="error" sx={{ minWidth: 25, mr: 0.5 }} />);
        }
        if (flags?.includes('U') || isUpdatable) {
            chips.push(<Chip key="U" label="U" size="small" color="primary" sx={{ minWidth: 25, mr: 0.5 }} />);
        }
        if (flags?.includes('I') || isInsertable) {
            chips.push(<Chip key="I" label="I" size="small" color="success" sx={{ minWidth: 25, mr: 0.5 }} />);
        }
        if (flags?.includes('M') || isMandatory) {
            chips.push(<Chip key="M" label="M" size="small" color="warning" sx={{ minWidth: 25, mr: 0.5 }} />);
        }
        
        return chips.length > 0 ? chips : '-';
    };

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    {viewMode === 'columns' && (
                        <IconButton onClick={handleBackToTables} color="primary">
                            <BackIcon />
                        </IconButton>
                    )}
                    <Typography variant="h4">
                        {viewMode === 'tables' ? 'Gestion des Structures de Tables' : `Colonnes de ${selectedTable}`}
                    </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={() => viewMode === 'tables' ? loadTables() : loadColumns(selectedTable!, selectedJob!)}
                    >
                        Actualiser
                    </Button>
                    {viewMode === 'tables' && (
                        <Button
                            variant="contained"
                            startIcon={<UploadIcon />}
                            onClick={() => setUploadDialogOpen(true)}
                        >
                            Importer Excel
                        </Button>
                    )}
                </Box>
            </Box>

            {error && (
                <Alert severity="error" onClose={() => setError(null)} sx={{ mb: 2 }}>
                    {error}
                </Alert>
            )}

            {success && (
                <Alert severity="success" onClose={() => setSuccess(null)} sx={{ mb: 2 }}>
                    {success}
                </Alert>
            )}

            {viewMode === 'tables' ? (
                // Vue des tables
                <>
                    <Box sx={{ mb: 3 }}>
                        <TextField
                            fullWidth
                            placeholder="Rechercher par nom de table ou job..."
                            value={searchTables}
                            onChange={(e) => setSearchTables(e.target.value)}
                            size="small"
                        />
                    </Box>

                    <Grid container spacing={3}>
                        {loading ? (
                            <Grid item xs={12} sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
                                <CircularProgress />
                            </Grid>
                        ) : filteredTables.length === 0 ? (
                        <Grid item xs={12}>
                            <Paper sx={{ p: 5, textAlign: 'center' }}>
                                <TableIcon sx={{ fontSize: 60, color: 'text.secondary', mb: 2 }} />
                                <Typography variant="h6" color="text.secondary">
                                    Aucune table importée
                                </Typography>
                                <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                                    Importez un fichier Excel pour commencer
                                </Typography>
                            </Paper>
                        </Grid>
                    ) : (
                        filteredTables.map((table) => (
                            <Grid item xs={12} sm={6} md={4} key={`${table.job_name}-${table.table_name}`}>
                                <Card>
                                    <CardContent>
                                        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', mb: 2 }}>
                                            <Box>
                                                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                                                    {table.table_name}
                                                </Typography>
                                                <Chip label={table.job_name} size="small" color="primary" sx={{ mt: 1 }} />
                                            </Box>
                                            <IconButton
                                                color="primary"
                                                onClick={() => handleViewColumns(table.table_name, table.job_name)}
                                            >
                                                <ViewIcon />
                                            </IconButton>
                                        </Box>
                                        
                                        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', mt: 2 }}>
                                            <Chip
                                                label={`${table.column_count} colonnes`}
                                                size="small"
                                                variant="outlined"
                                            />
                                            <Chip
                                                label={`${table.key_count} clés`}
                                                size="small"
                                                variant="outlined"
                                                color="error"
                                            />
                                            <Chip
                                                label={`${table.mandatory_count} obligatoires`}
                                                size="small"
                                                variant="outlined"
                                                color="warning"
                                            />
                                        </Box>

                                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 2 }}>
                                            Importé le {new Date(table.imported_at).toLocaleDateString('fr-FR')}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))
                    )}
                    </Grid>
                </>
            ) : (
                // Vue des colonnes
                <>
                    <Box sx={{ mb: 3, display: 'flex', gap: 2 }}>
                        <TextField
                            fullWidth
                            placeholder="Rechercher dans les colonnes..."
                            value={searchColumns}
                            onChange={(e) => setSearchColumns(e.target.value)}
                            onKeyPress={(e) => {
                                if (e.key === 'Enter') {
                                    handleSearchColumns();
                                }
                            }}
                            size="small"
                        />
                        <Button
                            variant="contained"
                            onClick={handleSearchColumns}
                            sx={{ minWidth: 120 }}
                        >
                            Rechercher
                        </Button>
                    </Box>

                    <TableContainer component={Paper}>
                        <Table size="small">
                            <TableHead>
                                <TableRow sx={{ backgroundColor: '#f5f5f5' }}>
                                    <TableCell sx={{ fontWeight: 600, width: 60 }}>Seq</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Colonne</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Description</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Type</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Taille</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Flags</TableCell>
                                    <TableCell sx={{ fontWeight: 600 }}>Valeur par défaut</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 5 }}>
                                            <CircularProgress />
                                        </TableCell>
                                    </TableRow>
                                ) : columns.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 5 }}>
                                            <Typography color="text.secondary">Aucune colonne trouvée</Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    columns.map((col) => (
                                        <TableRow key={col.id} hover>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem" color="text.secondary">
                                                    {col.attr_seq || '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem" fontWeight={col.is_key ? 600 : 400}>
                                                    {col.column_name}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem">
                                                    {col.description || '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem">
                                                    {col.data_type || '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem">
                                                    {col.length ? `${col.length}${col.decimal_length ? `,${col.decimal_length}` : ''}` : '-'}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Box sx={{ display: 'flex', gap: 0.5 }}>
                                                    {getFlagsChips(col.flags, col.is_key, col.is_mandatory, col.is_updatable, col.is_insertable)}
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontSize="0.85rem">
                                                    {col.default_value || '-'}
                                                </Typography>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>

                    <TablePagination
                        component="div"
                        count={totalCount}
                        page={page}
                        onPageChange={(_, newPage) => {
                            setPage(newPage);
                            loadColumns(selectedTable!, selectedJob!);
                        }}
                        rowsPerPage={rowsPerPage}
                        onRowsPerPageChange={(e) => {
                            setRowsPerPage(parseInt(e.target.value, 10));
                            setPage(0);
                            loadColumns(selectedTable!, selectedJob!);
                        }}
                        rowsPerPageOptions={[25, 50, 100, 250]}
                        labelRowsPerPage="Lignes par page:"
                        labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
                    />
                </>
            )}

            {/* Dialog d'upload */}
            <Dialog open={uploadDialogOpen} onClose={() => setUploadDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Importer une structure de table</DialogTitle>
                <DialogContent>
                    <Box sx={{ mt: 2 }}>
                        <TextField
                            fullWidth
                            label="Nom du Job"
                            value={jobName}
                            onChange={(e) => setJobName(e.target.value)}
                            placeholder="Ex: IMPORT_CLIENTS"
                            sx={{ mb: 2 }}
                            required
                        />

                        <TextField
                            fullWidth
                            label="Nom de la Table"
                            value={tableName}
                            onChange={(e) => setTableName(e.target.value)}
                            placeholder="Ex: PROJECT"
                            sx={{ mb: 2 }}
                            required
                        />

                        <TextField
                            fullWidth
                            select
                            label="Schéma"
                            value={schemaName}
                            onChange={(e) => setSchemaName(e.target.value)}
                            sx={{ mb: 2 }}
                            SelectProps={{
                                native: true,
                            }}
                        >
                            <option value="clean_data">clean_data</option>
                            <option value="raw_data">raw_data</option>
                            <option value="public">public</option>
                        </TextField>

                        <Button
                            variant="outlined"
                            component="label"
                            fullWidth
                            startIcon={<UploadIcon />}
                            sx={{ mb: 2 }}
                        >
                            Sélectionner un fichier Excel
                            <input
                                type="file"
                                hidden
                                accept=".xls,.xlsx"
                                onChange={handleFileSelect}
                            />
                        </Button>

                        {selectedFile && (
                            <Alert severity="info">
                                Fichier sélectionné : {selectedFile.name}
                            </Alert>
                        )}
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setUploadDialogOpen(false)}>Annuler</Button>
                    <Button
                        onClick={handleUpload}
                        variant="contained"
                        disabled={uploading || !selectedFile || !jobName.trim() || !tableName.trim()}
                        startIcon={uploading ? <CircularProgress size={20} /> : <UploadIcon />}
                    >
                        {uploading ? 'Import en cours...' : 'Importer'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Légende des flags */}
            <Paper sx={{ p: 2, mt: 3 }}>
                <Typography variant="subtitle2" gutterBottom>Légende des flags :</Typography>
                <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip label="K" size="small" color="error" />
                        <Typography variant="body2">Clé primaire (Key)</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip label="M" size="small" color="warning" />
                        <Typography variant="body2">Obligatoire (Mandatory)</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip label="U" size="small" color="primary" />
                        <Typography variant="body2">Modifiable (Updatable)</Typography>
                    </Box>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Chip label="I" size="small" color="success" />
                        <Typography variant="body2">Insertable</Typography>
                    </Box>
                </Box>
            </Paper>
        </Box>
    );
};

export default TableStructureManagementNew;

