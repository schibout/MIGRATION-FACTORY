import {
    Cached as RecalculIcon,
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

// Onglet « commandes » = table à plat commande_achat_ifs ; les trois autres = objets de
// reprise IFS (Lot 11) remplis par clean_data.alimenter_purchase_order().
type Vue = 'commandes' | 'purchase_order' | 'purchase_order_line_part' | 'purchase_order_line_nopart';

interface IfsResponse {
  colonnes: string[];
  rows: CdeRow[];
  total: number;
  sync: SyncStatus | null;
}

// Colonnes affichées par défaut dans les onglets IFS (« Toutes les colonnes » montre le reste)
const IFS_PRINCIPALES: Record<Exclude<Vue, 'commandes'>, string[]> = {
  purchase_order: ['order_no', 'contract', 'vendor_no', 'invoicing_supplier', 'currency_code', 'pay_term_id',
    'delivery_terms', 'del_terms_location', 'ship_via_code', 'addr_no', 'pre_accounting_id', 'date_entered',
    'order_date', 'wanted_receipt_date', 'buyer_code', 'address1', 'city'],
  purchase_order_line_part: ['order_no', 'line_no', 'contract', 'part_no', 'description', 'buy_qty_due',
    'buy_unit_meas', 'buy_unit_price', 'currency_code', 'currency_rate', 'planned_delivery_date',
    'promised_delivery_date', 'pre_accounting_id', 'invoicing_supplier'],
  purchase_order_line_nopart: ['order_no', 'line_no', 'contract', 'description', 'buy_qty_due', 'buy_unit_meas',
    'buy_unit_price', 'currency_code', 'currency_rate', 'planned_delivery_date', 'promised_delivery_date',
    'pre_accounting_id', 'invoicing_supplier'],
};

const ONGLETS: { value: Vue; label: string; description: string }[] = [
  { value: 'commandes', label: "Commandes d'achat SAP",
    description: "Commandes d'achat SAP ouvertes de la société STJN (postes non clos, reliquat à livrer), au format de reprise IFS." },
  { value: 'purchase_order', label: 'Purchase order',
    description: 'En-têtes IFS (PURCHASE_ORDER) : une ligne par commande éligible, identifiants IFS (fournisseur, adresse, condition de paiement) résolus par jointure.' },
  { value: 'purchase_order_line_part', label: 'Order line part',
    description: "Lignes IFS avec article (PURCHASE_ORDER_LINE_PART) : postes dont l'article existe dans le catalogue IFS (part_catalog)." },
  { value: 'purchase_order_line_nopart', label: 'Order line no part',
    description: 'Lignes IFS sans article (PURCHASE_ORDER_LINE_NOPART).' },
];

// Les dates IFS arrivent en ISO ('2026-09-01T00:00:00') : affichées JJ/MM/AAAA
const formatIfs = (v: string | number | null) => {
  if (v == null || v === '') return '';
  if (typeof v === 'number') return v.toLocaleString('fr-FR');
  const iso = /^(\d{4})-(\d{2})-(\d{2})(T00:00:00)?$/.exec(v);
  return iso ? `${iso[3]}/${iso[2]}/${iso[1]}` : v;
};

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
  const [vue, setVue] = useState<Vue>('commandes');
  const [data, setData] = useState<ListResponse | null>(null);
  const [ifs, setIfs] = useState<IfsResponse | null>(null);
  const [sites, setSites] = useState<string[]>([]);
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
      const params = { page: page + 1, page_size: pageSize, search, site };
      if (vue === 'commandes') {
        const res = await api.get<ListResponse>('/finance/commandes-achat', { params });
        setData(res.data);
        setSites(res.data.sites);
        setSync(res.data.sync);
      } else {
        const res = await api.get<IfsResponse>(`/finance/commandes-achat/ifs/${vue}`, { params });
        setIfs(res.data);
        setSync(res.data.sync);
      }
    } catch (err) {
      console.error("Erreur chargement commandes d'achat:", err);
      setError("Erreur lors du chargement des commandes d'achat");
    } finally {
      setLoading(false);
    }
  }, [vue, page, pageSize, search, site]);

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

  // 'sap' : extraction SAP puis rechargement ; 'mf' : rechargement seul depuis raw_data
  // (commande_achat_ifs puis dispatch alimenter_purchase_order)
  const handleSync = async (source: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/commandes-achat/sync', { source });
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
        params: { search, site, vue: vue === 'commandes' ? undefined : vue },
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
  const isIfs = vue !== 'commandes';
  const total = isIfs ? ifs?.total : data?.total;
  const colonnesIfs = vue === 'commandes'
    ? []
    : (ifs?.colonnes ?? []).filter((c) => toutes || IFS_PRINCIPALES[vue].includes(c));
  const nbColonnes = isIfs ? colonnesIfs.length : colonnes.length;

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
                disabled={exporting || !total}
              >
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Recharge les commandes depuis les tables SAP déjà extraites dans Migration Factory, puis exécute la procédure de dispatch vers Purchase order / Order line part / Order line no part (valeurs par défaut et transcodifications appliquées), sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<RecalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Recalculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP EKKO, EKPO, EKBE, EKET, EKPA, EKKN, LFA1, T001W, ADRC, PRPS, recharge la table puis exécute le dispatch IFS">
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

      {isIfs && ifs && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
          <Chip label={`${ifs.total.toLocaleString('fr-FR')} lignes`} color="primary" />
        </Box>
      )}

      {!isIfs && stats && (
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
          placeholder={isIfs ? 'N° commande (S…), fournisseur, article, description…' : 'N° commande, fournisseur, article, désignation…'}
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
            {sites.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
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
                {colonnesIfs.map((c) => (
                  <TableCell key={c} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{c.toUpperCase()}</TableCell>
                ))}
                {!isIfs && colonnes.map((c) => (
                  <TableCell key={c.key} align={c.kind ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
                    {c.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {isIfs && ifs?.rows.map((r) => (
                <TableRow key={`${r.order_no}-${r.line_no ?? ''}`} hover>
                  {colonnesIfs.map((c) => (
                    <TableCell key={c} align={typeof r[c] === 'number' ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {formatIfs(r[c])}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {!isIfs && data?.rows.map((r) => (
                <TableRow key={`${r.num_commande_sap}-${r.num_ligne_sap}`} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} align={c.kind ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {formatCell(r[c.key], c.kind)}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {((isIfs && ifs?.rows.length === 0) || (!isIfs && data?.rows.length === 0)) && (
                <TableRow>
                  <TableCell colSpan={nbColonnes} align="center">
                    {isIfs ? 'Aucune ligne : lancer « Recalculer » pour exécuter le dispatch' : "Aucune commande d'achat"}
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <TablePagination
          component="div"
          count={total ?? 0}
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
