import {
    Cancel as CancelIcon,
    Clear as ClearIcon,
    FilterList as FilterIcon,
    Refresh as RefreshIcon,
    Replay as RetryIcon,
    Visibility as ViewIcon
} from '@mui/icons-material';
import {
    Box,
    Button,
    Card,
    Chip,
    FormControl,
    Grid,
    IconButton,
    InputLabel,
    MenuItem,
    Select,
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
import React, { useState } from 'react';
import { ImportJob } from '../../types/import.types';

interface ImportHistoryProps {
    jobs: ImportJob[];
    loading?: boolean;
    onRefresh?: () => void;
    onViewDetails?: (jobUuid: string) => void;
    onCancel?: (jobUuid: string) => void;
    onRetry?: (jobUuid: string) => void;
    totalCount?: number;
    page?: number;
    rowsPerPage?: number;
    onPageChange?: (page: number) => void;
    onRowsPerPageChange?: (rowsPerPage: number) => void;
}

const ImportHistory: React.FC<ImportHistoryProps> = ({
    jobs,
    loading = false,
    onRefresh,
    onViewDetails,
    onCancel,
    onRetry,
    totalCount = 0,
    page = 0,
    rowsPerPage = 10,
    onPageChange,
    onRowsPerPageChange
}) => {
    const [filters, setFilters] = useState({
        status: '',
        fileType: '',
        search: ''
    });
    const [showFilters, setShowFilters] = useState(false);

    // Configuration des couleurs par statut
    const getStatusConfig = (status: string) => {
        switch (status) {
            case 'pending':
                return { color: 'warning', label: 'En attente' };
            case 'processing':
                return { color: 'info', label: 'En cours' };
            case 'completed':
                return { color: 'success', label: 'Terminé' };
            case 'completed_with_errors':
                return { color: 'warning', label: 'Terminé avec erreurs' };
            case 'failed':
                return { color: 'error', label: 'Échec' };
            case 'cancelled':
                return { color: 'default', label: 'Annulé' };
            default:
                return { color: 'default', label: status };
        }
    };

    // Configuration des couleurs par type de fichier
    const getFileTypeColor = (type: string) => {
        switch (type) {
            case 'customers': return '#ff9800';
            case 'products': return '#4caf50';
            case 'orders': return '#2196f3';
            default: return '#9c27b0';
        }
    };

    // Formatage des dates
    const formatDateTime = (dateString: string) => {
        return new Date(dateString).toLocaleString('fr-FR');
    };

    // Formatage de la durée
    const formatDuration = (startDate?: string, endDate?: string) => {
        if (!startDate) return '-';
        
        const start = new Date(startDate);
        const end = endDate ? new Date(endDate) : new Date();
        const diffMs = end.getTime() - start.getTime();
        
        const minutes = Math.floor(diffMs / 60000);
        const seconds = Math.floor((diffMs % 60000) / 1000);
        
        if (minutes > 0) {
            return `${minutes}m ${seconds}s`;
        }
        return `${seconds}s`;
    };

    // Gestion des filtres
    const handleFilterChange = (filterName: string, value: string) => {
        setFilters(prev => ({
            ...prev,
            [filterName]: value
        }));
    };

    const clearFilters = () => {
        setFilters({
            status: '',
            fileType: '',
            search: ''
        });
    };

    return (
        <Card>
            {/* En-tête avec actions */}
            <Box sx={{ p: 3, borderBottom: 1, borderColor: 'divider' }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Typography variant="h6" sx={{ fontWeight: 600 }}>
                        Historique des Imports
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                        <Tooltip title="Filtres">
                            <IconButton
                                onClick={() => setShowFilters(!showFilters)}
                                color={showFilters ? 'primary' : 'default'}
                            >
                                <FilterIcon />
                            </IconButton>
                        </Tooltip>
                        {onRefresh && (
                            <Tooltip title="Actualiser">
                                <IconButton onClick={onRefresh} disabled={loading}>
                                    <RefreshIcon />
                                </IconButton>
                            </Tooltip>
                        )}
                    </Box>
                </Box>

                {/* Filtres */}
                {showFilters && (
                    <Box sx={{ mt: 2 }}>
                        <Grid container spacing={2}>
                            <Grid item xs={12} md={3}>
                                <FormControl fullWidth size="small">
                                    <InputLabel>Statut</InputLabel>
                                    <Select
                                        value={filters.status}
                                        label="Statut"
                                        onChange={(e) => handleFilterChange('status', e.target.value)}
                                    >
                                        <MenuItem value="">Tous</MenuItem>
                                        <MenuItem value="pending">En attente</MenuItem>
                                        <MenuItem value="processing">En cours</MenuItem>
                                        <MenuItem value="completed">Terminé</MenuItem>
                                        <MenuItem value="completed_with_errors">Terminé avec erreurs</MenuItem>
                                        <MenuItem value="failed">Échec</MenuItem>
                                        <MenuItem value="cancelled">Annulé</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12} md={3}>
                                <FormControl fullWidth size="small">
                                    <InputLabel>Type de fichier</InputLabel>
                                    <Select
                                        value={filters.fileType}
                                        label="Type de fichier"
                                        onChange={(e) => handleFilterChange('fileType', e.target.value)}
                                    >
                                        <MenuItem value="">Tous</MenuItem>
                                        <MenuItem value="customers">Clients</MenuItem>
                                        <MenuItem value="products">Produits</MenuItem>
                                        <MenuItem value="orders">Commandes</MenuItem>
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12} md={4}>
                                <TextField
                                    fullWidth
                                    size="small"
                                    label="Rechercher"
                                    value={filters.search}
                                    onChange={(e) => handleFilterChange('search', e.target.value)}
                                    placeholder="Nom de fichier..."
                                />
                            </Grid>
                            <Grid item xs={12} md={2}>
                                <Button
                                    fullWidth
                                    variant="outlined"
                                    startIcon={<ClearIcon />}
                                    onClick={clearFilters}
                                >
                                    Effacer
                                </Button>
                            </Grid>
                        </Grid>
                    </Box>
                )}
            </Box>

            {/* Table */}
            <TableContainer>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>Fichier</TableCell>
                            <TableCell>Type</TableCell>
                            <TableCell>Statut</TableCell>
                            <TableCell align="right">Lignes</TableCell>
                            <TableCell align="right">Succès</TableCell>
                            <TableCell align="right">Erreurs</TableCell>
                            <TableCell>Durée</TableCell>
                            <TableCell>Date</TableCell>
                            <TableCell align="center">Actions</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                        {jobs.map((job) => {
                            const statusConfig = getStatusConfig(job.status);
                            const fileTypeColor = getFileTypeColor(job.file_type);
                            
                            return (
                                <TableRow key={job.job_uuid} hover>
                                    <TableCell>
                                        <Typography variant="body2" sx={{ fontWeight: 500 }}>
                                            {job.file_name}
                                        </Typography>
                                        {job.user_name && (
                                            <Typography variant="caption" color="text.secondary">
                                                par {job.user_name}
                                            </Typography>
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        <Chip
                                            size="small"
                                            label={job.file_type}
                                            sx={{
                                                backgroundColor: `${fileTypeColor}20`,
                                                color: fileTypeColor,
                                                fontWeight: 600
                                            }}
                                        />
                                    </TableCell>
                                    <TableCell>
                                        <Chip
                                            size="small"
                                            label={statusConfig.label}
                                            color={statusConfig.color as any}
                                            variant={job.status === 'processing' ? 'filled' : 'outlined'}
                                        />
                                    </TableCell>
                                    <TableCell align="right">
                                        {job.total_rows ? job.total_rows.toLocaleString() : '-'}
                                    </TableCell>
                                    <TableCell align="right">
                                        <Typography
                                            variant="body2"
                                            color={job.success_rows && job.success_rows > 0 ? 'success.main' : 'text.secondary'}
                                        >
                                            {job.success_rows ? job.success_rows.toLocaleString() : '-'}
                                        </Typography>
                                    </TableCell>
                                    <TableCell align="right">
                                        <Typography
                                            variant="body2"
                                            color={job.error_rows && job.error_rows > 0 ? 'error.main' : 'text.secondary'}
                                        >
                                            {job.error_rows ? job.error_rows.toLocaleString() : '-'}
                                        </Typography>
                                    </TableCell>
                                    <TableCell>
                                        <Typography variant="body2">
                                            {formatDuration(job.started_at, job.completed_at)}
                                        </Typography>
                                    </TableCell>
                                    <TableCell>
                                        <Typography variant="body2">
                                            {formatDateTime(job.created_at)}
                                        </Typography>
                                    </TableCell>
                                    <TableCell align="center">
                                        <Box sx={{ display: 'flex', gap: 0.5 }}>
                                            {onViewDetails && (
                                                <Tooltip title="Voir détails">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => onViewDetails(job.job_uuid)}
                                                    >
                                                        <ViewIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>
                                            )}
                                            {onCancel && ['pending', 'processing'].includes(job.status) && (
                                                <Tooltip title="Annuler">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => onCancel(job.job_uuid)}
                                                    >
                                                        <CancelIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>
                                            )}
                                            {onRetry && ['failed', 'cancelled'].includes(job.status) && (
                                                <Tooltip title="Relancer">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => onRetry(job.job_uuid)}
                                                    >
                                                        <RetryIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>
                                            )}
                                        </Box>
                                    </TableCell>
                                </TableRow>
                            );
                        })}
                    </TableBody>
                </Table>
            </TableContainer>

            {/* Message si vide */}
            {jobs.length === 0 && !loading && (
                <Box sx={{ p: 4, textAlign: 'center' }}>
                    <Typography variant="body2" color="text.secondary">
                        Aucun import trouvé
                    </Typography>
                </Box>
            )}

            {/* Pagination */}
            {totalCount > 0 && onPageChange && onRowsPerPageChange && (
                <TablePagination
                    component="div"
                    count={totalCount}
                    page={page}
                    onPageChange={(_, newPage) => onPageChange(newPage)}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={(e) => onRowsPerPageChange(parseInt(e.target.value, 10))}
                    rowsPerPageOptions={[5, 10, 25, 50]}
                    labelRowsPerPage="Lignes par page:"
                    labelDisplayedRows={({ from, to, count }) => 
                        `${from}-${to} sur ${count !== -1 ? count : `plus de ${to}`}`
                    }
                />
            )}
        </Card>
    );
};

export default ImportHistory; 