import {
    Cancel as CancelIcon,
    CloudDownload as CloudDownloadIcon,
    KeyboardArrowDown as ArrowDownIcon,
    KeyboardArrowUp as ArrowUpIcon,
    Search as SearchIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    CircularProgress,
    Collapse,
    FormControl,
    Grid,
    IconButton,
    InputAdornment,
    InputLabel,
    LinearProgress,
    MenuItem,
    Paper,
    Select,
    Snackbar,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TableSortLabel,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

// Ligne de l'export : colonnes TEXT nommées comme dans SharePoint (accents, %, espaces)
type ProjetRow = Record<string, string | boolean | null> & {
    in_migration: boolean;
    migration_sharepoint_id: number | null;
};

interface Stats {
    total: number;
    en_cours: number;
    clotures: number;
    pas_demarre: number;
    in_migration: number;
    a_reprendre_ifs: number;
}

const STATUTS = ['En cours', 'Clôturé', 'Annulé', 'En attente', 'Pas démarré'];
const SITES = ['Saint Jean de Maurienne', 'Castelsarrasin'];

const STATUT_COLOR: Record<string, 'primary' | 'default' | 'error' | 'warning' | 'info'> = {
    'En cours': 'primary',
    'Clôturé': 'default',
    'Annulé': 'error',
    'En attente': 'warning',
    'Pas démarré': 'info',
};

const CFV_COLOR: Record<string, string> = {
    'Vert': '#4caf50',
    'Orange': '#ff9800',
    'Rouge': '#f44336',
    'Prévue': '#90a4ae',
    'pas nécessaire (NA)': '#bdbdbd',
};

const txt = (v: string | boolean | null | undefined): string => {
    if (v === null || v === undefined || v === true || v === false) return '';
    return String(v).trim();
};

const pct = (v: string | boolean | null | undefined): number => {
    const n = parseInt(txt(v).replace('%', ''), 10);
    return isNaN(n) ? 0 : Math.min(100, Math.max(0, n));
};

const KV: React.FC<{ label: string; value?: string }> = ({ label, value }) => (
    <Box sx={{ minWidth: 150, mb: 1 }}>
        <Typography variant="caption" color="text.secondary" display="block">{label}</Typography>
        <Typography variant="body2">{value || '—'}</Typography>
    </Box>
);

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => (
    <Paper variant="outlined" sx={{ p: 1.5, height: '100%' }}>
        <Typography variant="subtitle2" sx={{ mb: 1, color: '#0f766e', fontWeight: 700, textTransform: 'uppercase', fontSize: 11, letterSpacing: '0.05em' }}>
            {title}
        </Typography>
        {children}
    </Paper>
);

const ProjetsAReprendre: React.FC = () => {
    const navigate = useNavigate();
    const [rows, setRows] = useState<ProjetRow[]>([]);
    const [stats, setStats] = useState<Stats | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(50);
    const [total, setTotal] = useState(0);
    const [search, setSearch] = useState('');
    const [statut, setStatut] = useState('');
    const [site, setSite] = useState('');
    const [sortBy, setSortBy] = useState('Numéro du projet');
    const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
    const [expanded, setExpanded] = useState<string | null>(null);
    const [refreshing, setRefreshing] = useState(false);
    const [snack, setSnack] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
        open: false, message: '', severity: 'success',
    });

    // Recharge la table depuis la liste SharePoint (TRUNCATE + réimport côté backend)
    const refreshFromSharePoint = async () => {
        try {
            setRefreshing(true);
            const res = await api.post('/data/projets-a-reprendre/refresh');
            if (res.data?.success) {
                setSnack({
                    open: true,
                    message: `Liste mise à jour : ${res.data.imported_count} projets importés depuis SharePoint`,
                    severity: 'success',
                });
                setPage(0);
                load();
            } else {
                setSnack({ open: true, message: res.data?.message || res.data?.error || 'Échec de la mise à jour', severity: 'error' });
            }
        } catch (e: any) {
            setSnack({
                open: true,
                message: e?.response?.data?.message || e?.response?.data?.error || 'Erreur lors de la mise à jour depuis SharePoint',
                severity: 'error',
            });
        } finally {
            setRefreshing(false);
        }
    };

    const load = async () => {
        try {
            setLoading(true);
            setError(null);
            const res = await api.get('/data/projets-a-reprendre', {
                params: {
                    page: page + 1,
                    per_page: rowsPerPage,
                    search,
                    statut,
                    site,
                    sort_by: sortBy,
                    sort_order: sortOrder,
                },
            });
            if (res.data?.success) {
                setRows(res.data.data || []);
                setTotal(res.data.total || 0);
                setStats(res.data.stats || null);
            } else {
                setError(res.data?.error || 'Erreur de chargement');
            }
        } catch (e: any) {
            setError(e?.response?.data?.error || e?.message || 'Erreur réseau');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        load();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [page, rowsPerPage, statut, site, sortBy, sortOrder]);

    const handleSort = (column: string) => {
        if (sortBy === column) {
            setSortOrder((p) => (p === 'asc' ? 'desc' : 'asc'));
        } else {
            setSortBy(column);
            setSortOrder('asc');
        }
        setPage(0);
    };

    const sortableColumns: { id: string; label: string; align?: 'right' }[] = [
        { id: 'Numéro du projet', label: 'Numéro' },
        { id: 'Nom du projet', label: 'Nom du projet' },
        { id: 'Site', label: 'Site' },
        { id: 'Secteur', label: 'Secteur' },
        { id: 'Chef de projet', label: 'Chef de projet' },
        { id: 'Statut Global', label: 'Statut' },
        { id: '% Complété', label: '% Complété' },
    ];

    return (
        <Box sx={{ p: 3 }}>
            <Box sx={{ mb: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 2 }}>
                <Box>
                    <Typography variant="h4" component="h1">Projets à reprendre</Typography>
                    <Typography variant="body2" color="text.secondary">
                        Liste de référence des projets à reprendre — raw_data.sharepoint_project_to_save
                    </Typography>
                </Box>
                <Button
                    variant="contained"
                    startIcon={refreshing ? <CircularProgress size={16} color="inherit" /> : <CloudDownloadIcon />}
                    onClick={refreshFromSharePoint}
                    disabled={refreshing || loading}
                >
                    {refreshing ? 'Mise à jour en cours…' : 'Mettre à jour depuis SharePoint'}
                </Button>
            </Box>

            {/* Puces de résumé */}
            {stats && (
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 2 }}>
                    {[
                        { label: 'projets', n: stats.total, c: '#0f766e' },
                        { label: 'en cours', n: stats.en_cours, c: '#2563eb' },
                        { label: 'clôturés', n: stats.clotures, c: '#64748b' },
                        { label: 'pas démarrés', n: stats.pas_demarre, c: '#0ea5e9' },
                        { label: 'dans migration', n: stats.in_migration, c: '#16a34a' },
                        { label: 'à reprendre par IFS', n: stats.a_reprendre_ifs, c: '#f59e0b' },
                    ].map((s) => (
                        <Box key={s.label} sx={{
                            display: 'flex', alignItems: 'baseline', gap: 0.75,
                            px: 1.5, py: 0.75, borderRadius: 2,
                            bgcolor: alpha(s.c, 0.08), border: `1px solid ${alpha(s.c, 0.25)}`,
                        }}>
                            <Typography sx={{ fontWeight: 800, color: s.c, fontSize: 17, lineHeight: 1 }}>{s.n}</Typography>
                            <Typography sx={{ opacity: 0.75, fontSize: 13 }}>{s.label}</Typography>
                        </Box>
                    ))}
                </Box>
            )}

            {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>{error}</Alert>}

            {/* Barre d'outils */}
            <Paper sx={{ mb: 2, p: 2, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
                <TextField
                    sx={{ flex: 1, minWidth: 260 }}
                    size="small"
                    placeholder="Rechercher par numéro, nom ou chef de projet…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (setPage(0), load())}
                    InputProps={{
                        startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment>,
                        endAdornment: search && (
                            <InputAdornment position="end">
                                <IconButton size="small" onClick={() => { setSearch(''); setPage(0); load(); }}>
                                    <CancelIcon fontSize="small" />
                                </IconButton>
                            </InputAdornment>
                        ),
                    }}
                />
                <FormControl size="small" sx={{ minWidth: 170 }}>
                    <InputLabel>Statut Global</InputLabel>
                    <Select value={statut} label="Statut Global" onChange={(e) => { setStatut(e.target.value); setPage(0); }}>
                        <MenuItem value="">Tous</MenuItem>
                        {STATUTS.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
                    </Select>
                </FormControl>
                <FormControl size="small" sx={{ minWidth: 210 }}>
                    <InputLabel>Site</InputLabel>
                    <Select value={site} label="Site" onChange={(e) => { setSite(e.target.value); setPage(0); }}>
                        <MenuItem value="">Tous</MenuItem>
                        {SITES.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
                    </Select>
                </FormControl>
            </Paper>

            <Paper>
                <TableContainer>
                    <Table size="small">
                        <TableHead>
                            <TableRow>
                                <TableCell sx={{ width: 40 }} />
                                {sortableColumns.map((col) => (
                                    <TableCell key={col.id} sortDirection={sortBy === col.id ? sortOrder : false}>
                                        <TableSortLabel
                                            active={sortBy === col.id}
                                            direction={sortBy === col.id ? sortOrder : 'asc'}
                                            onClick={() => handleSort(col.id)}
                                        >
                                            {col.label}
                                        </TableSortLabel>
                                    </TableCell>
                                ))}
                                <TableCell align="right">Budget Total SAP</TableCell>
                                <TableCell>Migration</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow><TableCell colSpan={10} align="center" sx={{ py: 5 }}><CircularProgress /></TableCell></TableRow>
                            ) : rows.length === 0 ? (
                                <TableRow><TableCell colSpan={10} align="center" sx={{ py: 4 }}>
                                    <Typography color="text.secondary">Aucun projet trouvé</Typography>
                                </TableCell></TableRow>
                            ) : rows.map((r, i) => {
                                const num = txt(r['Numéro du projet']);
                                const key = `${num}-${i}`;
                                const open = expanded === key;
                                const statutVal = txt(r['Statut Global']);
                                const completion = pct(r['% Complété']);
                                return (
                                    <React.Fragment key={key}>
                                        <TableRow hover onClick={() => setExpanded(open ? null : key)} sx={{ cursor: 'pointer', '& > td': { borderBottom: open ? 'unset' : undefined } }}>
                                            <TableCell>
                                                <IconButton size="small">
                                                    {open ? <ArrowUpIcon fontSize="small" /> : <ArrowDownIcon fontSize="small" />}
                                                </IconButton>
                                            </TableCell>
                                            <TableCell sx={{ fontFamily: 'monospace', fontWeight: 700, whiteSpace: 'nowrap' }}>{num}</TableCell>
                                            <TableCell sx={{ maxWidth: 320 }}>
                                                <Tooltip title={txt(r['Nom du projet'])}>
                                                    <Typography variant="body2" noWrap>{txt(r['Nom du projet'])}</Typography>
                                                </Tooltip>
                                            </TableCell>
                                            <TableCell sx={{ whiteSpace: 'nowrap' }}>{txt(r['Site'])}</TableCell>
                                            <TableCell>{txt(r['Secteur'])}</TableCell>
                                            <TableCell sx={{ whiteSpace: 'nowrap' }}>{txt(r['Chef de projet'])}</TableCell>
                                            <TableCell>
                                                {statutVal && <Chip label={statutVal} size="small" color={STATUT_COLOR[statutVal] || 'default'} />}
                                            </TableCell>
                                            <TableCell sx={{ minWidth: 110 }}>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <LinearProgress variant="determinate" value={completion} sx={{ width: 55, height: 6, borderRadius: 3 }} />
                                                    <Typography variant="caption">{txt(r['% Complété']) || '0%'}</Typography>
                                                </Box>
                                            </TableCell>
                                            <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>{txt(r['Budget Total SAP']) || '—'}</TableCell>
                                            <TableCell>
                                                {r.in_migration && r.migration_sharepoint_id ? (
                                                    <Tooltip title="Ouvrir la fiche projet dans Migration Factory">
                                                        <Chip
                                                            label="Dans migration"
                                                            size="small"
                                                            clickable
                                                            onClick={(e) => {
                                                                e.stopPropagation(); // ne pas déplier la ligne
                                                                navigate(`/projets/detail/${r.migration_sharepoint_id}`);
                                                            }}
                                                            sx={{
                                                                bgcolor: '#e8f5e9', color: '#2e7d32', fontWeight: 600,
                                                                '&:hover': { bgcolor: '#c8e6c9' },
                                                            }}
                                                        />
                                                    </Tooltip>
                                                ) : (
                                                    <Chip label="Non importé" size="small" sx={{ bgcolor: '#f5f5f5', color: '#757575' }} />
                                                )}
                                            </TableCell>
                                        </TableRow>
                                        <TableRow>
                                            <TableCell colSpan={10} sx={{ py: 0, borderBottom: open ? undefined : 'none' }}>
                                                <Collapse in={open} timeout="auto" unmountOnExit>
                                                    <Box sx={{ m: 1.5, p: 2, bgcolor: '#fafafa', borderRadius: 1 }}>
                                                        <Grid container spacing={2}>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Responsables">
                                                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', columnGap: 3 }}>
                                                                        <KV label="Chef de projet" value={txt(r['Chef de projet'])} />
                                                                        <KV label="Correspondant / Client" value={txt(r['Correspondant/ Client du projet'])} />
                                                                        <KV label="Acheteur CAPEX" value={txt(r['Acheteur CAPEX'])} />
                                                                        <KV label="Correspondant Maintenance" value={txt(r['Correspondant Maintenance'])} />
                                                                        <KV label="Sponsor" value={txt(r['Sponsor'])} />
                                                                        <KV label="Équipe projet" value={txt(r['Equipe projet'])} />
                                                                    </Box>
                                                                </Section>
                                                            </Grid>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Avancement">
                                                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', columnGap: 3 }}>
                                                                        <KV label="Statut Global" value={statutVal} />
                                                                        <KV label="Santé" value={txt(r['Santé'])} />
                                                                        <KV label="Coût" value={txt(r['Coût'])} />
                                                                        <KV label="Planning" value={txt(r['Planning'])} />
                                                                        <KV label="Phase" value={txt(r['Phase'])} />
                                                                        <KV label="Passage porte" value={txt(r['Passage porte'])} />
                                                                        <KV label="% Complété" value={txt(r['% Complété'])} />
                                                                    </Box>
                                                                </Section>
                                                            </Grid>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Jalons">
                                                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                                                                        {['P0', 'P1', 'P2', 'P3', 'P4', 'P6'].map((g) => {
                                                                            const d = txt(r[g]);
                                                                            return (
                                                                                <Box key={g} sx={{
                                                                                    px: 1.25, py: 0.5, borderRadius: 1, minWidth: 84, textAlign: 'center',
                                                                                    border: '1px solid', borderColor: d ? '#0f766e' : '#e0e0e0',
                                                                                    bgcolor: d ? alpha('#0f766e', 0.06) : 'transparent',
                                                                                }}>
                                                                                    <Typography variant="caption" sx={{ fontWeight: 700, color: d ? '#0f766e' : 'text.disabled' }}>{g}</Typography>
                                                                                    <Typography variant="caption" display="block" color={d ? 'text.primary' : 'text.disabled'}>
                                                                                        {d || '—'}
                                                                                    </Typography>
                                                                                </Box>
                                                                            );
                                                                        })}
                                                                    </Box>
                                                                    <Box mt={1}>
                                                                        <KV label="Date du dernier jalon passé" value={txt(r['Date du dernier jalon passé'])} />
                                                                    </Box>
                                                                </Section>
                                                            </Grid>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Commissions Feu Vert">
                                                                    {[
                                                                        { phase: 'Conception', etat: 'État CFV Conception', date: 'Date CFV Conception' },
                                                                        { phase: 'Mise en service', etat: 'État CFV Mise en service', date: 'Date CFV Mise en service' },
                                                                        { phase: 'Achèvement industriel', etat: 'État CFV Achèvement industriel', date: 'Date CFV Achèvement industriel' },
                                                                    ].map((c) => {
                                                                        const etat = txt(r[c.etat]);
                                                                        const color = CFV_COLOR[etat] || '#bdbdbd';
                                                                        return (
                                                                            <Box key={c.phase} sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.75 }}>
                                                                                <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: color, flexShrink: 0 }} />
                                                                                <Typography variant="body2" sx={{ minWidth: 165 }}>{c.phase}</Typography>
                                                                                <Typography variant="body2" sx={{ fontWeight: 600, minWidth: 70 }}>{etat || '—'}</Typography>
                                                                                <Typography variant="caption" color="text.secondary">{txt(r[c.date])}</Typography>
                                                                            </Box>
                                                                        );
                                                                    })}
                                                                </Section>
                                                            </Grid>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Budgets">
                                                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', columnGap: 3 }}>
                                                                        <KV label="Budget Initial" value={txt(r['Budget Initial'])} />
                                                                        <KV label="Budget Total SAP" value={txt(r['Budget Total SAP'])} />
                                                                        <KV label="Engagé" value={txt(r['Engagé'])} />
                                                                        <KV label="Réceptionné" value={txt(r['Réceptionné'])} />
                                                                        <KV label="Pris en charge" value={txt(r['Pris en charge'])} />
                                                                        <KV label="Reste à engager" value={txt(r['Reste à engager'])} />
                                                                        <KV label="Budget demandé" value={txt(r['Budget demandé'])} />
                                                                        <KV label="Budget 1ère P3" value={txt(r['Budget 1ère P3'])} />
                                                                        <KV label="Budget EX SAP" value={txt(r['Budget EX SAP'])} />
                                                                        <KV label="Budget IM SAP" value={txt(r['Budget IM SAP'])} />
                                                                        <KV label="Numéro de crédit" value={txt(r['Numéro de crédit'])} />
                                                                        <KV label="Date ouverture crédit" value={txt(r['Date ouverture crédit'])} />
                                                                    </Box>
                                                                </Section>
                                                            </Grid>
                                                            <Grid item xs={12} md={6}>
                                                                <Section title="Dates & référence">
                                                                    <Box sx={{ display: 'flex', flexWrap: 'wrap', columnGap: 3 }}>
                                                                        <KV label="Date de début" value={txt(r['Date de début'])} />
                                                                        <KV label="Date de fin estimée" value={txt(r['Date de fin estimée'])} />
                                                                        <KV label="Dernière MAJ état d'avancement" value={txt(r["Dernière MAJ de l'état d'avancement"])} />
                                                                        <KV label="URL du site" value={txt(r['URL du site'])} />
                                                                    </Box>
                                                                </Section>
                                                            </Grid>
                                                        </Grid>
                                                    </Box>
                                                </Collapse>
                                            </TableCell>
                                        </TableRow>
                                    </React.Fragment>
                                );
                            })}
                        </TableBody>
                    </Table>
                </TableContainer>

                <TablePagination
                    component="div"
                    count={total}
                    page={page}
                    onPageChange={(_e, p) => setPage(p)}
                    rowsPerPage={rowsPerPage}
                    onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
                    rowsPerPageOptions={[25, 50, 100]}
                    labelRowsPerPage="Lignes par page:"
                    labelDisplayedRows={({ from, to, count }) => `${from}-${to} sur ${count}`}
                />
            </Paper>

            <Snackbar
                open={snack.open}
                autoHideDuration={5000}
                onClose={() => setSnack((s) => ({ ...s, open: false }))}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
            >
                <Alert
                    severity={snack.severity}
                    onClose={() => setSnack((s) => ({ ...s, open: false }))}
                    sx={{ width: '100%' }}
                >
                    {snack.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default ProjetsAReprendre;
