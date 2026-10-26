import {
    Cached as RecalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
    Timeline as HistoriqueIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    FormControl,
    InputAdornment,
    InputLabel,
    LinearProgress,
    MenuItem,
    Paper,
    Select,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    Tabs,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import api from '../services/api';

// Même logique que FinanceCommandesAchat : liste paginée, export Excel, Recalculer / Synchroniser SAP.
// Source : clean_data.historique_cout_projet (RPSCO ledger 0003, cf. docs/zcoa_credits_investissement_raw_data.sql).

type Row = Record<string, string | number | null>;
type Vue = 'projet' | 'otp';

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Colonne { key: string; label: string; kind: 'montant' | 'text' }

interface Stats {
  lignes: number;
  projets: number;
  reel: number | null;
  plan: number | null;
  budget_annuel: number | null;
  engag_cde: number | null;
  engag_da: number | null;
}

interface ListResponse {
  rows: Row[];
  total: number;
  stats: Stats;
  annees: number[];
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

const ONGLETS: { value: Vue; label: string; description: string }[] = [
  { value: 'projet', label: 'Par projet',
    description: "Une ligne par projet SAP, année et période (tous les éléments d'OTP du projet cumulés). Réel cumulé = depuis le début de l'historique." },
  { value: 'otp', label: "Par élément d'OTP",
    description: "Une ligne par élément d'OTP, année et période. Réel cumulé = depuis le début de l'historique de l'OTP." },
];

const euros = (v: number | null | undefined) =>
  v == null ? '—' : v.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatCell = (v: string | number | null, kind: Colonne['kind']) => {
  if (v == null || v === '') return '';
  return kind === 'montant' ? euros(Number(v)) : String(v);
};

const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceHistoriqueCouts: React.FC = () => {
  const [vue, setVue] = useState<Vue>('projet');
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [anneeDebut, setAnneeDebut] = useState('');
  const [anneeFin, setAnneeFin] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);

  const filtres = { vue, search, annee_debut: anneeDebut, annee_fin: anneeFin };

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/historique-couts', {
        params: { vue, search, annee_debut: anneeDebut, annee_fin: anneeFin, page: page + 1, page_size: pageSize },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement historique des coûts:', err);
      setError("Erreur lors du chargement de l'historique des coûts");
    } finally {
      setLoading(false);
    }
  }, [vue, page, pageSize, search, anneeDebut, anneeFin]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/historique-couts/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  // 'sap' : extraction RPSCO/PRPS/PROJ puis rechargement ; 'mf' : rechargement seul depuis raw_data
  const handleSync = async (source: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/historique-couts/sync', { source });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) setSync(err.response.data);
      else setError('Impossible de lancer la synchronisation');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/historique-couts/export.xlsx', { params: filtres, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'historique_couts.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel historique des coûts:', err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;
  const colonnes = data?.colonnes ?? [];
  const annees = data?.annees ?? [];

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <HistoriqueIcon sx={{ fontSize: 32, color: '#3949ab' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Historique des coûts par projet
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Tooltip title="Classeur Excel des lignes filtrées (toutes les pages) de l'onglet affiché">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Recharge l'historique depuis les tables SAP déjà extraites (RPSCO, PRPS, PROJ), sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<RecalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Recalculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP RPSCO, PRPS, PROJ puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Tabs value={vue} onChange={(_, v: Vue) => { setVue(v); setPage(0); }} sx={{ mb: 2 }}>
        {ONGLETS.map((o) => <Tab key={o.value} value={o.value} label={o.label} />)}
      </Tabs>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        {ONGLETS.find((o) => o.value === vue)?.description}
      </Typography>

      <Alert severity="info" sx={{ mb: 2 }}>
        Société STJN, ledger RPSCO 0003, montants en EUR. Réel = valeurs réelles (WRTTP 04) hors répartition KOAO,
        Plan = 01, Budget annuel = 41 en période 0 (le budget global sans année est exclu), Commandes non
        réceptionnées = 22, Demandes d'achat = 21 (engagements rangés par période de livraison prévue : encours actuel).
        Les ordres d'investissement (IM01) ne sont pas couverts : COEP, COOI et BPGE ne sont pas extraites.
      </Alert>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.projets.toLocaleString('fr-FR')} projets`} color="primary" />
          <Chip label={`${stats.lignes.toLocaleString('fr-FR')} lignes`} />
          <Chip label={`Réel : ${euros(stats.reel)} €`} color="success" />
          <Chip label={`Budget annuel : ${euros(stats.budget_annuel)} €`} />
          <Chip label={`Plan : ${euros(stats.plan)} €`} />
          <Chip label={`Cdes non réceptionnées : ${euros(stats.engag_cde)} €`} />
          <Chip label={`DA : ${euros(stats.engag_da)} €`} />
        </Box>
      )}

      {running && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {sync?.step} — démarrée le {formatDateTime(sync?.started_at)}
          <LinearProgress variant="determinate" value={sync?.progress ?? 0} sx={{ mt: 1 }} />
        </Alert>
      )}
      {sync?.status === 'completed' && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Dernière synchronisation le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} lignes chargées.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Synchronisation en échec le {formatDateTime(sync.finished_at)} : {sync.error}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="Projet, N° projet, désignation, responsable, élément OTP…"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              setPage(0);
              setSearch(searchInput);
            }
          }}
          sx={{ minWidth: 380 }}
          InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
        />
        <FormControl size="small" sx={{ minWidth: 130 }}>
          <InputLabel>Année de</InputLabel>
          <Select label="Année de" value={anneeDebut} onChange={(e) => { setPage(0); setAnneeDebut(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {annees.map((a) => <MenuItem key={a} value={String(a)}>{a}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 130 }}>
          <InputLabel>Année à</InputLabel>
          <Select label="Année à" value={anneeFin} onChange={(e) => { setPage(0); setAnneeFin(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {annees.map((a) => <MenuItem key={a} value={String(a)}>{a}</MenuItem>)}
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 480px)', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} align={c.kind === 'montant' ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {c.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r) => (
                <TableRow key={`${r.projet}-${r.element_otp ?? ''}-${r.annee}-${r.periode}`} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} align={c.kind === 'montant' ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {formatCell(r[c.key], c.kind)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">
                    Aucune ligne : lancer « Recalculer » (ou « Synchroniser SAP » si RPSCO n'a jamais été extraite)
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination
          component="div"
          count={data?.total ?? 0}
          page={page}
          rowsPerPage={pageSize}
          rowsPerPageOptions={[25, 50, 100, 250]}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => { setPageSize(parseInt(e.target.value, 10)); setPage(0); }}
          labelRowsPerPage="Lignes par page"
        />
      </Paper>
    </Box>
  );
};

export default FinanceHistoriqueCouts;
