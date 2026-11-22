import {
    Cached as RecalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Sync as SyncIcon,
    ViewColumn as ViewColumnIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Checkbox,
    Chip,
    Divider,
    InputAdornment,
    LinearProgress,
    ListItemText,
    Menu,
    MenuItem,
    Paper,
    Tab,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TablePagination,
    TableRow,
    TableSortLabel,
    Tabs,
    TextField,
    Tooltip,
    Typography,
} from '@mui/material';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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

// Colonnes masquées par table, mémorisées dans le navigateur (simple confort, sans enjeu)
type Masquees = Record<string, string[]>;
const lireMasquees = (cle: string): Masquees => {
  try { return JSON.parse(localStorage.getItem(cle) ?? '{}') as Masquees; } catch { return {}; }
};

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
  const cleColonnes = `ifs-colonnes:${apiUrl}`;
  const [masquees, setMasquees] = useState<Masquees>(() => lireMasquees(cleColonnes));
  const [menuColonnes, setMenuColonnes] = useState<HTMLElement | null>(null);
  // Tri et filtres par colonne, côté serveur (liste paginée) ; remis à zéro au changement de table
  const [tri, setTri] = useState<{ cle: string; sens: 'asc' | 'desc' } | null>(null);
  const [filtres, setFiltres] = useState<Record<string, string>>({});
  const [saisieFiltres, setSaisieFiltres] = useState<Record<string, string>>({});
  const derniereRequete = useRef(0); // une réponse lente ne doit pas écraser l'onglet affiché

  const paramsColonnes = useMemo(() => {
    const actifs = Object.fromEntries(Object.entries(filtres).filter(([, v]) => v.trim()));
    return {
      ...(tri ? { tri: tri.cle, sens: tri.sens } : {}),
      ...(Object.keys(actifs).length ? { filtres: JSON.stringify(actifs) } : {}),
    };
  }, [tri, filtres]);

  const load = useCallback(async () => {
    if (onglet === 'mode_emploi') return;
    const requete = ++derniereRequete.current;
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>(apiUrl, {
        params: { onglet, table, search, page: page + 1, page_size: pageSize, ...paramsColonnes },
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
  }, [apiUrl, titre, onglet, table, search, page, pageSize, paramsColonnes]);

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
      const res = await api.get(`${apiUrl}/export.xlsx`, { params: { onglet, search, table: data?.table, ...paramsColonnes }, responseType: 'blob' });
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

  const reinitialiserColonnes = () => {
    setTri(null);
    setFiltres({});
    setSaisieFiltres({});
  };

  const changerOnglet = (v: string) => {
    setOnglet(v);
    reinitialiserColonnes();
    setTable('');
    setPage(0);
    setData(null);
  };

  const running = sync?.status === 'running';
  const toutesColonnes = data?.colonnes ?? [];
  const masqueesTable = masquees[data?.table ?? ''] ?? [];
  const colonnes = toutesColonnes.filter((c) => !masqueesTable.includes(c.key));
  const masquer = (cles: string[]) => {
    if (!data) return;
    const suivant = { ...masquees, [data.table]: cles };
    setMasquees(suivant);
    try { localStorage.setItem(cleColonnes, JSON.stringify(suivant)); } catch { /* stockage indisponible */ }
  };
  const trier = (cle: string) => {
    // croissant -> décroissant -> sans tri
    setTri((t) => (t?.cle !== cle ? { cle, sens: 'asc' } : t.sens === 'asc' ? { cle, sens: 'desc' } : null));
    setPage(0);
  };
  const appliquerFiltres = () => {
    setFiltres(saisieFiltres);
    setPage(0);
  };
  const nbFiltres = Object.values(filtres).filter((v) => v.trim()).length;
  const basculer = (cle: string) =>
    masquer(masqueesTable.includes(cle) ? masqueesTable.filter((k) => k !== cle) : [...masqueesTable, cle]);
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
          <Tooltip title="Choisir les colonnes affichées (mémorisé pour cette table)">
            <Button size="small" variant="outlined" startIcon={<ViewColumnIcon />} onClick={(e) => setMenuColonnes(e.currentTarget)}>
              Colonnes ({colonnes.length}/{toutesColonnes.length})
            </Button>
          </Tooltip>
          {(nbFiltres > 0 || tri) && (
            <Button size="small" onClick={() => { reinitialiserColonnes(); setPage(0); }}>
              Effacer tri et filtres{nbFiltres > 0 ? ` (${nbFiltres})` : ''}
            </Button>
          )}
          <Menu
            anchorEl={menuColonnes}
            open={Boolean(menuColonnes)}
            onClose={() => setMenuColonnes(null)}
            slotProps={{ paper: { sx: { maxHeight: 460 } } }}
          >
            <Box sx={{ display: 'flex', gap: 1, px: 2, py: 0.5 }}>
              <Button size="small" onClick={() => masquer([])}>Tout afficher</Button>
              <Button size="small" onClick={() => masquer(toutesColonnes.map((c) => c.key))}>Tout masquer</Button>
            </Box>
            <Divider />
            {toutesColonnes.map((c) => (
              <MenuItem key={c.key} dense onClick={() => basculer(c.key)}>
                <Checkbox size="small" checked={!masqueesTable.includes(c.key)} sx={{ p: 0.5, mr: 1 }} />
                <ListItemText primary={c.label} secondary={c.key} primaryTypographyProps={{ variant: 'body2' }} />
              </MenuItem>
            ))}
          </Menu>
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
              onClick={() => { setTable(t.key); setPage(0); reinitialiserColonnes(); }}
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
                  <TableCell key={c.key} title={c.key} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}
                    sortDirection={tri?.cle === c.key ? tri.sens : false}>
                    <TableSortLabel
                      active={tri?.cle === c.key}
                      direction={tri?.cle === c.key ? tri.sens : 'asc'}
                      onClick={() => trier(c.key)}
                    >
                      {c.label}
                    </TableSortLabel>
                  </TableCell>
                ))}
              </TableRow>
              <TableRow>
                {colonnes.map((c) => (
                  // top = hauteur de la ligne d'en-tête, pour rester visible au défilement
                  <TableCell key={c.key} sx={{ py: 0.5, top: 37 }}>
                    <TextField
                      size="small"
                      variant="standard"
                      placeholder="Filtrer…"
                      value={saisieFiltres[c.key] ?? ''}
                      onChange={(e) => setSaisieFiltres((f) => ({ ...f, [c.key]: e.target.value }))}
                      onKeyDown={(e) => { if (e.key === 'Enter') appliquerFiltres(); }}
                      onBlur={() => { if ((saisieFiltres[c.key] ?? '') !== (filtres[c.key] ?? '')) appliquerFiltres(); }}
                      inputProps={{ 'aria-label': `Filtrer ${c.label}` }}
                      sx={{ minWidth: 90 }}
                    />
                  </TableCell>
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
