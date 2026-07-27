import {
    CloudDownload as CloudDownloadIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Visibility as VisibilityIcon
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    IconButton,
    InputAdornment,
    LinearProgress,
    Paper,
    TextField,
    Tooltip,
    Typography
} from '@mui/material';
import React, { useEffect, useMemo, useState } from 'react';
import { DataTable } from '../components/table';
import type { DataTableColumn } from '../components/table';
import { useNavigate } from 'react-router-dom';
import { projectService, SharePointProject } from '../services/projectService';

const SharePointProjectsPage: React.FC = () => {
    const navigate = useNavigate();
    const [projects, setProjects] = useState<SharePointProject[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [totalProjects, setTotalProjects] = useState(0);
    const [search, setSearch] = useState('');
    const [importing, setImporting] = useState(false);

    // Charger les projets
    const loadProjects = async () => {
        try {
            setLoading(true);
            setError(null);
            const response = await projectService.getProjects(page + 1, rowsPerPage, search);
            
            if (response.success) {
                setProjects(response.data);
                setTotalProjects(response.total);
            } else {
                setError(response.message || 'Erreur lors du chargement des projets');
            }
        } catch (err) {
            setError('Erreur lors du chargement des projets');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    // Importer les projets depuis SharePoint
    const handleImport = async () => {
        try {
            setImporting(true);
            setError(null);
            const response = await projectService.importProjects();
            
            if (response.success) {
                // Recharger les projets après l'import
                await loadProjects();
                alert(`${response.imported_count} projets importés avec succès !`);
            } else {
                setError(response.message || 'Erreur lors de l\'import');
            }
        } catch (err) {
            setError('Erreur lors de l\'import des projets');
            console.error(err);
        } finally {
            setImporting(false);
        }
    };

    // Charger les projets au montage et quand la page change
    useEffect(() => {
        loadProjects();
    }, [page, rowsPerPage]);

    // Recherche avec debounce
    useEffect(() => {
        const timer = setTimeout(() => {
            if (page === 0) {
                loadProjects();
            } else {
                setPage(0); // Reset page quand on recherche
            }
        }, 500); // 500ms de délai

        return () => clearTimeout(timer);
    }, [search]);

    // (pagination pilotee directement par la DataTable via setPage/setRowsPerPage)

    // Obtenir la couleur du statut
    const getStatusColor = (status: string): 'success' | 'warning' | 'error' | 'info' | 'default' => {
        if (!status) return 'default';
        const statusLower = status.toLowerCase();
        if (statusLower.includes('clôturé') || statusLower.includes('terminé')) return 'success';
        if (statusLower.includes('cours') || statusLower.includes('actif')) return 'info';
        if (statusLower.includes('pause') || statusLower.includes('attente')) return 'warning';
        if (statusLower.includes('annulé') || statusLower.includes('échec')) return 'error';
        return 'default';
    };

    // Obtenir la couleur pour les indicateurs (health, planning, cost)
    const getIndicatorColor = (indicator: string): 'success' | 'warning' | 'error' | 'default' => {
        if (!indicator) return 'default';
        const indicatorLower = indicator.toLowerCase();
        if (indicatorLower.includes('ok') || indicatorLower === 'vert') return 'success';
        if (indicatorLower.includes('attention') || indicatorLower === 'orange') return 'warning';
        if (indicatorLower.includes('alerte') || indicatorLower === 'rouge') return 'error';
        return 'default';
    };

    // Formater le montant
    const formatCurrency = (value: number | null): string => {
        if (value === null || value === undefined) return '-';
        return new Intl.NumberFormat('fr-FR', {
            style: 'currency',
            currency: 'EUR'
        }).format(value);
    };

    // Formater la date
    const formatDate = (dateString: string | null): string => {
        if (!dateString) return '-';
        return new Date(dateString).toLocaleDateString('fr-FR');
    };

    // 14 colonnes : les 8 premieres suffisent au quotidien, les autres sont
    // masquees par defaut et reactivables via le menu « Colonnes ».
    const projectColumns: DataTableColumn<SharePointProject>[] = useMemo(
        () => [
            { key: 'sharepoint_id', label: 'ID', width: 80, mono: true },
            {
                key: 'code',
                label: 'Code',
                width: 120,
                mono: true,
                render: (p) => p.code || '—',
            },
            {
                key: 'title',
                label: 'Titre',
                width: 260,
                ellipsisMaxWidth: 300,
                render: (p) => (
                    <Tooltip title={p.description || p.title || ''}>
                        <Typography
                            variant="body2"
                            sx={{
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                                whiteSpace: 'nowrap',
                                color: 'primary.main',
                            }}
                        >
                            {p.title || '—'}
                        </Typography>
                    </Tooltip>
                ),
                csvValue: (p) => p.title || '',
            },
            {
                key: 'project_number',
                label: 'Numéro',
                width: 120,
                mono: true,
                render: (p) => p.project_number || '—',
            },
            {
                key: 'global_status',
                label: 'Statut',
                width: 130,
                render: (p) => (
                    <Chip
                        label={p.global_status || 'N/A'}
                        color={getStatusColor(p.global_status)}
                        size="small"
                    />
                ),
            },
            {
                key: 'phase_text',
                label: 'Phase',
                width: 150,
                ellipsisMaxWidth: 180,
                render: (p) => p.phase_text || '—',
            },
            {
                key: 'percent_completed',
                label: 'Avancement',
                width: 150,
                render: (p) => (
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <LinearProgress
                            variant="determinate"
                            value={(p.percent_completed || 0) * 100}
                            sx={{ flexGrow: 1, height: 6, borderRadius: 3 }}
                        />
                        <Typography variant="caption" sx={{ minWidth: 34, textAlign: 'right' }}>
                            {p.percent_completed ? `${(p.percent_completed * 100).toFixed(0)}%` : '0%'}
                        </Typography>
                    </Box>
                ),
                csvValue: (p) =>
                    p.percent_completed ? `${(p.percent_completed * 100).toFixed(0)}%` : '0%',
            },
            {
                key: 'budget_total_sap',
                label: 'Budget SAP',
                width: 140,
                align: 'right',
                mono: true,
                render: (p) => formatCurrency(p.budget_total_sap),
            },
            {
                key: 'health',
                label: 'Santé',
                width: 110,
                align: 'center',
                defaultHidden: true,
                render: (p) => (
                    <Chip
                        label={p.health || 'N/A'}
                        color={getIndicatorColor(p.health)}
                        size="small"
                        variant="outlined"
                    />
                ),
            },
            {
                key: 'planning',
                label: 'Planning',
                width: 110,
                align: 'center',
                defaultHidden: true,
                render: (p) => (
                    <Chip
                        label={p.planning || 'N/A'}
                        color={getIndicatorColor(p.planning)}
                        size="small"
                        variant="outlined"
                    />
                ),
            },
            {
                key: 'cost',
                label: 'Coût',
                width: 110,
                align: 'center',
                defaultHidden: true,
                render: (p) => (
                    <Chip
                        label={p.cost || 'N/A'}
                        color={getIndicatorColor(p.cost)}
                        size="small"
                        variant="outlined"
                    />
                ),
            },
            {
                key: 'sector',
                label: 'Secteur',
                width: 140,
                defaultHidden: true,
                render: (p) => p.sector || '—',
            },
            {
                key: 'imported_at',
                label: 'Date import',
                width: 130,
                mono: true,
                defaultHidden: true,
                render: (p) => formatDate(p.imported_at),
            },
            {
                key: 'actions',
                label: 'Actions',
                width: 90,
                align: 'center',
                csvValue: () => '',
                render: (p) => (
                    <Tooltip title="Voir les détails">
                        <IconButton
                            size="small"
                            color="primary"
                            onClick={(e) => {
                                // La ligne entiere est deja cliquable : on evite
                                // le double declenchement.
                                e.stopPropagation();
                                navigate(`/projets/detail/${p.sharepoint_id}`);
                            }}
                        >
                            <VisibilityIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                ),
            },
        ],
        // eslint-disable-next-line react-hooks/exhaustive-deps
        [],
    );

    return (
        <Box sx={{ p: 3 }}>
            <Paper sx={{ p: 3, mb: 3 }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
                    <Typography variant="h4" component="h1">
                        Projets SharePoint
                    </Typography>
                    <Box sx={{ display: 'flex', gap: 2 }}>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={loadProjects}
                            disabled={loading || importing}
                        >
                            Actualiser
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<CloudDownloadIcon />}
                            onClick={handleImport}
                            disabled={loading || importing}
                        >
                            {importing ? 'Import en cours...' : 'Importer depuis SharePoint'}
                        </Button>
                    </Box>
                </Box>

                {error && (
                    <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
                        {error}
                    </Alert>
                )}

                <TextField
                    fullWidth
                    placeholder="Rechercher par titre, code, numéro ou statut..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon />
                            </InputAdornment>
                        ),
                    }}
                    sx={{ mb: 3 }}
                />
            </Paper>

            {importing && <LinearProgress sx={{ mb: 1 }} />}

            <DataTable<SharePointProject>
                columns={projectColumns}
                rows={projects}
                getRowKey={(p) => p.id}
                loading={loading}
                emptyLabel={'Aucun projet trouvé. Cliquez sur « Importer depuis SharePoint » pour commencer.'}
                onRowClick={(p) => navigate(`/projets/detail/${p.sharepoint_id}`)}
                pagination={{
                    page,
                    pageSize: rowsPerPage,
                    total: totalProjects,
                    onPageChange: setPage,
                    onPageSizeChange: setRowsPerPage,
                    pageSizeOptions: [25, 50, 100],
                }}
                // 14 colonnes : le menu permet d'alleger l'affichage, et la
                // largeur minimale fait defiler DANS le tableau plutot que de
                // pousser la page (les dernieres colonnes etaient inaccessibles).
                toolbar={{ columnVisibility: true, csvExport: { filePrefix: 'projets_sharepoint' } }}
                minTableWidth={1700}
                maxHeight="calc(100vh - 300px)"
            />

        </Box>
    );
};

export default SharePointProjectsPage;

