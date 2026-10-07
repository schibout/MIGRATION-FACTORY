import {
    AccountBalance as ImmobilisationIcon,
    Cached as RecalculIcon,
    FileDownload as ExcelIcon,
    Search as SearchIcon,
    Summarize as SyntheseIcon,
    Sync as SyncIcon,
} from '@mui/icons-material';
import {
    Alert,
    Box,
    Button,
    Chip,
    Dialog,
    DialogContent,
    DialogTitle,
    FormControl,
    InputAdornment,
    InputLabel,
    LinearProgress,
    List,
    ListItem,
    ListItemText,
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
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

type ImmoRow = Record<string, string | number | boolean | null>;
type Kind = 'text' | 'date' | 'montant' | 'nombre' | 'bool';
type Vue = 'immobilisations' | 'travail';

interface Colonne {
  key: string;
  label: string;
  kind: Kind;
}

export interface SyncStatus {
  status: 'never' | 'running' | 'completed' | 'failed';
  step?: string;
  progress?: number;
  error?: string | null;
  rows?: number | null;
  source?: 'sap' | 'mf';
  started_at?: string;
  finished_at?: string | null;
  started_by?: string;
}

interface Stats {
  immobilisations: number;
  actives: number;
  a_reprendre: number;
  exclues: number;
  sans_compte_ifs: number;
  sans_groupe_objet: number;
  valeur_acquisition: number | null;
  amort_cumules: number | null;
  vnc: number | null;
  exercice: string | null;
  date_arrete: string | null;
  date_bascule: string | null;
}

interface ListResponse {
  vue: Vue;
  colonnes: Colonne[];
  methode: [string, string][] | null;
  rows: ImmoRow[];
  total: number;
  stats: Stats;
  secteurs: { code: string; libelle: string | null }[];
  sync: SyncStatus | null;
}

interface SyntheseLigne {
  libelle: string;
  nombre: number;
  acquisition: number | null;
  amortissements: number | null;
  vnc: number | null;
}

interface Synthese {
  kpi: SyntheseLigne & { exercice: string | null; date_situation: string | null; zone: string };
  par_type: SyntheseLigne[];
  par_famille: SyntheseLigne[];
  par_secteur: SyntheseLigne[];
  par_compte: SyntheseLigne[];
}

const SYNTHESE_BLOCS: { key: keyof Omit<Synthese, 'kpi'>; titre: string }[] = [
  { key: 'par_type', titre: "Sous-totaux par type d'amortissement" },
  { key: 'par_famille', titre: 'Sous-totaux par famille' },
  { key: 'par_secteur', titre: 'Sous-totaux par secteur' },
  { key: 'par_compte', titre: 'Sous-totaux par compte immobilisation (SAP → IFS)' },
];

export const euros = (v: number | null | undefined) =>
  v == null ? '—' : v.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatCell = (v: string | number | boolean | null, kind?: Kind) => {
  if (v == null || v === '') return '';
  if (kind === 'bool') return v ? 'Oui' : 'Non';
  if (kind === 'date') return new Date(`${v}T00:00:00`).toLocaleDateString('fr-FR');
  if (kind === 'montant') return euros(Number(v));
  if (kind === 'nombre') return Number(v).toLocaleString('fr-FR');
  return String(v);
};

const formatDate = (iso?: string | null) => (iso ? new Date(`${iso}T00:00:00`).toLocaleDateString('fr-FR') : '');
export const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

// Bandeau d'état de la synchronisation (partagé avec l'écran Comptes)
export const SyncAlerts: React.FC<{ sync: SyncStatus | null }> = ({ sync }) => (
  <>
    {sync?.status === 'running' && (
      <Alert severity="info" sx={{ mb: 2 }}>
        {sync.step} — démarrée le {formatDateTime(sync.started_at)}
        {sync.source === 'mf' ? ' (rechargement Migration Factory)' : ' (synchronisation SAP)'}
        <LinearProgress variant="determinate" value={sync.progress ?? 0} sx={{ mt: 1 }} />
      </Alert>
    )}
    {sync?.status === 'completed' && (
      <Alert severity="success" sx={{ mb: 2 }}>
        Dernier rechargement le {formatDateTime(sync.finished_at)}
        {sync.source === 'mf' ? ' (Migration Factory)' : ' (SAP)'} : {sync.rows?.toLocaleString('fr-FR')} immobilisations chargées.
      </Alert>
    )}
    {sync?.status === 'failed' && (
      <Alert severity="error" sx={{ mb: 2 }}>
        Rechargement en échec le {formatDateTime(sync.finished_at)} : {sync.error}
      </Alert>
    )}
  </>
);

const FinanceImmobilisations: React.FC = () => {
  const navigate = useNavigate();
  const [vue, setVue] = useState<Vue>('immobilisations');
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [secteur, setSecteur] = useState('');
  const [statut, setStatut] = useState('');
  const [reprise, setReprise] = useState('');
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);
  const [synthese, setSynthese] = useState<Synthese | null>(null);
  const [syntheseOpen, setSyntheseOpen] = useState(false);
  const [syntheseLoading, setSyntheseLoading] = useState(false);

  const filtres = { vue, search, secteur, statut, reprise };

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/immobilisations', {
        params: { page: page + 1, page_size: pageSize, ...filtres },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement immobilisations:', err);
      setError('Erreur lors du chargement des immobilisations');
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, pageSize, vue, search, secteur, statut, reprise]);

  useEffect(() => {
    load();
  }, [load]);

  // Suivi du rechargement en cours (rafraîchissement de la liste à la fin)
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

  // source 'sap' = ré-extraction SAP puis rechargement ; 'mf' = rechargement seul
  // depuis les tables SAP déjà extraites (applique transcodifications et valeurs par défaut)
  const handleSync = async (source: 'sap' | 'mf') => {
    try {
      setError(null);
      const res = await api.post<SyncStatus>('/finance/immobilisations/sync', { source });
      setSync(res.data);
    } catch (err: any) {
      if (err?.response?.status === 409) {
        setSync(err.response.data);
      } else {
        setError('Impossible de lancer le rechargement');
      }
    }
  };

  // Export Excel = le classeur complet : Immobilisations, Travail, Conversion cpte général,
  // TRansco comptes generaux, Synthèse (filtres de l'écran appliqués)
  const handleExportExcel = async () => {
    try {
      setExporting(true);
      setError(null);
      const res = await api.get('/finance/immobilisations/export.xlsx', {
        params: filtres,
        responseType: 'blob',
      });
      const match = /filename="?([^";]+)"?/.exec(res.headers['content-disposition'] ?? '');
      const url = window.URL.createObjectURL(res.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = match?.[1] ?? 'immobilisations.xlsx';
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Erreur export Excel immobilisations:', err);
      setError("Erreur lors de l'export Excel");
    } finally {
      setExporting(false);
    }
  };

  const handleSynthese = async () => {
    try {
      setSyntheseLoading(true);
      setSyntheseOpen(true);
      const res = await api.get<Synthese>('/finance/immobilisations/synthese', { params: filtres });
      setSynthese(res.data);
    } catch (err) {
      console.error('Erreur synthèse immobilisations:', err);
      setError('Erreur lors du calcul de la synthèse');
      setSyntheseOpen(false);
    } finally {
      setSyntheseLoading(false);
    }
  };

  const running = sync?.status === 'running';
  const stats = data?.stats;
  const colonnes = data?.colonnes ?? [];
  const transcoTooltip = (categorie: string) =>
    `À compléter dans ${categorie}, puis « Recalculer »`;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ImmobilisationIcon sx={{ fontSize: 32, color: '#5d4037' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Immobilisations
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1, flexWrap: 'wrap' }}>
          <Button variant="outlined" startIcon={<SyntheseIcon />} onClick={handleSynthese} disabled={!data?.total}>
            Synthèse
          </Button>
          <Tooltip title="Classeur Excel complet : Immobilisations, Travail, Conversion cpte général, TRansco comptes generaux, Synthèse (filtres de l'écran appliqués)">
            <span>
              <Button variant="outlined" color="success" startIcon={<ExcelIcon />} onClick={handleExportExcel} disabled={exporting || !data?.total}>
                {exporting ? 'Export…' : 'Exporter Excel'}
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Recharge la table depuis les tables SAP déjà extraites dans Migration Factory : applique les transcodifications (comptes, groupes objet) et la date de bascule, sans appeler SAP">
            <span>
              <Button variant="outlined" startIcon={<RecalculIcon />} onClick={() => handleSync('mf')} disabled={running}>
                Recalculer
              </Button>
            </span>
          </Tooltip>
          <Tooltip title="Ré-extrait de SAP ANLA, ANLB, ANLC, ANLZ, ANKT, T001, T095, T095T, T090NAT, CSKT, TGSBT, PRPS puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={() => handleSync('sap')} disabled={running}>
                {running ? 'Rechargement…' : 'Synchroniser SAP'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Tabs value={vue} onChange={(_, v: Vue) => { setVue(v); setPage(0); }} sx={{ mb: 2 }}>
        <Tab value="immobilisations" label="Immobilisations (extraction SAP)" />
        <Tab value="travail" label="Travail (reprise IFS)" />
      </Tabs>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        {vue === 'immobilisations'
          ? `Société STJN, une ligne par immobilisation, les 60 colonnes de l'extraction transmise aux métiers. Valeurs statutaires (zone 02) de l'exercice SAP ${stats?.exercice ?? '2027'}, arrêtées au ${stats?.date_arrete ? new Date(stats.date_arrete).toLocaleDateString('fr-FR') : 'dernier mois clôturé'}.`
          : `Onglet « Travail » du classeur métier, fabriqué selon la Méthode : immobilisations à reprendre (sortie après le ${formatDate(stats?.date_bascule) || '30/06/2026'}, date de bascule paramétrée dans Valeurs par défaut), date de sortie effacée, tri par date d'acquisition, OBJECT_GROUP_ID et colonnes converties pour IFS.`}
      </Typography>

      {vue === 'travail' && data?.methode && (
        <Paper variant="outlined" sx={{ mb: 2, px: 2 }}>
          <List dense>
            {data.methode.map(([etape, automatisation]) => (
              <ListItem key={etape} disableGutters>
                <ListItemText primary={etape} secondary={`→ ${automatisation}`} />
              </ListItem>
            ))}
          </List>
        </Paper>
      )}

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.immobilisations.toLocaleString('fr-FR')} immobilisations`} color="primary" />
          {vue === 'immobilisations' && reprise === '' && (
            <>
              <Chip label={`${stats.a_reprendre.toLocaleString('fr-FR')} à reprendre`} color="success" variant="outlined" />
              <Chip label={`${stats.exclues.toLocaleString('fr-FR')} exclues (sortie avant bascule)`} variant="outlined" />
            </>
          )}
          <Chip label={`Acquisition : ${euros(stats.valeur_acquisition)} €`} />
          <Chip label={`Amortissements cumulés : ${euros(stats.amort_cumules)} €`} />
          <Chip label={`VNC : ${euros(stats.vnc)} €`} color="success" />
          {stats.sans_groupe_objet > 0 && (
            <Tooltip title={transcoTooltip('Configuration > Transcodification (FA_OBJECT_GROUP par classe, FA_OBJECT_GROUP_IMMO par fiche)')}>
              <Chip label={`${stats.sans_groupe_objet.toLocaleString('fr-FR')} sans groupe objet`} color="warning" onClick={() => navigate('/transcodification')} />
            </Tooltip>
          )}
          {stats.sans_compte_ifs > 0 && (
            <Tooltip title={transcoTooltip('Finance > Comptes')}>
              <Chip label={`${stats.sans_compte_ifs.toLocaleString('fr-FR')} sans compte IFS`} color="warning" onClick={() => navigate('/finance/comptes')} />
            </Tooltip>
          )}
        </Box>
      )}

      <SyncAlerts sync={sync} />
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        <TextField
          size="small"
          placeholder="N° immo, libellé, famille, centre de coût, inventaire, compte…"
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
        {vue === 'immobilisations' && (
          <FormControl size="small" sx={{ minWidth: 170 }}>
            <InputLabel>Reprise IFS</InputLabel>
            <Select label="Reprise IFS" value={reprise} onChange={(e) => { setPage(0); setReprise(e.target.value); }}>
              <MenuItem value="">Toutes</MenuItem>
              <MenuItem value="a_reprendre">À reprendre</MenuItem>
              <MenuItem value="exclues">Exclues</MenuItem>
            </Select>
          </FormControl>
        )}
        <FormControl size="small" sx={{ minWidth: 220 }}>
          <InputLabel>Secteur</InputLabel>
          <Select label="Secteur" value={secteur} onChange={(e) => { setPage(0); setSecteur(e.target.value); }}>
            <MenuItem value="">Tous</MenuItem>
            {data?.secteurs.map((s) => (
              <MenuItem key={s.code} value={s.code}>{s.code}{s.libelle ? ` — ${s.libelle}` : ''}</MenuItem>
            ))}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Statut</InputLabel>
          <Select label="Statut" value={statut} onChange={(e) => { setPage(0); setStatut(e.target.value); }}>
            <MenuItem value="">Toutes</MenuItem>
            <MenuItem value="actives">Actives</MenuItem>
            <MenuItem value="desactivees">Désactivées</MenuItem>
          </Select>
        </FormControl>
      </Box>

      <Paper>
        {loading && <LinearProgress />}
        <TableContainer sx={{ maxHeight: 'calc(100vh - 440px)' }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {colonnes.map((c) => (
                  <TableCell
                    key={c.key}
                    align={c.kind === 'montant' || c.kind === 'nombre' ? 'right' : 'left'}
                    sx={{ fontWeight: 600, minWidth: 120, maxWidth: 220, verticalAlign: 'top', lineHeight: 1.2 }}
                  >
                    {c.label}
                  </TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {data?.rows.map((r) => (
                <TableRow
                  key={`${r.num_immobilisation}-${r.sous_numero}`}
                  hover
                  sx={r.reprise_ifs === false ? { '& td': { color: 'text.disabled' } } : undefined}
                >
                  {colonnes.map((c) => (
                    <TableCell key={c.key} align={c.kind === 'montant' || c.kind === 'nombre' ? 'right' : 'left'} sx={{ whiteSpace: 'nowrap' }}>
                      {c.key === 'reprise_ifs' && r.reprise_ifs === false ? (
                        <Tooltip title={String(r.motif_exclusion ?? '')}>
                          <Chip size="small" label="Exclue" />
                        </Tooltip>
                      ) : (
                        formatCell(r[c.key], c.kind)
                      )}
                    </TableCell>
                  ))}
                </TableRow>
              ))}
              {data && data.rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={Math.max(colonnes.length, 1)} align="center">Aucune immobilisation</TableCell>
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

      <Dialog open={syntheseOpen} onClose={() => setSyntheseOpen(false)} maxWidth="lg" fullWidth>
        <DialogTitle>Synthèse des immobilisations statutaires — {vue === 'travail' ? 'onglet Travail' : 'sélection en cours'}</DialogTitle>
        <DialogContent>
          {syntheseLoading && <LinearProgress sx={{ mb: 2 }} />}
          {synthese && (
            <>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                Société STJN · Date de situation {synthese.kpi.date_situation ?? '—'} · Exercice SAP {synthese.kpi.exercice ?? '—'} · Zone {synthese.kpi.zone}
              </Typography>
              <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
                <Chip label={`${synthese.kpi.nombre.toLocaleString('fr-FR')} immobilisations`} color="primary" />
                <Chip label={`Acquisition : ${euros(synthese.kpi.acquisition)} €`} />
                <Chip label={`Amortissements cumulés : ${euros(synthese.kpi.amortissements)} €`} />
                <Chip label={`VNC : ${euros(synthese.kpi.vnc)} €`} color="success" />
              </Box>
              {SYNTHESE_BLOCS.map((bloc) => (
                <TableContainer key={bloc.key} component={Paper} variant="outlined" sx={{ mb: 2 }}>
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell sx={{ fontWeight: 600 }}>{bloc.titre}</TableCell>
                        <TableCell align="right" sx={{ fontWeight: 600 }}>Nombre</TableCell>
                        <TableCell align="right" sx={{ fontWeight: 600 }}>Acquisition</TableCell>
                        <TableCell align="right" sx={{ fontWeight: 600 }}>Amortissements cumulés</TableCell>
                        <TableCell align="right" sx={{ fontWeight: 600 }}>VNC</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {synthese[bloc.key].map((l) => (
                        <TableRow key={l.libelle} hover>
                          <TableCell>{l.libelle}</TableCell>
                          <TableCell align="right">{l.nombre.toLocaleString('fr-FR')}</TableCell>
                          <TableCell align="right">{euros(l.acquisition)}</TableCell>
                          <TableCell align="right">{euros(l.amortissements)}</TableCell>
                          <TableCell align="right">{euros(l.vnc)}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              ))}
            </>
          )}
        </DialogContent>
      </Dialog>
    </Box>
  );
};

export default FinanceImmobilisations;
