import {
    Calculate as CalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Store as FournisseurIcon,
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
import api from '../services/api';

// Même logique que FinanceHistoriqueCouts : liste paginée, export Excel, Calculer / Synchroniser SAP.
// Source : clean_data.ifs_fournisseurs_perimetre (sql/supplier/01b_alimenter_ifs_fournisseurs_perimetre.sql).

type Row = Record<string, string | number | null>;

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Colonne { key: string; label: string; kind: 'date' | 'text' }

interface ListResponse {
  rows: Row[];
  total: number;
  stats: { total: number; fichier: number; sap_nouveau: number; date_arrete: string | null };
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

const formatCell = (v: string | number | null, kind: Colonne['kind']) => {
  if (v == null || v === '') return '';
  return kind === 'date' ? new Date(String(v)).toLocaleDateString('fr-FR') : String(v);
};

const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceFournisseurs: React.FC = () => {
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
      const res = await api.get<ListResponse>('/finance/fournisseurs', {
        params: { search, source, page: page + 1, page_size: pageSize },
      });
      setData(res.data);
      setSync(res.data.sync);
      // Pré-remplit la date avec celle du dernier chargement, sans écraser une saisie
      setDateArrete((d) => d || res.data.stats.date_arrete || '');
    } catch (err) {
      console.error('Erreur chargement fournisseurs:', err);
      setError('Erreur lors du chargement des fournisseurs');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, source]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/fournisseurs/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  // 'sap' : extraction LFA1, LFB1... puis rechargement ; 'mf' : rechargement seul depuis raw_data
  const handleSync = async (src: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/fournisseurs/sync', { source: src, date_arrete: dateArrete || null });
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
      const res = await api.get('/finance/fournisseurs/export.xlsx', { params: { search, source }, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'fournisseurs.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel fournisseurs:', err);
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
        <FournisseurIcon sx={{ fontSize: 32, color: '#6d4c41' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Fournisseurs
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1, alignItems: 'center', flexWrap: 'wrap' }}>
          <Tooltip title="Les fournisseurs absents du fichier et créés dans SAP à partir de cette date sont repris (source SAP_NOUVEAU)">
            <TextField
              size="small"
              type="date"
              label="Date d'arrêté"
              value={dateArrete}
              onChange={(e) => setDateArrete(e.target.value)}
              InputLabelProps={{ shrink: true }}
            />
          </Tooltip>
          <Tooltip title="Recharge la table depuis le fichier de sélection et les tables SAP déjà extraites, avec la date d'arrêté saisie, sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<CalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Calculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP LFA1, LFB1, LFM1, LFBK, TIBAN, BNKA puis recharge la table avec la date d'arrêté saisie">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Classeur Excel des lignes filtrées (toutes les pages)">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Alert severity="info" sx={{ mb: 2 }}>
        FICHIER = fournisseur du fichier de sélection (valeurs du fichier, complétées par SAP) ; SAP_NOUVEAU = fournisseur
        absent du fichier, créé dans SAP à partir de la date d'arrêté, non marqué pour suppression et hors employés (groupes de comptes ZPER, ZPE1, P001) (données SAP seules,
        sans N° IFS). Coordonnées bancaires : LFBK / TIBAN / BNKA.
      </Alert>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.total.toLocaleString('fr-FR')} fournisseurs`} color="primary" />
          <Chip label={`${stats.fichier.toLocaleString('fr-FR')} FICHIER`} />
          <Chip label={`${stats.sap_nouveau.toLocaleString('fr-FR')} SAP_NOUVEAU`} color="warning" />
          {stats.date_arrete && <Chip label={`Date d'arrêté du chargement : ${formatCell(stats.date_arrete, 'date')}`} variant="outlined" />}
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
          Dernier calcul le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} fournisseurs chargés.
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
          placeholder="N° SAP, N° IFS, nom, localité, SIRET, TVA…"
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
              {data?.rows.map((r) => (
                <TableRow key={String(r.numero_compte_fournisseur)} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} sx={{ whiteSpace: 'nowrap' }}>
                      {c.key === 'source' && r.source
                        ? <Chip size="small" label={r.source} color={r.source === 'SAP_NOUVEAU' ? 'warning' : 'default'} />
                        : formatCell(r[c.key], c.kind)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">
                    Aucun fournisseur : lancer « Calculer » (ou « Synchroniser SAP » si LFA1 n'a jamais été extraite)
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

export default FinanceFournisseurs;
