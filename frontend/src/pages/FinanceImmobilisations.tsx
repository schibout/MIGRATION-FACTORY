import {
    AccountBalance as ImmobilisationIcon,
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
import api from '../services/api';

type ImmoRow = Record<string, string | boolean | null>;

interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  started_at?: string;
  finished_at?: string | null;
  started_by?: string;
}

interface ListResponse {
  rows: ImmoRow[];
  total: number;
  stats: { lignes: number; immobilisations: number; societes: number };
  societes: string[];
  zones: { afabe: string; libelle: string | null }[];
  sync: SyncStatus | null;
}

// Colonnes affichées (clé = colonne de clean_data.immobilisation)
const COLONNES: { key: string; label: string }[] = [
  { key: 'bukrs', label: 'Société' },
  { key: 'anln1', label: 'Immobilisation' },
  { key: 'anln2', label: 'Sous-n°' },
  { key: 'designation', label: 'Désignation' },
  { key: 'classe_immo', label: 'Classe' },
  { key: 'ktogr_immo', label: 'Groupe comptes' },
  { key: 'ktogr_libelle', label: 'Libellé groupe' },
  { key: 'afabe', label: 'Zone' },
  { key: 'afabe_libelle', label: 'Libellé zone' },
  { key: 'cpt_valeur_acquisition', label: 'Cpt acquisition' },
  { key: 'cpt_amort_cumules', label: 'Cpt amort. cumulés' },
  { key: 'cpt_dotation_amort', label: 'Cpt dotation' },
  { key: 'cpt_produit_cession', label: 'Cpt produit cession' },
  { key: 'cpt_vnc_cession', label: 'Cpt VNC cession' },
  { key: 'cpt_vnc_mise_au_rebut', label: 'Cpt mise au rebut' },
  { key: 'cpt_contrepartie_acq', label: 'Cpt contrepartie acq.' },
  { key: 'cpt_amort_deroga_bilan', label: 'Cpt dérog. bilan' },
  { key: 'cpt_amort_deroga_charge', label: 'Cpt dérog. charge' },
  { key: 'cpt_amort_except_bilan', label: 'Cpt except. bilan' },
  { key: 'cpt_amort_except_charge', label: 'Cpt except. charge' },
];

const formatDate = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceImmobilisations: React.FC = () => {
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [bukrs, setBukrs] = useState('');
  const [afabe, setAfabe] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/immobilisations', {
        params: { page: page + 1, page_size: pageSize, search, bukrs, afabe },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement immobilisations:', err);
      setError('Erreur lors du chargement des immobilisations');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, bukrs, afabe]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>('/finance/immobilisations/sync');
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
      const res = await api.post<SyncStatus>('/finance/immobilisations/sync');
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) {
        setSync(err.response.data);
      } else {
        setError('Impossible de lancer la synchronisation');
      }
    }
  };

  const running = sync?.status === 'running';

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ImmobilisationIcon sx={{ fontSize: 32, color: '#5d4037' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Immobilisations
        </Typography>
        <Box sx={{ ml: 'auto' }}>
          <Tooltip title="Ré-extrait de SAP les tables ANLA, ANKA, T001, T093, T093T, T095, T095B, T095T puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={handleSync} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      {data && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${data.stats.immobilisations.toLocaleString('fr-FR')} immobilisations`} color="primary" />
          <Chip label={`${data.stats.lignes.toLocaleString('fr-FR')} lignes (immo × zone)`} />
          <Chip label={`${data.stats.societes} sociétés`} />
        </Box>
      )}

      {running && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {sync?.step} — démarrée le {formatDate(sync?.started_at)}
          <LinearProgress variant="determinate" value={sync?.progress ?? 0} sx={{ mt: 1 }} />
        </Alert>
      )}
      {sync?.status === 'completed' && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Dernière synchronisation le {formatDate(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} lignes chargées.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Synchronisation en échec le {formatDate(sync.finished_at)} : {sync.error}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <TextField
          size="small"
          placeholder="N° immo, désignation, classe, compte…"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              setPage(0);
              setSearch(searchInput);
            }
          }}
          sx={{ minWidth: 320 }}
          InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
        />
        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel>Société</InputLabel>
          <Select label="Société" value={bukrs} onChange={(e) => { setPage(0); setBukrs(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {data?.societes.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 240 }}>
          <InputLabel>Zone d'amortissement</InputLabel>
          <Select label="Zone d'amortissement" value={afabe} onChange={(e) => { setPage(0); setAfabe(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            {data?.zones.map((z) => (
              <MenuItem key={z.afabe} value={z.afabe}>{z.afabe}{z.libelle ? ` — ${z.libelle}` : ''}</MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 380px)' }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {COLONNES.map((c) => (
                  <TableCell key={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{c.label}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r) => (
                <TableRow key={`${r.bukrs}-${r.anln1}-${r.anln2}-${r.afabe}`} hover>
                  {COLONNES.map((c) => (
                    <TableCell key={c.key} sx={{ whiteSpace: 'nowrap' }}>
                      {c.key === 'ktogr_immo' && r.ecart_ktogr ? (
                        <Tooltip title={`Groupe de la classe : ${r.ktogr_classe ?? '—'}`}>
                          <Chip size="small" color="warning" label={r.ktogr_immo ?? '—'} />
                        </Tooltip>
                      ) : (
                        (r[c.key] as string) ?? ''
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data && data.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={COLONNES.length} align="center">Aucune immobilisation</TableCell>
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

export default FinanceImmobilisations;
