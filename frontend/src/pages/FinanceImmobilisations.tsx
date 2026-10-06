import {
    AccountBalance as ImmobilisationIcon,
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
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

type ImmoRow = Record<string, string | number | boolean | null>;

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
  date_bascule: string | null;
}

interface ListResponse {
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

type Kind = 'text' | 'date' | 'montant' | 'nombre' | 'bool';

// Colonnes de clean_data.immobilisation, libellés de l'extraction transmise aux métiers.
// principale = affichée par défaut (toutes avec « Toutes les colonnes »).
const COLONNES: { key: string; label: string; kind?: Kind; principale?: boolean }[] = [
  { key: 'societe_sap', label: 'Société SAP' },
  { key: 'num_immobilisation', label: 'Numéro immobilisation', principale: true },
  { key: 'sous_numero', label: 'Sous-numéro', principale: true },
  { key: 'cle_immobilisation', label: 'Clé immobilisation' },
  { key: 'libelle', label: 'Libellé immobilisation', principale: true },
  { key: 'libelle_complementaire', label: 'Libellé complémentaire' },
  { key: 'classe_immo', label: 'Classe immobilisation' },
  { key: 'famille_immo', label: 'Famille immobilisation', principale: true },
  { key: 'indicateur_suppression', label: 'Indicateur suppression' },
  { key: 'numero_serie', label: 'Numéro de série' },
  { key: 'pays', label: 'Pays' },
  { key: 'groupe_evaluation_1', label: 'Groupe évaluation 1' },
  { key: 'groupe_evaluation_2', label: 'Groupe évaluation 2' },
  { key: 'groupe_evaluation_3', label: 'Groupe évaluation 3' },
  { key: 'groupe_evaluation_4', label: 'Groupe évaluation 4' },
  { key: 'projet', label: 'Projet' },
  { key: 'cle_comptes_immo', label: 'Clé détermination comptes immo' },
  { key: 'libelle_cle_comptes_immo', label: 'Libellé clé comptable immo' },
  { key: 'compte_immobilisation', label: 'Compte immobilisation SAP', principale: true },
  { key: 'compte_amort_cumule', label: 'Compte amortissement cumulé SAP' },
  { key: 'compte_dotation_amort', label: 'Compte dotation amortissement' },
  { key: 'date_acquisition', label: 'Date acquisition / capitalisation', kind: 'date', principale: true },
  { key: 'date_premiere_acquisition', label: 'Date première acquisition', kind: 'date' },
  { key: 'date_debut_amort', label: 'Date début amortissement', kind: 'date', principale: true },
  { key: 'date_fin_amort_estimee', label: 'Date fin amortissement estimée', kind: 'date' },
  { key: 'duree_amort_annees', label: 'Durée amort. années' },
  { key: 'duree_amort_periodes', label: 'Durée amort. périodes' },
  { key: 'duree_amort_totale_mois', label: 'Durée amort. totale (mois)', kind: 'nombre', principale: true },
  { key: 'zone_amortissement', label: 'Zone amortissement retenue' },
  { key: 'type_amortissement', label: 'Type amortissement' },
  { key: 'libelle_type_amortissement', label: 'Libellé type amortissement', principale: true },
  { key: 'taux_amort_estime', label: 'Taux amortissement estimé %', kind: 'nombre' },
  { key: 'centre_cout', label: 'Centre de coût', principale: true },
  { key: 'libelle_centre_cout', label: 'Libellé centre de coût' },
  { key: 'site_sap', label: 'Site SAP' },
  { key: 'secteur_sap', label: 'Secteur SAP' },
  { key: 'libelle_secteur', label: 'Libellé secteur', principale: true },
  { key: 'emplacement', label: 'Lieu / emplacement' },
  { key: 'immo_origine', label: "Immobilisation d'origine" },
  { key: 'sous_numero_origine', label: "Sous-numéro d'origine" },
  { key: 'date_origine', label: 'Date origine immobilisation', kind: 'date' },
  { key: 'numero_inventaire', label: 'Numéro inventaire' },
  { key: 'fabricant', label: 'Fabricant' },
  { key: 'type_modele', label: 'Type / modèle' },
  { key: 'fournisseur', label: 'Fournisseur' },
  { key: 'quantite', label: 'Quantité' },
  { key: 'unite', label: 'Unité' },
  { key: 'ordre_investissement', label: 'Ordre investissement' },
  { key: 'zone_valorisation', label: 'Zone valorisation retenue' },
  { key: 'exercice_valorisation', label: 'Exercice de valorisation' },
  { key: 'valeur_acq_debut_exercice', label: 'Valeur acquisition début exercice', kind: 'montant', principale: true },
  { key: 'mouvements_acq_exercice', label: 'Mouvements acquisition exercice', kind: 'montant' },
  { key: 'sorties_exercice', label: 'Sorties valeur exercice', kind: 'montant' },
  { key: 'valeur_acq_fin_exercice', label: 'Valeur acquisition fin exercice', kind: 'montant' },
  { key: 'amort_cumules', label: 'Amortissements cumulés', kind: 'montant', principale: true },
  { key: 'vnc', label: 'VNC', kind: 'montant', principale: true },
  { key: 'dotation_annuelle', label: 'Dotation annuelle comptabilisée', kind: 'montant' },
  { key: 'blocage_comptabilisation', label: 'Blocage comptabilisation' },
  { key: 'date_sortie', label: 'Date sortie', kind: 'date', principale: true },
  { key: 'date_desactivation', label: 'Date désactivation', kind: 'date' },
  // Reprise IFS (migration 098, classeur métier du 18/08/2026)
  { key: 'reprise_ifs', label: 'Reprise IFS', kind: 'bool', principale: true },
  { key: 'motif_exclusion', label: "Motif d'exclusion" },
  { key: 'compte_immobilisation_ifs', label: 'Compte immobilisation IFS', principale: true },
  { key: 'compte_amort_cumule_ifs', label: 'Compte amortissement cumulé IFS' },
  { key: 'object_group_id', label: 'Groupe objet IFS', principale: true },
  { key: 'site_ifs', label: 'Site IFS', principale: true },
  { key: 'element_otp', label: "Élément d'OTP", principale: true },
  { key: 'libelle_otp', label: 'Libellé OTP' },
];

const euros = (v: number | null | undefined) =>
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
const formatDateTime = (iso?: string | null) => (iso ? new Date(iso).toLocaleString('fr-FR') : '');

const FinanceImmobilisations: React.FC = () => {
  const navigate = useNavigate();
  const [data, setData] = useState<ListResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [secteur, setSecteur] = useState('');
  const [statut, setStatut] = useState('');
  const [reprise, setReprise] = useState('a_reprendre');
  const [toutes, setToutes] = useState(false);
  const [sync, setSync] = useState<SyncStatus | null>(null);
  const [exporting, setExporting] = useState(false);
  const [synthese, setSynthese] = useState<Synthese | null>(null);
  const [syntheseOpen, setSyntheseOpen] = useState(false);
  const [syntheseLoading, setSyntheseLoading] = useState(false);

  const colonnes = toutes ? COLONNES : COLONNES.filter((c) => c.principale);
  const filtres = { search, secteur, statut, reprise };

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.get<ListResponse>('/finance/immobilisations', {
        params: { page: page + 1, page_size: pageSize, search, secteur, statut, reprise },
      });
      setData(res.data);
      setSync(res.data.sync);
    } catch (err) {
      console.error('Erreur chargement immobilisations:', err);
      setError('Erreur lors du chargement des immobilisations');
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, secteur, statut, reprise]);

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

  // Export Excel des immobilisations filtrées (toutes les pages, toutes les colonnes + feuille Synthèse)
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

  // Synthèse (KPI + sous-totaux) sur la sélection filtrée
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
  const transcoTooltip = (categorie: string) =>
    `À compléter dans Configuration > Transcodification, catégorie ${categorie}, puis Synchroniser`;

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 2, flexWrap: 'wrap' }}>
        <ImmobilisationIcon sx={{ fontSize: 32, color: '#5d4037' }} />
        <Typography variant="h4" component="h1" sx={{ fontWeight: 600 }}>
          Immobilisations
        </Typography>
        <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
          <Button variant="outlined" startIcon={<SyntheseIcon />} onClick={handleSynthese} disabled={!data?.total}>
            Synthèse
          </Button>
          <Tooltip title="Classeur Excel des immobilisations filtrées (toutes les pages, toutes les colonnes, libellés métier) + feuille Synthèse">
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
          <Tooltip title="Ré-extrait de SAP ANLA, ANLB, ANLC, ANLZ, ANKT, T001, T095, T095T, T090NAT, CSKT, TGSBT, PRPS puis recharge la table">
            <span>
              <Button variant="contained" startIcon={<SyncIcon />} onClick={handleSync} disabled={running}>
                {running ? 'Synchronisation…' : 'Synchroniser'}
              </Button>
            </span>
          </Tooltip>
        </Box>
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Société STJN, une ligne par immobilisation. Valeurs statutaires (zone 02) à l'ouverture de
        l'exercice SAP {stats?.exercice ?? '2027'}. Reprise IFS : les immobilisations sorties au plus tard le{' '}
        {formatDate(stats?.date_bascule) || '30/06/2026'} (date de bascule, écran Valeurs par défaut) sont exclues.
      </Typography>

      {stats && (
        <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap' }}>
          <Chip label={`${stats.immobilisations.toLocaleString('fr-FR')} immobilisations`} color="primary" />
          <Chip label={`${stats.a_reprendre.toLocaleString('fr-FR')} à reprendre`} color="success" variant="outlined" />
          <Chip label={`${stats.exclues.toLocaleString('fr-FR')} exclues (sortie avant bascule)`} variant="outlined" />
          <Chip label={`Acquisition : ${euros(stats.valeur_acquisition)} €`} />
          <Chip label={`Amortissements cumulés : ${euros(stats.amort_cumules)} €`} />
          <Chip label={`VNC : ${euros(stats.vnc)} €`} color="success" />
          {stats.sans_groupe_objet > 0 && (
            <Tooltip title={transcoTooltip('FA_OBJECT_GROUP (par classe) ou FA_OBJECT_GROUP_IMMO (par fiche)')}>
              <Chip
                label={`${stats.sans_groupe_objet.toLocaleString('fr-FR')} sans groupe objet`}
                color="warning"
                onClick={() => navigate('/transcodification')}
              />
            </Tooltip>
          )}
          {stats.sans_compte_ifs > 0 && (
            <Tooltip title={transcoTooltip('FA_ACCOUNT')}>
              <Chip
                label={`${stats.sans_compte_ifs.toLocaleString('fr-FR')} sans compte IFS`}
                color="warning"
                onClick={() => navigate('/transcodification')}
              />
            </Tooltip>
          )}
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
          Dernière synchronisation le {formatDateTime(sync.finished_at)} : {sync.rows?.toLocaleString('fr-FR')} immobilisations chargées.
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
        <FormControl size="small" sx={{ minWidth: 170 }}>
          <InputLabel>Reprise IFS</InputLabel>
          <Select label="Reprise IFS" value={reprise} onChange={(e) => { setPage(0); setReprise(e.target.value); }}>
            <MenuItem value="a_reprendre">À reprendre</MenuItem>
            <MenuItem value="exclues">Exclues</MenuItem>
            <MenuItem value="">Toutes</MenuItem>
          </Select>
        </FormControl>
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
                  <TableCell key={c.key} align={c.kind === 'montant' || c.kind === 'nombre' ? 'right' : 'left'} sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>
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
                  <TableCell colSpan={colonnes.length} align="center">Aucune immobilisation</TableCell>
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
        <DialogTitle>Synthèse des immobilisations statutaires — sélection en cours</DialogTitle>
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
