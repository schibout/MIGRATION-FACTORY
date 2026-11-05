import {
    Cached as RecalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    InputAdornment,
    LinearProgress,
    Paper,
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
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import api from '../../services/api';

// Écran de consultation Données IFS (api/ifs_consultation.py), même logique que FinanceHistoriqueCouts :
// onglets, liste paginée, export Excel, Recalculer / Synchroniser SAP. L'onglet 'mode_emploi' affiche le guide.

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

interface Colonne { key: string; label: string; kind: 'bool' | 'text' }
interface SourceInfo { key: string; label: string; lignes: number }

interface ListResponse {
  table: string;
  tables: SourceInfo[];
  rows: Row[];
  total: number;
  entites: number;
  colonnes: Colonne[];
  sync: SyncStatus | null;
}

export interface OngletConsultation { value: string; label: string; description: string; placeholder?: string }

interface Props {
  titre: string;
  icone: React.ReactNode;
  apiUrl: string;
  guide?: string; // requis si un onglet 'mode_emploi' existe
  onglets: OngletConsultation[];
  placeholder: string;
  entite: string; // pluriel affiché sur le compteur : « 1 927 fournisseurs »
  fichierExport: string;
  // Sans ces aides, l'écran est en consultation seule : pas de bouton de rechargement
  aideRecalculer?: string;
  aideSynchroniser?: string;
  libelleSynchroniser?: string; // « Synchroniser ASAP » pour les projets
  sansSynchronisation?: string; // source fichier : bouton grisé, avec la raison
  libelleRecharge?: string; // « 1 841 fournisseurs chargés »
  noteEchec?: string;
}

const nombre = (v: number) => v.toLocaleString('fr-FR');
const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');
const formatCell = (v: Row[string], kind: Colonne['kind']) => {
  if (kind === 'bool') return v ? 'Oui' : 'Non';
  return v == null ? '' : String(v);
};

const IfsConsultationPage: React.FC<Props> = ({
  titre, icone, apiUrl, guide, onglets, placeholder, entite, fichierExport,
  aideRecalculer, aideSynchroniser, libelleSynchroniser = 'Synchroniser SAP', sansSynchronisation, libelleRecharge, noteEchec,
}) => {
  const [searchParams] = useSearchParams(); // ?onglet=controles depuis le tableau de bord
  const [onglet, setOnglet] = useState(
    () => onglets.find((o) => o.value === searchParams.get('onglet'))?.value ?? onglets[0].value,
  );
  const [table, setTable] = useState('');
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);
  const derniereRequete = useRef(0); // une réponse lente ne doit pas écraser l'onglet affiché

  const load = useCallback(async () => {
    if (onglet === 'mode_emploi') return;
    const requete = ++derniereRequete.current;
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>(apiUrl, {
        params: { onglet, table, search, page: page + 1, page_size: pageSize },
      });
      if (requete !== derniereRequete.current) return;
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      if (requete !== derniereRequete.current) return;
      console.error(`Erreur chargement ${titre}:`, err);
      setError(`Erreur lors du chargement : ${titre}`);
    } finally {
      if (requete === derniereRequete.current) setLoading(false);
    }
  }, [apiUrl, titre, onglet, table, search, page, pageSize]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi de la synchronisation en cours (rechargement de la liste à la fin)
  useEffect(() => {
    if (sync?.status !== 'running') return undefined;
    const timer = setInterval(async () => {
      try {
        const res = await api.get<SyncStatus>(`${apiUrl}/sync`);
        setSync(res.data);
        if (res.data.status !== 'running') load();
      } catch (err) {
        console.error('Erreur statut synchronisation:', err);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, [apiUrl, sync?.status, load]);

  // 'sap' : extraction SAP puis rechargement ; 'mf' : rechargement seul
  const handleSync = async (source: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>(`${apiUrl}/sync`, { source });
      setSync(res.data);
    } catch (err: any) {
      const refus = err?.response?.data;
      if (err?.response?.status === 409 && refus?.status) setSync(refus); // déjà en cours : on suit ce traitement
      else if (refus?.message || refus?.error) setError(refus.message ?? refus.error);
      else setError('Impossible de lancer la synchronisation');
    }
  };

  const handleExport = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get(`${apiUrl}/export.xlsx`, { params: { onglet, search }, responseType: 'blob' });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? fichierExport;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error(`Erreur export Excel ${titre}:`, err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const changerOnglet = (v: string) => {
    setOnglet(v);
    setTable('');
    setPage(0);
    setData(null);
  };

  const running = sync?.status === 'running';
  const colonnes = data?.colonnes ?? [];
  const tables = data?.tables ?? [];
  const consultation = onglet !== 'mode_emploi';
  const ongletActif = onglets.find((o) => o.value === onglet);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        {icone}
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          {titre}
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Tooltip title="Classeur Excel de l'onglet affiché : une feuille par table, recherche appliquée">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExport} disabled={exporting || !consultation || !data}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          {aideRecalculer && (
            <Tooltip title={aideRecalculer}>
              <span>
                <Button variant="outlined" startIcon={<RecalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                  Calculer
                </Button>
              </span>
            </Tooltip>
          )}
          {aideSynchroniser && (
            <Tooltip title={aideSynchroniser}>
              <span>
                <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                  {running ? 'Synchronisation…' : libelleSynchroniser}
                </Button>
              </span>
            </Tooltip>
          )}
          {sansSynchronisation && (
            <Tooltip title={sansSynchronisation}>
              <span>
                <Button variant="contained" startIcon={<SyncIcon />} disabled>{libelleSynchroniser}</Button>
              </span>
            </Tooltip>
          )}
        </Box>
      </Box>

      <Tabs value={onglet} onChange={(_, v: string) => changerOnglet(v)} variant="scrollable" scrollButtons="auto" sx={{ mb: 2 }}>
        {onglets.map((o) => <Tab key={o.value} value={o.value} label={o.label} />)}
      </Tabs>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        {ongletActif?.description}
      </Typography>

      {running && (
        <Alert severity="info" sx={{ mb: 2 }}>
          {sync?.step} — démarrée le {formatDateTime(sync?.started_at)}. La liste reste en attente tant que le rechargement n'est pas terminé.
          <LinearProgress variant="determinate" value={sync?.progress ?? 0} sx={{ mt: 1 }} />
        </Alert>
      )}
      {sync?.status === 'completed' && (
        <Alert severity="success" sx={{ mb: 2 }}>
          Dernier rechargement le {formatDateTime(sync.finished_at)} : {nombre(sync.rows ?? 0)} {libelleRecharge}.
        </Alert>
      )}
      {sync?.status === 'failed' && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Rechargement en échec le {formatDateTime(sync.finished_at)} : {sync.error}. {noteEchec}
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      {!consultation ? (
        <Box
          component="iframe"
          src={guide}
          title={`Mode d'emploi : ${titre}`}
          sx={{ width: '100%', height: 'calc(100vh - 300px)', minHeight: 500, border: 1, borderColor: 'divider', borderRadius: 1, bgcolor: 'background.paper' }}
        />
      ) : (<>
      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder={ongletActif?.placeholder ?? placeholder}
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              setPage(0);
              setSearch(searchInput);
            }
          }}
          sx={{ minWidth: 340 }}
          InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
        />
        {data && (<>
          <Chip label={`${nombre(data.entites)} ${entite}`} color="primary" />
          <Chip label={`${nombre(data.total)} lignes`} />
        </>)}
      </Box>

      {tables.length > 1 && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          {tables.map((t) => (
            <Chip
              key={t.key}
              label={`${t.label} (${nombre(t.lignes)})`}
              color={t.key === data?.table ? 'primary' : onglet === 'controles' && t.lignes > 0 ? 'warning' : 'default'}
              variant={t.key === data?.table ? 'filled' : 'outlined'}
              onClick={() => { setTable(t.key); setPage(0); }}
            />
          ))}
        </Box>
      )}

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 460px)', minHeight: 300 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell key={c.key} title={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{c.label}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r, i) => (
                <TableRow key={i} hover>
                  {colonnes.map((c) => (
                    <TableCell key={c.key} sx={{ whiteSpace: 'nowrap' }}>{formatCell(r[c.key], c.kind)}</TableCell>
                  ))}
                </TableRow>
              ))}
              {data?.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={colonnes.length || 1} align="center">Aucune ligne</TableCell>
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
      </>)}
    </Box>
  );
};

export default IfsConsultationPage;
