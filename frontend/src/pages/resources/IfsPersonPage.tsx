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
import { useSearchParams } from 'react-router-dom';
import api from '../../services/api';

interface IfsPerson {
    id: number;
    person_id: string;
    first_name: string;
    last_name: string;
    title: string;
    internal_display_name: string;
    date_of_birth: string;
    gender: string;
    marital_status: string;
    currently_employed: string;
    loaded_at: string;
}

const IfsPersonPage: React.FC = () => {
    const [data, setData] = useState<IfsPerson[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalCount, setTotalCount] = useState(0);
    const [searchParams] = useSearchParams();
    const [search, setSearch] = useState(searchParams.get('search') || '');

    const loadData = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await api.get('/resources/ifs-persons', {
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
                    IFS Persons
                </Typography>
                <Typography variant="body2" color="text.secondary">
                    Table: clean_data.ifs_person
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
                                <TableCell>Person ID</TableCell>
                                <TableCell>Prénom</TableCell>
                                <TableCell>Nom</TableCell>
                                <TableCell>Titre</TableCell>
                                <TableCell>Nom d'affichage</TableCell>
                                <TableCell>Genre</TableCell>
                                <TableCell>Statut marital</TableCell>
                                <TableCell>Employé</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                                        <CircularProgress />
                                    </TableCell>
                                </TableRow>
                            ) : data.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                                        <Typography color="text.secondary">
                                            Aucune donnée disponible
                                        </Typography>
                                    </TableCell>
                                </TableRow>
                            ) : (
                                data.map((row, index) => (
                                    <TableRow key={index} hover>
                                        <TableCell>{row.person_id}</TableCell>
                                        <TableCell>{row.first_name}</TableCell>
                                        <TableCell>{row.last_name}</TableCell>
                                        <TableCell>{row.title}</TableCell>
                                        <TableCell>
                                            <Typography variant="body2" sx={{ fontSize: '0.85rem' }}>
                                                {row.internal_display_name}
                                            </Typography>
                                        </TableCell>
                                        <TableCell>{row.gender}</TableCell>
                                        <TableCell>{row.marital_status}</TableCell>
                                        <TableCell>{row.currently_employed}</TableCell>
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

export default IfsPersonPage;
