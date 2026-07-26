import {
    Refresh as RefreshIcon,
    Search as SearchIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    CircularProgress,
    IconButton,
    InputAdornment,
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
import React, { useEffect, useState } from 'react';
import api from '../../services/api';

interface ResourceDetailFile {
    resource_seq: number;
    resource_id: string;
    description: string;
    resource_type: string;
    calendar_id: string;
    resource_category: string;
    loaded_at: string;
}

const ResourceDetailFilePage: React.FC = () => {
    const [data, setData] = useState<ResourceDetailFile[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalCount, setTotalCount] = useState(0);
    const [search, setSearch] = useState('');

    const loadData = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/resources/detail-files', {
                params: {
                    page: page + 1,
                    per_page: rowsPerPage,
                    search: search
                }
            });
            
            setData(response.data.data || []);
            setTotalCount(response.data.total || 0);
        } catch (err: any) {
            setError(err.response?.data?.message || 'Erreur lors du chargement des données');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadData();
    }, [page, rowsPerPage, search]);

    const handleChangePage = (_event: unknown, newPage: number) => {
        setPage(newPage);
    };

    const handleChangeRowsPerPage = (event: React.ChangeEvent<HTMLInputElement>) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
    };

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ mb: 3 }}>
                <Typography variant="h4" component="h1" gutterBottom>
                    Resource Detail Files
                </Typography>
                <Typography variant="body2" color="text.secondary">
                    Table: clean_data.resource_detail_file
                </Typography>
            </Box>

            {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                    {error}
                </Alert>
            )}

            <Paper sx={{ mb: 2, p: 2 }}>
                <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
                    <TextField
                        placeholder="Rechercher..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        size="small"
                        fullWidth
                        InputProps={{
                            startAdornment: (
                                <InputAdornment position="start">
                                    <SearchIcon />
                                </InputAdornment>
                            ),
                        }}
                    />
                    <Tooltip title="Actualiser">
                        <IconButton onClick={loadData} color="primary">
                            <RefreshIcon />
                        </IconButton>
                    </Tooltip>
                </Box>
            </Paper>

            <Paper>
                <TableContainer>
                    <Table>
                        <TableHead>
                            <TableRow>
                                <TableCell>Resource Seq</TableCell>
                                <TableCell>Resource ID</TableCell>
                                <TableCell>Description</TableCell>
                                <TableCell>Type</TableCell>
                                <TableCell>Calendrier</TableCell>
                                <TableCell>Catégorie</TableCell>
                                <TableCell>Date de chargement</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                        <CircularProgress />
                                    </TableCell>
                                </TableRow>
                            ) : data.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                        <Typography color="text.secondary">
                                            Aucune donnée disponible
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                data.map((row, index) => (
                                    <TableRow key={index} hover>
                                        <TableCell>{row.resource_seq}</TableCell>
                                        <TableCell>{row.resource_id}</TableCell>
                                        <TableCell>
                                            <Typography variant="body2" sx={{ fontSize: '0.85rem' }}>
                                                {row.description}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>{row.resource_type}</TableCell>
                                        <TableCell>{row.calendar_id}</TableCell>
                                        <TableCell>{row.resource_category}</TableCell>
                                        <TableCell>{row.loaded_at}</TableCell>
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
        </Box>
    );
};

export default ResourceDetailFilePage;

