import {
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    ShoppingCart as CommandeAchatIcon,
    Sync as SyncIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    FormControl,
    FormControlLabel,
    InputAdornment,
    InputLabel,
    LinearProgress,
    MenuItem,
    Paper,
    Select,
    Switch,
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

// Même logique que FinanceImmobilisations : liste, export Excel, synchronisation SAP.

type CdeRow = Record<string, string | number | null>;

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
}

interface Stats {
  lignes: number;
  commandes: number;
  fournisseurs: number;
  restant_livrer_eur: number | null;
  restant_facturer_eur: number | null;
}

interface ListResponse {
  rows: CdeRow[];
  total: number;
  stats: Stats;
  sites: string[];
  sync: SyncStatus | null;
}

type Kind = 'text' | 'montant' | 'nombre';

// Colonnes de clean_data.commande_achat_ifs (dates déjà au format JJ/MM/AAAA en base).
const COLONNES: { key: string; label: string; kind?: Kind; principale?: boolean }[] = [
  { key: 'site', label: 'Site', principale: true },
  { key: 'societe_sap', label: 'Société SAP' },
  { key: 'num_commande_sap', label: 'N° commande SAP', principale: true },
  { key: 'num_ligne_sap', label: 'N° ligne', principale: true },
  { key: 'fournisseur_sap', label: 'Fournisseur SAP', principale: true },
  { key: 'fournisseur_ifs', label: 'Fournisseur IFS', principale: true },
  { key: 'nom_fournisseur', label: 'Nom fournisseur', principale: true },
  { key: 'fournisseur_facturation_sap', label: 'Fournisseur facturation SAP' },
  { key: 'fournisseur_facturation_ifs', label: 'Fournisseur facturation IFS' },
  { key: 'type_ligne_ifs', label: 'Type ligne IFS' },
  { key: 'article_sap', label: 'Article SAP', principale: true },
  { key: 'designation', label: 'Désignation', principale: true },
  { key: 'qte_commandee', label: 'Qté commandée', kind: 'nombre', principale: true },
  { key: 'qte_restant_livrer', label: 'Qté restant à livrer', kind: 'nombre', principale: true },
  { key: 'qte_restant_facturer', label: 'Qté restant à facturer', kind: 'nombre' },
  { key: 'unite_achat', label: "Unité d'achat", principale: true },
  { key: 'prix_net_unitaire', label: 'Prix net unitaire', kind: 'montant', principale: true },
  { key: 'montant_restant_livrer', label: 'Montant restant à livrer', kind: 'montant', principale: true },
  { key: 'montant_restant_facturer', label: 'Montant restant à facturer', kind: 'montant' },
  { key: 'devise', label: 'Devise', principale: true },
  { key: 'taux_change', label: 'Taux de change' },
  { key: 'date_creation', label: 'Date création', principale: true },
  { key: 'date_livraison_planifiee', label: 'Date livraison planifiée', principale: true },
  { key: 'date_reception_souhaitee', label: 'Date réception souhaitée' },
  { key: 'date_livraison_promise', label: 'Date livraison promise' },
  { key: 'acheteur_sap', label: 'Acheteur SAP' },
  { key: 'condition_paiement', label: 'Condition de paiement' },
  { key: 'condition_livraison', label: 'Condition de livraison' },
  { key: 'mode_expedition', label: "Mode d'expédition" },
  { key: 'adresse_livraison', label: 'Adresse de livraison' },
  { key: 'code_postal_livraison', label: 'Code postal' },
  { key: 'ville_livraison', label: 'Ville' },
  { key: 'pays_livraison', label: 'Pays' },
  { key: 'pre_imputation_projet', label: 'Pré-imputation projet' },
];

const euros = (v: number | null | undefined) =>
  v == null ? '—' : v.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatCell = (v: string | number | null, kind?: Kind) => {
  if (v == null || v === '') return '';
  if (kind === 'montant') return euros(Number(v));
  if (kind === 'nombre') return Number(v).toLocaleString('fr-FR');
  return String(v);
};

const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceCommandesAchat: React.FC = () => {
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [site, setSite] = useState('');
  const [toutes, setToutes] = useState(false);
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);

  const colonnes = toutes ? COLONNES : COLONNES.filter((c) => c.principale);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/commandes-achat', {
        params: { page: page + 1, page_size: pageSize, search, site },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error("Erreur chargement commandes d'achat:", err);
      setError("Erreur lors du chargement des commandes d'achat");
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, site]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/commandes-achat/sync');
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [sync?.status, load]);

  const handleSync = async () => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/commandes-achat/sync');
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) {
        setSync(err.response.data);
      } else {
        setError('Impossible de lancer la synchronisation');
      }
    }
  };

  // Export Excel des lignes filtrées (toutes les pages, toutes les colonnes)
  const handleExportExcel = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/commandes-achat/export.xlsx', {
        params: { search, site },
        responseType: 'blob',
      });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'commandes_achat.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error("Erreur export Excel commandes d'achat:", err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <CommandeAchatIcon sx={{ fontSize: 32, color: '#00897b' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Commandes d'achat
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Tooltip title="Classeur Excel des lignes filtrées (toutes les pages, toutes les colonnes)">
            <span>
              <Button
                variant="outlined"
                color="success"
                startIcon={<ExcelIcon />}
                onClick={handleExportExcel}
                disabled={exporting || !data?.total}
              >
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP EKKO, EKPO, EKBE, EKET, EKPA, EKKN, LFA1, T001W, ADRC, PRPS puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={handleSync} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Commandes d'achat SAP ouvertes de la société STJN (postes non clos, reliquat à livrer), au format de reprise IFS.
      </Typography>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.commandes.toLocaleString('fr-FR')} commandes`} color="primary" />
          <Chip label={`${stats.lignes.toLocaleString('fr-FR')} lignes`} />
          <Chip label={`${stats.fournisseurs.toLocaleString('fr-FR')} fournisseurs`} />
          <Chip label={`Restant à livrer : ${euros(stats.restant_livrer_eur)} € (EUR)`} color="success" />
          <Chip label={`Restant à facturer : ${euros(stats.restant_facturer_eur)} € (EUR)`} />
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
          placeholder="N° commande, fournisseur, article, désignation…"
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
        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel>Site</InputLabel>
          <Select label="Site" value={site} onChange={(e) => { setPage(0); setSite(e.target.value); }}>
            <MenuItem value="">Tous</MenuItem>
            {data?.sites.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControlLabel
          control={<Switch checked={toutes} onChange={(e) => setToutes(e.target.checked)} />}
          label="Toutes les colonnes"
        />
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 420px)' }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} align={c.kind ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {c.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r) => (
                <TableRow key={`${r.num_commande_sap}-${r.num_ligne_sap}`} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} align={c.kind ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {formatCell(r[c.key], c.kind)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data && data.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length} align="center">Aucune commande d'achat</TableCell>
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

export default FinanceCommandesAchat;
