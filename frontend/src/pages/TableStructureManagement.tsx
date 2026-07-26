import {
    Refresh as RefreshIcon,
    Search as SearchIcon,
    CloudUpload as UploadIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Card,
    CardContent,
    Chip,
    CircularProgress,
    Container,
    Dialog,
    DialogActions,
    DialogContent,
    DialogTitle,
    Grid,
    InputAdornment,
    LinearProgress,
    Paper,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Typography
} from '@mui/material';
import React, { useEffect, useState } from 'react';
import api from '../services/api';

interface TableStructureMetadata {
    id: number;
    job_name: string;
    table_name: string;
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
    imported_at: string;
    imported_by: string;
    source_file: string;
}

interface TableSummary {
    table_name: string;
    job_name: string;
    column_count: number;
    key_count: number;
    mandatory_count: number;
    imported_at: string;
}

const TableStructureManagement: React.FC = () => {
    const [structures, setStructures] = useState<TableStructureMetadata[]>([]);
    const [loading, setLoading] = useState(false);
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(25);
    const [totalCount, setTotalCount] = useState(0);
    const [search, setSearch] = useState('');
    const [selectedFile, setSelectedFile] = useState<File | null>(null);
    const [uploadDialogOpen, setUploadDialogOpen] = useState(false);
    const [jobName, setJobName] = useState('');
    const [tableName, setTableName] = useState('');
    const [schemaName, setSchemaName] = useState('clean_data');
    
    // Nouveaux états pour la vue par table
    const [viewMode, setViewMode] = useState<'tables' | 'columns'>('tables');
    const [selectedTable, setSelectedTable] = useState<string | null>(null);
    const [selectedJob, setSelectedJob] = useState<string | null>(null);
    const [tableSummaries, setTableSummaries] = useState<TableSummary[]>([]);

    useEffect(() => {
        loadStructures();
    }, [page, rowsPerPage]);

    const loadStructures = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/config/table-structure', {
                params: {
                    page: page + 1,
                    per_page: rowsPerPage,
                    search: search
                }
            });

            if (response.data.success) {
                setStructures(response.data.data);
                setTotalCount(response.data.total);
            } else {
                setError(response.data.message || 'Erreur lors du chargement');
            }
        } catch (err: any) {
            setError(err.response?.data?.message || 'Erreur lors du chargement');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

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
        if (!selectedFile) {
            setError('Veuillez sélectionner un fichier');
            return;
        }

        if (!jobName.trim()) {
            setError('Veuillez saisir un nom de job');
            return;
        }

        if (!tableName.trim()) {
            setError('Veuillez saisir un nom de table');
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
                loadStructures();
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

    const handleSearch = () => {
        setPage(0);
        loadStructures();
    };

    const handleChangePage = (_event: unknown, newPage: number) => {
        setPage(newPage);
    };

    const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
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
        <Container maxWidth="xl" sx={{ py: 4 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 4 }}>
                <Box>
                    <Typography variant="h4" component="h1" gutterBottom>
                        Structure de Tables
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                        Importer et gérer les structures de tables depuis Excel
                    </Typography>
                </Box>
                <Box sx={{ display: 'flex', gap: 2 }}>
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadStructures}
                        disabled={loading}
                    >
                        Actualiser
                    </Button>
                    <Button
                        variant="contained"
                        startIcon={<UploadIcon />}
                        onClick={() => setUploadDialogOpen(true)}
                    >
                        Importer Excel
                    </Button>
                </Box>
            </Box>

            {error && (
                <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
                    {error}
                </Alert>
            )}

            {success && (
                <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
                    {success}
                </Alert>
            )}

            {/* Légende des flags */}
            <Card sx={{ mb: 3 }}>
                <CardContent>
                    <Typography variant="h6" gutterBottom>
                        Légende des Flags
                    </Typography>
                    <Grid container spacing={2}>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Chip label="K" size="small" color="error" />
                                <Typography variant="body2">Clé primaire (Key)</Typography>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Chip label="U" size="small" color="primary" />
                                <Typography variant="body2">Modifiable (Updatable)</Typography>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Chip label="I" size="small" color="success" />
                                <Typography variant="body2">Insertable</Typography>
                            </Box>
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                <Chip label="M" size="small" color="warning" />
                                <Typography variant="body2">Obligatoire (Mandatory)</Typography>
                            </Box>
                        </Grid>
                    </Grid>
                </CardContent>
            </Card>

            {/* Recherche */}
            <Paper sx={{ mb: 2, p: 2 }}>
                <TextField
                    fullWidth
                    placeholder="Rechercher par nom de table ou colonne..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon />
                            </InputAdornment>
                        )
                    }}
                />
            </Paper>

            {/* Tableau */}
            <Paper>
                {loading && <LinearProgress />}
                
                <TableContainer>
                    <Table size="small">
                        <TableHead>
                            <TableRow>
                                <TableCell>Job</TableCell>
                                <TableCell>Table</TableCell>
                                <TableCell>Colonne</TableCell>
                                <TableCell>Description</TableCell>
                                <TableCell>Type</TableCell>
                                <TableCell>Longueur</TableCell>
                                <TableCell>Flags</TableCell>
                                <TableCell>Valeur par défaut</TableCell>
                                <TableCell>Importé le</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading && structures.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={9} align="center">
                                        <CircularProgress />
                                    </TableCell>
                                </TableRow>
                            ) : structures.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={9} align="center">
                                        <Typography color="text.secondary">
                                            Aucune structure trouvée
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                structures.map((row) => (
                                    <TableRow key={row.id} hover>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {row.job_name || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight="medium">
                                                {row.table_name}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight="medium">
                                                {row.column_name}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {row.description || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {row.data_type || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {row.length ? `${row.length}${row.decimal_length ? `,${row.decimal_length}` : ''}` : '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Box sx={{ display: 'flex', gap: 0.5 }}>
                                                {getFlagsChips(row.flags, row.is_key, row.is_mandatory, row.is_updatable, row.is_insertable)}
                                            </Box>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {row.default_value || '-'}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontSize="0.85rem">
                                                {new Date(row.imported_at).toLocaleDateString('fr-FR')}
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
                    onPageChange={handleChangePage}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={handleChangeRowsPerPage}
                    rowsPerPageOptions={[25, 50, 100]}
                    labelRowsPerPage="Lignes par page:"
                    labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
                />
            </Paper>

            {/* Dialog d'upload */}
            <Dialog open={uploadDialogOpen} onClose={() => setUploadDialogOpen(false)} maxWidth="sm" fullWidth>
                <DialogTitle>Importer une structure de table</DialogTitle>
                <DialogContent>
                    <Box sx={{ mt: 2 }}>
                        <Typography variant="body2" color="text.secondary" paragraph>
                            Importez un fichier Excel contenant la structure d'une table avec les colonnes suivantes :
                        </Typography>
                        <ul style={{ marginTop: 0, paddingLeft: 20 }}>
                            <li><Typography variant="body2">Column Name</Typography></li>
                            <li><Typography variant="body2">Description</Typography></li>
                            <li><Typography variant="body2">Flags (K, U, I, M)</Typography></li>
                            <li><Typography variant="body2">Data Type</Typography></li>
                            <li><Typography variant="body2">Length</Typography></li>
                            <li><Typography variant="body2">Decimal Length</Typography></li>
                            <li><Typography variant="body2">Default Value</Typography></li>
                        </ul>

                        <TextField
                            fullWidth
                            label="Nom du Job"
                            value={jobName}
                            onChange={(e) => setJobName(e.target.value)}
                            placeholder="Ex: IMPORT_CLIENTS"
                            sx={{ mb: 2, mt: 2 }}
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
        </Container>
    );
};

export default TableStructureManagement;

