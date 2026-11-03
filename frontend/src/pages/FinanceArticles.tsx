import {
    Calculate as CalculIcon,
    FileDownload as ExcelIcon,
    FileUpload as ImportIcon,
    Inventory2 as ArticleIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
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
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

// Même logique que FinanceFournisseurs : date d'arrêté, Calculer / Synchroniser SAP, import du fichier validé.
// Source : clean_data.article_perimetre (sql/articleSap/article_perimetre.sql), colonnes de clean_data.v_article_sap
// (écran Données SAP > Articles).

type Row = Record<string, string | number | boolean | null>;

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Colonne { key: string; label: string }

interface ListResponse {
  rows: Row[];
  total: number;
  stats: { total: number; fichier: number; sap_nouveau: number; date_arrete: string | null };
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

const formatDate = (v?: string | null) => (v ? new Date(v).toLocaleDateString('fr-FR') : '');
const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceArticles: React.FC = () => {
  const navigate = useNavigate();
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [source, setSource] = useState('');
  const [dateArrete, setDateArrete] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/articles', {
        params: { search, source, page: page + 1, page_size: pageSize },
      });
      setData(res.data);
      setSync(res.data.sync);
      setDateArrete((d) => d || res.data.stats.date_arrete || '');
    } catch (err) {
      console.error('Erreur chargement articles:', err);
      setError('Erreur lors du chargement des articles');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, source]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/articles/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  const handleSync = async (src: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/articles/sync', { source: src, date_arrete: dateArrete || null });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) setSync(err.response.data);
      else setError(err?.response?.data?.error ?? 'Impossible de lancer le calcul');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/articles/export.xlsx', { params: { search, source }, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'articles.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel articles:', err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;
  const colonnes = data?.colonnes ?? [];

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ArticleIcon sx={{ fontSize: 32, color: '#00838f' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Articles
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1, alignItems: 'center', flexWrap: 'wrap' }}>
          <Tooltip title="Les articles créés dans SAP à partir de cette date, absents des fichiers validés, sont ajoutés au périmètre (SAP_NOUVEAU)">
            <TextField
              size="small"
              type="date"
              label="Date d'arrêté"
              value={dateArrete}
              onChange={(e) => setDateArrete(e.target.value)}
              InputLabelProps={{ shrink: true }}
            />
          </Tooltip>
          <Tooltip title="Recalcule le périmètre depuis les fichiers validés et la table des articles SAP déjà chargée, avec la date d'arrêté saisie, sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<CalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Calculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP les tables articles (MARA, MAKT, MARC…), rejoue les modules ETL articles comme l'écran Données SAP > Articles, puis recalcule le périmètre">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Assistant d'import (comme l'import générique) : mapping des colonnes du fichier validé, N° article obligatoire, autres colonnes conservées ; les articles du fichier passent en FICHIER puis le périmètre est recalculé avec la date de validation">
            <span>
              <Button variant="outlined" startIcon={<ImportIcon />} onClick={() => navigate('/finance/articles/import')} disabled={running}>
                Importer le fichier validé
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Classeur Excel des articles filtrés (recherche, source), toutes colonnes">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Alert severity="info" sx={{ mb: 2 }}>
        FICHIER = article des fichiers validés par le métier (la référence, même absent de SAP : ses colonnes SAP restent
        vides) ; SAP_NOUVEAU = article de Données SAP &gt; Articles créé dans SAP (date de création MARA) à partir de la
        date d'arrêté et absent des fichiers validés. Les colonnes « Fichier · … » viennent des fichiers importés.
      </Alert>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.total.toLocaleString('fr-FR')} articles`} color="primary" />
          <Chip label={`${stats.fichier.toLocaleString('fr-FR')} FICHIER`} />
          <Chip label={`${stats.sap_nouveau.toLocaleString('fr-FR')} SAP_NOUVEAU`} color="warning" />
          {stats.date_arrete && <Chip label={`Date d'arrêté du chargement : ${formatDate(stats.date_arrete)}`} variant="outlined" />}
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
          Dernier calcul le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} articles chargés.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Échec le {formatDateTime(sync.finished_at)} : {sync.error}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}


      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="N° article, description, ancien numéro…"
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
        <FormControl size="small" sx={{ minWidth: 170 }}>
          <InputLabel>Source</InputLabel>
          <Select label="Source" value={source} onChange={(e) => { setPage(0); setSource(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            <MenuItem value="FICHIER">FICHIER</MenuItem>
            <MenuItem value="SAP_NOUVEAU">SAP_NOUVEAU</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 460px)', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{c.label}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r, i) => (
                <TableRow key={i} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} sx={{ whiteSpace: 'nowrap', maxWidth: 400, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {c.key === 'source' && r.source
                        ? <Chip size="small" label={String(r.source)} color={r.source === 'SAP_NOUVEAU' ? 'warning' : 'default'} />
                        : String(r[c.key] ?? '')}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">
                    Aucune ligne : lancer « Calculer » (ou « Synchroniser SAP » si les articles SAP n'ont jamais été chargés)
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

export default FinanceArticles;
